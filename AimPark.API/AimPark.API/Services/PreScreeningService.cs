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
            verification.PlatePhotoMatch = CheckPlatePhoto(verification, notes);
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
        /// The names on the documents against each other, and against the account
        /// they were submitted under.
        /// </summary>
        /// <remarks>
        /// The account name is the leg that makes this worth running. Comparing the
        /// school document to the licence alone establishes only that the two papers
        /// describe one person — so a set of documents belonging entirely to someone
        /// else agrees with itself perfectly and passes. The applicant's own name
        /// reached the account through an email they had to receive a code at, which
        /// is the closest thing to an identity this registration has.
        ///
        /// The Official Receipt's owner is still never compared: campus users
        /// commonly drive vehicles registered to a parent, so a mismatch there is
        /// expected and proves nothing.
        ///
        /// Faculty and staff used to be skipped entirely, because a school ID is
        /// filed rather than read. Their licence is read, so the account comparison
        /// covers them now — they simply have one pairing available instead of three.
        /// </remarks>
        private static CheckResult CheckName(DocumentVerification v, User user, List<string> notes)
        {
            var accountName = user.FullName;
            var licenseName = v.ConfirmedLicenseName ?? v.ExtractedLicenseName;

            // Only students submit a document these rules can take a name off.
            var schoolName = user.Affiliation == Affiliation.Student
                ? v.ConfirmedStudentName ?? v.ExtractedStudentName
                : null;

            var compared = 0;
            var mismatches = 0;

            void Compare(string? left, string leftLabel, string? right, string rightLabel)
            {
                if (string.IsNullOrWhiteSpace(left) || string.IsNullOrWhiteSpace(right))
                    return;

                compared++;

                if (NameMatching.IsProbableMatch(left, right))
                    return;

                mismatches++;
                notes.Add($"Name mismatch — {leftLabel} reads \"{left.Trim()}\", {rightLabel} reads \"{right.Trim()}\".");
            }

            Compare(schoolName, "the school document", licenseName, "the licence");
            Compare(accountName, "the account", licenseName, "the licence");
            Compare(accountName, "the account", schoolName, "the school document");

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
        /// Whether the plate now on the account is the one the receipt gave.
        /// </summary>
        /// <remarks>
        /// This used to compare the receipt against a plate the applicant typed, and
        /// that comparison no longer exists: the plate is read off the receipt and
        /// shown read-only, then the vehicle record is created from it. Comparing it
        /// back against itself would pass every time and tell a reviewer nothing.
        ///
        /// What is left is worth keeping. The app echoes the plate back when
        /// confirming, so a value that differs from the stored reading did not come
        /// from the screen the user saw, and the record should not quietly carry it.
        /// Corroboration that the plate is genuinely this vehicle's comes from
        /// <see cref="CheckPlatePhoto"/>, which reads the physical plate.
        ///
        /// Never guessed at. A blank an admin fills in is recoverable; a confidently
        /// wrong plate sits in the database until someone is denied at the gate with
        /// a perfectly valid card and no way to understand why.
        /// </remarks>
        private static CheckResult CheckPlate(DocumentVerification v, Vehicle? vehicle, List<string> notes)
        {
            var fromReceipt = IdentifierNormalizer.NormalizePlate(v.ExtractedPlateNumber);

            if (fromReceipt.Length == 0)
            {
                notes.Add("Could not read a plate number from the receipt.");
                return CheckResult.NotChecked;
            }

            var committed = IdentifierNormalizer.NormalizePlate(v.ConfirmedPlateNumber);

            if (committed.Length != 0 && committed != fromReceipt)
            {
                notes.Add(
                    $"The plate submitted ({committed}) is not the plate read from the receipt ({fromReceipt}). " +
                    "The app shows this value read-only, so it was not changed on the confirmation screen.");
                return CheckResult.Failed;
            }

            if (vehicle is null)
                return CheckResult.NotChecked;

            return CheckResult.Passed;
        }

        private static CheckResult CheckPlatePhoto(DocumentVerification v, List<string> notes)
        {
            var expected = IdentifierNormalizer.NormalizePlate(
                v.ConfirmedPlateNumber ?? v.ExtractedPlateNumber);

            var seen = IdentifierNormalizer.NormalizePlate(v.ExtractedPlatePhotoNumber);

            if (expected.Length == 0 || seen.Length == 0)
            {
                notes.Add("Could not read the plate in the photo of the vehicle.");
                return CheckResult.NotChecked;
            }

            var distance = FuzzyText.EditDistance(seen, expected);

            if (distance == 0)
                return CheckResult.Passed;

            // One character apart is not agreement, and must never be recorded as
            // one. The slack is there because these are outdoor photos at an angle,
            // but it is exactly wide enough to swallow a one-character misreading of
            // the receipt — and the plate is shown read-only, then written to the
            // vehicle the gate matches on. Passing this silently is how a valid card
            // stops working with nothing to point at.
            if (distance == 1)
            {
                notes.Add(
                    $"Plate needs a second look — the receipt reads {expected}, the photo of the vehicle reads {seen}. " +
                    "One character apart; confirm which is correct against the images before approving.");
                return CheckResult.NotChecked;
            }

            notes.Add($"The plate in the photo reads {seen}, but the receipt says {expected}.");
            return CheckResult.Failed;
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
            // The plate is deliberately absent: it is read-only on screen, so a
            // difference is not an edit, and CheckPlate already reports it.
            Compare(v.ExtractedSection, v.ConfirmedSection, "section", identity: false);
            Compare(v.ExtractedSemester, v.ConfirmedSemester, "semester", identity: false);
        }
    }
}
