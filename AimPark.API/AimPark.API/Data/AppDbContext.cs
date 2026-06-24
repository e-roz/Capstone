using AimPark.API.Entities;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options)
            : base(options) { }

        //Each DbSet = one table in my database
        public DbSet<User> Users { get; set; }

        public DbSet<Vehicle> vehicles { get; set; }

        public DbSet<Document> Documents { get; set; }


        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Configure the User entity
            modelBuilder.Entity<User>(entity =>
            {
                // Primary Key
                entity.HasKey(u => u.Id);


                //Unique email - no duplicate accounts
                entity.HasIndex(u => u.Email)
                      .IsUnique();

                entity.Property(u => u.Status)
                      .HasConversion<string>();

                entity.Property(u => u.Role)
                      .HasConversion<string>();

                entity.Property(u => u.CreatedAt)
                      .HasDefaultValueSql("NOW()");


                entity.Property(u => u.UpdatedAt)
                      .HasDefaultValueSql("NOW()");
            });

            modelBuilder.Entity<Vehicle>(entity =>
            {
                // Primary Key
                entity.HasKey(v => v.Id);

                entity.HasIndex(v => v.PlateNumber)
                      .IsUnique();

                //foreign key relationship with User
                entity.HasOne(v => v.User)
                      .WithOne()
                      .HasForeignKey<Vehicle>(v => v.UserId)
                      .OnDelete(DeleteBehavior.Cascade);

            });

            modelBuilder.Entity<Document>(entity =>
            {
                // Primary Key
                entity.HasKey(d => d.Id);
                //foreign key relationship with User
                entity.HasIndex(d => d.UserId);
                
                entity.HasOne(d => d.User)
                      .WithMany()
                      .HasForeignKey(d => d.UserId)
                      .OnDelete(DeleteBehavior.Cascade);
            });
        }

    }
}
