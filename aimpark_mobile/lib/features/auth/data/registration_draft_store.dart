import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ocr/document_check.dart';
import '../../../core/ocr/document_scanner.dart';
import '../../../core/ocr/ocr_payload.dart';

/// What was recovered from a previous run of the registration flow.
typedef RegistrationDraft = ({
  /// The wire name of the affiliation chosen at the profile step, or null when
  /// nothing was saved. A wire name rather than the enum so this layer does not
  /// have to import the provider that imports it.
  String? affiliationWireName,
  Map<ScanDocumentType, CapturedDocument> captured,
  Map<ScanDocumentType, int> attempts,
});

/// Remembers a registration in progress across a restart of the app.
///
/// Registration is the longest unbroken stretch of work the app asks anyone to
/// do — an OTP, a form, four photographs — and the document step runs the
/// camera, which is exactly when Android is most likely to kill the process for
/// memory. Without this, coming back meant photographing all four documents
/// again, and a staff member came back as a student because the affiliation had
/// gone with the rest of the state.
///
/// Only what cannot be recovered any other way is stored here. The email, the
/// session token and the eventual JWT already live in secure storage, and the
/// server holds the account itself.
///
/// The photographs are *not* copied anywhere: what is saved is the path the
/// camera wrote to, in the app's own cache directory. That is deliberate —
/// copying four full-resolution photos into permanent storage to guard against
/// a crash that may not come is a poor trade, and a photo the OS has since
/// swept up simply reappears as one still to take, which the flow already knows
/// how to ask for.
class RegistrationDraftStore {
  const RegistrationDraftStore();

  static const _key = 'registration_draft';

  /// Every write runs after the one before it finished.
  ///
  /// Nothing here is awaited by its caller — a button press must not wait on
  /// the disk — so two mutations can otherwise be in flight at once and land in
  /// either order. The case that matters is real: starting a fresh
  /// registration clears the draft, and the affiliation chosen a moment later
  /// writes a new one. Those landing the wrong way round would clear the
  /// affiliation the user had just picked.
  static Future<void> _writes = Future.value();

  static Future<void> _serialize(Future<void> Function() work) {
    final next = _writes.then((_) => work());
    // Keeps one failed write from poisoning every write after it.
    _writes = next.catchError((_) {});
    return next;
  }

  Future<RegistrationDraft?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return null;

    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;

      final captured = <ScanDocumentType, CapturedDocument>{};
      final attempts = <ScanDocumentType, int>{};

      final storedAttempts = json['attempts'] as Map<String, dynamic>? ?? {};
      final storedPhotos = json['captured'] as Map<String, dynamic>? ?? {};

      for (final entry in storedPhotos.entries) {
        final type = ScanDocumentType.fromWire(entry.key);
        if (type == null) continue;

        final photo = _photoFromJson(entry.value as Map<String, dynamic>);
        if (photo == null) continue;

        captured[type] = photo;

        // Attempts are only carried forward for a photo that survived with it.
        // A document whose file the OS swept up is one the user has to take
        // again from nothing, and charging them for tries they can no longer
        // see the results of would be the flow punishing them for a cache
        // eviction. The server keeps its own count of scans regardless, so this
        // is not the limit that matters.
        final count = storedAttempts[entry.key];
        if (count is int) attempts[type] = count;
      }

      return (
        affiliationWireName: json['affiliation'] as String?,
        captured: captured,
        attempts: attempts,
      );
    } catch (_) {
      // A draft written by an older build, or a half-written one. Neither is
      // worth failing a launch over — the flow simply starts clean.
      await clear();
      return null;
    }
  }

  Future<void> write({
    required String? affiliationWireName,
    required Map<ScanDocumentType, CapturedDocument> captured,
    required Map<ScanDocumentType, int> attempts,
  }) {
    // Serialised as JSON here rather than inside the queued closure, so what
    // gets written is the state as it was when the call was made.
    final payload = jsonEncode({
      'affiliation': affiliationWireName,
      'captured': {
        for (final entry in captured.entries)
          entry.key.wireName: _photoToJson(entry.value),
      },
      'attempts': {
        for (final entry in attempts.entries) entry.key.wireName: entry.value,
      },
    });

    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, payload);
    });
  }

  Future<void> clear() {
    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    });
  }

  static Map<String, dynamic> _photoToJson(CapturedDocument photo) => {
    'path': photo.file.path,
    'issue': photo.issue?.name,
    'payload': photo.payload?.toJson(),
  };

  /// Null when the photograph itself is gone, which is the only case that
  /// matters: everything else about a captured document can be reconstructed,
  /// but a file the cache no longer holds cannot be uploaded.
  static CapturedDocument? _photoFromJson(Map<String, dynamic> json) {
    final path = json['path'] as String?;
    if (path == null) return null;

    final file = File(path);
    if (!file.existsSync()) return null;

    final payload = json['payload'];

    return CapturedDocument(
      file: file,
      payload: payload is Map<String, dynamic>
          ? OcrPayload.fromJson(payload)
          : null,
      issue: _issueFromName(json['issue'] as String?),
    );
  }

  static DocumentIssue? _issueFromName(String? name) {
    if (name == null) return null;
    for (final issue in DocumentIssue.values) {
      if (issue.name == name) return issue;
    }
    return null;
  }
}
