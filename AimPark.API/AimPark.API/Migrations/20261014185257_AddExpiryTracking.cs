using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddExpiryTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "RegistrationExpiryReminderSentFor",
                table: "vehicles",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LicenseExpiryReminderSentFor",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LicenseValidThrough",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            // Existing users already have a licence date, but only inside the
            // verification row it was read into. Copy the latest one across so the
            // new column is not empty for everyone approved before this existed.
            migrationBuilder.Sql(
                """
                UPDATE "Users" u
                SET "LicenseValidThrough" = v."Expiry"
                FROM (
                    SELECT DISTINCT ON ("UserId")
                           "UserId",
                           COALESCE("ConfirmedLicenseExpiry", "ExtractedLicenseExpiry") AS "Expiry"
                    FROM "DocumentVerifications"
                    WHERE COALESCE("ConfirmedLicenseExpiry", "ExtractedLicenseExpiry") IS NOT NULL
                    ORDER BY "UserId", "CreatedAt" DESC
                ) v
                WHERE u."Id" = v."UserId";
                """);

            migrationBuilder.CreateTable(
                name: "DocumentRenewals",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    VehicleId = table.Column<Guid>(type: "uuid", nullable: true),
                    Type = table.Column<string>(type: "text", nullable: false),
                    DocumentId = table.Column<Guid>(type: "uuid", nullable: false),
                    ExtractedExpiry = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    NewExpiry = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Status = table.Column<string>(type: "text", nullable: false),
                    ReviewedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    ReviewedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    RejectReason = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DocumentRenewals", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DocumentRenewals_Documents_DocumentId",
                        column: x => x.DocumentId,
                        principalTable: "Documents",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_DocumentRenewals_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_DocumentRenewals_vehicles_VehicleId",
                        column: x => x.VehicleId,
                        principalTable: "vehicles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DocumentRenewals_DocumentId",
                table: "DocumentRenewals",
                column: "DocumentId");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentRenewals_Status_CreatedAt",
                table: "DocumentRenewals",
                columns: new[] { "Status", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_DocumentRenewals_UserId",
                table: "DocumentRenewals",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentRenewals_VehicleId",
                table: "DocumentRenewals",
                column: "VehicleId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DocumentRenewals");

            migrationBuilder.DropColumn(
                name: "RegistrationExpiryReminderSentFor",
                table: "vehicles");

            migrationBuilder.DropColumn(
                name: "LicenseExpiryReminderSentFor",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "LicenseValidThrough",
                table: "Users");
        }
    }
}
