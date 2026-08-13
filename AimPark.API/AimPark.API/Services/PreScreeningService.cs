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
        /// The receipt's plate against the plate the user registered.
        /// </summary>
        /// <remarks>
        /// Never guessed at. A blank an admin fills in is recoverable; a confidently
        /// wrong plate sits in the database until someone is denied at the gate with
        /// a perfectly valid card and no way to understand why.
        /// </remarks>
        private static CheckResult CheckPlate(DocumentVerification v, Vehicle? vehicle, List<string> notes)
        {
            if (vehicle is null)
                return CheckResult.NotChecked;

            var fromReceipt = IdentifierNormalizer.NormalizePlate(
                v.ConfirmedPlateNumber ?? v.ExtractedPlateNumber);

            if (fromReceipt.Length == 0)
            {
                notes.Add("Could not read a plate number from the receipt.");
                return CheckResult.NotChecked;
            }

            if (fromReceipt == vehicle.PlateNumber)
                return CheckResult.Passed;

            notes.Add($"Plate mismatch — receipt reads {fromReceipt}, the account is registered to {vehicle.PlateNumber}.");
            return CheckResult.Failed;
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
            Compare(v.ExtractedPlateNumber, v.ConfirmedPlateNumber, "plate number", identity: false);
            Compare(v.ExtractedSection, v.ConfirmedSection, "section", identity: false);
            Compare(v.ExtractedSemester, v.ConfirmedSemester, "semester", identity: false);
        }
    }
}
