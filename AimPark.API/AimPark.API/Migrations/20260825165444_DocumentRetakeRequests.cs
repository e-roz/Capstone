using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class DocumentRetakeRequests : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DocumentRetakeJson",
                table: "Users",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DocumentRetakeJson",
                table: "Users");
        }
    }
}
