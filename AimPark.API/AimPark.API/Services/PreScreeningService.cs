using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    public class PreScreeningService : IPreScreeningService
    {
        public void Evaluate(DocumentVerification verification, User user, Vehicle? vehicle)
        {
            var notes = new List<string>();

            verification.NameMatch = CheckName(verification, user, notes);
            verification.PlateMatch = CheckPlate(verification, vehicle, notes);
            verification.LicenseValidity = CheckLicenseValidity(verification, notes);
            verification.RegistrationValidity = CheckRegistrationValidity(verification, notes);
            verification.EnrollmentValidity = CheckEnrollment(verification, user, notes);

            NoteUserEdits(verification, notes);

            verification.Notes = notes.Count == 0 ? null : string.Join('\n', notes);

            // The system never approves on its own. A clean pass still reaches a
            // reviewer — nothing here examines whether the documents are genuine, and
            // nothing here establishes who the applicant is.
            verification.Result = VerificationStatus.ManualReview;
        }

        /// <summary>
        /// The account's name against the school document, and against the
        /// licence.
        /// </summary>
        /// <remarks>
        /// The account name is the leg that makes this worth running. Comparing
        /// the school document to the licence alone would establish only that
        /// the two papers describe one person — so a set of documents belonging
        /// entirely to someone else agrees with itself perfectly and passes. The
        /// applicant's own name reached the account through an email they had to
        /// receive a code at, which is the closest thing to an identity this
        /// registration has.
        ///
        /// The licence half of this is no longer a second independently-read
        /// value compared against the first. It is
        /// <see cref="DocumentVerification.LicenseNameFound"/> — whether the
        /// trusted name (the RAF's, or the account's for faculty/staff) was
        /// found printed on the licence at all. See
        /// <see cref="DocumentExtractionService.Extract"/> and
        /// <see cref="NameLocator"/> for why: the licence's name caption reads
        /// badly often enough that trying to read a second name off it and
        /// comparing two guesses produced false mismatches from OCR noise alone.
        ///
        /// The Official Receipt's owner is still never compared: campus users
        /// commonly drive vehicles registered to a parent, so a mismatch there is
        /// expected and proves nothing.
        /// </remarks>
        private static CheckResult CheckName(DocumentVerification v, User user, List<string> notes)
        {
            var accountName = user.FullName;

            // Only students submit a document these rules can take a name off.
            var schoolName = user.Affiliation == Affiliation.Student
                ? v.ConfirmedStudentName ?? v.ExtractedStudentName
                : null;

            var compared = 0;
            var mismatches = 0;

            if (!string.IsNullOrWhiteSpace(accountName) && !string.IsNullOrWhiteSpace(schoolName))
            {
                compared++;
                if (!NameMatching.IsProbableMatch(accountName, schoolName))
                {
                    mismatches++;
                    notes.Add(
                        $"Name mismatch — the account reads \"{accountName.Trim()}\", " +
                        $"the school document reads \"{schoolName.Trim()}\".");
                }
            }

            switch (v.LicenseNameFound)
            {
                case true:
                    compared++;
                    break;
                case false:
                    compared++;
                    mismatches++;
                    notes.Add(
                        "Name mismatch — the name on file does not appear to be printed on the licence.");
                    break;
            }

            if (mismatches > 0)
                return CheckResult.Failed;

            if (compared == 0)
            {
                notes.Add("Could not compare names — no readable name came off the documents.");
                return CheckResult.NotChecked;
            }

            return CheckResult.Passed;
        }

        /// <summary>
        /// Whether a usable plate ended up on the account.
        /// </summary>
        /// <remarks>
        /// The plate is editable now — there is no corroborating photo any more, so
        /// a value the user typed to correct an OCR misread is a legitimate
        /// correction, not tampering. This check only asks whether a plate exists;
        /// whether it was edited, and what it was edited from, is reported separately
        /// by <see cref="NoteUserEdits"/> so the reviewer can look at the receipt
        /// image and judge it themselves — the same treatment every other identity
        /// field already gets.
        /// </remarks>
        private static CheckResult CheckPlate(DocumentVerification v, Vehicle? vehicle, List<string> notes)
        {
            var plate = IdentifierNormalizer.NormalizePlate(v.ConfirmedPlateNumber ?? v.ExtractedPlateNumber);

            if (plate.Length == 0)
            {
                notes.Add("Could not read a plate number from the receipt.");
                return CheckResult.NotChecked;
            }

            if (vehicle is null)
                return CheckResult.NotChecked;

            return CheckResult.Passed;
        }

        private static CheckResult CheckLicenseValidity(DocumentVerification v, List<string> notes)
        {
            var expiry = v.ConfirmedLicenseExpiry ?? v.ExtractedLicenseExpiry;

            if (expiry is null)
            {
                notes.Add("Could not read the licence expiry date.");
                return CheckResult.NotChecked;
            }

            if (expiry.Value.Date >= DateTime.UtcNow.Date)
                return CheckResult.Passed;

            notes.Add($"The driver's licence expired on {expiry.Value:MMMM d, yyyy}.");
            return CheckResult.Failed;
        }

        private static CheckResult CheckRegistrationValidity(DocumentVerification v, List<string> notes)
        {
            var expiry = v.ConfirmedRegistrationExpiry ?? v.ExtractedRegistrationExpiry;

            if (expiry is null)
            {
                notes.Add("Could not determine when the vehicle registration expires.");
                return CheckResult.NotChecked;
            }

            if (expiry.Value.Date >= DateTime.UtcNow.Date)
                return CheckResult.Passed;

            notes.Add($"The vehicle registration expired in {expiry.Value:MMMM yyyy}.");
            return CheckResult.Failed;
        }

        /// <summary>
        /// Whether the school document covers the current term.
        /// </summary>
        /// <remarks>
        /// The semester is recorded as printed but not turned into a date here — term
        /// dates vary and the admin sets the enrolment end date during review. So this
        /// only reports whether a semester was captured at all.
        /// </remarks>
        private static CheckResult CheckEnrollment(DocumentVerification v, User user, List<string> notes)
        {
            if (user.Affiliation != Affiliation.Student)
                return CheckResult.NotChecked;

            var semester = v.ConfirmedSemester ?? v.ExtractedSemester;

            if (string.IsNullOrWhiteSpace(semester))
            {
                notes.Add("Could not read the semester from the school document.");
                return CheckResult.NotChecked;
            }

            notes.Add($"School document covers {semester} — set the enrolment end date when approving.");
            return CheckResult.NotChecked;
        }

        /// <summary>
        /// Records where the user overrode what the rules read.
        /// </summary>
        /// <remarks>
        /// Edits are expected on the plate and the dates — OCR errors there are common
        /// and correcting them is the point of showing the values at all.
        ///
        /// Edits to the name and student number are different. Those are the identity
        /// fields, and a value the applicant typed themselves proves nothing about who
        /// they are, so the reviewer is told plainly rather than left to compare
        /// columns.
        /// </remarks>
        private static void NoteUserEdits(DocumentVerification v, List<string> notes)
        {
            void Compare(string? read, string? confirmed, string field, bool identity)
            {
                if (string.IsNullOrWhiteSpace(confirmed))
                    return;

                if (string.Equals(read?.Trim(), confirmed.Trim(), StringComparison.OrdinalIgnoreCase))
                    return;

                var was = string.IsNullOrWhiteSpace(read) ? "nothing readable" : $"\"{read}\"";
                var prefix = identity ? "Identity field edited" : "Edited by user";
                notes.Add($"{prefix} — {field}: we read {was}, the user submitted \"{confirmed}\".");
            }

            Compare(v.ExtractedStudentName, v.ConfirmedStudentName, "name", identity: true);
            Compare(v.ExtractedStudentNumber, v.ConfirmedStudentNumber, "student number", identity: true);
            Compare(v.ExtractedLicenseName, v.ConfirmedLicenseName, "licence name", identity: true);
            // Identity-weight now that there is no plate photo to corroborate it —
            // a plate the user typed is the sole evidence behind what the gate
            // matches on, so an edit here deserves the same scrutiny as a changed
            // name.
            Compare(v.ExtractedPlateNumber, v.ConfirmedPlateNumber, "plate number", identity: true);
            Compare(v.ExtractedSection, v.ConfirmedSection, "section", identity: false);
            Compare(v.ExtractedSemester, v.ConfirmedSemester, "semester", identity: false);
        }
    }
}
