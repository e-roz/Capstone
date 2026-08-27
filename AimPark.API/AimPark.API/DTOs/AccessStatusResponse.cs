namespace AimPark.API.DTOs
{
    public class AccessStatusResponse
    {
        public string? RfidTagId { get; set; }
        public string RfidStatus { get; set; } = string.Empty;
        public string AccountStatus { get; set; } = string.Empty;

        /// <summary>Whether the gate would refuse this tag right now.</summary>
        /// <remarks>
        /// Not the same as <c>RfidStatus == "Suspended"</c> any more: a
        /// suspension attached to a violation is scheduled a few days out so the
        /// user can appeal first, and reads as Suspended for that whole window
        /// while the card still works.
        /// </remarks>
        public bool IsSuspendedNow { get; set; }

        /// <summary>
        /// When a scheduled suspension begins, or null when there is not one
        /// waiting. Non-null is the app's cue to show the appeal deadline.
        /// </summary>
        public DateTime? SuspensionStartsAt { get; set; }

        /// <summary>When a temporary suspension lifts. Null if permanent.</summary>
        public DateTime? SuspensionEndsAt { get; set; }
    }
}
