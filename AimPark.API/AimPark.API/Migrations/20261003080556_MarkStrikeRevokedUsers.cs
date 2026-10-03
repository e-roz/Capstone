using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class MarkStrikeRevokedUsers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Users whose card was taken by the three-strike rule before the
            // Revoked status existed were left looking like they simply had no
            // card. RfidRevokedAt marks the violation that did it; a user who
            // has since been given a card again is left alone.
            migrationBuilder.Sql(@"
                UPDATE ""Users"" u
                SET ""AccountStatus"" = 'Revoked',
                    ""RfidStatus"" = 'Revoked',
                    ""RfidSuspendedFrom"" = NULL,
                    ""RfidSuspendedUntil"" = NULL
                WHERE u.""RfidTagId"" IS NULL
                  AND u.""RfidStatus"" = 'Unassigned'
                  AND EXISTS (SELECT 1 FROM ""Violations"" v
                              WHERE v.""UserId"" = u.""Id"" AND v.""RfidRevokedAt"" IS NOT NULL);");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

        }
    }
}
