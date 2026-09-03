namespace AimPark.API.DTOs
{
    public class RevokeRfidDto
    {
        /// <summary>One of <see cref="Enums.RfidRevokeReason"/>, as a string —
        /// decides whether the card goes back into circulation or is blocked.</summary>
        public string Reason { get; set; } = string.Empty;

        public string? Note { get; set; }
    }

    public class BulkRevokeRfidDto
    {
        public List<Guid> UserIds { get; set; } = [];
        public string Reason { get; set; } = string.Empty;
        public string? Note { get; set; }
    }

    public class BulkRevokeRfidResponse
    {
        public int Revoked { get; set; }
        public List<BulkRevokeSkip> Skipped { get; set; } = [];
    }

    public class BulkRevokeSkip
    {
        public Guid UserId { get; set; }
        public string Reason { get; set; } = string.Empty;
    }

    public class RfidCardResponse
    {
        public string RfidTagId { get; set; } = string.Empty;
        public string State { get; set; } = string.Empty;
        public string Reason { get; set; } = string.Empty;
        public string? Note { get; set; }
        public Guid LastUserId { get; set; }
        public string LastUserName { get; set; } = string.Empty;
        public DateTime UpdatedAt { get; set; }
    }
}
