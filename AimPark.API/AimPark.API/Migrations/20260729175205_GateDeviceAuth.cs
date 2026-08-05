using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class GateDeviceAuth : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<Guid>(
                name: "LoggedByUserId",
                table: "ParkingLogs",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<Guid>(
                name: "LoggedByDeviceId",
                table: "ParkingLogs",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "GateDevices",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "text", nullable: false),
                    Gate = table.Column<int>(type: "integer", nullable: false),
                    ApiKeyHash = table.Column<string>(type: "text", nullable: false),
                    ApiKeyPrefix = table.Column<string>(type: "text", nullable: false),
                    IsRevoked = table.Column<bool>(type: "boolean", nullable: false),
                    LastSeenAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GateDevices", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_GateDevices_ApiKeyHash",
                table: "GateDevices",
                column: "ApiKeyHash",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GateDevices");

            migrationBuilder.DropColumn(
                name: "LoggedByDeviceId",
                table: "ParkingLogs");

            migrationBuilder.AlterColumn<Guid>(
                name: "LoggedByUserId",
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
