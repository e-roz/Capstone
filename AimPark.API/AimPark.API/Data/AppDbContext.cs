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
        public DbSet<RegistrationSession> RegistrationSessions { get; set; }
        public DbSet<AdminAuditLog> AdminAuditLogs { get; set; }
        public DbSet<ParkingSlot> ParkingSlots { get; set; }
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

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<User>(entity =>
            {
                entity.HasKey(u => u.Id);

                entity.HasIndex(u => u.Email)
                      .IsUnique();

                entity.HasIndex(u => u.PhoneNumber)
                      .IsUnique()
                      .HasFilter("\"PhoneNumber\" IS NOT NULL AND \"PhoneNumber\" <> ''");

                entity.Property(u => u.AuthProvider)
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

                entity.HasOne(v => v.User)
                      .WithOne()
                      .HasForeignKey<Vehicle>(v => v.UserId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<Document>(entity =>
            {
                entity.HasKey(d => d.Id);
                entity.HasIndex(d => d.UserId);

                entity.HasOne(d => d.User)
                      .WithMany()
                      .HasForeignKey(d => d.UserId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<ParkingSlot>(entity =>
            {
                entity.HasKey(s => s.Id);

                entity.HasIndex(s => s.SlotCode)
                      .IsUnique();

                entity.Property(s => s.Status)
                      .HasConversion<string>();

                entity.Property(s => s.UpdatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.HasData(ParkingSlotSeed.GetSeedSlots());
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

                entity.HasOne(l => l.Slot)
                      .WithMany()
                      .HasForeignKey(l => l.SlotId)
                      .OnDelete(DeleteBehavior.SetNull);
            });

            modelBuilder.Entity<Notification>(entity =>
            {
                entity.HasKey(n => n.Id);

                entity.HasIndex(n => n.CreatedAt);

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

                entity.HasIndex(r => r.VehicleType)
                      .IsUnique()
                      .HasFilter("\"VehicleType\" IS NOT NULL");

                entity.Property(r => r.RatePerHour)
                      .HasColumnType("decimal(10,2)");

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

            modelBuilder.Entity<ViolationAppeal>(entity =>
            {
                entity.HasKey(a => a.Id);

                entity.HasIndex(a => a.ViolationId)
                      .IsUnique();

                entity.Property(a => a.Status)
                      .HasConversion<string>();

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
