using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddLicenseNumberToVerification : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ConfirmedLicenseNumber",
                table: "DocumentVerifications",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ExtractedLicenseNumber",
                table: "DocumentVerifications",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ConfirmedLicenseNumber",
                table: "DocumentVerifications");

            migrationBuilder.DropColumn(
                name: "ExtractedLicenseNumber",
                table: "DocumentVerifications");
        }
    }
}
