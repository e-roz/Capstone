using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddPolicyRuleAppealWindow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // 3, not the 0 EF generates for an int. Zero means "suspend
            // immediately", so taking the generated default would silently
            // convert every rule already written into a harsh one — the exact
            // opposite of the intent, applied to the whole rulebook at once.
            migrationBuilder.AddColumn<int>(
                name: "AppealWindowDays",
                table: "PolicyRules",
                type: "integer",
                nullable: false,
                defaultValue: 3);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AppealWindowDays",
                table: "PolicyRules");
        }
    }
}
