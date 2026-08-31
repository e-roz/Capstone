using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class PaymentGatewayAndMinimumFee : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "CheckoutStartedAt",
                table: "PaymentTransactions",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ConfirmedByUserId",
                table: "PaymentTransactions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Method",
                table: "PaymentTransactions",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Provider",
                table: "PaymentTransactions",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProviderPaymentId",
                table: "PaymentTransactions",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ReferenceNumber",
                table: "PaymentTransactions",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "MinimumFee",
                table: "ParkingRates",
                type: "numeric(10,2)",
                nullable: false,
                defaultValue: 20.00m);

            migrationBuilder.UpdateData(
                table: "ParkingRates",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-0000000000f1"),
                column: "MinimumFee",
                value: 20.00m);

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_ProviderPaymentId",
                table: "PaymentTransactions",
                column: "ProviderPaymentId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_PaymentTransactions_ProviderPaymentId",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "CheckoutStartedAt",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "ConfirmedByUserId",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "Method",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "Provider",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "ProviderPaymentId",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "ReferenceNumber",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "MinimumFee",
                table: "ParkingRates");
        }
    }
}
