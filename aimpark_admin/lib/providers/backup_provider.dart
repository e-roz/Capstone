import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/browser_files.dart';
import '../models/backup.dart';

part 'backup_provider.g.dart';

/// A failure with a sentence in it that is safe to show an administrator.
///
/// The screens here have three steps that can each fail for a different reason
/// — a bad file, a wrong password, a refused restore — and every one of them
/// needs to say which. Letting a raw `DioException` reach the UI would print
/// the URL instead.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ── Backup history ───────────────────────────────────────────────────────────

@riverpod
Future<List<BackupFile>> backupList(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.backups);

  final data = response.data as Map<String, dynamic>;
  return (data['backups'] as List<dynamic>? ?? [])
      .map((b) => BackupFile.fromJson(b as Map<String, dynamic>))
      .toList();
}

// ── Actions ──────────────────────────────────────────────────────────────────

@riverpod
class BackupActions extends _$BackupActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Takes a fresh backup, hands the file to the browser, and refreshes the
  /// history. Returns the name of the file that was written.
  Future<String> create() async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final response = await dio.post<List<int>>(
        ApiEndpoints.backups,
        options: Options(responseType: ResponseType.bytes),
      );

      final name = _fileNameFrom(response.headers) ?? _fallbackName();
      BrowserFiles.download(name, Uint8List.fromList(response.data ?? const []));

      ref.invalidate(backupListProvider);
      return name;
    });
  }

  /// Re-downloads a backup taken earlier.
  Future<void> downloadExisting(String fileName) async {
    await _run(() async {
      final dio = ref.read(dioProvider);
      final response = await dio.get<List<int>>(
        ApiEndpoints.backupFile(fileName),
        options: Options(responseType: ResponseType.bytes),
      );

      BrowserFiles.download(
          fileName, Uint8List.fromList(response.data ?? const []));
      return null;
    });
  }

  /// Asks the server what restoring [file] would do. Writes nothing.
  Future<RestorePreview> preview(PickedFile file) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        ApiEndpoints.backupPreview,
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(file.bytes, filename: file.name),
        }),
      );

      return RestorePreview.fromJson(response.data as Map<String, dynamic>);
    });
  }

  /// Replaces the database with [file].
  Future<RestoreResult> restore({
    required PickedFile file,
    required String password,
    required String confirmation,
  }) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        ApiEndpoints.backupRestore,
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(file.bytes, filename: file.name),
          'password': password,
          'confirmation': confirmation,
        }),
      );

      ref.invalidate(backupListProvider);
      return RestoreResult.fromJson(response.data as Map<String, dynamic>);
    });
  }

  /// Runs [fn] with the busy flag set, turning a transport failure into a
  /// [BackupException] carrying the server's own message where there is one.
  Future<T> _run<T>(Future<T> Function() fn) async {
    state = const AsyncLoading();
    try {
      final result = await fn();
      state = const AsyncData(null);
      return result;
    } on DioException catch (e) {
      state = const AsyncData(null);
      throw BackupException(_messageFrom(e));
    } catch (e) {
      state = const AsyncData(null);
      throw BackupException('$e');
    }
  }

  /// The server answers a refused restore with `{ "message": "..." }`, which is
  /// written for the administrator and is always the better thing to show. When
  /// the response came back as bytes — the download endpoints ask for those —
  /// the body is not a map, so fall through to the transport message.
  static String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();

    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        'The server took too long to answer. A large backup can outrun the '
            'timeout — try again, and check the System Logs if it repeats.',
      DioExceptionType.connectionError =>
        'Could not reach the server. Check that the API is running.',
      _ => e.message ?? 'Something went wrong.',
    };
  }

  /// Pulls the file name out of `Content-Disposition`, so the download is named
  /// by the server that made it rather than by a second guess here.
  static String? _fileNameFrom(Headers headers) {
    final header = headers.value('content-disposition');
    if (header == null) return null;

    final match = RegExp(r'filename\*?=(?:UTF-8'
            r"''"
            r')?"?([^";]+)"?')
        .firstMatch(header);
    return match?.group(1)?.trim();
  }

  static String _fallbackName() {
    final now = DateTime.now().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'aimpark-backup-${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
  }
}
