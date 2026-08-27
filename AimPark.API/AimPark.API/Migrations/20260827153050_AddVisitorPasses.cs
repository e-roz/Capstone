using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddVisitorPasses : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<Guid>(
                name: "UserId",
                table: "ParkingLogs",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<Guid>(
                name: "VisitorPassId",
                table: "ParkingLogs",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "VisitorPasses",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RfidTagId = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    VisitorName = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    PlateNumber = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    VehicleType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Purpose = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    ContactNumber = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    IssuedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    IssuedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ReturnedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VisitorPasses", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ParkingLogs_VisitorPassId",
                table: "ParkingLogs",
                column: "VisitorPassId");

            migrationBuilder.CreateIndex(
                name: "IX_VisitorPasses_IssuedAt",
                table: "VisitorPasses",
                column: "IssuedAt");

            migrationBuilder.CreateIndex(
                name: "IX_VisitorPasses_RfidTagId",
                table: "VisitorPasses",
                column: "RfidTagId",
                unique: true,
                filter: "\"Status\" = 'Active'");

            migrationBuilder.AddForeignKey(
                name: "FK_ParkingLogs_VisitorPasses_VisitorPassId",
                table: "ParkingLogs",
                column: "VisitorPassId",
                principalTable: "VisitorPasses",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ParkingLogs_VisitorPasses_VisitorPassId",
                table: "ParkingLogs");

            migrationBuilder.DropTable(
                name: "VisitorPasses");

            migrationBuilder.DropIndex(
                name: "IX_ParkingLogs_VisitorPassId",
                table: "ParkingLogs");

            migrationBuilder.DropColumn(
                name: "VisitorPassId",
                table: "ParkingLogs");

            migrationBuilder.AlterColumn<Guid>(
                name: "UserId",
                table: "ParkingLogs",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);
        }
    }
}
