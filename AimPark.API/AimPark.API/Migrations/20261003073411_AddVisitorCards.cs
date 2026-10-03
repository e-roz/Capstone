using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddVisitorCards : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "CardCollectedAt",
                table: "VisitorPasses",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CardCollectedByUserId",
                table: "VisitorPasses",
                type: "uuid",
                nullable: true);

            // Before this, a pass only ended when a guard took the card back by
            // hand, so every ended pass already had its card in the drawer.
            migrationBuilder.Sql(
                "UPDATE \"VisitorPasses\" SET \"CardCollectedAt\" = \"ReturnedAt\" WHERE \"ReturnedAt\" IS NOT NULL;");

            migrationBuilder.CreateTable(
                name: "VisitorCards",
                columns: table => new
                {
                    RfidTagId = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Label = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    State = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Note = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VisitorCards", x => x.RfidTagId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_VisitorCards_Label",
                table: "VisitorCards",
                column: "Label",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "VisitorCards");

            migrationBuilder.DropColumn(
                name: "CardCollectedAt",
                table: "VisitorPasses");

            migrationBuilder.DropColumn(
                name: "CardCollectedByUserId",
                table: "VisitorPasses");
        }
    }
}
