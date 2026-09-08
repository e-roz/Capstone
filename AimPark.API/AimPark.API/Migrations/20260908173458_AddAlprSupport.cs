using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddAlprSupport : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "AlprMatched",
                table: "ParkingLogs",
                type: "boolean",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AlprPlateNumber",
                table: "ParkingLogs",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "AlprReadingId",
                table: "ParkingLogs",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeviceType",
                table: "GateDevices",
                type: "text",
                nullable: false,
                defaultValue: "RfidReader");

            migrationBuilder.CreateTable(
                name: "AlprReadings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Gate = table.Column<int>(type: "integer", nullable: false),
                    PlateNumber = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Confidence = table.Column<double>(type: "double precision", nullable: true),
                    DeviceId = table.Column<Guid>(type: "uuid", nullable: false),
                    ReadAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    ConsumedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AlprReadings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AlprReadings_GateDevices_DeviceId",
                        column: x => x.DeviceId,
                        principalTable: "GateDevices",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "GateAccessAttempts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Gate = table.Column<int>(type: "integer", nullable: false),
                    RfidTagId = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: true),
                    VisitorPassId = table.Column<Guid>(type: "uuid", nullable: true),
                    AlprPlateNumber = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    AlprConfidence = table.Column<double>(type: "double precision", nullable: true),
                    Outcome = table.Column<string>(type: "text", nullable: false),
                    ReviewedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    ReviewedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ResultingLogId = table.Column<Guid>(type: "uuid", nullable: true),
                    AttemptedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GateAccessAttempts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_GateAccessAttempts_ParkingLogs_ResultingLogId",
                        column: x => x.ResultingLogId,
                        principalTable: "ParkingLogs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_GateAccessAttempts_Users_ReviewedByUserId",
                        column: x => x.ReviewedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_GateAccessAttempts_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_GateAccessAttempts_VisitorPasses_VisitorPassId",
                        column: x => x.VisitorPassId,
                        principalTable: "VisitorPasses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ParkingLogs_AlprReadingId",
                table: "ParkingLogs",
                column: "AlprReadingId");

            migrationBuilder.CreateIndex(
                name: "IX_AlprReadings_DeviceId",
                table: "AlprReadings",
                column: "DeviceId");

            migrationBuilder.CreateIndex(
                name: "IX_AlprReadings_Gate_ConsumedAt_ReadAt",
                table: "AlprReadings",
                columns: new[] { "Gate", "ConsumedAt", "ReadAt" });

            migrationBuilder.CreateIndex(
                name: "IX_GateAccessAttempts_AttemptedAt",
                table: "GateAccessAttempts",
                column: "AttemptedAt");

            migrationBuilder.CreateIndex(
                name: "IX_GateAccessAttempts_ResultingLogId",
                table: "GateAccessAttempts",
                column: "ResultingLogId");

            migrationBuilder.CreateIndex(
                name: "IX_GateAccessAttempts_ReviewedAt",
                table: "GateAccessAttempts",
                column: "ReviewedAt");

            migrationBuilder.CreateIndex(
                name: "IX_GateAccessAttempts_ReviewedByUserId",
                table: "GateAccessAttempts",
                column: "ReviewedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_GateAccessAttempts_UserId",
                table: "GateAccessAttempts",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_GateAccessAttempts_VisitorPassId",
                table: "GateAccessAttempts",
                column: "VisitorPassId");

            migrationBuilder.AddForeignKey(
                name: "FK_ParkingLogs_AlprReadings_AlprReadingId",
                table: "ParkingLogs",
                column: "AlprReadingId",
                principalTable: "AlprReadings",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ParkingLogs_AlprReadings_AlprReadingId",
                table: "ParkingLogs");

            migrationBuilder.DropTable(
                name: "AlprReadings");

            migrationBuilder.DropTable(
                name: "GateAccessAttempts");

            migrationBuilder.DropIndex(
                name: "IX_ParkingLogs_AlprReadingId",
                table: "ParkingLogs");

            migrationBuilder.DropColumn(
                name: "AlprMatched",
                table: "ParkingLogs");

            migrationBuilder.DropColumn(
                name: "AlprPlateNumber",
                table: "ParkingLogs");

            migrationBuilder.DropColumn(
                name: "AlprReadingId",
                table: "ParkingLogs");

            migrationBuilder.DropColumn(
                name: "DeviceType",
                table: "GateDevices");
        }
    }
}
