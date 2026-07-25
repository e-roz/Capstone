using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddRfidAccessStatusAndParkingFeatures : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "RfidStatus",
                table: "Users",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "RfidTagId",
                table: "Users",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ParkingSlots",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SlotCode = table.Column<string>(type: "text", nullable: false),
                    VehicleType = table.Column<string>(type: "text", nullable: true),
                    Status = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ParkingSlots", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ParkingLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    SlotId = table.Column<Guid>(type: "uuid", nullable: true),
                    EntryTime = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExitTime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LoggedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ParkingLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ParkingLogs_ParkingSlots_SlotId",
                        column: x => x.SlotId,
                        principalTable: "ParkingSlots",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_ParkingLogs_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "ParkingSlots",
                columns: new[] { "Id", "CreatedAt", "SlotCode", "Status", "UpdatedAt", "VehicleType" },
                values: new object[,]
                {
                    { new Guid("00000000-0000-0000-0000-000000000001"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A1", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000002"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A2", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000003"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A3", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000004"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A4", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000005"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A5", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000006"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A6", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000007"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A7", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000008"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A8", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000009"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A9", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000010"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A10", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000011"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A11", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000012"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A12", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000013"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A13", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000014"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A14", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000015"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A15", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000016"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A16", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000017"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A17", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000018"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A18", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000019"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A19", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null },
                    { new Guid("00000000-0000-0000-0000-000000000020"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "A20", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), null }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Users_RfidTagId",
                table: "Users",
                column: "RfidTagId",
                unique: true,
                filter: "\"RfidTagId\" IS NOT NULL AND \"RfidTagId\" <> ''");

            migrationBuilder.CreateIndex(
                name: "IX_ParkingLogs_EntryTime",
                table: "ParkingLogs",
                column: "EntryTime");

            migrationBuilder.CreateIndex(
                name: "IX_ParkingLogs_SlotId",
                table: "ParkingLogs",
                column: "SlotId");

            migrationBuilder.CreateIndex(
                name: "IX_ParkingLogs_UserId",
                table: "ParkingLogs",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_ParkingSlots_SlotCode",
                table: "ParkingSlots",
                column: "SlotCode",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ParkingLogs");

            migrationBuilder.DropTable(
                name: "ParkingSlots");

            migrationBuilder.DropIndex(
                name: "IX_Users_RfidTagId",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "RfidStatus",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "RfidTagId",
                table: "Users");
        }
    }
}
