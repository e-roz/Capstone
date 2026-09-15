namespace AimPark.API.DTOs
{
    /// <summary>
    /// What the reviewer supplies when approving. Which fields are required
    /// depends on the applicant and on whether the computed checks came back
    /// clean — see <see cref="Services.AdminRegistrationService.ApproveAsync"/>.
    /// </summary>
    public class ApproveRegistrationDto
    {
        /// <summary>
        /// Required for a Student applicant. Nothing on the RAF gives a usable
        /// end date — the semester is read as text, not a date — so the
        /// reviewer sets it from the term shown alongside the checks.
        /// </summary>
        public DateTime? EnrollmentValidUntil { get; set; }

        /// <summary>
        /// Required when the computed verdict is not Clear. Recorded on the
        /// submission so "the checks flagged this, we approved anyway" has a
        /// reason attached rather than just a bare audit-log row.
        /// </summary>
        public string? OverrideNote { get; set; }
    }
}
