using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddEBikeSupport : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Brand",
                table: "vehicles",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DistinguishingMarks",
                table: "vehicles",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsEBike",
                table: "vehicles",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "EBikeInspectionDeadline",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsEBikeApplicant",
                table: "Users",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Brand",
                table: "vehicles");

            migrationBuilder.DropColumn(
                name: "DistinguishingMarks",
                table: "vehicles");

            migrationBuilder.DropColumn(
                name: "IsEBike",
                table: "vehicles");

            migrationBuilder.DropColumn(
                name: "EBikeInspectionDeadline",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "IsEBikeApplicant",
                table: "Users");
        }
    }
}
