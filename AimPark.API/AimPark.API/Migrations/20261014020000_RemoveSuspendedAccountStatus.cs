using AimPark.API.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <summary>
    /// The account-level Suspended status is gone: losing access is now only
    /// Revoked (three accountable violations). Accounts an admin had suspended
    /// by hand go back to Active — the RFID card keeps its own suspension.
    /// Nothing about the model changes, so there is no snapshot to update.
    /// </summary>
    [DbContext(typeof(AppDbContext))]
    [Migration("20261014020000_RemoveSuspendedAccountStatus")]
    public partial class RemoveSuspendedAccountStatus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"UPDATE ""Users"" SET ""AccountStatus"" = 'Active' WHERE ""AccountStatus"" = 'Suspended';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
        }
    }
}
