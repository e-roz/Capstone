using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddSlotConfirmCorrections : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "SlotConfirmCorrections",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ParkingLogId = table.Column<Guid>(type: "uuid", nullable: false),
                    FromSlotId = table.Column<Guid>(type: "uuid", nullable: false),
                    ToSlotId = table.Column<Guid>(type: "uuid", nullable: false),
                    Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    CorrectedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CorrectedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SlotConfirmCorrections", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SlotConfirmCorrections_ParkingLogs_ParkingLogId",
                        column: x => x.ParkingLogId,
                        principalTable: "ParkingLogs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_SlotConfirmCorrections_ParkingSlots_FromSlotId",
                        column: x => x.FromSlotId,
                        principalTable: "ParkingSlots",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SlotConfirmCorrections_ParkingSlots_ToSlotId",
                        column: x => x.ToSlotId,
                        principalTable: "ParkingSlots",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_SlotConfirmCorrections_FromSlotId",
                table: "SlotConfirmCorrections",
                column: "FromSlotId");

            migrationBuilder.CreateIndex(
                name: "IX_SlotConfirmCorrections_ParkingLogId_CorrectedAt",
                table: "SlotConfirmCorrections",
                columns: new[] { "ParkingLogId", "CorrectedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_SlotConfirmCorrections_ToSlotId",
                table: "SlotConfirmCorrections",
                column: "ToSlotId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SlotConfirmCorrections");
        }
    }
}
