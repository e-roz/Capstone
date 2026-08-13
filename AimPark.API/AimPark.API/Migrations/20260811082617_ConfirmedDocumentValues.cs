using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class ConfirmedDocumentValues : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ConfirmedLicenseExpiry",
                table: "DocumentVerifications",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ConfirmedLicenseName",
                table: "DocumentVerifications",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ConfirmedPlateNumber",
                table: "DocumentVerifications",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ConfirmedRegistrationExpiry",
                table: "DocumentVerifications",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ConfirmedSection",
                table: "DocumentVerifications",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ConfirmedSemester",
                table: "DocumentVerifications",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ConfirmedStudentName",
                table: "DocumentVerifications",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ConfirmedStudentNumber",
                table: "DocumentVerifications",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ConfirmedLicenseExpiry",
                table: "DocumentVerifications");

            migrationBuilder.DropColumn(
                name: "ConfirmedLicenseName",
                table: "DocumentVerifications");

            migrationBuilder.DropColumn(
                name: "ConfirmedPlateNumber",
                table: "DocumentVerifications");

            migrationBuilder.DropColumn(
                name: "ConfirmedRegistrationExpiry",
                table: "DocumentVerifications");

            migrationBuilder.DropColumn(
                name: "ConfirmedSection",
                table: "DocumentVerifications");

            migrationBuilder.DropColumn(
                name: "ConfirmedSemester",
                table: "DocumentVerifications");

            migrationBuilder.DropColumn(
                name: "ConfirmedStudentName",
                table: "DocumentVerifications");

            migrationBuilder.DropColumn(
                name: "ConfirmedStudentNumber",
                table: "DocumentVerifications");
        }
    }
}
