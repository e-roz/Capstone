using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class ThreeDocumentPreScreening : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_vehicles_UserId",
                table: "vehicles");

            migrationBuilder.DropIndex(
                name: "IX_Users_PhoneNumber",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "IsPhoneVerified",
                table: "Users");

            // Scaffolded as a rename of PhoneNumber, which it is not — that would
            // load every existing phone number into StudentNumber and then apply a
            // unique index to it. Drop and add instead.
            migrationBuilder.DropColumn(
                name: "PhoneNumber",
                table: "Users");

            migrationBuilder.AddColumn<string>(
                name: "StudentNumber",
                table: "Users",
                type: "text",
                nullable: true);

            // Document.Type became an enum. Existing rows hold "OR" and "CR", which
            // are no longer valid values — and thanks to the upload field mix-up the
            // rows labelled "OR" are government ID backs anyway. These are test
            // uploads and the documents are being re-collected, so clear them rather
            // than relabel data that was never right.
            migrationBuilder.Sql("DELETE FROM \"Documents\";");

            migrationBuilder.AddColumn<int>(
                name: "RegistrationRenewalMonth",
                table: "vehicles",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "RegistrationValidThrough",
                table: "vehicles",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Affiliation",
                table: "Users",
                type: "text",
                nullable: false,
                // Not "" — that is not a valid Affiliation and every existing row
                // would fail to read back.
                defaultValue: "Student");

            migrationBuilder.AddColumn<DateTime>(
                name: "EnrollmentValidUntil",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Section",
                table: "Users",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "DocumentVerifications",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    VehicleId = table.Column<Guid>(type: "uuid", nullable: true),
                    ExtractedStudentNumber = table.Column<string>(type: "text", nullable: true),
                    ExtractedStudentName = table.Column<string>(type: "text", nullable: true),
                    ExtractedSection = table.Column<string>(type: "text", nullable: true),
                    ExtractedSemester = table.Column<string>(type: "text", nullable: true),
                    ExtractedLicenseName = table.Column<string>(type: "text", nullable: true),
                    ExtractedLicenseExpiry = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ExtractedPlateNumber = table.Column<string>(type: "text", nullable: true),
                    ExtractedRegistrationExpiry = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ExtractedPlatePhotoNumber = table.Column<string>(type: "text", nullable: true),
                    NameMatch = table.Column<string>(type: "text", nullable: false),
                    PlateMatch = table.Column<string>(type: "text", nullable: false),
                    PlatePhotoMatch = table.Column<string>(type: "text", nullable: false),
                    LicenseValidity = table.Column<string>(type: "text", nullable: false),
                    RegistrationValidity = table.Column<string>(type: "text", nullable: false),
                    EnrollmentValidity = table.Column<string>(type: "text", nullable: false),
                    Result = table.Column<string>(type: "text", nullable: false),
                    Notes = table.Column<string>(type: "text", nullable: true),
                    WasOverridden = table.Column<bool>(type: "boolean", nullable: false),
                    OverriddenByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    OverriddenAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DocumentVerifications", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DocumentVerifications_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_DocumentVerifications_vehicles_VehicleId",
                        column: x => x.VehicleId,
                        principalTable: "vehicles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_vehicles_UserId",
                table: "vehicles",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Users_StudentNumber",
                table: "Users",
                column: "StudentNumber",
                unique: true,
                filter: "\"StudentNumber\" IS NOT NULL AND \"StudentNumber\" <> ''");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentVerifications_CreatedAt",
                table: "DocumentVerifications",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentVerifications_UserId",
                table: "DocumentVerifications",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentVerifications_VehicleId",
                table: "DocumentVerifications",
                column: "VehicleId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DocumentVerifications");

            migrationBuilder.DropIndex(
                name: "IX_vehicles_UserId",
                table: "vehicles");

            migrationBuilder.DropIndex(
                name: "IX_Users_StudentNumber",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "RegistrationRenewalMonth",
                table: "vehicles");

            migrationBuilder.DropColumn(
                name: "RegistrationValidThrough",
                table: "vehicles");

            migrationBuilder.DropColumn(
                name: "Affiliation",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "EnrollmentValidUntil",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "Section",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "StudentNumber",
                table: "Users");

            migrationBuilder.AddColumn<string>(
                name: "PhoneNumber",
                table: "Users",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsPhoneVerified",
                table: "Users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_vehicles_UserId",
                table: "vehicles",
                column: "UserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_PhoneNumber",
                table: "Users",
                column: "PhoneNumber",
                unique: true,
                filter: "\"PhoneNumber\" IS NOT NULL AND \"PhoneNumber\" <> ''");
        }
    }
}
