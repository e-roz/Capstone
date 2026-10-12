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

        /// <summary>"Free" or "Blocked" for a pool card; "Assigned" for a card
        /// on someone's account (only returned with <c>includeAssigned=true</c>).</summary>
        public string State { get; set; } = string.Empty;

        /// <summary>Empty for an assigned card — nothing has been revoked.</summary>
        public string Reason { get; set; } = string.Empty;
        public string? Note { get; set; }

        /// <summary>Who the card was last taken from. Empty for an assigned card.</summary>
        public Guid LastUserId { get; set; }
        public string LastUserName { get; set; } = string.Empty;

        /// <summary>
        /// When the card last changed hands. For an assigned card, the newest
        /// AssignRfid audit row for the holder — or null when the audit log
        /// has none (cards handed out before the log existed).
        /// </summary>
        public DateTime? UpdatedAt { get; set; }

        // The holder fields below are filled only for State = "Assigned".
        public Guid? HolderUserId { get; set; }
        public string? HolderName { get; set; }
        public string? HolderStudentNumber { get; set; }
        public string? HolderAffiliation { get; set; }
        public string? HolderRole { get; set; }

        /// <summary>The holder's RfidStatus — Active or Suspended.</summary>
        public string? HolderRfidStatus { get; set; }
        public DateTime? HolderSuspendedUntil { get; set; }

        /// <summary>True when the holder's account is archived but the card
        /// was never taken off it.</summary>
        public bool HolderArchived { get; set; }
    }

    /// <summary>One line of a card's history, rebuilt from the admin audit log.</summary>
    public class RfidCardHistoryEntry
    {
        /// <summary>The audit action: AssignRfid, RevokeRfid or Reinstate.</summary>
        public string Action { get; set; } = string.Empty;

        /// <summary>The revoke reason (an <see cref="Enums.RfidRevokeReason"/>
        /// name) for RevokeRfid; null otherwise.</summary>
        public string? Reason { get; set; }
        public string? Note { get; set; }

        public Guid UserId { get; set; }
        public string UserName { get; set; } = string.Empty;

        /// <summary>Null when the system did it (the violation deadline job).</summary>
        public Guid? ActorUserId { get; set; }
        public string ActorName { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; }
    }
}
