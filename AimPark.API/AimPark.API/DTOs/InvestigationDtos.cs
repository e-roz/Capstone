using AimPark.API.Controllers;

namespace AimPark.API.DTOs
{
    /// <summary>One line in the Overview's search results.</summary>
    /// <param name="Kind">
    /// <c>person</c>, <c>visitor</c>, <c>card</c> (a card nobody holds that
    /// was tapped) or <c>plate</c> (a plate the camera read that nobody
    /// registered).
    /// </param>
    public record SearchResult(
        string Kind, string Title, string Subtitle,
        Guid? UserId, Guid? VisitorPassId, string? Card, string? Plate);

    public record SearchResponse(List<SearchResult> Results);

    public record ProfileVehicle(string Plate, string VehicleType, string Color);

    public record ProfilePerson(
        Guid Id, string FullName, string Email, string Role, string Affiliation,
        string? StudentNumber, string AccountStatus, string? RfidTagId, string RfidStatus,
        bool Archived, List<ProfileVehicle> Vehicles);

    public record ProfileVisitor(
        Guid Id, string VisitorName, string PlateNumber, string RfidTagId, string? Purpose,
        DateTime IssuedAt, DateTime ExpiresAt, DateTime? ReturnedAt);

    /// <param name="SlotCode">The bay on the session: the driver's pick when <paramref name="SlotConfirmed"/>, else only the gate's suggestion.</param>
    public record ProfileSession(
        Guid Id, DateTime EntryTime, DateTime? ExitTime, int? Gate, string? Plate, bool? PlateMatched,
        string? SlotCode = null, bool SlotConfirmed = false);

    public record ProfileViolation(
        Guid Id, string RuleTitle, string Status, decimal PenaltyAmount, DateTime CreatedAt);

    /// <param name="Preview">The start of what was written, so the row is recognisable.</param>
    public record ProfileIncident(Guid Id, string Category, string Status, DateTime CreatedAt, string Preview);

    /// <summary>How much there is behind each list, since a list shows only the latest few.</summary>
    public record ProfileTotals(
        int Taps, int DeniedTaps, int SeriousDeniedTaps, int Sessions, int Violations, int Incidents);

    /// <summary>
    /// Everything the system holds about one person, visitor card, unknown card
    /// or unregistered plate: the starting point for an investigation.
    /// </summary>
    /// <remarks>
    /// <c>Taps</c> uses the Gate Taps row so the panel can show them the way
    /// that page does. For a person they are the taps made with their card,
    /// plus any where the camera read one of their plates, even on somebody
    /// else's card. Incidents are the ones this person filed: an incident has
    /// no plate or vehicle of its own to be matched against.
    /// </remarks>
    public class InvestigationProfile
    {
        /// <summary><c>person</c>, <c>visitor</c>, <c>card</c> or <c>plate</c>.</summary>
        public string Kind { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public string Subtitle { get; set; } = string.Empty;

        public ProfilePerson? Person { get; set; }
        public ProfileVisitor? Visitor { get; set; }

        /// <summary>Set when the subject is a card nobody holds.</summary>
        public string? Card { get; set; }

        /// <summary>Set when the subject is a plate nobody registered.</summary>
        public string? Plate { get; set; }

        public ProfileTotals Totals { get; set; } = new(0, 0, 0, 0, 0, 0);
        public List<LiveGateController.GateTapRow> Taps { get; set; } = [];
        public List<ProfileSession> Sessions { get; set; } = [];
        public List<ProfileViolation> Violations { get; set; } = [];
        public List<ProfileIncident> Incidents { get; set; } = [];
    }
}
