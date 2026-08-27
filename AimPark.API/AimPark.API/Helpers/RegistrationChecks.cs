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
                        Source = "Official Receipt + plate photo",
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
                    Source = "Official Receipt + plate photo",
                    Checks = BuildVehicleChecks(newestFirst[0], nowUtc)
                });
            }

            Summarise(response);
            return response;
        }

        // ── Person ───────────────────────────────────────────────────────────

        private static List<CheckItemResponse> BuildPersonChecks(
            DocumentVerification v, User user, DateTime nowUtc)
        {
            var checks = new List<CheckItemResponse>();

            var schoolName = v.ConfirmedStudentName ?? v.ExtractedStudentName;
            var licenseName = v.ConfirmedLicenseName ?? v.ExtractedLicenseName;

            // Faculty and staff submit a school ID these rules do not read, so the
            // comparison is absent rather than failed.
            if (user.Affiliation == Affiliation.Student)
            {
                var name = new CheckItemResponse { Key = "NameMatch", Label = "Name matches" };

                if (string.IsNullOrWhiteSpace(schoolName) || string.IsNullOrWhiteSpace(licenseName))
                {
                    name.State = NotChecked;
                    name.Detail = "Could not compare names — one of the documents did not give a readable name.";
                }
                else
                {
                    name.State = v.NameMatch == CheckResult.Passed ? Passed : Failed;
                    if (name.State == Failed)
                        name.Detail = $"Name mismatch — school document reads \"{schoolName}\", licence reads \"{licenseName}\".";
                }

                AddValue(name, "School form", schoolName);
                AddValue(name, "Licence", licenseName);
                checks.Add(name);
            }

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

                if (string.IsNullOrWhiteSpace(semester))
                {
                    enrolment.State = NotChecked;
                    enrolment.Detail = "Could not read the semester from the school document.";
                }
                else
                {
                    // The stored result is always NotChecked here, because the API
                    // never turns a printed semester into a date — the admin sets
                    // the enrolment end date during review. For the reviewer's
                    // purposes the check did everything it can: a term was read.
                    enrolment.State = Passed;
                    enrolment.Detail = $"School document covers {semester} — set the enrolment end date when approving.";
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

            var plate = new CheckItemResponse { Key = "PlateMatch", Label = "Plate on file" };

            if (fromReceipt.Length == 0)
            {
                plate.State = NotChecked;
                plate.Detail = "Could not read a plate number from the receipt.";
            }
            else if (committed.Length != 0 && committed != fromReceipt)
            {
                plate.State = Failed;
                plate.Detail =
                    $"The plate submitted ({committed}) is not the plate read from the receipt ({fromReceipt}). " +
                    "The app shows this value read-only, so it was not changed on the confirmation screen.";
            }
            else
            {
                plate.State = v.PlateMatch == CheckResult.Passed ? Passed : NotChecked;
            }

            AddValue(plate, "Receipt", fromReceipt);
            AddValue(plate, "On file", committed.Length == 0 ? fromReceipt : committed);
            checks.Add(plate);

            var expected = IdentifierNormalizer.NormalizePlate(v.ConfirmedPlateNumber ?? v.ExtractedPlateNumber);
            var seen = IdentifierNormalizer.NormalizePlate(v.ExtractedPlatePhotoNumber);

            var photo = new CheckItemResponse { Key = "PlatePhotoMatch", Label = "Plate photo" };

            if (expected.Length == 0 || seen.Length == 0)
            {
                photo.State = NotChecked;
                photo.Detail = "Could not read the plate in the photo of the vehicle.";
            }
            else if (v.PlatePhotoMatch == CheckResult.Passed)
            {
                photo.State = Passed;
            }
            else if (FuzzyText.EditDistance(seen, expected) == 1)
            {
                // Stored as NotChecked, same as PreScreeningService.CheckPlatePhoto: one
                // character apart is neither agreement nor a mismatch, so it must not
                // read as Failed here either — that would tell the reviewer the plate is
                // wrong when it may just be an angle the camera caught badly.
                photo.State = NotChecked;
                photo.Detail = $"Plate needs a second look — the receipt reads {expected}, the photo of the "
                    + $"vehicle reads {seen}. One character apart; confirm which is correct against the images "
                    + "before approving.";
            }
            else
            {
                photo.State = Failed;
                photo.Detail = $"The plate in the photo reads {seen}, but the receipt says {expected}.";
            }

            AddValue(photo, "Photo", seen);
            AddValue(photo, "Receipt", expected);
            checks.Add(photo);

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
            // The plate is absent on purpose: it is read-only on the confirmation
            // screen, so a difference is not an edit, and the plate check reports it.
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
            r.Unreadable = all.Count(c => c.State == NotChecked);

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
                r.Verdict = "Clear";
                r.Summary = $"Nothing contradicted itself — all {r.Total} checks passed";
            }
        }

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
