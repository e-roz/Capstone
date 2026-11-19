using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddArchiveWhenClear : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "AutoArchive",
                table: "BulkArchiveRuns",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "AutoArchiveStoppedAt",
                table: "BulkArchiveRuns",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "AutoArchiveUntil",
                table: "BulkArchiveRuns",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "GraceDays",
                table: "BulkArchiveRuns",
                type: "integer",
                nullable: false,
                defaultValue: 7);

            migrationBuilder.AddColumn<string>(
                name: "Reason",
                table: "BulkArchiveRuns",
                type: "character varying(500)",
                maxLength: 500,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateTable(
                name: "BulkArchivePending",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RunId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    State = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Note = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    WarnedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ArchiveAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ResolvedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BulkArchivePending", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BulkArchivePending_BulkArchiveRuns_RunId",
                        column: x => x.RunId,
                        principalTable: "BulkArchiveRuns",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_BulkArchivePending_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BulkArchivePending_RunId_UserId",
                table: "BulkArchivePending",
                columns: new[] { "RunId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_BulkArchivePending_State",
                table: "BulkArchivePending",
                column: "State");

            migrationBuilder.CreateIndex(
                name: "IX_BulkArchivePending_UserId",
                table: "BulkArchivePending",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BulkArchivePending");

            migrationBuilder.DropColumn(
                name: "AutoArchive",
                table: "BulkArchiveRuns");

            migrationBuilder.DropColumn(
                name: "AutoArchiveStoppedAt",
                table: "BulkArchiveRuns");

            migrationBuilder.DropColumn(
                name: "AutoArchiveUntil",
                table: "BulkArchiveRuns");

            migrationBuilder.DropColumn(
                name: "GraceDays",
                table: "BulkArchiveRuns");

            migrationBuilder.DropColumn(
                name: "Reason",
                table: "BulkArchiveRuns");
        }
    }
}
