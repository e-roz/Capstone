using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddNotificationData : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Data",
                table: "Notifications",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Data",
                table: "Notifications");
        }
    }
}
