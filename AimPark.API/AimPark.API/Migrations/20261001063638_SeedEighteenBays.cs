using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class SeedEighteenBays : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000009"));

            migrationBuilder.DeleteData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000019"));

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000010"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "G1-C3", "Car" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000020"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "G2-C3", "Car" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000010"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "G1-M8", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000020"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "G2-M8", "Motorcycle" });

            migrationBuilder.InsertData(
                table: "ParkingSlots",
                columns: new[] { "Id", "CreatedAt", "Gate", "SlotCode", "Status", "UpdatedAt", "VehicleType" },
                values: new object[,]
                {
                    { new Guid("00000000-0000-0000-0000-000000000009"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), 1, "G1-M7", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "Motorcycle" },
                    { new Guid("00000000-0000-0000-0000-000000000019"), new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), 2, "G2-M7", "Available", new DateTime(2026, 7, 23, 0, 0, 0, 0, DateTimeKind.Utc), "Motorcycle" }
                });
        }
    }
}
