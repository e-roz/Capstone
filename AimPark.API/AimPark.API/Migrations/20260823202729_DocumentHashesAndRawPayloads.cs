using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class DocumentHashesAndRawPayloads : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "RawPayloads",
                table: "DocumentVerifications",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Sha256",
                table: "Documents",
                type: "text",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Documents_Sha256",
                table: "Documents",
                column: "Sha256");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Documents_Sha256",
                table: "Documents");

            migrationBuilder.DropColumn(
                name: "RawPayloads",
                table: "DocumentVerifications");

            migrationBuilder.DropColumn(
                name: "Sha256",
                table: "Documents");
        }
    }
}
