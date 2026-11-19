using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddRateLock : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "PreviousMinimumFee",
                table: "ParkingRates",
                type: "numeric(10,2)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "PreviousRatePerHour",
                table: "ParkingRates",
                type: "numeric(10,2)",
                nullable: true);

            migrationBuilder.UpdateData(
                table: "ParkingRates",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-0000000000f1"),
                columns: new[] { "PreviousMinimumFee", "PreviousRatePerHour" },
                values: new object[] { null, null });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PreviousMinimumFee",
                table: "ParkingRates");

            migrationBuilder.DropColumn(
                name: "PreviousRatePerHour",
                table: "ParkingRates");
        }
    }
}
