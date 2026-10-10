namespace AimPark.API.DTOs
{
    /// <summary>
    /// What the reviewer supplies when approving. Whether a note is required
    /// depends on whether the computed checks came back clean — see
    /// <see cref="Services.AdminRegistrationService.ApproveAsync"/>.
    /// </summary>
    public class ApproveRegistrationDto
    {
        /// <summary>
        /// Required when the computed verdict is not Clear. Recorded on the
        /// submission so "the checks flagged this, we approved anyway" has a
        /// reason attached rather than just a bare audit-log row.
        /// </summary>
        public string? OverrideNote { get; set; }
    }
}
