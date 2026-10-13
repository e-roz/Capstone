using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Turns stored verification rows into the evidence panel the reviewer reads.
    /// </summary>
    /// <remarks>
    /// Pure and stateless, like the other helpers here — it decides nothing and
    /// writes nothing. <see cref="PreScreeningService"/> forms the opinions at
    /// submission time; this only arranges them.
    ///
    /// Two things are deliberately recomputed here rather than replayed from the
    /// stored <see cref="CheckResult"/>:
    ///
    /// The expiry checks, because "expired" is a fact about today, not about the
    /// day the documents were scanned. An application that waited three weeks in
    /// the queue must not still claim a licence is valid.
    ///
    /// The per-check wording, so the banner and the rows can never disagree —
    /// both are built from the same values in the same pass.
    /// </remarks>
    public static class RegistrationChecks
    {
        /// <summary>
        /// How close an expiry has to be before the reviewer is warned.
        /// </summary>
        /// <remarks>
        /// Nothing re-checks a document after approval, so a licence lapsing next
        /// month means a card that keeps opening the gate against a dead licence.
        /// This is the only place that number lives.
        /// </remarks>
        public const int ExpiringSoonDays = 30;

        public const string ClearVerdict = "Clear";

        public const string Passed = "Passed";
        public const string ExpiringSoon = "ExpiringSoon";
        public const string Failed = "Failed";
        public const string NotChecked = "NotChecked";

        /// <summary>
        /// Builds the panel, or null when the applicant never submitted documents.
        /// </summary>
        public static RegistrationChecksResponse? Build(
            User user,
            IReadOnlyList<DocumentVerification> verifications,
            IReadOnlyList<Vehicle> vehicles,
            DateTime nowUtc)
        {
            if (verifications.Count == 0)
                return null;

            var newestFirst = verifications.OrderByDescending(v => v.CreatedAt).ToList();

            // Not simply the newest row. A submission that only adds a vehicle
            // carries no name or licence, and reading the person's checks off it
            // would report "could not compare names" about documents that were
            // read perfectly well on an earlier submission.
            var personRow = newestFirst.FirstOrDefault(HasPersonReadings) ?? newestFirst[0];

            var response = new RegistrationChecksResponse
            {
                EvaluatedAt = nowUtc,
                Person = new CheckGroupResponse
                {
                    Title = "Checks on the person",
                    Source = user.Affiliation == Affiliation.Student
                        ? "School form + Driver's licence"
                        : "Driver's licence",
                    Checks = BuildPersonChecks(personRow, user, nowUtc)
                },
                Edits = BuildEdits(personRow)
            };

            if (vehicles.Count > 0)
            {
                for (var i = 0; i < vehicles.Count; i++)
                {
                    var vehicle = vehicles[i];

                    // The row that covers this vehicle. Falling back to the newest
                    // row matters for older submissions saved before VehicleId was
                    // being set, which would otherwise show a vehicle with no
                    // checks at all.
                    var row = newestFirst.FirstOrDefault(v => v.VehicleId == vehicle.Id)
                              ?? newestFirst[0];

                    response.Vehicles.Add(new CheckGroupResponse
                    {
                        Title = vehicles.Count > 1
                            ? $"Checks on Vehicle {i + 1} · {Display(vehicle.PlateNumber)}"
                            : $"Checks on the vehicle · {Display(vehicle.PlateNumber)}",
                        Source = "Official Receipt",
                        Checks = BuildVehicleChecks(row, nowUtc)
                    });
                }
            }
            else
            {
                // No vehicle record yet, but the receipt was still read. Showing the
                // readings is what tells the reviewer why no vehicle was created.
                response.Vehicles.Add(new CheckGroupResponse
                {
                    Title = "Checks on the vehicle",
                    Source = "Official Receipt",
                    Checks = BuildVehicleChecks(newestFirst[0], nowUtc)
                });
            }

            Summarise(response);

            response.Findings = BuildFindings(response, personRow, user, vehicles, newestFirst, nowUtc);
            response.Facts = BuildFacts(personRow, user, vehicles, newestFirst);
            response.Readings = BuildReadings(personRow, user, vehicles, newestFirst);
            return response;
        }

        // ── Person ───────────────────────────────────────────────────────────

        private static List<CheckItemResponse> BuildPersonChecks(
            DocumentVerification v, User user, DateTime nowUtc)
        {
            var checks = new List<CheckItemResponse>();

            // Faculty and staff submit a school ID these rules do not read, so
            // there is no school-form name to show them — but the licence is
            // still checked against their account name, so the row is still
            // worth showing, just with one fewer piece of evidence.
            var schoolName = user.Affiliation == Affiliation.Student
                ? v.ConfirmedStudentName ?? v.ExtractedStudentName
                : null;
            var licenseName = v.ConfirmedLicenseName ?? v.ExtractedLicenseName;

            var name = new CheckItemResponse { Key = "NameMatch", Label = "Name matches" };

            name.State = v.NameMatch switch
            {
                CheckResult.Passed => Passed,
                CheckResult.Failed => Failed,
                _ => NotChecked
            };

            name.Detail = name.State switch
            {
                Failed when v.LicenseNameFound == false =>
                    "Name mismatch — the name on file does not appear to be printed on the licence.",
                Failed =>
                    $"Name mismatch — the account reads \"{user.FullName}\", the school document reads \"{schoolName}\".",
                NotChecked => "Could not compare names — no readable name came off the documents.",
                _ => null
            };

            if (!string.IsNullOrWhiteSpace(schoolName))
                AddValue(name, "School form", schoolName);
            AddValue(name, "Licence", licenseName);
            checks.Add(name);

            checks.Add(ExpiryCheck(
                key: "LicenseValidity",
                label: "Licence still valid",
                expiry: v.ConfirmedLicenseExpiry ?? v.ExtractedLicenseExpiry,
                valueLabel: "Read from licence",
                unreadable: "Could not read the licence expiry date.",
                expiredWord: "The driver's licence expired on",
                soonWord: "Driver's licence expires",
                nowUtc: nowUtc));

            if (user.Affiliation == Affiliation.Student)
            {
                var semester = v.ConfirmedSemester ?? v.ExtractedSemester;
                var enrolment = new CheckItemResponse { Key = "EnrollmentValidity", Label = "Enrolment" };

                // Never Passed. The system does not know what the current term is,
                // so reading "1st Term 2026-2027" off the form proves nothing about
                // whether the applicant is enrolled now; a green tick here used to
                // say otherwise. The reviewer confirms it.
                enrolment.State = NotChecked;

                if (string.IsNullOrWhiteSpace(semester))
                {
                    enrolment.Detail = "Could not read the term from the school document.";
                }
                else
                {
                    enrolment.Detail = $"School document reads {semester}. The system does not know the current term. Confirm it yourself.";
                    AddValue(enrolment, "Semester", semester);
                }

                checks.Add(enrolment);
            }

            return checks;
        }

        // ── Vehicle ──────────────────────────────────────────────────────────

        private static List<CheckItemResponse> BuildVehicleChecks(
            DocumentVerification v, DateTime nowUtc)
        {
            var checks = new List<CheckItemResponse>();

            var fromReceipt = IdentifierNormalizer.NormalizePlate(v.ExtractedPlateNumber);
            var committed = IdentifierNormalizer.NormalizePlate(v.ConfirmedPlateNumber);
            var onFile = committed.Length == 0 ? fromReceipt : committed;

            var plate = new CheckItemResponse { Key = "PlateMatch", Label = "Plate on file" };

            if (onFile.Length == 0)
            {
                plate.State = NotChecked;
                plate.Detail = "Could not read a plate number from the receipt.";
            }
            else
            {
                // No corroborating photo any more — a difference from the OCR
                // reading is a user correction, not a failure. It is surfaced
                // separately, in Edits, where the reviewer can check it against the
                // receipt image.
                plate.State = v.PlateMatch == CheckResult.Passed ? Passed : NotChecked;
            }

            AddValue(plate, "Receipt", fromReceipt);
            AddValue(plate, "On file", onFile);
            checks.Add(plate);

            checks.Add(ExpiryCheck(
                key: "RegistrationValidity",
                label: "Registration valid",
                expiry: v.ConfirmedRegistrationExpiry ?? v.ExtractedRegistrationExpiry,
                valueLabel: "Valid until",
                unreadable: "Could not determine when the vehicle registration expires.",
                expiredWord: "The vehicle registration expired on",
                soonWord: "Vehicle registration expires",
                nowUtc: nowUtc));

            return checks;
        }

        // ── Expiry ───────────────────────────────────────────────────────────

        /// <summary>
        /// The only check with three healthy outcomes: fine, running out, gone.
        /// </summary>
        private static CheckItemResponse ExpiryCheck(
            string key, string label, DateTime? expiry, string valueLabel,
            string unreadable, string expiredWord, string soonWord, DateTime nowUtc)
        {
            var check = new CheckItemResponse { Key = key, Label = label };

            if (expiry is null)
            {
                check.State = NotChecked;
                check.Detail = unreadable;
                return check;
            }

            var date = expiry.Value.Date;
            var today = nowUtc.Date;
            var days = (date - today).Days;

            if (days < 0)
            {
                check.State = Failed;
                check.Detail = $"{expiredWord} {date:MMMM d, yyyy}.";
            }
            else if (days <= ExpiringSoonDays)
            {
                check.State = ExpiringSoon;
                check.Detail = days == 0
                    ? $"{soonWord} today ({date:MMMM d, yyyy})."
                    : $"{soonWord} in {days} {(days == 1 ? "day" : "days")} ({date:MMMM d, yyyy}).";
            }
            else
            {
                check.State = Passed;
            }

            AddValue(check, valueLabel, date.ToString("MMMM d, yyyy"));
            return check;
        }

        // ── Edits ────────────────────────────────────────────────────────────

        private static List<ValueEditResponse> BuildEdits(DocumentVerification v)
        {
            var edits = new List<ValueEditResponse>();

            void Compare(string? read, string? confirmed, string field, bool identity)
            {
                if (string.IsNullOrWhiteSpace(confirmed))
                    return;

                if (string.Equals(read?.Trim(), confirmed.Trim(), StringComparison.OrdinalIgnoreCase))
                    return;

                edits.Add(new ValueEditResponse
                {
                    Field = field,
                    Read = string.IsNullOrWhiteSpace(read) ? null : read.Trim(),
                    Submitted = confirmed.Trim(),
                    IsIdentity = identity
                });
            }

            Compare(v.ExtractedStudentName, v.ConfirmedStudentName, "Name", identity: true);
            Compare(v.ExtractedStudentNumber, v.ConfirmedStudentNumber, "Student number", identity: true);
            Compare(v.ExtractedLicenseName, v.ConfirmedLicenseName, "Licence name", identity: true);
            Compare(v.ExtractedLicenseNumber, v.ConfirmedLicenseNumber, "Licence number", identity: true);
            // Identity-weight, matching PreScreeningService.NoteUserEdits: there is
            // no plate photo left to corroborate the receipt reading, so an edit
            // here is the sole evidence behind what the gate will match on.
            Compare(v.ExtractedPlateNumber, v.ConfirmedPlateNumber, "Plate number", identity: true);
            Compare(v.ExtractedSection, v.ConfirmedSection, "Section", identity: false);
            Compare(v.ExtractedSemester, v.ConfirmedSemester, "Semester", identity: false);

            return edits;
        }

        // ── Summary ──────────────────────────────────────────────────────────

        private static void Summarise(RegistrationChecksResponse r)
        {
            var all = new List<CheckItemResponse>();
            if (r.Person is not null) all.AddRange(r.Person.Checks);
            foreach (var group in r.Vehicles) all.AddRange(group.Checks);

            r.Total = all.Count;
            r.NeedsAttention = all.Count(c => c.State is Failed or ExpiringSoon);
            // A read term is NotChecked only because the system cannot judge it,
            // not because anything failed to read. Counting it here would mark
            // every student application "could not be checked" and demand an
            // override note on every approval.
            r.Unreadable = all.Count(c => c.State == NotChecked && !IsLeftToReviewer(c));

            r.Headlines = all
                .Where(c => c.State is Failed or ExpiringSoon)
                .Select(c => c.Detail)
                .Where(d => !string.IsNullOrWhiteSpace(d))
                .Select(d => d!)
                .ToList();

            // An identity field the applicant typed themselves is worth as much of
            // the reviewer's attention as a failed comparison, so it is said out
            // loud rather than left to be noticed further down the page.
            foreach (var edit in r.Edits.Where(e => e.IsIdentity))
            {
                r.Headlines.Add(edit.Read is null
                    ? $"{edit.Field} was typed by the applicant — we read nothing from the document."
                    : $"{edit.Field} was changed by the applicant — we read \"{edit.Read}\", they submitted \"{edit.Submitted}\".");
            }

            if (r.NeedsAttention > 0)
            {
                r.Verdict = "LookCloser";
                r.Summary = $"Look closer — {r.NeedsAttention} of {r.Total} checks need attention";
            }
            else if (r.Unreadable > 0)
            {
                r.Verdict = "Unreadable";
                r.Summary = r.Unreadable == 1
                    ? $"1 of {r.Total} checks could not be made"
                    : $"{r.Unreadable} of {r.Total} checks could not be made";
            }
            else
            {
                r.Verdict = ClearVerdict;
                r.Summary = all.Any(IsLeftToReviewer)
                    ? "Nothing contradicted itself — enrolment is yours to confirm"
                    : $"Nothing contradicted itself — all {r.Total} checks passed";
            }
        }

        // ── Findings ─────────────────────────────────────────────────────────

        public const string Identity = "Identity";
        public const string Validity = "Validity";
        public const string Edited = "Edited";
        // NotChecked and Passed double as categories.

        public const string Danger = "Danger";
        public const string Warning = "Warning";
        public const string Neutral = "Neutral";

        private const string Raf = nameof(DocumentType.Raf);
        private const string SchoolId = nameof(DocumentType.SchoolId);
        private const string License = nameof(DocumentType.License);
        private const string Receipt = nameof(DocumentType.OfficialReceipt);

        /// <summary>
        /// Every check and edit as one list, most serious first.
        /// </summary>
        /// <remarks>
        /// Identity before validity: a name that does not match says something
        /// about who is applying, an expired date only about paperwork. Within a
        /// category, red before amber before grey.
        /// </remarks>
        private static List<FindingResponse> BuildFindings(
            RegistrationChecksResponse r, DocumentVerification personRow, User user,
            IReadOnlyList<Vehicle> vehicles, List<DocumentVerification> newestFirst, DateTime nowUtc)
        {
            var findings = new List<FindingResponse>();
            var isStudent = user.Affiliation == Affiliation.Student;
            var newest = newestFirst[0];

            if (r.Person is not null)
            {
                foreach (var check in r.Person.Checks)
                {
                    findings.Add(check.Key switch
                    {
                        "NameMatch" => NameFinding(check, personRow, user, isStudent),
                        "LicenseValidity" => ExpiryFinding(check, "Licence",
                            personRow.ConfirmedLicenseExpiry ?? personRow.ExtractedLicenseExpiry, License, nowUtc),
                        _ => FromCheck(check, Raf)
                    });
                }
            }

            for (var i = 0; i < r.Vehicles.Count; i++)
            {
                var vehicle = i < vehicles.Count ? vehicles[i] : null;
                var row = vehicle is null
                    ? newest
                    : newestFirst.FirstOrDefault(v => v.VehicleId == vehicle.Id) ?? newest;
                var suffix = r.Vehicles.Count > 1 ? $" · {Display(vehicle?.PlateNumber)}" : string.Empty;

                foreach (var check in r.Vehicles[i].Checks)
                {
                    var finding = check.Key == "RegistrationValidity"
                        ? ExpiryFinding(check, "Registration",
                            row.ConfirmedRegistrationExpiry ?? row.ExtractedRegistrationExpiry, Receipt, nowUtc)
                        : PlateFinding(check);
                    finding.Title += suffix;
                    findings.Add(finding);
                }
            }

            foreach (var edit in r.Edits)
                findings.Add(EditFinding(edit));

            // Written into the notes at submission by RegistrationService and shown
            // nowhere else, so a shared photograph used to reach review unseen.
            foreach (var line in (newest.Notes ?? string.Empty).Split('\n'))
            {
                const string marker = "Duplicate upload";
                if (!line.StartsWith(marker, StringComparison.Ordinal))
                    continue;

                var detail = line[marker.Length..].TrimStart(' ', '—', '-').Trim();
                findings.Add(new FindingResponse
                {
                    Key = "DuplicateUpload",
                    Category = Identity,
                    Severity = Danger,
                    Title = "Same file as another account",
                    Detail = detail.Length == 0 ? null : char.ToUpperInvariant(detail[0]) + detail[1..]
                });
            }

            // OrderBy is stable, so within one rank the order stays the order the
            // checks were built in: person before vehicle.
            return findings
                .OrderBy(f => CategoryRank(f.Category))
                .ThenBy(f => SeverityRank(f.Severity))
                .ThenBy(f => f.Key == "EnrollmentValidity" ? 1 : 0)
                .ToList();
        }

        /// <summary>
        /// The findings the queue calls out: red, amber, and anything that could
        /// not be read. Not the term left to the reviewer, which every student
        /// application has and so would tell the queue nothing.
        /// </summary>
        public static List<FindingResponse> Flagged(RegistrationChecksResponse r)
        {
            var termLeftToReviewer = r.Person?.Checks.Any(IsLeftToReviewer) == true;

            return r.Findings
                .Where(f => f.Severity is Danger or Warning
                            || (f.Category == NotChecked
                                && !(f.Key == "EnrollmentValidity" && termLeftToReviewer)))
                .ToList();
        }

        private static int CategoryRank(string category) => category switch
        {
            Identity => 0,
            Validity => 1,
            Edited => 2,
            NotChecked => 3,
            _ => 4
        };

        private static int SeverityRank(string severity) => severity switch
        {
            Danger => 0,
            Warning => 1,
            Neutral => 2,
            _ => 3
        };

        private static FindingResponse NameFinding(
            CheckItemResponse check, DocumentVerification v, User user, bool isStudent)
        {
            var schoolName = isStudent ? v.ConfirmedStudentName ?? v.ExtractedStudentName : null;

            return check.State switch
            {
                Failed when v.LicenseNameFound == false || string.IsNullOrWhiteSpace(schoolName) => new FindingResponse
                {
                    Key = check.Key, Category = Identity, Severity = Danger,
                    Title = "Name mismatch",
                    Detail = $"The account name \"{user.FullName}\" does not appear on the licence.",
                    Document = License
                },
                Failed => new FindingResponse
                {
                    Key = check.Key, Category = Identity, Severity = Danger,
                    Title = "Name mismatch",
                    Detail = $"Account reads \"{user.FullName}\". School form reads \"{schoolName!.Trim()}\".",
                    Document = Raf
                },
                Passed => new FindingResponse
                {
                    Key = check.Key, Category = Passed, Severity = Passed,
                    Title = "Name matches",
                    Detail = "The name was found on the licence.",
                    Document = License
                },
                _ => new FindingResponse
                {
                    Key = check.Key, Category = NotChecked, Severity = Neutral,
                    Title = "Names not compared",
                    Detail = "No readable name came off the documents.",
                    Document = isStudent ? Raf : License
                }
            };
        }

        private static FindingResponse ExpiryFinding(
            CheckItemResponse check, string thing, DateTime? expiry, string document, DateTime nowUtc)
        {
            var finding = new FindingResponse { Key = check.Key, Document = document };
            var date = expiry?.Date;
            var on = date?.ToString("MMMM d, yyyy");

            switch (check.State)
            {
                case Failed:
                    finding.Category = Validity;
                    finding.Severity = Danger;
                    finding.Title = $"{thing} expired";
                    finding.Detail = $"Expired on {on}.";
                    break;
                case ExpiringSoon:
                    var days = (date!.Value - nowUtc.Date).Days;
                    finding.Category = Validity;
                    finding.Severity = Warning;
                    finding.Title = $"{thing} expires soon";
                    finding.Detail = days == 0
                        ? $"Expires today, {on}."
                        : $"Expires in {days} {(days == 1 ? "day" : "days")}, on {on}.";
                    break;
                case Passed:
                    finding.Category = Passed;
                    finding.Severity = Passed;
                    finding.Title = $"{thing} valid";
                    finding.Detail = $"Valid until {on}.";
                    break;
                default:
                    finding.Category = NotChecked;
                    finding.Severity = Neutral;
                    finding.Title = $"{thing} expiry not read";
                    finding.Detail = "Could not read the expiry date.";
                    break;
            }

            return finding;
        }

        private static FindingResponse PlateFinding(CheckItemResponse check)
        {
            var onFile = check.Values.FirstOrDefault(x => x.Label == "On file")?.Value;
            var read = check.Values.FirstOrDefault(x => x.Label == "Receipt")?.Value;

            if (check.State == Passed)
            {
                return new FindingResponse
                {
                    Key = check.Key, Category = Passed, Severity = Passed,
                    Title = "Plate read from receipt",
                    Detail = $"Receipt reads {read ?? onFile}.",
                    Document = Receipt
                };
            }

            return new FindingResponse
            {
                Key = check.Key, Category = NotChecked, Severity = Neutral,
                Title = onFile is null ? "Plate not read" : "Plate not confirmed",
                Detail = onFile is null
                    ? "Could not read a plate number from the receipt."
                    : $"Plate on file is {onFile}. Check it against the receipt.",
                Document = Receipt
            };
        }

        /// <summary>
        /// Any other check, as it stands. Today that is only Enrolment, which is
        /// always grey: the system cannot judge a term it does not know.
        /// </summary>
        private static FindingResponse FromCheck(CheckItemResponse check, string document) => new()
        {
            Key = check.Key,
            Category = check.State switch
            {
                Failed or ExpiringSoon => Validity,
                Passed => Passed,
                _ => NotChecked
            },
            Severity = check.State switch
            {
                Failed => Danger,
                ExpiringSoon => Warning,
                Passed => Passed,
                _ => Neutral
            },
            Title = check.Key == "EnrollmentValidity" ? "Enrolment not checked" : check.Label,
            Detail = check.Detail,
            Document = document
        };

        /// <summary>
        /// Amber, not red, on an identity field: nothing contradicted anything, the
        /// document just never proved the value. That is why it is listed with the
        /// identity findings, ahead of an expired date.
        /// </summary>
        private static FindingResponse EditFinding(ValueEditResponse edit)
        {
            var isLicenceNumber = edit.Field == "Licence number";
            string Show(string value) => isLicenceNumber ? Mask(value) : value;

            return new FindingResponse
            {
                Key = "Edit." + edit.Field.Replace(" ", string.Empty, StringComparison.Ordinal),
                Category = edit.IsIdentity ? Identity : Edited,
                Severity = edit.IsIdentity ? Warning : Neutral,
                Title = edit.Read is null
                    ? $"{edit.Field} typed by applicant"
                    : $"{edit.Field} changed by applicant",
                Detail = edit.Read is null
                    ? $"The phone read nothing. The applicant typed {Show(edit.Submitted)}."
                    : $"Phone read {Show(edit.Read)}. Applicant submitted {Show(edit.Submitted)}.",
                Document = edit.Field switch
                {
                    "Licence name" or "Licence number" => License,
                    "Plate number" => Receipt,
                    _ => Raf
                }
            };
        }

        // ── Facts and readings ───────────────────────────────────────────────

        private static RegistrationFactsResponse BuildFacts(
            DocumentVerification v, User user, IReadOnlyList<Vehicle> vehicles, List<DocumentVerification> newestFirst)
        {
            var isStudent = user.Affiliation == Affiliation.Student;
            var licenceNumber = Trimmed(v.ConfirmedLicenseNumber) ?? Trimmed(v.ExtractedLicenseNumber);

            var facts = new RegistrationFactsResponse
            {
                SchoolFormName = isStudent ? Trimmed(v.ConfirmedStudentName) ?? Trimmed(v.ExtractedStudentName) : null,
                LicenseName = Trimmed(v.ConfirmedLicenseName) ?? Trimmed(v.ExtractedLicenseName),
                StudentNumber = isStudent ? Trimmed(v.ConfirmedStudentNumber) ?? Trimmed(v.ExtractedStudentNumber) : null,
                StudentNumberTyped = isStudent && IsTyped(v.ExtractedStudentNumber, v.ConfirmedStudentNumber,
                    IdentifierNormalizer.NormalizeStudentNumber),
                Section = isStudent ? Trimmed(v.ConfirmedSection) ?? Trimmed(v.ExtractedSection) : null,
                Semester = isStudent ? Trimmed(v.ConfirmedSemester) ?? Trimmed(v.ExtractedSemester) : null,
                LicenseNumberMasked = licenceNumber is null ? null : Mask(licenceNumber),
                LicenseNumberTyped = IsTyped(v.ExtractedLicenseNumber, v.ConfirmedLicenseNumber,
                    IdentifierNormalizer.NormalizeLicenseNumber),
                LicenseExpiry = (v.ConfirmedLicenseExpiry ?? v.ExtractedLicenseExpiry)?.Date
            };

            foreach (var row in ReceiptRows(vehicles, newestFirst))
            {
                facts.Vehicles.Add(new VehicleFactsResponse
                {
                    PlateNumber = Trimmed(row.Vehicle?.PlateNumber)
                                  ?? Trimmed(row.Row.ConfirmedPlateNumber) ?? Trimmed(row.Row.ExtractedPlateNumber),
                    RegistrationExpiry = (row.Row.ConfirmedRegistrationExpiry ?? row.Row.ExtractedRegistrationExpiry)?.Date
                });
            }

            return facts;
        }

        /// <summary>
        /// What the phone read off each document. A school ID gets an entry with no
        /// values: the phone does not read it, and saying so beats an empty panel.
        /// </summary>
        private static List<DocumentReadingResponse> BuildReadings(
            DocumentVerification v, User user, IReadOnlyList<Vehicle> vehicles, List<DocumentVerification> newestFirst)
        {
            var readings = new List<DocumentReadingResponse>();

            if (user.Affiliation == Affiliation.Student)
            {
                readings.Add(new DocumentReadingResponse
                {
                    Document = Raf,
                    Values =
                    [
                        Reading("Name", v.ExtractedStudentName, v.ConfirmedStudentName),
                        Reading("Student number", v.ExtractedStudentNumber, v.ConfirmedStudentNumber),
                        Reading("Section", v.ExtractedSection, v.ConfirmedSection),
                        Reading("Term", v.ExtractedSemester, v.ConfirmedSemester)
                    ]
                });
            }
            else
            {
                readings.Add(new DocumentReadingResponse { Document = SchoolId });
            }

            readings.Add(new DocumentReadingResponse
            {
                Document = License,
                Values =
                [
                    Reading("Name", v.ExtractedLicenseName, v.ConfirmedLicenseName),
                    Reading("Licence number", MaskOrNull(v.ExtractedLicenseNumber), MaskOrNull(v.ConfirmedLicenseNumber)),
                    Reading("Valid until", Date(v.ExtractedLicenseExpiry), Date(v.ConfirmedLicenseExpiry))
                ]
            });

            foreach (var row in ReceiptRows(vehicles, newestFirst))
            {
                readings.Add(new DocumentReadingResponse
                {
                    Document = Receipt,
                    Values =
                    [
                        Reading("Plate", row.Row.ExtractedPlateNumber, row.Row.ConfirmedPlateNumber),
                        Reading("Registration valid until",
                            Date(row.Row.ExtractedRegistrationExpiry), Date(row.Row.ConfirmedRegistrationExpiry))
                    ]
                });
            }

            return readings;
        }

        /// <summary>
        /// The submission behind each vehicle, with the same newest-row fallback
        /// <see cref="Build"/> uses — or the newest row alone when no vehicle exists yet.
        /// </summary>
        private static IEnumerable<(Vehicle? Vehicle, DocumentVerification Row)> ReceiptRows(
            IReadOnlyList<Vehicle> vehicles, List<DocumentVerification> newestFirst)
        {
            if (vehicles.Count == 0)
            {
                yield return (null, newestFirst[0]);
                yield break;
            }

            foreach (var vehicle in vehicles)
                yield return (vehicle, newestFirst.FirstOrDefault(x => x.VehicleId == vehicle.Id) ?? newestFirst[0]);
        }

        private static ReadingValueResponse Reading(string label, string? read, string? submitted)
        {
            var r = Trimmed(read);
            var s = Trimmed(submitted);

            return new ReadingValueResponse
            {
                Label = label,
                Read = r,
                Submitted = s is null || string.Equals(r, s, StringComparison.OrdinalIgnoreCase) ? null : s
            };
        }

        /// <summary>
        /// The phone read nothing, or the applicant changed what it read. Compared
        /// normalised, so "N01-23" against "N0123" is not called an edit.
        /// </summary>
        private static bool IsTyped(string? read, string? confirmed, Func<string?, string> normalise)
        {
            var c = normalise(confirmed);
            if (c.Length == 0) return false;

            var r = normalise(read);
            return r.Length == 0 || r != c;
        }

        /// <summary>Everything but the last four characters as dots.</summary>
        public static string Mask(string value)
        {
            var trimmed = value.Trim();
            return trimmed.Length <= 4
                ? trimmed
                : new string('•', trimmed.Length - 4) + trimmed[^4..];
        }

        private static string? MaskOrNull(string? value) =>
            Trimmed(value) is { } v ? Mask(v) : null;

        private static string? Trimmed(string? value) =>
            string.IsNullOrWhiteSpace(value) ? null : value.Trim();

        private static string? Date(DateTime? value) => value?.Date.ToString("MMMM d, yyyy");

        /// <summary>
        /// A check the system cannot make at all, as opposed to one that failed to
        /// read: a term read off the school form. Grey, but not "unreadable".
        /// </summary>
        private static bool IsLeftToReviewer(CheckItemResponse c) =>
            c.Key == "EnrollmentValidity" && c.Values.Count > 0;

        // ── Bits ─────────────────────────────────────────────────────────────

        /// <summary>
        /// Whether this submission read the applicant's own documents, as opposed
        /// to only adding a vehicle.
        /// </summary>
        private static bool HasPersonReadings(DocumentVerification v) =>
            !string.IsNullOrWhiteSpace(v.ExtractedStudentName)
            || !string.IsNullOrWhiteSpace(v.ConfirmedStudentName)
            || !string.IsNullOrWhiteSpace(v.ExtractedLicenseName)
            || !string.IsNullOrWhiteSpace(v.ConfirmedLicenseName)
            || v.ExtractedLicenseExpiry is not null
            || v.ConfirmedLicenseExpiry is not null;

        private static void AddValue(CheckItemResponse check, string label, string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return;

            check.Values.Add(new CheckValueResponse { Label = label, Value = value.Trim() });
        }

        private static string Display(string? plate) =>
            string.IsNullOrWhiteSpace(plate) ? "no plate on file" : plate.Trim();
    }
}
