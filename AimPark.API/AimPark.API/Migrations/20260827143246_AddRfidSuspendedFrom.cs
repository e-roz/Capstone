using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddRfidSuspendedFrom : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "RfidSuspendedFrom",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RfidSuspendedFrom",
                table: "Users");
        }
    }
}
