import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/ocr/document_scanner.dart';
import '../../../../core/ocr/ocr_payload.dart';
import '../../data/models/document_request.dart';
import '../../data/models/document_spec.dart';
import '../../data/registration_draft_store.dart';
import 'auth_provider.dart';

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

  static Affiliation? fromWire(String? value) {
    for (final affiliation in values) {
      if (affiliation.wireName == value) return affiliation;
    }
    return null;
  }
}

/// The documents this pass through the capture flow has to collect, and why.
class DocumentAgenda {
  const DocumentAgenda({required this.specs, this.reasons = const {}});

  final List<DocumentSpec> specs;

  /// The reviewer's wording per document, when this is a requested retake.
  final Map<ScanDocumentType, String> reasons;

  /// True when a reviewer asked for these specifically, rather than this being
  /// a first submission.
  bool get isRetake => reasons.isNotEmpty;
}

/// Which documents to ask for: all four, or only the ones sent back.
///
/// Asked of the server rather than inferred, because only the server knows a
/// reviewer has been through the submission. Falling back to the full set on any
/// failure is deliberate — a network error must not silently turn a first
/// registration into a one-document one, and asking for a document already on
/// file costs a photograph while asking for too few costs a rejected
/// application.
@riverpod
Future<DocumentAgenda> documentAgenda(Ref ref) async {
  final affiliation =
      ref.watch(registrationNotifierProvider.select((s) => s.affiliation));
  final full = DocumentSpec.forAffiliation(affiliation);

  try {
    final response = await ref.read(authRepositoryProvider).registrationStatus();
    final status =
        RegistrationStatus.fromJson(response.data as Map<String, dynamic>);

    if (!status.hasRetakes) return DocumentAgenda(specs: full);

    // Matched against the affiliation's own slots, so a reviewer naming the RAF
    // on a staff account still resolves to the school ID that account files
    // under — the same folding the server does.
    final wanted = {for (final r in status.documentsToRetake) r.type: r.reason};
    final identity = full.first.type;

    final specs = full.where((spec) {
      if (wanted.containsKey(spec.type)) return true;
      final isIdentity = spec.type == identity;
      return isIdentity &&
          (wanted.containsKey(ScanDocumentType.raf) ||
              wanted.containsKey(ScanDocumentType.schoolId));
    }).toList();

    if (specs.isEmpty) return DocumentAgenda(specs: full);

    return DocumentAgenda(
      specs: specs,
      reasons: {
        for (final spec in specs)
          spec.type: wanted[spec.type] ??
              wanted[ScanDocumentType.raf] ??
              wanted[ScanDocumentType.schoolId] ??
              '',
      },
    );
  } catch (_) {
    return DocumentAgenda(specs: full);
  }
}

class RegistrationState {
  const RegistrationState({
    this.registrationSessionId,
    this.email,
    this.isOAuthFlow = false,
    this.googleDisplayName,
    this.affiliation = Affiliation.student,
    this.captured = const {},
    this.captureAttempts = const {},
    this.hydrated = false,
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

  /// How many photographs have been taken of each document.
  ///
  /// Held here rather than on the capture screen because that screen is replaced
  /// on every step change, and a counter that resets whenever the user steps
  /// back and forward would never reach its limit.
  ///
  /// The limit exists so a rejection is never a dead end. Landmark matching is
  /// derived from the forms on hand, and a campus printing a different template
  /// must not be able to lock a real student out of registering — so after
  /// enough tries the photo goes up anyway, and the reviewer is told the system
  /// never recognised it.
  final Map<ScanDocumentType, int> captureAttempts;

  /// False until the saved draft has been read back off disk.
  ///
  /// The read is a frame or two on a fast phone and a few hundred milliseconds
  /// on a slow one, and in that window a document step would otherwise render
  /// its empty "take a photo" prompt for a document that has already been
  /// photographed. Long enough for someone to tap it, so the step waits instead.
  final bool hydrated;

  RegistrationState copyWith({
    String? registrationSessionId,
    String? email,
    bool? isOAuthFlow,
    String? googleDisplayName,
    Affiliation? affiliation,
    Map<ScanDocumentType, CapturedDocument>? captured,
    Map<ScanDocumentType, int>? captureAttempts,
    bool? hydrated,
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
      captureAttempts: captureAttempts ?? this.captureAttempts,
      hydrated: hydrated ?? this.hydrated,
    );
  }
}

@Riverpod(keepAlive: true)
class RegistrationNotifier extends _$RegistrationNotifier {
  static const _store = RegistrationDraftStore();

  /// Set once the user has chosen or captured anything in this run.
  ///
  /// The disk read is asynchronous, so a user who is quick enough could pick an
  /// affiliation or take a photo before it lands. Their choice wins: a draft is
  /// there to fill a gap, never to overwrite what somebody has just done.
  bool _touched = false;

  @override
  RegistrationState build() {
    _restore();
    return const RegistrationState();
  }

  Future<void> _restore() async {
    final draft = await _store.read();

    if (_touched) {
      // Still worth marking hydrated — the wait is over either way, and the
      // document step is holding its render on this.
      state = state.copyWith(hydrated: true);
      return;
    }

    state = state.copyWith(
      affiliation: Affiliation.fromWire(draft?.affiliationWireName),
      captured: draft?.captured,
      captureAttempts: draft?.attempts,
      hydrated: true,
    );
  }

  /// Writes the parts of the flow that a restart would otherwise lose.
  ///
  /// Fire-and-forget: nothing downstream waits on the write, and a failed write
  /// costs the user a re-capture in a crash that may never happen — which is not
  /// worth blocking a button press over.
  void _persist() {
    unawaited(
      _store.write(
        affiliationWireName: state.affiliation.wireName,
        captured: state.captured,
        attempts: state.captureAttempts,
      ),
    );
  }

  void setEmail(String email) {
    state = state.copyWith(email: email);
  }

  /// Drops anything a previous, abandoned registration left behind.
  ///
  /// Called when the email step succeeds, which is the one point that always
  /// means "a registration is beginning" — a resumed one re-enters at the step
  /// its token names and never passes back through here.
  ///
  /// Without this, someone who gave up at the document step would leave four
  /// photographs and an affiliation on the phone, and the next person to
  /// register on it would find them restored into their own application. A
  /// shared phone is not the unusual case on a campus.
  void startFresh() {
    _touched = true;
    state = state.copyWith(
      affiliation: Affiliation.student,
      captured: const {},
      captureAttempts: const {},
      hydrated: true,
    );
    unawaited(_store.clear());
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
    _touched = true;
    state = state.copyWith(affiliation: affiliation);
    _persist();
  }

  void setCaptured(ScanDocumentType type, CapturedDocument document) {
    _touched = true;
    state = state.copyWith(
      captured: {...state.captured, type: document},
      captureAttempts: {
        ...state.captureAttempts,
        type: (state.captureAttempts[type] ?? 0) + 1,
      },
    );
    _persist();
  }

  /// Forgets the photos once they have been submitted, so a second pass through
  /// the flow — a re-application, or a back-out and restart — does not upload
  /// last time's images.
  void clearCaptured() {
    _touched = true;
    state = state.copyWith(captured: const {}, captureAttempts: const {});
    unawaited(_store.clear());
  }

  void clearSession() {
    state = state.copyWith(clearSession: true, isOAuthFlow: false);
  }
}
