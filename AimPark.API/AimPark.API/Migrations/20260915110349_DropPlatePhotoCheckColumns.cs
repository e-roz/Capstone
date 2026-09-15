using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class DropPlatePhotoCheckColumns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ExtractedPlatePhotoNumber",
                table: "DocumentVerifications");

            migrationBuilder.DropColumn(
                name: "PlatePhotoMatch",
                table: "DocumentVerifications");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ExtractedPlatePhotoNumber",
                table: "DocumentVerifications",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PlatePhotoMatch",
                table: "DocumentVerifications",
                type: "text",
                nullable: false,
                defaultValue: "");
        }
    }
}
