using AimPark.API.Enums;

namespace AimPark.API.DTOs
{
    /// <summary>Hands a spare RFID card to a visitor.</summary>
    public class IssueVisitorPassDto
    {
        public string RfidTagId { get; set; } = string.Empty;
        public string VisitorName { get; set; } = string.Empty;
        public string PlateNumber { get; set; } = string.Empty;

        /// <summary>Motorcycle or Car. Decides which bays they can be given.</summary>
        public string VehicleType { get; set; } = "Car";

        public string? Purpose { get; set; }
        public string? ContactNumber { get; set; }

        /// <summary>
        /// Hours the card stays valid. Left null it expires at the end of the
        /// day it was issued, which is what a day pass means.
        /// </summary>
        public int? ValidForHours { get; set; }
    }

    public class VisitorPassResponse
    {
        public Guid PassId { get; set; }
        public string RfidTagId { get; set; } = string.Empty;
        public string VisitorName { get; set; } = string.Empty;
        public string PlateNumber { get; set; } = string.Empty;
        public string VehicleType { get; set; } = string.Empty;
        public string? Purpose { get; set; }
        public string? ContactNumber { get; set; }
        public string Status { get; set; } = string.Empty;
        public DateTime IssuedAt { get; set; }
        public DateTime ExpiresAt { get; set; }
        public DateTime? ReturnedAt { get; set; }

        /// <summary>Who handed the card over, for the log.</summary>
        public string? IssuedByName { get; set; }

        /// <summary>
        /// True while the visitor's vehicle is inside the lot. The guard must
        /// not take a card back from somebody whose car is still parked.
        /// </summary>
        public bool IsInside { get; set; }

        /// <summary>Where they were parked, while they are still inside.</summary>
        public string? SlotCode { get; set; }
    }

    public class VisitorPassListResponse
    {
        public List<VisitorPassResponse> Passes { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    /// <summary>
    /// What a guard sees when they scan or type a card at the barrier: who it
    /// belongs to, and what should be sitting in front of them.
    /// </summary>
    /// <remarks>
    /// This is the "dual-factor verification" half the hardware cannot do. The
    /// reader proves the card is genuine; only a person can check that the car
    /// holding it is the car the card is registered to.
    /// </remarks>
    public class TagLookupResponse
    {
        /// <summary>"User", "Visitor", or "Unknown".</summary>
        public string Holder { get; set; } = "Unknown";

        public string? Name { get; set; }
        public string? Affiliation { get; set; }

        /// <summary>Every plate this card may legitimately arrive on.</summary>
        public List<TagVehicleResponse> Vehicles { get; set; } = [];

        /// <summary>Whether the barrier would open for this card right now.</summary>
        public bool AccessAllowed { get; set; }

        /// <summary>Why not, when it would not. Null when access is fine.</summary>
        public string? DeniedReason { get; set; }

        public bool IsInside { get; set; }
        public string? SlotCode { get; set; }
        public DateTime? EntryTime { get; set; }

        /// <summary>Set only for a visitor card.</summary>
        public DateTime? PassExpiresAt { get; set; }
    }

    public class TagVehicleResponse
    {
        public string PlateNumber { get; set; } = string.Empty;
        public string VehicleType { get; set; } = string.Empty;
        public string? Color { get; set; }
        public bool RegistrationExpired { get; set; }
    }
}
