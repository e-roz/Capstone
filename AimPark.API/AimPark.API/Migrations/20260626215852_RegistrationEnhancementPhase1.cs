using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class RegistrationEnhancementPhase1 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "Status",
                table: "Users",
                newName: "OldStatus");

            migrationBuilder.AlterColumn<string>(
                name: "PasswordHash",
                table: "Users",
                type: "text",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "text");

            migrationBuilder.AddColumn<string>(
                name: "AccountStatus",
                table: "Users",
                type: "text",
                nullable: false,
                defaultValue: "PendingReview");

            migrationBuilder.AddColumn<string>(
                name: "AuthProvider",
                table: "Users",
                type: "text",
                nullable: false,
                defaultValue: "Local");

            migrationBuilder.AddColumn<DateTime>(
                name: "CanReapplyAt",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ExternalProviderId",
                table: "Users",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsEmailVerified",
                table: "Users",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsPhoneVerified",
                table: "Users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "PhoneNumber",
                table: "Users",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RegistrationStep",
                table: "Users",
                type: "text",
                nullable: false,
                defaultValue: "VehicleInfo");

            migrationBuilder.AddColumn<DateTime>(
                name: "RejectedAt",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "RejectionCount",
                table: "Users",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "VerificationStatus",
                table: "Users",
                type: "text",
                nullable: false,
                defaultValue: "NotStarted");

            migrationBuilder.CreateTable(
                name: "AdminAuditLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AdminUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    TargetUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Action = table.Column<string>(type: "text", nullable: false),
                    OldValue = table.Column<string>(type: "text", nullable: true),
                    NewValue = table.Column<string>(type: "text", nullable: true),
                    Reason = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminAuditLogs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "RegistrationSessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    PhoneNumber = table.Column<string>(type: "text", nullable: true),
                    IsPhoneVerified = table.Column<bool>(type: "boolean", nullable: false),
                    Email = table.Column<string>(type: "text", nullable: true),
                    IsEmailVerified = table.Column<bool>(type: "boolean", nullable: false),
                    OtpHash = table.Column<string>(type: "text", nullable: true),
                    LastOtpChannel = table.Column<string>(type: "text", nullable: false),
                    OtpExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    OtpAttempts = table.Column<int>(type: "integer", nullable: false),
                    IsLocked = table.Column<bool>(type: "boolean", nullable: false),
                    PendingAuthProvider = table.Column<string>(type: "text", nullable: true),
                    PendingExternalProviderId = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RegistrationSessions", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Users_PhoneNumber",
                table: "Users",
                column: "PhoneNumber",
                unique: true,
                filter: "\"PhoneNumber\" IS NOT NULL AND \"PhoneNumber\" <> ''");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_AdminUserId",
                table: "AdminAuditLogs",
                column: "AdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_CreatedAt",
                table: "AdminAuditLogs",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_TargetUserId",
                table: "AdminAuditLogs",
                column: "TargetUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RegistrationSessions_Email",
                table: "RegistrationSessions",
                column: "Email");

            migrationBuilder.CreateIndex(
                name: "IX_RegistrationSessions_ExpiresAt",
                table: "RegistrationSessions",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_RegistrationSessions_PhoneNumber",
                table: "RegistrationSessions",
                column: "PhoneNumber");

            migrationBuilder.Sql("""
                UPDATE "Users"
                SET "RegistrationStep" = CASE
                    WHEN "OldStatus" = 'Incomplete' AND EXISTS (SELECT 1 FROM vehicles v WHERE v."UserId" = "Users"."Id") THEN 'DocumentUpload'
                    WHEN "OldStatus" = 'Incomplete' THEN 'VehicleInfo'
                    ELSE 'Completed'
                END,
                "AccountStatus" = CASE
                    WHEN "OldStatus" = 'Pending' THEN 'PendingReview'
                    WHEN "OldStatus" = 'Approved' THEN 'Active'
                    WHEN "OldStatus" = 'Rejected' THEN 'Rejected'
                    WHEN "OldStatus" = 'Suspended' THEN 'Suspended'
                    ELSE 'PendingReview'
                END,
                "VerificationStatus" = CASE
                    WHEN "OldStatus" = 'Pending' THEN 'ManualReview'
                    WHEN "OldStatus" = 'Approved' THEN 'Passed'
                    WHEN "OldStatus" = 'Rejected' THEN 'Failed'
                    ELSE 'NotStarted'
                END,
                "IsEmailVerified" = TRUE,
                "AuthProvider" = 'Local'
                WHERE "OldStatus" IS NOT NULL;
                """);

            migrationBuilder.DropColumn(
                name: "OldStatus",
                table: "Users");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "OldStatus",
                table: "Users",
                type: "text",
                nullable: false,
                defaultValue: "Incomplete");

            migrationBuilder.Sql("""
                UPDATE "Users"
                SET "OldStatus" = CASE
                    WHEN "RegistrationStep" <> 'Completed' THEN 'Incomplete'
                    WHEN "AccountStatus" = 'PendingReview' THEN 'Pending'
                    WHEN "AccountStatus" = 'Active' THEN 'Approved'
                    WHEN "AccountStatus" = 'Rejected' THEN 'Rejected'
                    WHEN "AccountStatus" = 'Suspended' THEN 'Suspended'
                    ELSE 'Incomplete'
                END;
                """);

            migrationBuilder.DropTable(
                name: "AdminAuditLogs");

            migrationBuilder.DropTable(
                name: "RegistrationSessions");

            migrationBuilder.DropIndex(
                name: "IX_Users_PhoneNumber",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "AccountStatus",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "AuthProvider",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "CanReapplyAt",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "ExternalProviderId",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "IsEmailVerified",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "IsPhoneVerified",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "PhoneNumber",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "RegistrationStep",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "RejectedAt",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "RejectionCount",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "VerificationStatus",
                table: "Users");

            migrationBuilder.RenameColumn(
                name: "OldStatus",
                table: "Users",
                newName: "Status");

            migrationBuilder.AlterColumn<string>(
                name: "PasswordHash",
                table: "Users",
                type: "text",
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "text",
                oldNullable: true);
        }
    }
}
