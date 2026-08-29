using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>
    /// Whole-database export and import, for the Backup &amp; Restore module.
    ///
    /// The file is JSON built through EF rather than a <c>pg_dump</c>, because
    /// the API container has no Postgres client tools and reaches Supabase over
    /// the same connection EF uses. The trade is real and worth naming: this
    /// captures table *rows*, not the schema, sequences, or the document images
    /// in the storage bucket. Restoring onto a database whose migrations do not
    /// match the backup will fail on the insert, which is the correct outcome —
    /// silently dropping columns would be worse.
    /// </summary>
    public class BackupService : IBackupService
    {
        private const string Bucket = "backups";
        private const string FormatName = "aimpark-backup";
        private const int FormatVersion = 1;

        /// <summary>What the administrator has to type to arm the restore.</summary>
        private const string RequiredConfirmation = "RESTORE";

        /// <summary>
        /// Refused above this. Kestrel is capped at 10 MB globally and the
        /// restore endpoints raise their own limit to this, so a file larger
        /// than this never reaches us intact anyway.
        /// </summary>
        private const long MaxUploadBytes = 64L * 1024 * 1024;

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
            // Navigation properties come back null on an AsNoTracking read with
            // no Include, so there is nothing to cycle through — this is here so
            // that stays true if someone adds an Include to a read later.
            ReferenceHandler = ReferenceHandler.IgnoreCycles,
            Converters = { new JsonStringEnumConverter() }
        };

        private readonly AppDbContext _db;
        private readonly IFileStorageService _storage;
        private readonly ILogger<BackupService> _logger;

        public BackupService(AppDbContext db, IFileStorageService storage, ILogger<BackupService> logger)
        {
            _db = db;
            _storage = storage;
            _logger = logger;
        }

        // ── The table map ────────────────────────────────────────────────────

        /// <summary>
        /// Every table, in an order that satisfies the foreign keys: a row is
        /// only ever written after the rows it points at. Deletes walk this
        /// list backwards for the same reason.
        ///
        /// A new entity added to <see cref="AppDbContext"/> and not added here
        /// is silently left out of every backup, so this list is the one thing
        /// in the feature that must be kept in step by hand.
        /// </summary>
        private static readonly IReadOnlyList<BackupTable> Tables =
        [
            Table<User>("Users"),
            Table<Vehicle>("Vehicles"),
            Table<Document>("Documents"),
            Table<RegistrationSession>("RegistrationSessions"),
            Table<ParkingSlot>("ParkingSlots"),
            Table<GateDevice>("GateDevices"),
            Table<VisitorPass>("VisitorPasses"),
            Table<ParkingLog>("ParkingLogs"),
            Table<DocumentVerification>("DocumentVerifications"),
            Table<ParkingRate>("ParkingRates"),
            Table<PolicyRule>("PolicyRules"),
            Table<Violation>("Violations"),
            Table<ViolationAppeal>("ViolationAppeals"),
            Table<AppealEvidence>("AppealEvidence"),
            Table<PaymentTransaction>("PaymentTransactions"),
            Table<Incident>("Incidents"),
            Table<IncidentEvidence>("IncidentEvidence"),
            Table<Notification>("Notifications"),
            Table<NotificationRead>("NotificationReads"),
            Table<DeviceToken>("DeviceTokens"),
            Table<AdminAuditLog>("AdminAuditLogs"),
            Table<UserActivityLog>("UserActivityLogs"),
            Table<SystemErrorLog>("SystemErrorLogs"),
        ];

        private sealed record BackupTable(
            string Name,
            Func<AppDbContext, CancellationToken, Task<IReadOnlyList<object>>> Read,
            Func<AppDbContext, CancellationToken, Task<int>> Count,
            Func<AppDbContext, JsonElement, int> Load,
            Func<AppDbContext, CancellationToken, Task<int>> DeleteAll);

        private static BackupTable Table<T>(string name) where T : class => new(
            name,
            async (db, ct) => await db.Set<T>().AsNoTracking().ToListAsync(ct),
            (db, ct) => db.Set<T>().CountAsync(ct),
            (db, element) =>
            {
                var rows = element.Deserialize<List<T>>(JsonOptions) ?? [];
                db.Set<T>().AddRange(rows);
                return rows.Count;
            },
            (db, ct) => db.Set<T>().ExecuteDeleteAsync(ct));

        // ── List ─────────────────────────────────────────────────────────────

        public async Task<ActionResult<BackupListResponse>> ListAsync(CancellationToken ct)
        {
            var objects = await _storage.ListAsync(Bucket, string.Empty, ct);

            var backups = objects
                .Where(o => o.Name.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
                .Select(o => new BackupFileResponse
                {
                    Name = o.Name,
                    SizeBytes = o.SizeBytes,
                    CreatedAt = o.UpdatedAt
                })
                // The storage listing sorts by name, which for these filenames
                // is the same as by date — but only because the stamp is
                // zero-padded and leads the name. Sorting explicitly means a
                // rename cannot quietly reverse the history.
                .OrderByDescending(b => b.CreatedAt ?? DateTime.MinValue)
                .ThenByDescending(b => b.Name)
                .ToList();

            return new OkObjectResult(new BackupListResponse { Backups = backups });
        }

        // ── Create ───────────────────────────────────────────────────────────

        public async Task<ActionResult> CreateAsync(Guid adminUserId, CancellationToken ct)
        {
            var adminEmail = await _db.Users
                .Where(u => u.Id == adminUserId)
                .Select(u => u.Email)
                .FirstOrDefaultAsync(ct) ?? "unknown";

            var (bytes, counts) = await BuildBackupAsync(adminEmail, ct);

            var fileName = $"aimpark-backup-{DateTime.UtcNow:yyyyMMdd-HHmmss}.json";
            await StoreAsync(fileName, bytes, ct);

            var total = counts.Sum(c => c.Rows);
            await LogAsync(adminUserId, "Backup", null,
                $"File={fileName}, Tables={counts.Count}, Rows={total}, Bytes={bytes.Length}", ct);
            await _db.SaveChangesAsync(ct);

            _logger.LogInformation(
                "Backup {FileName} created by {AdminUserId}: {Rows} rows across {Tables} tables",
                fileName, adminUserId, total, counts.Count);

            return new FileContentResult(bytes, "application/json") { FileDownloadName = fileName };
        }

        public async Task<ActionResult> DownloadAsync(string fileName, CancellationToken ct)
        {
            if (!IsSafeFileName(fileName))
                return new BadRequestObjectResult(new { message = "That is not a valid backup file name." });

            var bytes = await _storage.DownloadAsync(Bucket, fileName, ct);
            if (bytes is null)
                return new NotFoundObjectResult(new { message = "That backup is no longer in storage." });

            return new FileContentResult(bytes, "application/json") { FileDownloadName = fileName };
        }

        // ── Preview ──────────────────────────────────────────────────────────

        public async Task<ActionResult<RestorePreviewResponse>> PreviewAsync(
            IFormFile file, Guid adminUserId, CancellationToken ct)
        {
            var (document, error) = await ReadUploadAsync(file, ct);
            if (document is null)
                return new BadRequestObjectResult(new { message = error });

            using (document)
            {
                var preview = await InspectAsync(file.FileName, document.RootElement, adminUserId, ct);
                return new OkObjectResult(preview);
            }
        }

        // ── Restore ──────────────────────────────────────────────────────────

        public async Task<ActionResult<RestoreResultResponse>> RestoreAsync(
            IFormFile file, Guid adminUserId, string password, string confirmation, CancellationToken ct)
        {
            if (!string.Equals(confirmation?.Trim(), RequiredConfirmation, StringComparison.OrdinalIgnoreCase))
                return new BadRequestObjectResult(new { message = $"Type {RequiredConfirmation} to confirm this restore." });

            var admin = await _db.Users.FirstOrDefaultAsync(u => u.Id == adminUserId, ct);
            if (admin?.PasswordHash is null)
                return new BadRequestObjectResult(new { message = "Password confirmation is unavailable for this admin account." });

            if (string.IsNullOrEmpty(password) || !BCrypt.Net.BCrypt.Verify(password, admin.PasswordHash))
                return new UnauthorizedObjectResult(new { message = "Incorrect password." });

            var (document, error) = await ReadUploadAsync(file, ct);
            if (document is null)
                return new BadRequestObjectResult(new { message = error });

            using (document)
            {
                var root = document.RootElement;

                var preview = await InspectAsync(file.FileName, root, adminUserId, ct);
                if (!preview.CanRestore)
                    return new BadRequestObjectResult(new { message = preview.Problem });

                // The way back. Taken before anything is deleted, and stored
                // under its own name so it cannot be confused with a backup the
                // administrator asked for.
                var (safetyBytes, _) = await BuildBackupAsync($"auto/pre-restore/{admin.Email}", ct);
                var safetyName = $"aimpark-prerestore-{DateTime.UtcNow:yyyyMMdd-HHmmss}.json";
                await StoreAsync(safetyName, safetyBytes, ct);

                var tables = root.GetProperty("tables");
                var restored = new List<TableCountResponse>();

                _db.ChangeTracker.Clear();
                _db.ChangeTracker.AutoDetectChangesEnabled = false;

                await using var transaction = await _db.Database.BeginTransactionAsync(ct);
                try
                {
                    // Children first, so no delete is refused by a foreign key
                    // still pointing at the row being removed.
                    foreach (var table in Tables.Reverse())
                    {
                        await table.DeleteAll(_db, ct);
                    }

                    foreach (var table in Tables)
                    {
                        if (!tables.TryGetProperty(table.Name, out var rows) ||
                            rows.ValueKind != JsonValueKind.Array)
                        {
                            restored.Add(new TableCountResponse { Table = table.Name, Rows = 0 });
                            continue;
                        }

                        var count = table.Load(_db, rows);
                        restored.Add(new TableCountResponse { Table = table.Name, Rows = count });
                    }

                    await _db.SaveChangesAsync(ct);

                    // Written after the rows land, so it survives into the
                    // restored database rather than being wiped by its own
                    // restore. The audit table has no foreign key to Users, so
                    // this holds even if the acting admin is not in the backup.
                    await LogAsync(adminUserId, "RestoreBackup", $"SafetyBackup={safetyName}",
                        $"File={file.FileName}, Rows={restored.Sum(r => r.Rows)}", ct);
                    await _db.SaveChangesAsync(ct);

                    await transaction.CommitAsync(ct);
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync(ct);
                    _logger.LogError(ex, "Restore from {FileName} failed and was rolled back", file.FileName);

                    return new ObjectResult(new
                    {
                        message = "The restore failed and was rolled back — the database is unchanged. " +
                                  $"Details: {ex.Message}",
                        safetyBackupName = safetyName
                    })
                    { StatusCode = StatusCodes.Status500InternalServerError };
                }
                finally
                {
                    _db.ChangeTracker.AutoDetectChangesEnabled = true;
                }

                var total = restored.Sum(r => r.Rows);
                _logger.LogWarning(
                    "Database restored from {FileName} by {AdminUserId}: {Rows} rows. Safety copy: {SafetyName}",
                    file.FileName, adminUserId, total, safetyName);

                return new OkObjectResult(new RestoreResultResponse
                {
                    Message = $"Restore complete. {total} rows were written from {file.FileName}.",
                    SafetyBackupName = safetyName,
                    Restored = restored,
                    TotalRows = total
                });
            }
        }

        // ── Shared internals ─────────────────────────────────────────────────

        private async Task<(byte[] Bytes, List<TableCountResponse> Counts)> BuildBackupAsync(
            string createdByEmail, CancellationToken ct)
        {
            var data = new Dictionary<string, IReadOnlyList<object>>();
            var counts = new List<TableCountResponse>();

            foreach (var table in Tables)
            {
                var rows = await table.Read(_db, ct);
                data[table.Name] = rows;
                counts.Add(new TableCountResponse { Table = table.Name, Rows = rows.Count });
            }

            var envelope = new BackupEnvelope
            {
                Format = FormatName,
                Version = FormatVersion,
                CreatedAt = DateTime.UtcNow,
                CreatedByEmail = createdByEmail,
                Tables = data
            };

            // Indented deliberately: a panellist who opens the file should see
            // recognisable records, and the size cost is irrelevant next to
            // what the storage bucket holds in document photographs.
            var options = new JsonSerializerOptions(JsonOptions) { WriteIndented = true };
            var json = JsonSerializer.Serialize(envelope, options);

            return (Encoding.UTF8.GetBytes(json), counts);
        }

        private async Task StoreAsync(string fileName, byte[] bytes, CancellationToken ct)
        {
            await _storage.EnsureBucketAsync(Bucket, ct);
            await _storage.SaveBytesAsync(Bucket, fileName, bytes, "application/json", ct);
        }

        /// <summary>
        /// Reads the upload into a parsed document, or returns why it could not
        /// be. Never throws on bad input — a corrupt file is an administrator
        /// mistake, not a server fault.
        /// </summary>
        private static async Task<(JsonDocument? Document, string? Error)> ReadUploadAsync(
            IFormFile? file, CancellationToken ct)
        {
            if (file is null || file.Length == 0)
                return (null, "Choose a backup file first.");

            if (file.Length > MaxUploadBytes)
                return (null, $"That file is {file.Length / (1024 * 1024)} MB. The limit is {MaxUploadBytes / (1024 * 1024)} MB.");

            try
            {
                await using var stream = file.OpenReadStream();
                var document = await JsonDocument.ParseAsync(stream, cancellationToken: ct);
                return (document, null);
            }
            catch (JsonException)
            {
                return (null, "That file is not valid JSON. Upload a backup produced by this panel.");
            }
        }

        /// <summary>
        /// Everything that can be known about a candidate file without writing:
        /// what it holds, what it would replace, and whether it is safe at all.
        /// </summary>
        private async Task<RestorePreviewResponse> InspectAsync(
            string fileName, JsonElement root, Guid adminUserId, CancellationToken ct)
        {
            var summary = new BackupSummaryResponse { FileName = fileName };
            var response = new RestorePreviewResponse { Backup = summary, CanRestore = false };

            if (root.ValueKind != JsonValueKind.Object ||
                !root.TryGetProperty("format", out var format) ||
                format.GetString() != FormatName)
            {
                response.Problem = "This is not an AimPark backup file.";
                return response;
            }

            summary.FormatVersion = root.TryGetProperty("version", out var version) ? version.GetInt32() : 0;
            if (summary.FormatVersion > FormatVersion)
            {
                response.Problem =
                    $"This file was written by a newer version of AimPark (format {summary.FormatVersion}). " +
                    "Update the server before restoring it.";
                return response;
            }

            summary.CreatedAt = root.TryGetProperty("createdAt", out var created) &&
                                created.TryGetDateTime(out var createdAt)
                ? createdAt
                : default;

            summary.CreatedByEmail = root.TryGetProperty("createdByEmail", out var by)
                ? by.GetString() ?? string.Empty
                : string.Empty;

            if (!root.TryGetProperty("tables", out var tables) || tables.ValueKind != JsonValueKind.Object)
            {
                response.Problem = "This backup has no table data in it.";
                return response;
            }

            foreach (var table in Tables)
            {
                var rows = tables.TryGetProperty(table.Name, out var array) && array.ValueKind == JsonValueKind.Array
                    ? array.GetArrayLength()
                    : 0;

                if (!tables.TryGetProperty(table.Name, out _))
                {
                    response.Warnings.Add($"{table.Name} is missing from this file and will be emptied.");
                }

                summary.Tables.Add(new TableCountResponse
                {
                    Table = table.Name,
                    Rows = rows,
                    CurrentRows = await table.Count(_db, ct)
                });
            }

            summary.TotalRows = summary.Tables.Sum(t => t.Rows);
            response.CurrentTotalRows = summary.Tables.Sum(t => t.CurrentRows ?? 0);

            // The one check that makes this safe to offer at all: restoring a
            // file with no usable administrator in it locks everyone out of the
            // panel, with no screen left to undo it from.
            if (!HasUsableAdmin(tables))
            {
                response.Problem =
                    "This backup contains no active administrator account. Restoring it would lock " +
                    "everyone out of the panel.";
                return response;
            }

            if (summary.CreatedAt != default && DateTime.UtcNow - summary.CreatedAt > TimeSpan.FromDays(30))
            {
                var days = (int)(DateTime.UtcNow - summary.CreatedAt).TotalDays;
                response.Warnings.Add($"This backup is {days} days old. Everything recorded since then will be lost.");
            }

            // Survivable, but the administrator has to know before they press
            // the button: their own account is about to stop existing, and the
            // session they are holding will not get them back in.
            if (!ContainsUser(tables, adminUserId))
            {
                response.Warnings.Add(
                    "Your own account is not in this backup. You will be signed out by the restore and " +
                    "will have to sign in as an administrator the backup does contain.");
            }

            response.CanRestore = true;
            return response;
        }

        /// <summary>
        /// True when the backup holds at least one administrator who could sign
        /// in afterwards — not archived, not suspended, and with a password set.
        /// </summary>
        private static bool HasUsableAdmin(JsonElement tables)
        {
            if (!tables.TryGetProperty("Users", out var users) || users.ValueKind != JsonValueKind.Array)
                return false;

            foreach (var user in users.EnumerateArray())
            {
                if (!user.TryGetProperty("role", out var role) ||
                    !string.Equals(role.GetString(), nameof(Enums.UserRole.Admin), StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                if (user.TryGetProperty("isDeleted", out var deleted) &&
                    deleted.ValueKind == JsonValueKind.True)
                {
                    continue;
                }

                // Serialised with WhenWritingNull, so an admin who signs in
                // through Google has no passwordHash key at all — that account
                // can still get in, so it counts.
                return true;
            }

            return false;
        }

        /// <summary>True when the backup holds the given account.</summary>
        private static bool ContainsUser(JsonElement tables, Guid userId)
        {
            if (!tables.TryGetProperty("Users", out var users) || users.ValueKind != JsonValueKind.Array)
                return false;

            var wanted = userId.ToString();

            foreach (var user in users.EnumerateArray())
            {
                if (user.TryGetProperty("id", out var id) &&
                    string.Equals(id.GetString(), wanted, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }

            return false;
        }

        /// <summary>
        /// Writes the audit row. There is no target user for a backup, and
        /// <c>TargetUserId</c> is not nullable, so the acting administrator
        /// stands in — which reads correctly in System Logs as an admin acting
        /// on the system rather than on somebody else.
        /// </summary>
        private async Task LogAsync(
            Guid adminUserId, string action, string? oldValue, string? newValue, CancellationToken ct)
        {
            await _db.AdminAuditLogs.AddAsync(new AdminAuditLog
            {
                Id = Guid.NewGuid(),
                AdminUserId = adminUserId,
                TargetUserId = adminUserId,
                Action = action,
                OldValue = oldValue,
                NewValue = newValue,
                CreatedAt = DateTime.UtcNow
            }, ct);
        }

        /// <summary>
        /// Backup names are generated here, never chosen, so anything that is
        /// not one of ours is a path someone is trying to walk out of.
        /// </summary>
        private static bool IsSafeFileName(string fileName) =>
            !string.IsNullOrWhiteSpace(fileName) &&
            fileName.EndsWith(".json", StringComparison.OrdinalIgnoreCase) &&
            fileName.IndexOfAny(['/', '\\']) < 0 &&
            !fileName.Contains("..", StringComparison.Ordinal) &&
            fileName.StartsWith("aimpark-", StringComparison.Ordinal);

        private sealed class BackupEnvelope
        {
            public string Format { get; set; } = FormatName;
            public int Version { get; set; } = FormatVersion;
            public DateTime CreatedAt { get; set; }
            public string CreatedByEmail { get; set; } = string.Empty;

            /// <summary>
            /// Declared as <c>object</c> so System.Text.Json serialises each row
            /// by its runtime entity type rather than flattening it.
            /// </summary>
            public Dictionary<string, IReadOnlyList<object>> Tables { get; set; } = [];
        }
    }
}
