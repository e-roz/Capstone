namespace AimPark.API.DTOs
{
    /// <summary>
    /// One saved backup file, as the history table lists it.
    /// </summary>
    public class BackupFileResponse
    {
        public string Name { get; set; } = string.Empty;
        public long SizeBytes { get; set; }
        public DateTime? CreatedAt { get; set; }
    }

    public class BackupListResponse
    {
        public List<BackupFileResponse> Backups { get; set; } = [];
    }

    /// <summary>
    /// What a backup file says about itself — read from its header, without
    /// touching the database.
    /// </summary>
    public class BackupSummaryResponse
    {
        public string FileName { get; set; } = string.Empty;
        public int FormatVersion { get; set; }
        public DateTime CreatedAt { get; set; }
        public string CreatedByEmail { get; set; } = string.Empty;

        /// <summary>Row count per table, in the order they are written.</summary>
        public List<TableCountResponse> Tables { get; set; } = [];

        public int TotalRows { get; set; }
    }

    public class TableCountResponse
    {
        public string Table { get; set; } = string.Empty;

        /// <summary>Rows the backup file holds.</summary>
        public int Rows { get; set; }

        /// <summary>Rows the live database holds right now. Null on a plain
        /// backup summary, filled in on a restore preview so the administrator
        /// can see what the restore would replace.</summary>
        public int? CurrentRows { get; set; }
    }

    /// <summary>
    /// The answer to "what would happen if I restored this file" — computed
    /// without writing anything.
    /// </summary>
    public class RestorePreviewResponse
    {
        public BackupSummaryResponse Backup { get; set; } = new();

        /// <summary>False when the file cannot safely be restored at all.</summary>
        public bool CanRestore { get; set; }

        /// <summary>Why not, when <see cref="CanRestore"/> is false.</summary>
        public string? Problem { get; set; }

        /// <summary>
        /// Things that are survivable but the administrator should see first —
        /// an old file, or one that does not contain their own account.
        /// </summary>
        public List<string> Warnings { get; set; } = [];

        /// <summary>Rows in the live database that the restore would discard.</summary>
        public int CurrentTotalRows { get; set; }
    }

    public class RestoreResultResponse
    {
        public string Message { get; set; } = string.Empty;

        /// <summary>
        /// The copy of the pre-restore database taken automatically before
        /// anything was deleted. This is the way back if the restore was a
        /// mistake, so it is returned rather than only logged.
        /// </summary>
        public string SafetyBackupName { get; set; } = string.Empty;

        public List<TableCountResponse> Restored { get; set; } = [];
        public int TotalRows { get; set; }
    }
}
