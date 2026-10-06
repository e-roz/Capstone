import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'update_config.dart';
import 'update_manifest.dart';

/// A download that reached the device but isn't trustworthy — wrong shape,
/// wrong size, wrong hash — as opposed to a plain network failure, which
/// throws as a [DioException] instead.
class UpdateDownloadException implements Exception {
  UpdateDownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A ZIP file (an APK is a ZIP) always starts with this 4-byte signature.
/// Google Drive's "can't scan this file for viruses" interstitial — and any
/// other host that silently serves an HTML page instead of the binary — does
/// not, so checking it first turns that failure mode into a clean, specific
/// error instead of a corrupt install attempt.
const List<int> _zipSignature = [0x50, 0x4B, 0x03, 0x04];

/// Fetches the update manifest and downloads/verifies the APK it points at.
///
/// Takes its own bare [Dio] — deliberately not the app's shared `dioProvider`
/// instance, which attaches the signed-in user's JWT to every request via an
/// interceptor. That header has no business going to GitHub or wherever the
/// APK happens to be hosted.
class UpdateRepository {
  UpdateRepository(this._dio);

  final Dio _dio;

  Future<UpdateManifest> fetchManifest() async {
    // GitHub's raw content host serves this as text/plain, not
    // application/json, so Dio won't auto-decode it — fetch as a string and
    // decode by hand.
    final response = await _dio.get<String>(
      UpdateConfig.manifestUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final body = response.data;
    if (body == null || body.isEmpty) {
      throw const FormatException('Update manifest response was empty');
    }

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Update manifest was not a JSON object');
    }

    return UpdateManifest.fromJson(json);
  }

  /// Downloads [manifest]'s APK to a fresh file under the app's cache
  /// directory, verifying it before returning. Throws [UpdateDownloadException]
  /// (bad shape/size/hash) or lets a [DioException] (network failure)
  /// propagate — either way the caller treats it as "the update didn't work
  /// this time", not as a crash.
  Future<File> downloadApk(
    UpdateManifest manifest, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final updatesDir = await _freshUpdatesDir();
    final partFile = File('${updatesDir.path}/aimpark-${manifest.version}.apk.part');
    final apkFile = File('${updatesDir.path}/aimpark-${manifest.version}.apk');

    try {
      await _dio.download(
        manifest.apkUrl,
        partFile.path,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        deleteOnError: true,
      );

      await _verify(partFile, manifest);

      if (await apkFile.exists()) {
        await apkFile.delete();
      }
      await partFile.rename(apkFile.path);
      return apkFile;
    } catch (_) {
      if (await partFile.exists()) {
        await partFile.delete();
      }
      rethrow;
    }
  }

  Future<void> _verify(File file, UpdateManifest manifest) async {
    if (!await file.exists()) {
      throw UpdateDownloadException('Downloaded file is missing');
    }

    final length = await file.length();
    if (length < _zipSignature.length) {
      throw UpdateDownloadException('Downloaded file is too small to be an APK');
    }

    final handle = await file.open();
    final header = await handle.read(_zipSignature.length);
    await handle.close();
    if (!_bytesMatch(header, _zipSignature)) {
      throw UpdateDownloadException(
        "Downloaded file isn't a valid APK — the host may have returned an "
        'error page instead of the file',
      );
    }

    if (manifest.apkSizeBytes != null && length != manifest.apkSizeBytes) {
      throw UpdateDownloadException(
        'Downloaded file size (${length}B) does not match the expected size '
        '(${manifest.apkSizeBytes}B)',
      );
    }

    if (manifest.apkSha256 != null) {
      final digest = await sha256.bind(file.openRead()).first;
      final actual = digest.toString().toLowerCase();
      if (actual != manifest.apkSha256!.toLowerCase()) {
        throw UpdateDownloadException(
          'Downloaded file failed its integrity check',
        );
      }
    }
  }

  bool _bytesMatch(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  /// Clears out anything left over from a previous attempt — an interrupted
  /// download, a cancelled one — so the updates folder never accumulates
  /// partial APKs across app launches.
  Future<Directory> _freshUpdatesDir() async {
    final cacheDir = await getTemporaryDirectory();
    final updatesDir = Directory('${cacheDir.path}/updates');
    if (await updatesDir.exists()) {
      await updatesDir.delete(recursive: true);
    }
    await updatesDir.create(recursive: true);
    return updatesDir;
  }
}
