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

                entity.HasIndex(u => u.Status);
                entity.HasIndex(u => u.Role);

                //Auto-generate GUID on insert
                entity.Property(u => u.Id)
                      .HasDefaultValueSql("gen_random_uuid()");


                entity.Property(u => u.CreatedAt)
                      .HasDefaultValueSql("NOW()");


                entity.Property(u => u.UpdatedAt)
                      .HasDefaultValueSql("NOW()");
            });
        }

    }
}
