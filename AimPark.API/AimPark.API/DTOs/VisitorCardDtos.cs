namespace AimPark.API.DTOs
{
    /// <summary>Registers a card as one of the guard post's visitor cards.</summary>
    public class AddVisitorCardDto
    {
        public string RfidTagId { get; set; } = string.Empty;

        /// <summary>What is written on the card, e.g. "V1".</summary>
        public string Label { get; set; } = string.Empty;
    }

    public class BlockVisitorCardDto
    {
        public string? Note { get; set; }
    }

    /// <summary>One visitor card and where it is right now.</summary>
    public class VisitorCardResponse
    {
        public string RfidTagId { get; set; } = string.Empty;
        public string Label { get; set; } = string.Empty;

        /// <summary>"Active" or "Blocked".</summary>
        public string State { get; set; } = string.Empty;
        public string? Note { get; set; }

        /// <summary>
        /// "InDrawer", "OutWithVisitor", "NotYetReturned" or "Blocked" — see
        /// <c>VisitorCardService.WhereIs</c>.
        /// </summary>
        public string Whereabouts { get; set; } = string.Empty;

        /// <summary>The pass that last held the card, if it was ever lent.</summary>
        public Guid? LastPassId { get; set; }
        public string? LastVisitorName { get; set; }
        public string? LastPlateNumber { get; set; }
        public DateTime? LastIssuedAt { get; set; }
        public DateTime? LastReturnedAt { get; set; }

        /// <summary>How many visitors have carried it. A card with none can be removed outright.</summary>
        public int TimesLent { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
