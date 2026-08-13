import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/ocr/document_scanner.dart';
import '../../../../core/ocr/ocr_payload.dart';

part 'registration_provider.g.dart';

/// One text recogniser for the whole registration flow.
///
/// The documents are now captured on four separate screens, so a recogniser
/// owned by a screen would load the model four times over. Kept alive across
/// them and closed when the flow's providers go.
@Riverpod(keepAlive: true)
DocumentScanner documentScanner(Ref ref) {
  final scanner = DocumentScanner();
  ref.onDispose(scanner.dispose);
  return scanner;
}

/// How the applicant is attached to the school. Names match the C# `Affiliation`
/// enum, which the server parses by name.
enum Affiliation {
  student('Student', 'Student'),
  faculty('Faculty', 'Faculty'),
  staff('Staff', 'Staff');

  const Affiliation(this.wireName, this.label);

  final String wireName;
  final String label;
}

class RegistrationState {
  const RegistrationState({
    this.registrationSessionId,
    this.email,
    this.isOAuthFlow = false,
    this.googleDisplayName,
    this.affiliation = Affiliation.student,
    this.captured = const {},
  });

  final String? registrationSessionId;
  final String? email;

  /// Decides which proof of affiliation the document step asks for: a
  /// registration form from students, a school ID from everyone else.
  ///
  /// Kept only to label the capture screen correctly. The server files the
  /// document under the affiliation it has on record, so a stale value here
  /// mislabels a button but never stores the wrong kind of document.
  final Affiliation affiliation;

  /// True when the current registration was initiated via Google Sign-In.
  /// Used by [RegisterProfileScreen] to hide password fields and pre-fill name.
  final bool isOAuthFlow;

  /// The display name returned by Google, used to pre-fill the profile form.
  final String? googleDisplayName;

  /// Photos taken so far, with what was read from each.
  ///
  /// Held here because the four documents are captured on four screens but
  /// uploaded in one call at the end. Keeping them on any single screen would
  /// lose the earlier three the moment it was popped, and uploading each as it
  /// is taken would mean four round trips before the user has finished.
  final Map<ScanDocumentType, CapturedDocument> captured;

  RegistrationState copyWith({
    String? registrationSessionId,
    String? email,
    bool? isOAuthFlow,
    String? googleDisplayName,
    Affiliation? affiliation,
    Map<ScanDocumentType, CapturedDocument>? captured,
    bool clearSession = false,
  }) {
    return RegistrationState(
      registrationSessionId:
          clearSession ? null : registrationSessionId ?? this.registrationSessionId,
      email: email ?? this.email,
      isOAuthFlow: isOAuthFlow ?? this.isOAuthFlow,
      googleDisplayName:
          clearSession ? null : googleDisplayName ?? this.googleDisplayName,
      affiliation: affiliation ?? this.affiliation,
      captured: captured ?? this.captured,
    );
  }
}

@Riverpod(keepAlive: true)
class RegistrationNotifier extends _$RegistrationNotifier {
  @override
  RegistrationState build() => const RegistrationState();

  void setEmail(String email) {
    state = state.copyWith(email: email);
  }

  void setRegistrationSessionId(String sessionId) {
    state = state.copyWith(registrationSessionId: sessionId);
  }

  /// Called when the Google sign-in flow starts registration for a new user.
  void setOAuthFlow({required String displayName}) {
    state = state.copyWith(
      isOAuthFlow: true,
      googleDisplayName: displayName,
    );
  }

  /// Survives [clearSession] deliberately: the session token is finished with
  /// once the profile step returns a JWT, but the document step still needs to
  /// know which proof of affiliation to ask for.
  void setAffiliation(Affiliation affiliation) {
    state = state.copyWith(affiliation: affiliation);
  }

  void setCaptured(ScanDocumentType type, CapturedDocument document) {
    state = state.copyWith(
      captured: {...state.captured, type: document},
    );
  }

  /// Forgets the photos once they have been submitted, so a second pass through
  /// the flow — a re-application, or a back-out and restart — does not upload
  /// last time's images.
  void clearCaptured() {
    state = state.copyWith(captured: const {});
  }

  void clearSession() {
    state = state.copyWith(clearSession: true, isOAuthFlow: false);
  }
}
