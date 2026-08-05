using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class SmartSlotAllocation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Gate",
                table: "ParkingSlots",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000001"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 1, "G1-C1", "Car" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000002"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 1, "G1-C2", "Car" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000003"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 1, "G1-M1", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000004"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 1, "G1-M2", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000005"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 1, "G1-M3", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000006"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 1, "G1-M4", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000007"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 1, "G1-M5", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000008"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 1, "G1-M6", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000009"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 1, "G1-M7", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000010"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 1, "G1-M8", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000011"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 2, "G2-C1", "Car" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000012"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 2, "G2-C2", "Car" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000013"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 2, "G2-M1", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000014"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 2, "G2-M2", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000015"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 2, "G2-M3", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000016"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 2, "G2-M4", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000017"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 2, "G2-M5", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000018"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 2, "G2-M6", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000019"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 2, "G2-M7", "Motorcycle" });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000020"),
                columns: new[] { "Gate", "SlotCode", "VehicleType" },
                values: new object[] { 2, "G2-M8", "Motorcycle" });

            migrationBuilder.CreateIndex(
                name: "IX_ParkingSlots_Gate_VehicleType_Status",
                table: "ParkingSlots",
                columns: new[] { "Gate", "VehicleType", "Status" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ParkingSlots_Gate_VehicleType_Status",
                table: "ParkingSlots");

            migrationBuilder.DropColumn(
                name: "Gate",
                table: "ParkingSlots");

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000001"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A1", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000002"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A2", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000003"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A3", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000004"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A4", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000005"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A5", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000006"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A6", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000007"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A7", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000008"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A8", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000009"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A9", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000010"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A10", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000011"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A11", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000012"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A12", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000013"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A13", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000014"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A14", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000015"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A15", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000016"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A16", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000017"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A17", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000018"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A18", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000019"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A19", null });

            migrationBuilder.UpdateData(
                table: "ParkingSlots",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000020"),
                columns: new[] { "SlotCode", "VehicleType" },
                values: new object[] { "A20", null });
        }
    }
}
