using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddBulkRestore : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<List<Guid>>(
                name: "ArchivedUserIds",
                table: "BulkArchiveRuns",
                type: "uuid[]",
                nullable: false,
                defaultValueSql: "'{}'::uuid[]");

            migrationBuilder.AddColumn<DateTime>(
                name: "UndoneAt",
                table: "BulkArchiveRuns",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ArchivedUserIds",
                table: "BulkArchiveRuns");

            migrationBuilder.DropColumn(
                name: "UndoneAt",
                table: "BulkArchiveRuns");
        }
    }
}
