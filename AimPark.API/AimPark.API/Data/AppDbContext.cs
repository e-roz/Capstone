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

                entity.Property(u => u.CreatedAt)
                      .HasDefaultValueSql("NOW()");

                entity.Property(u => u.UpdatedAt)
                      .HasDefaultValueSql("NOW()");
            });

            modelBuilder.Entity<RegistrationSession>(entity =>
            {
                entity.HasKey(s => s.Id);

                entity.HasIndex(s => s.Email);
                entity.HasIndex(s => s.PhoneNumber);
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
        }
    }
}
