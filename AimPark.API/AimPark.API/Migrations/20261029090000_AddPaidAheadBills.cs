using AimPark.API.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(AppDbContext))]
    [Migration("20261029090000_AddPaidAheadBills")]
    public partial class AddPaidAheadBills : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "PaidAhead",
                table: "PaymentTransactions",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            // A session can now carry a second bill: the time a driver who paid
            // ahead stayed past the grace window.
            migrationBuilder.DropIndex(
                name: "IX_PaymentTransactions_ParkingLogId",
                table: "PaymentTransactions");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_ParkingLogId",
                table: "PaymentTransactions",
                column: "ParkingLogId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_PaymentTransactions_ParkingLogId",
                table: "PaymentTransactions");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_ParkingLogId",
                table: "PaymentTransactions",
                column: "ParkingLogId",
                unique: true,
                filter: "\"ParkingLogId\" IS NOT NULL");

            migrationBuilder.DropColumn(
                name: "PaidAhead",
                table: "PaymentTransactions");
        }
    }
}
