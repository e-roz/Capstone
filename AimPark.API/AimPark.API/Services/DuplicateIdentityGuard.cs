using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    /// <summary>The identifier that collided, and the account already holding it.</summary>
    public sealed record DuplicateHit(string Field, string Step, Guid HolderUserId);

    /// <summary>
    /// Finds identifiers an applicant's documents carry that already belong to a
    /// different account.
    /// </summary>
    /// <remarks>
    /// This is what answers "user B borrowed user A's documents". It deliberately
    /// compares what the OCR <i>read</i>, not only what the applicant typed: the
    /// photographed paper still says A's student number however B edits the form.
    /// The typed values are checked too, for the case where nothing could be read.
    ///
    /// Only accounts that actually submitted count. A scan that was never
    /// confirmed leaves a verification row behind, and an abandoned attempt must
    /// not lock a stranger out of their own student number. Rejected accounts do
    /// not count either — refusing someone does not make their documents theirs.
    ///
    /// Stored values are compared through <see cref="IdentifierNormalizer"/>, so
    /// a dash or a space does not defeat the check.
    /// </remarks>
    public class DuplicateIdentityGuard
    {
        private readonly IRepository<User> _users;
        private readonly IRepository<Vehicle> _vehicles;
        private readonly IRepository<DocumentVerification> _verifications;

        public DuplicateIdentityGuard(
            IRepository<User> users,
            IRepository<Vehicle> vehicles,
            IRepository<DocumentVerification> verifications)
        {
            _users = users;
            _vehicles = vehicles;
            _verifications = verifications;
        }

        /// <param name="userId">The applicant. Their own earlier attempts never collide.</param>
        /// <param name="step">"scan" or "confirm", recorded for the admin.</param>
        /// <param name="studentNumbers">Every value to test: what was read and what was typed.</param>
        public async Task<DuplicateHit?> FindAsync(
            Guid userId,
            string step,
            IEnumerable<string?> studentNumbers,
            IEnumerable<string?> licenseNumbers,
            IEnumerable<string?> plates,
            CancellationToken ct)
        {
            var students = Canonical(studentNumbers, IdentifierNormalizer.NormalizeStudentNumber);
            var licenses = Canonical(licenseNumbers, IdentifierNormalizer.NormalizeLicenseNumber);
            var plateList = Canonical(plates, IdentifierNormalizer.NormalizePlate);

            if (students.Count > 0)
            {
                var holder = await _users.FindAsync(
                    u => u.Id != userId
                         && u.AccountStatus != AccountStatus.Rejected
                         && u.StudentNumber != null
                         && students.Contains(u.StudentNumber),
                    ct);

                if (holder is not null)
                    return new DuplicateHit("student number", step, holder.Id);

                var submitted = await _verifications.FindAsync(
                    v => v.UserId != userId
                         && v.User.RegistrationStep == RegistrationStep.Completed
                         && v.User.AccountStatus != AccountStatus.Rejected
                         && ((v.ExtractedStudentNumber != null && students.Contains(v.ExtractedStudentNumber))
                             || (v.ConfirmedStudentNumber != null && students.Contains(v.ConfirmedStudentNumber))),
                    ct);

                if (submitted is not null)
                    return new DuplicateHit("student number", step, submitted.UserId);
            }

            if (licenses.Count > 0)
            {
                var submitted = await _verifications.FindAsync(
                    v => v.UserId != userId
                         && v.User.RegistrationStep == RegistrationStep.Completed
                         && v.User.AccountStatus != AccountStatus.Rejected
                         && ((v.ExtractedLicenseNumber != null && licenses.Contains(v.ExtractedLicenseNumber))
                             || (v.ConfirmedLicenseNumber != null && licenses.Contains(v.ConfirmedLicenseNumber))),
                    ct);

                if (submitted is not null)
                    return new DuplicateHit("licence number", step, submitted.UserId);
            }

            if (plateList.Count > 0)
            {
                var vehicle = await _vehicles.FindAsync(
                    v => v.UserId != userId && plateList.Contains(v.PlateNumber),
                    ct);

                if (vehicle is not null)
                    return new DuplicateHit("plate number", step, vehicle.UserId);
            }

            return null;
        }

        /// <summary>
        /// The one message the applicant ever sees. Naming the field or the owner
        /// would tell a borrower exactly what to change, and tell a stranger
        /// whose documents these are.
        /// </summary>
        public const string ApplicantMessage =
            "One of these documents is already registered to another account. "
            + "If these are your documents, please contact the administrator.";

        private static List<string> Canonical(IEnumerable<string?> values, Func<string?, string> normalise)
            => values.Select(normalise).Where(v => v.Length > 0).Distinct().ToList();
    }
}
