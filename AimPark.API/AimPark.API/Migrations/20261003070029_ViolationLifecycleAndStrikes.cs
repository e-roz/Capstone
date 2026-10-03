using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class ViolationLifecycleAndStrikes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "AccountableAt",
                table: "Violations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "AccountableByUserId",
                table: "Violations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AccountableReason",
                table: "Violations",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "AppealDeadline",
                table: "Violations",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<string>(
                name: "DismissReason",
                table: "Violations",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DismissedAt",
                table: "Violations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "DismissedByUserId",
                table: "Violations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "RfidRevokedAt",
                table: "Violations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RfidTagIdAtIssue",
                table: "Violations",
                type: "text",
                nullable: true);

            // The statuses were renamed to match the new case lifecycle.
            // Stored as text, so the rows have to be rewritten.
            migrationBuilder.Sql(@"
                UPDATE ""Violations"" SET ""Status"" = CASE ""Status""
                    WHEN 'Appealed'   THEN 'PendingAppeal'
                    WHEN 'Overturned' THEN 'Appealed'
                    WHEN 'Upheld'     THEN 'Accountable'
                    ELSE ""Status"" END;");

            // Same deadline rule as IssueAsync: the rule's window, never under three days.
            migrationBuilder.Sql(@"
                UPDATE ""Violations"" v
                SET ""AppealDeadline"" = v.""CreatedAt"" + make_interval(days => GREATEST(3, r.""AppealWindowDays""))
                FROM ""PolicyRules"" r
                WHERE r.""Id"" = v.""PolicyRuleId"";");

            // The card each existing violation was issued against is not known;
            // the user's current card is the best record there is.
            migrationBuilder.Sql(@"
                UPDATE ""Violations"" v
                SET ""RfidTagIdAtIssue"" = u.""RfidTagId""
                FROM ""Users"" u
                WHERE u.""Id"" = v.""UserId"";");

            // Old Upheld rows became Accountable through a rejected appeal.
            migrationBuilder.Sql(@"
                UPDATE ""Violations"" v
                SET ""AccountableAt"" = COALESCE(a.""DecidedAt"", v.""UpdatedAt""),
                    ""AccountableByUserId"" = a.""DecidedByUserId"",
                    ""AccountableReason"" = 'Appeal rejected' || COALESCE(': ' || a.""AdminNotes"", '')
                FROM ""ViolationAppeals"" a
                WHERE a.""ViolationId"" = v.""Id"" AND v.""Status"" = 'Accountable';");

            migrationBuilder.Sql(@"
                UPDATE ""Violations""
                SET ""DismissedAt"" = ""UpdatedAt"",
                    ""DismissReason"" = 'Dismissed before reasons were recorded'
                WHERE ""Status"" = 'Dismissed';");

            // A dismissed violation's waiting appeal was left Pending forever.
            migrationBuilder.Sql(@"
                UPDATE ""ViolationAppeals"" a
                SET ""Status"" = 'Dismissed', ""DecidedAt"" = v.""DismissedAt""
                FROM ""Violations"" v
                WHERE v.""Id"" = a.""ViolationId"" AND v.""Status"" = 'Dismissed' AND a.""Status"" = 'Pending';");

            // Fines are now raised when a violation becomes Accountable, not at
            // issue. Unpaid fines on cases still open are withdrawn so they stop
            // showing as owed; they are raised again if the case goes against
            // the user. Anything paid or mid-checkout is left alone.
            migrationBuilder.Sql(@"
                DELETE FROM ""PaymentTransactions"" p
                USING ""Violations"" v
                WHERE p.""ViolationId"" = v.""Id""
                  AND v.""Status"" IN ('Issued', 'PendingAppeal')
                  AND p.""Status"" = 'Pending'
                  AND p.""PaidAt"" IS NULL;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                UPDATE ""Violations"" SET ""Status"" = CASE ""Status""
                    WHEN 'Appealed'      THEN 'Overturned'
                    WHEN 'PendingAppeal' THEN 'Appealed'
                    WHEN 'Accountable'   THEN 'Upheld'
                    ELSE ""Status"" END;");

            migrationBuilder.DropColumn(
                name: "AccountableAt",
                table: "Violations");

            migrationBuilder.DropColumn(
                name: "AccountableByUserId",
                table: "Violations");

            migrationBuilder.DropColumn(
                name: "AccountableReason",
                table: "Violations");

            migrationBuilder.DropColumn(
                name: "AppealDeadline",
                table: "Violations");

            migrationBuilder.DropColumn(
                name: "DismissReason",
                table: "Violations");

            migrationBuilder.DropColumn(
                name: "DismissedAt",
                table: "Violations");

            migrationBuilder.DropColumn(
                name: "DismissedByUserId",
                table: "Violations");

            migrationBuilder.DropColumn(
                name: "RfidRevokedAt",
                table: "Violations");

            migrationBuilder.DropColumn(
                name: "RfidTagIdAtIssue",
                table: "Violations");
        }
    }
}
