using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class RemovePhoneFromRegistrationSession : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_RegistrationSessions_PhoneNumber",
                table: "RegistrationSessions");

            migrationBuilder.DropColumn(
                name: "IsPhoneVerified",
                table: "RegistrationSessions");

            migrationBuilder.DropColumn(
                name: "PhoneNumber",
                table: "RegistrationSessions");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsPhoneVerified",
                table: "RegistrationSessions",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "PhoneNumber",
                table: "RegistrationSessions",
                type: "text",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_RegistrationSessions_PhoneNumber",
                table: "RegistrationSessions",
                column: "PhoneNumber");
        }
    }
}
