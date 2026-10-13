using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class ParkingLogGateAndDropRecordedBy : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Gate",
                table: "ParkingLogs",
                type: "integer",
                nullable: true);

            // Old rows only know a gate through the bay they were given, which
            // was a suggestion, so this is a best guess. Rows with no bay stay null.
            migrationBuilder.Sql(@"
                UPDATE ""ParkingLogs"" AS l
                SET ""Gate"" = s.""Gate""
                FROM ""ParkingSlots"" AS s
                WHERE l.""SlotId"" = s.""Id"";");

            migrationBuilder.DropColumn(
                name: "LoggedByDeviceId",
                table: "ParkingLogs");

            migrationBuilder.DropColumn(
                name: "LoggedByUserId",
                table: "ParkingLogs");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Gate",
                table: "ParkingLogs");

            migrationBuilder.AddColumn<Guid>(
                name: "LoggedByDeviceId",
                table: "ParkingLogs",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "LoggedByUserId",
                table: "ParkingLogs",
                type: "uuid",
                nullable: true);
        }
    }
}
