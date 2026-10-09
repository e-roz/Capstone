using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class WrongBayFlagsAndSessionVehicleType : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "VehicleType",
                table: "ParkingLogs",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "WrongBayFlags",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SlotId = table.Column<Guid>(type: "uuid", nullable: false),
                    DetectedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    ReviewedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    ReviewedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    BayClearedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WrongBayFlags", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WrongBayFlags_ParkingSlots_SlotId",
                        column: x => x.SlotId,
                        principalTable: "ParkingSlots",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_WrongBayFlags_SlotId_BayClearedAt",
                table: "WrongBayFlags",
                columns: new[] { "SlotId", "BayClearedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "WrongBayFlags");

            migrationBuilder.DropColumn(
                name: "VehicleType",
                table: "ParkingLogs");
        }
    }
}
