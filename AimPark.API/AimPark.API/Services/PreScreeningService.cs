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
        /// The name on the school document against the name on the licence.
        /// </summary>
        /// <remarks>
        /// Both belong to the applicant, which is what makes this comparison
        /// meaningful. The Official Receipt's owner is never compared: students
        /// commonly drive vehicles registered to a parent, so a mismatch there is
        /// expected and proves nothing.
        /// </remarks>
        private static CheckResult CheckName(DocumentVerification v, User user, List<string> notes)
        {
            // Faculty and staff submit a school ID, which these rules do not read.
            if (user.Affiliation != Affiliation.Student)
                return CheckResult.NotChecked;

            var schoolName = v.ConfirmedStudentName ?? v.ExtractedStudentName;
            var licenseName = v.ConfirmedLicenseName ?? v.ExtractedLicenseName;

            if (string.IsNullOrWhiteSpace(schoolName) || string.IsNullOrWhiteSpace(licenseName))
            {
                notes.Add("Could not compare names — one of the documents did not give a readable name.");
                return CheckResult.NotChecked;
            }

            if (NameMatching.IsProbableMatch(schoolName, licenseName))
                return CheckResult.Passed;

            notes.Add($"Name mismatch — school document reads \"{schoolName}\", licence reads \"{licenseName}\".");
            return CheckResult.Failed;
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

            // One character of slack: these are outdoor photos at an angle, and the
            // reading has already been matched against a known expected value.
            if (FuzzyText.EditDistance(seen, expected) <= 1)
                return CheckResult.Passed;

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
