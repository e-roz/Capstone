using AimPark.API.Entities;
using AimPark.API.Enums;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace AimPark.API.Sync
{
    /// <summary>Values of <see cref="SyncOutboxEntry.Kind"/>.</summary>
    public static class SyncKinds
    {
        public const string AlprReading = nameof(Entities.AlprReading);
        public const string ParkingLog = nameof(Entities.ParkingLog);
        public const string ParkingSlot = nameof(Entities.ParkingSlot);
        public const string GateAccessAttempt = nameof(Entities.GateAccessAttempt);
        public const string PaymentTransaction = nameof(Entities.PaymentTransaction);
        public const string Notification = nameof(Entities.Notification);
        public const string VisitorPass = nameof(Entities.VisitorPass);
        public const string GateDevice = nameof(Entities.GateDevice);
        public const string Push = "Push";
    }

    /// <summary>
    /// Cloud → site. Everything a gate decision reads, in full. Sent whole
    /// rather than as changes: a school's worth of it is small, and a full copy
    /// cannot drift out of step the way a missed change could.
    /// </summary>
    public class SiteSnapshot
    {
        public DateTime GeneratedAt { get; set; }
        public List<SyncUser> Users { get; set; } = [];
        public List<SyncVehicle> Vehicles { get; set; } = [];
        public List<VisitorPass> VisitorPasses { get; set; } = [];
        public List<GateDevice> GateDevices { get; set; } = [];
        public List<ParkingSlot> ParkingSlots { get; set; } = [];
        public List<ParkingRate> ParkingRates { get; set; } = [];
    }

    /// <summary>
    /// The part of a <see cref="User"/> the site needs: who holds which card,
    /// whether it is suspended, and enough to let staff sign in at the guard
    /// post with no internet. Password hashes travel for staff accounts only.
    /// </summary>
    public class SyncUser
    {
        public Guid Id { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public bool IsEmailVerified { get; set; }
        public string? PasswordHash { get; set; }
        public AuthProvider AuthProvider { get; set; }
        public UserRole Role { get; set; }
        public Affiliation Affiliation { get; set; }
        public string? StudentNumber { get; set; }
        public DateTime? EnrollmentValidUntil { get; set; }
        public RegistrationStep RegistrationStep { get; set; }
        public AccountStatus AccountStatus { get; set; }
        public VerificationStatus VerificationStatus { get; set; }
        public bool IsFirstLogin { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public bool IsDeleted { get; set; }
        public DateTime? DeletedAt { get; set; }
        public string? RfidTagId { get; set; }
        public RfidStatus RfidStatus { get; set; }
        public DateTime? RfidSuspendedFrom { get; set; }
        public DateTime? RfidSuspendedUntil { get; set; }
    }

    public class SyncVehicle
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }
        public string PlateNumber { get; set; } = string.Empty;
        public VehicleType VehicleType { get; set; }
        public string Color { get; set; } = string.Empty;
        public DateTime? RegistrationValidThrough { get; set; }
        public int? RegistrationRenewalMonth { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    /// <summary>
    /// Site → cloud. Records as they stand on the site server now. Every list
    /// is safe to receive twice: the cloud matches on id.
    /// </summary>
    /// <remarks>
    /// Not validated: the records travel without their navigation properties
    /// (a plate read without its device object, a payment without its user),
    /// which the API's implicit "non-nullable means required" rule would
    /// otherwise refuse. The ids they carry are what matter.
    /// </remarks>
    [ValidateNever]
    public class SiteEventBatch
    {
        public List<VisitorPass> VisitorPasses { get; set; } = [];
        public List<AlprReading> AlprReadings { get; set; } = [];
        public List<ParkingLog> ParkingLogs { get; set; } = [];
        public List<SlotStatusUpdate> SlotStatuses { get; set; } = [];
        public List<GateAccessAttempt> GateAccessAttempts { get; set; } = [];
        public List<PaymentTransaction> PaymentTransactions { get; set; } = [];
        public List<Notification> Notifications { get; set; } = [];
        public List<DeviceSeenUpdate> DevicesSeen { get; set; } = [];
        public List<PushRequest> Pushes { get; set; } = [];

        public bool IsEmpty =>
            VisitorPasses.Count == 0 && AlprReadings.Count == 0 && ParkingLogs.Count == 0 &&
            SlotStatuses.Count == 0 && GateAccessAttempts.Count == 0 &&
            PaymentTransactions.Count == 0 && Notifications.Count == 0 &&
            DevicesSeen.Count == 0 && Pushes.Count == 0;
    }

    /// <summary>Occupancy only. What a bay is and where it sits belongs to the cloud.</summary>
    public class SlotStatusUpdate
    {
        public Guid Id { get; set; }
        public ParkingSlotStatus Status { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    public class DeviceSeenUpdate
    {
        public Guid Id { get; set; }
        public DateTime LastSeenAt { get; set; }
    }

    /// <summary>
    /// A phone notification the site wanted to send. The site cannot reach
    /// Firebase without the internet, so it hands these to the cloud instead.
    /// </summary>
    public class PushRequest
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        /// <summary>Set for one person; null means <see cref="TargetRole"/>.</summary>
        public Guid? TargetUserId { get; set; }

        /// <summary>Null together with a null <see cref="TargetUserId"/> means everyone.</summary>
        public UserRole? TargetRole { get; set; }

        public string Title { get; set; } = string.Empty;
        public string Body { get; set; } = string.Empty;
        public Dictionary<string, string>? Data { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
