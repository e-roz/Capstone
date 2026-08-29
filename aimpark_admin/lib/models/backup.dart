/// One backup file held in storage.
class BackupFile {
  final String name;
  final int sizeBytes;
  final DateTime? createdAt;

  const BackupFile({
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory BackupFile.fromJson(Map<String, dynamic> json) => BackupFile(
        name: json['name']?.toString() ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'].toString()),
      );

  /// Size in the unit a person would say it in.
  String get readableSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// True for the automatic copy taken immediately before a restore, which is
  /// worth marking: it is the way back from a restore that went wrong, not a
  /// backup anybody asked for.
  bool get isPreRestore => name.startsWith('aimpark-prerestore-');
}

/// Rows in one table — how many the backup holds, and how many are live now.
class TableCount {
  final String table;
  final int rows;
  final int? currentRows;

  const TableCount({
    required this.table,
    required this.rows,
    required this.currentRows,
  });

  factory TableCount.fromJson(Map<String, dynamic> json) => TableCount(
        table: json['table']?.toString() ?? '',
        rows: (json['rows'] as num?)?.toInt() ?? 0,
        currentRows: (json['currentRows'] as num?)?.toInt(),
      );

  /// Rows gained (positive) or lost (negative) if this backup were restored.
  int? get delta => currentRows == null ? null : rows - currentRows!;
}

/// What a backup file says about itself.
class BackupSummary {
  final String fileName;
  final int formatVersion;
  final DateTime? createdAt;
  final String createdByEmail;
  final List<TableCount> tables;
  final int totalRows;

  const BackupSummary({
    required this.fileName,
    required this.formatVersion,
    required this.createdAt,
    required this.createdByEmail,
    required this.tables,
    required this.totalRows,
  });

  factory BackupSummary.fromJson(Map<String, dynamic> json) => BackupSummary(
        fileName: json['fileName']?.toString() ?? '',
        formatVersion: (json['formatVersion'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'].toString()),
        createdByEmail: json['createdByEmail']?.toString() ?? '',
        tables: (json['tables'] as List<dynamic>? ?? [])
            .map((t) => TableCount.fromJson(t as Map<String, dynamic>))
            .toList(),
        totalRows: (json['totalRows'] as num?)?.toInt() ?? 0,
      );
}

/// What restoring a file would do, worked out without writing anything.
class RestorePreview {
  final BackupSummary backup;
  final bool canRestore;
  final String? problem;
  final List<String> warnings;
  final int currentTotalRows;

  const RestorePreview({
    required this.backup,
    required this.canRestore,
    required this.problem,
    required this.warnings,
    required this.currentTotalRows,
  });

  factory RestorePreview.fromJson(Map<String, dynamic> json) => RestorePreview(
        backup:
            BackupSummary.fromJson(json['backup'] as Map<String, dynamic>? ?? {}),
        canRestore: json['canRestore'] as bool? ?? false,
        problem: json['problem']?.toString(),
        warnings: (json['warnings'] as List<dynamic>? ?? [])
            .map((w) => w.toString())
            .toList(),
        currentTotalRows: (json['currentTotalRows'] as num?)?.toInt() ?? 0,
      );
}

class RestoreResult {
  final String message;
  final String safetyBackupName;
  final List<TableCount> restored;
  final int totalRows;

  const RestoreResult({
    required this.message,
    required this.safetyBackupName,
    required this.restored,
    required this.totalRows,
  });

  factory RestoreResult.fromJson(Map<String, dynamic> json) => RestoreResult(
        message: json['message']?.toString() ?? '',
        safetyBackupName: json['safetyBackupName']?.toString() ?? '',
        restored: (json['restored'] as List<dynamic>? ?? [])
            .map((t) => TableCount.fromJson(t as Map<String, dynamic>))
            .toList(),
        totalRows: (json['totalRows'] as num?)?.toInt() ?? 0,
      );
}
