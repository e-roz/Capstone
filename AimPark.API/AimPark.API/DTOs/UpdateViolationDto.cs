namespace AimPark.API.DTOs
{
    /// <summary>
    /// Corrections to an already-issued violation — a mistyped description, the
    /// wrong penalty, a suspension that should not have applied.
    ///
    /// Previously the only remedy was to dismiss and re-issue, which left a bogus
    /// dismissed record on the user's history and made their record look worse
    /// than it was.
    /// </summary>
    public class UpdateViolationDto
    {
        public string Description { get; set; } = string.Empty;
        public decimal PenaltyAmount { get; set; }
        public string SuspensionType { get; set; } = string.Empty;
        public int? SuspensionDays { get; set; }
    }
}
