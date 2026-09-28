using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddGateTapEvents : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "GateTapEvents",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    At = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Gate = table.Column<int>(type: "integer", nullable: false),
                    ReaderName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Direction = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false),
                    Opened = table.Column<bool>(type: "boolean", nullable: false),
                    Message = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    RfidTagId = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    PersonName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    PersonKind = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: true),
                    VisitorPassId = table.Column<Guid>(type: "uuid", nullable: true),
                    CameraPlate = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    RegisteredPlates = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    PlateMatches = table.Column<bool>(type: "boolean", nullable: true),
                    ParkingLogId = table.Column<Guid>(type: "uuid", nullable: true),
                    HasPhoto = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GateTapEvents", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_GateTapEvents_At",
                table: "GateTapEvents",
                column: "At");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GateTapEvents");
        }
    }
}
