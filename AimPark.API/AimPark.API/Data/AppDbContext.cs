using AimPark.API.Entities;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options)
            : base(options) { }

        public DbSet<User> Users { get; set; }
        public DbSet<Vehicle> vehicles { get; set; }
        public DbSet<Document> Documents { get; set; }
        public DbSet<DocumentVerification> DocumentVerifications { get; set; }
        public DbSet<RegistrationSession> RegistrationSessions { get; set; }
        public DbSet<AdminAuditLog> AdminAuditLogs { get; set; }
        public DbSet<ParkingSlot> ParkingSlots { get; set; }
        public DbSet<GateDevice> GateDevices { get; set; }
        public DbSet<AppealEvidence> AppealEvidence { get; set; }
        public DbSet<ParkingLog> ParkingLogs { get; set; }
        public DbSet<Notification> Notifications { get; set; }
        public DbSet<NotificationRead> NotificationReads { get; set; }
        public DbSet<Incident> Incidents { get; set; }
        public DbSet<IncidentEvidence> IncidentEvidence { get; set; }
        public DbSet<ParkingRate> ParkingRates { get; set; }
        public DbSet<PaymentTransaction> PaymentTransactions { get; set; }
        public DbSet<PolicyRule> PolicyRules { get; set; }
        public DbSet<Violation> Violations { get; set; }
        public DbSet<ViolationAppeal> ViolationAppeals { get; set; }
        public DbSet<DeviceToken> DeviceTokens { get; set; }
        public DbSet<UserActivityLog> UserActivityLogs { get; set; }
        public DbSet<SystemErrorLog> SystemErrorLogs { get; set; }
        public DbSet<VisitorPass> VisitorPasses { get; set; }
        public DbSet<RfidCard> RfidCards { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<User>(entity =>
            {
                entity.HasKey(u => u.Id);

                entity.HasIndex(u => u.Email)
                      .IsUnique();

                // One student, one account — otherwise the same person registers twice
                // under two emails and collects two RFID cards. Filtered, because
                // faculty and staff have no student number and must not collide.
                entity.HasIndex(u => u.StudentNumber)
                      .IsUnique()
                      .HasFilter("\"StudentNumber\" IS NOT NULL AND \"StudentNumber\" <> ''");

                entity.Property(u => u.AuthProvider)
                      .HasConversion<string>();

                entity.Property(u => u.Affiliation)
                      .HasConversion<string>();

                entity.Property(u => u.RegistrationStep)
                      .HasConversion<string>();

                entity.Property(u => u.AccountStatus)
                      .HasConversion<string>();

                entity.Property(u => u.VerificationStatus)
                      .HasConversion<string>();

                entity.Property(u => u.Role)
                      .HasConversion<string>();

                entity.Property(u => u.RfidStatus)
                      .HasConversion<string>();

                entity.HasIndex(u => u.RfidTagId)
                      .IsUnique()
                      .HasFilter("\"RfidTagId\" IS NOT NULL AND \"RfidTagId\" <> ''");

                entity.Property(u => u.CreatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.Property(u => u.UpdatedAt)
                      .HasDefaultValueSql("NOW()");
            });

            modelBuilder.Entity<RegistrationSession>(entity =>
            {
                entity.HasKey(s => s.Id);

                entity.HasIndex(s => s.Email);
                entity.HasIndex(s => s.ExpiresAt);

                entity.Property(s => s.LastOtpChannel)
                      .HasConversion<string>();

                entity.Property(s => s.PendingAuthProvider)
                      .HasConversion<string>();

                entity.Property(s => s.CreatedAt)
                      .HasDefaultValueSql("NOW()");
            });

            modelBuilder.Entity<UserActivityLog>(entity =>
            {
                entity.HasKey(a => a.Id);

                // The two questions this table is asked: "everything that
                // happened to this account" and "everything that happened this
                // week". Both get an index; nothing else is queried.
                entity.HasIndex(a => a.UserId);
                entity.HasIndex(a => a.CreatedAt);

                entity.Property(a => a.EmailAtTime).HasMaxLength(256);
                entity.Property(a => a.Activity).HasMaxLength(64);
                entity.Property(a => a.IpAddress).HasMaxLength(64);

                entity.Property(a => a.CreatedAt)
                      .HasDefaultValueSql("NOW()");
            });

            modelBuilder.Entity<SystemErrorLog>(entity =>
            {
                entity.HasKey(e => e.Id);

                entity.HasIndex(e => e.CreatedAt);

                entity.Property(e => e.ErrorType).HasMaxLength(256);
                entity.Property(e => e.Path).HasMaxLength(512);
                entity.Property(e => e.TraceId).HasMaxLength(128);

                entity.Property(e => e.CreatedAt)
                      .HasDefaultValueSql("NOW()");
            });

            modelBuilder.Entity<AdminAuditLog>(entity =>
            {
                entity.HasKey(a => a.Id);

                entity.HasIndex(a => a.TargetUserId);
                entity.HasIndex(a => a.AdminUserId);
                entity.HasIndex(a => a.CreatedAt);

                entity.Property(a => a.CreatedAt)
                      .HasDefaultValueSql("NOW()");
            });

            modelBuilder.Entity<Vehicle>(entity =>
            {
                entity.HasKey(v => v.Id);

                entity.HasIndex(v => v.PlateNumber)
                      .IsUnique();

                entity.Property(v => v.VehicleType)
                      .HasConversion<string>();

                // Many vehicles per user — one RFID card covers all of them. The plate
                // index above stays unique regardless: ALPR looks a plate up and must
                // get exactly one vehicle back, or the gate cannot decide.
                entity.HasOne(v => v.User)
                      .WithMany()
                      .HasForeignKey(v => v.UserId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<Document>(entity =>
            {
                entity.HasKey(d => d.Id);
                entity.HasIndex(d => d.UserId);

                // Looked up across accounts to spot the same photograph submitted
                // twice, which is a scan of the whole table without this.
                entity.HasIndex(d => d.Sha256);

                entity.Property(d => d.Type)
                      .HasConversion<string>();

                entity.HasOne(d => d.User)
                      .WithMany()
                      .HasForeignKey(d => d.UserId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<DocumentVerification>(entity =>
            {
                entity.HasKey(v => v.Id);

                // The review queue lists a user's submissions newest first.
                entity.HasIndex(v => v.UserId);
                entity.HasIndex(v => v.CreatedAt);

                entity.Property(v => v.NameMatch).HasConversion<string>();
                entity.Property(v => v.PlateMatch).HasConversion<string>();
                entity.Property(v => v.PlatePhotoMatch).HasConversion<string>();
                entity.Property(v => v.LicenseValidity).HasConversion<string>();
                entity.Property(v => v.RegistrationValidity).HasConversion<string>();
                entity.Property(v => v.EnrollmentValidity).HasConversion<string>();
                entity.Property(v => v.Result).HasConversion<string>();

                entity.Property(v => v.CreatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasOne(v => v.User)
                      .WithMany()
                      .HasForeignKey(v => v.UserId)
                      .OnDelete(DeleteBehavior.Cascade);

                // Losing the vehicle must not destroy the evidence behind a decision
                // already made about the person.
                entity.HasOne(v => v.Vehicle)
                      .WithMany()
                      .HasForeignKey(v => v.VehicleId)
                      .OnDelete(DeleteBehavior.SetNull);
            });

            modelBuilder.Entity<ParkingSlot>(entity =>
            {
                entity.HasKey(s => s.Id);

                entity.HasIndex(s => s.SlotCode)
                      .IsUnique();

                entity.Property(s => s.Status)
                      .HasConversion<string>();

                entity.Property(s => s.VehicleType)
                      .HasConversion<string>();

                // Allocation scores free capacity per gate on every scan.
                entity.HasIndex(s => new { s.Gate, s.VehicleType, s.Status });

                entity.Property(s => s.UpdatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasData(ParkingSlotSeed.GetSeedSlots());
            });

            modelBuilder.Entity<GateDevice>(entity =>
            {
                entity.HasKey(d => d.Id);

                // Authentication looks a device up by key hash on every scan.
                entity.HasIndex(d => d.ApiKeyHash)
                      .IsUnique();

                entity.Property(d => d.CreatedAt)
                      .HasDefaultValueSql("NOW()");
            });

            modelBuilder.Entity<VisitorPass>(entity =>
            {
                entity.HasKey(v => v.Id);

                entity.Property(v => v.RfidTagId).IsRequired().HasMaxLength(64);
                entity.Property(v => v.VisitorName).IsRequired().HasMaxLength(120);
                entity.Property(v => v.PlateNumber).IsRequired().HasMaxLength(20);
                entity.Property(v => v.Purpose).HasMaxLength(200);
                entity.Property(v => v.ContactNumber).HasMaxLength(32);

                entity.Property(v => v.VehicleType).HasConversion<string>().HasMaxLength(20);
                entity.Property(v => v.Status).HasConversion<string>().HasMaxLength(20);

                // One card, one open pass. The filter is what allows the same
                // physical card to be lent out again after it comes back —
                // a plain unique index would retire every card after one use.
                entity.HasIndex(v => v.RfidTagId)
                      .IsUnique()
                      .HasFilter("\"Status\" = 'Active'");

                entity.HasIndex(v => v.IssuedAt);
            });

            modelBuilder.Entity<ParkingLog>(entity =>
            {
                entity.HasKey(l => l.Id);

                entity.HasIndex(l => l.UserId);
                entity.HasIndex(l => l.EntryTime);

                entity.Property(l => l.CreatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasOne(l => l.User)
                      .WithMany()
                      .HasForeignKey(l => l.UserId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(l => l.VisitorPass)
                      .WithMany()
                      .HasForeignKey(l => l.VisitorPassId)
                      // Restrict, not Cascade: a visitor pass is the record of
                      // who was let in, and deleting one must never take the
                      // parking history with it.
                      .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(l => l.VisitorPassId);

                entity.HasOne(l => l.Slot)
                      .WithMany()
                      .HasForeignKey(l => l.SlotId)
                      .OnDelete(DeleteBehavior.SetNull);
            });

            modelBuilder.Entity<Notification>(entity =>
            {
                entity.HasKey(n => n.Id);

                entity.HasIndex(n => n.CreatedAt);

                // Every user's list query filters on this first.
                entity.HasIndex(n => n.TargetUserId);

                entity.Property(n => n.Type)
                      .HasConversion<string>();

                entity.Property(n => n.TargetRole)
                      .HasConversion<string>();

                entity.Property(n => n.CreatedAt)
                      .HasDefaultValueSql("NOW()");
            });

            modelBuilder.Entity<NotificationRead>(entity =>
            {
                entity.HasKey(r => r.Id);

                entity.HasIndex(r => new { r.NotificationId, r.UserId })
                      .IsUnique();

                entity.Property(r => r.ReadAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasOne(r => r.Notification)
                      .WithMany()
                      .HasForeignKey(r => r.NotificationId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(r => r.User)
                      .WithMany()
                      .HasForeignKey(r => r.UserId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<Incident>(entity =>
            {
                entity.HasKey(i => i.Id);

                entity.HasIndex(i => i.ReportedByUserId);
                entity.HasIndex(i => i.Status);

                entity.Property(i => i.Category)
                      .HasConversion<string>();

                entity.Property(i => i.Status)
                      .HasConversion<string>();

                entity.Property(i => i.CreatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.Property(i => i.UpdatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasOne(i => i.ReportedByUser)
                      .WithMany()
                      .HasForeignKey(i => i.ReportedByUserId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<IncidentEvidence>(entity =>
            {
                entity.HasKey(e => e.Id);

                entity.HasIndex(e => e.IncidentId);

                entity.Property(e => e.UploadedAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasOne(e => e.Incident)
                      .WithMany()
                      .HasForeignKey(e => e.IncidentId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<ParkingRate>(entity =>
            {
                entity.HasKey(r => r.Id);

                entity.Property(r => r.VehicleType)
                      .HasConversion<string>();

                entity.HasIndex(r => r.VehicleType)
                      .IsUnique()
                      .HasFilter("\"VehicleType\" IS NOT NULL");

                entity.Property(r => r.RatePerHour)
                      .HasColumnType("decimal(10,2)");

                entity.Property(r => r.MinimumFee)
                      .HasColumnType("decimal(10,2)")
                      .HasDefaultValue(20.00m);

                entity.Property(r => r.UpdatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasData(ParkingRateSeed.GetSeedRates());
            });

            modelBuilder.Entity<PaymentTransaction>(entity =>
            {
                entity.HasKey(p => p.Id);

                entity.HasIndex(p => p.ParkingLogId)
                      .IsUnique()
                      .HasFilter("\"ParkingLogId\" IS NOT NULL");

                entity.HasIndex(p => p.ViolationId)
                      .IsUnique()
                      .HasFilter("\"ViolationId\" IS NOT NULL");

                entity.HasIndex(p => p.UserId);
                entity.HasIndex(p => p.Status);

                entity.Property(p => p.Source)
                      .HasConversion<string>();

                entity.Property(p => p.Status)
                      .HasConversion<string>();

                entity.Property(p => p.Method)
                      .HasConversion<string>();

                entity.Property(p => p.Provider).HasMaxLength(32);
                entity.Property(p => p.ProviderPaymentId).HasMaxLength(128);
                entity.Property(p => p.ReferenceNumber).HasMaxLength(128);

                // The callback arrives knowing the provider's id and nothing
                // else, so this is the lookup every settlement goes through.
                entity.HasIndex(p => p.ProviderPaymentId);

                entity.Property(p => p.RatePerHourApplied)
                      .HasColumnType("decimal(10,2)");

                entity.Property(p => p.AmountDue)
                      .HasColumnType("decimal(10,2)");

                entity.Property(p => p.CreatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasOne(p => p.ParkingLog)
                      .WithMany()
                      .HasForeignKey(p => p.ParkingLogId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(p => p.Violation)
                      .WithMany()
                      .HasForeignKey(p => p.ViolationId)
                      .OnDelete(DeleteBehavior.SetNull);

                entity.HasOne(p => p.User)
                      .WithMany()
                      .HasForeignKey(p => p.UserId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<PolicyRule>(entity =>
            {
                entity.HasKey(r => r.Id);

                entity.Property(r => r.DefaultSuspensionType)
                      .HasConversion<string>();

                entity.Property(r => r.Category)
                      .HasConversion<string>()
                      .HasDefaultValue(Enums.PolicyCategory.Parking);

                entity.Property(r => r.DefaultPenaltyAmount)
                      .HasColumnType("decimal(10,2)");

                entity.Property(r => r.CreatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.Property(r => r.UpdatedAt)
                      .HasDefaultValueSql("NOW()");
            });

            modelBuilder.Entity<Violation>(entity =>
            {
                entity.HasKey(v => v.Id);

                entity.HasIndex(v => v.UserId);
                entity.HasIndex(v => v.Status);

                entity.Property(v => v.SuspensionType)
                      .HasConversion<string>();

                entity.Property(v => v.Status)
                      .HasConversion<string>();

                entity.Property(v => v.PenaltyAmount)
                      .HasColumnType("decimal(10,2)");

                entity.Property(v => v.CreatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.Property(v => v.UpdatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasOne(v => v.User)
                      .WithMany()
                      .HasForeignKey(v => v.UserId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(v => v.PolicyRule)
                      .WithMany()
                      .HasForeignKey(v => v.PolicyRuleId)
                      .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(v => v.ParkingLog)
                      .WithMany()
                      .HasForeignKey(v => v.ParkingLogId)
                      .OnDelete(DeleteBehavior.SetNull);
            });

            modelBuilder.Entity<DeviceToken>(entity =>
            {
                entity.HasKey(t => t.Id);

                // The FCM token is the natural identity — the same device re-registering
                // must update the existing row rather than create a duplicate.
                entity.HasIndex(t => t.Token)
                      .IsUnique();

                entity.HasIndex(t => t.UserId);

                entity.Property(t => t.CreatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.Property(t => t.LastSeenAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasOne(t => t.User)
                      .WithMany()
                      .HasForeignKey(t => t.UserId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<RfidCard>(entity =>
            {
                entity.HasKey(c => c.RfidTagId);

                // The screen this feeds is "show me the free ones" / "show me
                // the blocked ones" — nothing else filters on this table.
                entity.HasIndex(c => c.State);

                entity.Property(c => c.State).HasConversion<string>();
                entity.Property(c => c.Reason).HasConversion<string>();

                entity.Property(c => c.UpdatedAt)
                      .HasDefaultValueSql("NOW()");
            });

            modelBuilder.Entity<ViolationAppeal>(entity =>
            {
                entity.HasKey(a => a.Id);

                entity.HasIndex(a => a.ViolationId)
                      .IsUnique();

                entity.Property(a => a.Status)
                      .HasConversion<string>();

                entity.HasMany<AppealEvidence>()
                      .WithOne(e => e.Appeal)
                      .HasForeignKey(e => e.AppealId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.Property(a => a.CreatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasOne(a => a.Violation)
                      .WithMany()
                      .HasForeignKey(a => a.ViolationId)
                      .OnDelete(DeleteBehavior.Cascade);
            });
        }
    }
}
