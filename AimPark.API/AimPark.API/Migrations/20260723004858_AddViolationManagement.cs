using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class AddViolationManagement : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_PaymentTransactions_ParkingLogId",
                table: "PaymentTransactions");

            migrationBuilder.AddColumn<DateTime>(
                name: "RfidSuspendedUntil",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AlterColumn<Guid>(
                name: "ParkingLogId",
                table: "PaymentTransactions",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<string>(
                name: "Source",
                table: "PaymentTransactions",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<Guid>(
                name: "ViolationId",
                table: "PaymentTransactions",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "PolicyRules",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Title = table.Column<string>(type: "text", nullable: false),
                    Description = table.Column<string>(type: "text", nullable: false),
                    DefaultPenaltyAmount = table.Column<decimal>(type: "numeric(10,2)", nullable: false),
                    DefaultSuspensionType = table.Column<string>(type: "text", nullable: false),
                    DefaultSuspensionDays = table.Column<int>(type: "integer", nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PolicyRules", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Violations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PolicyRuleId = table.Column<Guid>(type: "uuid", nullable: false),
                    ParkingLogId = table.Column<Guid>(type: "uuid", nullable: true),
                    Description = table.Column<string>(type: "text", nullable: false),
                    PenaltyAmount = table.Column<decimal>(type: "numeric(10,2)", nullable: false),
                    SuspensionType = table.Column<string>(type: "text", nullable: false),
                    SuspensionDays = table.Column<int>(type: "integer", nullable: true),
                    Status = table.Column<string>(type: "text", nullable: false),
                    IssuedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Violations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Violations_ParkingLogs_ParkingLogId",
                        column: x => x.ParkingLogId,
                        principalTable: "ParkingLogs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_Violations_PolicyRules_PolicyRuleId",
                        column: x => x.PolicyRuleId,
                        principalTable: "PolicyRules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Violations_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ViolationAppeals",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ViolationId = table.Column<Guid>(type: "uuid", nullable: false),
                    ReasonText = table.Column<string>(type: "text", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    AdminNotes = table.Column<string>(type: "text", nullable: true),
                    DecidedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    DecidedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ViolationAppeals", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ViolationAppeals_Violations_ViolationId",
                        column: x => x.ViolationId,
                        principalTable: "Violations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_ParkingLogId",
                table: "PaymentTransactions",
                column: "ParkingLogId",
                unique: true,
                filter: "\"ParkingLogId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_ViolationId",
                table: "PaymentTransactions",
                column: "ViolationId",
                unique: true,
                filter: "\"ViolationId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_ViolationAppeals_ViolationId",
                table: "ViolationAppeals",
                column: "ViolationId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Violations_ParkingLogId",
                table: "Violations",
                column: "ParkingLogId");

            migrationBuilder.CreateIndex(
                name: "IX_Violations_PolicyRuleId",
                table: "Violations",
                column: "PolicyRuleId");

            migrationBuilder.CreateIndex(
                name: "IX_Violations_Status",
                table: "Violations",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_Violations_UserId",
                table: "Violations",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentTransactions_Violations_ViolationId",
                table: "PaymentTransactions",
                column: "ViolationId",
                principalTable: "Violations",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PaymentTransactions_Violations_ViolationId",
                table: "PaymentTransactions");

            migrationBuilder.DropTable(
                name: "ViolationAppeals");

            migrationBuilder.DropTable(
                name: "Violations");

            migrationBuilder.DropTable(
                name: "PolicyRules");

            migrationBuilder.DropIndex(
                name: "IX_PaymentTransactions_ParkingLogId",
                table: "PaymentTransactions");

            migrationBuilder.DropIndex(
                name: "IX_PaymentTransactions_ViolationId",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "RfidSuspendedUntil",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "Source",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "ViolationId",
                table: "PaymentTransactions");

            migrationBuilder.AlterColumn<Guid>(
                name: "ParkingLogId",
                table: "PaymentTransactions",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_ParkingLogId",
                table: "PaymentTransactions",
                column: "ParkingLogId",
                unique: true);
        }
    }
}
