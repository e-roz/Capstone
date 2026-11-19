using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddBulkArchiveRuns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "BulkArchiveRuns",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RanAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    AdminUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ArchivedCount = table.Column<int>(type: "integer", nullable: false),
                    LeftAloneUserIds = table.Column<List<Guid>>(type: "uuid[]", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BulkArchiveRuns", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BulkArchiveRuns_RanAt",
                table: "BulkArchiveRuns",
                column: "RanAt");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BulkArchiveRuns");
        }
    }
}
