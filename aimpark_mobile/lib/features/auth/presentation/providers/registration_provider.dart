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
/// The documents are now captured on three separate screens, so a recogniser
/// owned by a screen would load the model three times over. Kept alive across
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
  faculty('Faculty', 'Faculty / Staff'),

  /// Kept only so an account made before faculty and staff were merged still
  /// reads back. Never offered as a choice; see [asChoice].
  staff('Staff', 'Faculty / Staff');

  const Affiliation(this.wireName, this.label);

  final String wireName;
  final String label;

  /// What the sign-up form offers. Faculty and staff send the same documents
  /// and are checked the same way, so they are one option.
  static const choices = [Affiliation.student, Affiliation.faculty];

  /// This value as one of [choices]: an old `staff` reads as faculty.
  Affiliation get asChoice =>
      this == Affiliation.staff ? Affiliation.faculty : this;

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

/// Which documents to ask for: all three, or only the ones sent back.
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
  final isEBike =
      ref.watch(registrationNotifierProvider.select((s) => s.isEBike));
  final full = DocumentSpec.forAffiliation(affiliation, isEBike: isEBike);

  try {
    final response = await ref.read(authRepositoryProvider).registrationStatus();
    final status =
        RegistrationStatus.fromJson(response.data as Map<String, dynamic>);

    if (!status.hasRetakes) return DocumentAgenda(specs: full);

    // Matched against this account's own documents, so a request for the
    // registration form on a faculty or staff account, who send none, asks for
    // nothing — the same as the server.
    final wanted = {for (final r in status.documentsToRetake) r.type: r.reason};

    final specs = full.where((spec) => wanted.containsKey(spec.type)).toList();

    if (specs.isEmpty) return DocumentAgenda(specs: full);

    return DocumentAgenda(
      specs: specs,
      reasons: {for (final spec in specs) spec.type: wanted[spec.type] ?? ''},
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
    this.isEBike = false,
    this.captured = const {},
    this.captureAttempts = const {},
    this.confirmed = const {},
    this.hydrated = false,
  });

  final String? registrationSessionId;
  final String? email;

  /// Decides which proof of affiliation the document step asks for: a
  /// registration form from students and nothing extra from everyone else.
  ///
  /// Kept only to label the capture screen correctly. The server files the
  /// document under the affiliation it has on record, so a stale value here
  /// mislabels a button but never stores the wrong kind of document.
  final Affiliation affiliation;

  /// "E-bike" was chosen rather than "Motor vehicle". An e-bike has no LTO plate
  /// or receipt, so the document step skips the receipt and the applicant ends
  /// the flow by visiting the admin office.
  final bool isEBike;

  /// True when the current registration was initiated via Google Sign-In.
  /// Used by [RegisterProfileScreen] to hide password fields and pre-fill name.
  final bool isOAuthFlow;

  /// The display name returned by Google, used to pre-fill the profile form.
  final String? googleDisplayName;

  /// Photos taken so far, with what was read from each.
  ///
  /// Held here because the three documents are captured on three screens but
  /// uploaded in one call at the end. Keeping them on any single screen would
  /// lose the earlier ones the moment it was popped, and uploading each as it
  /// is taken would mean three round trips before the user has finished.
  final Map<ScanDocumentType, CapturedDocument> captured;

  /// How many photographs have been taken of each document.
  ///
  /// Held here rather than on the capture screen because that screen is replaced
  /// on every step change, and a counter that resets whenever the user steps
  /// back and forward would show the wrong number.
  ///
  /// Only shown to the user ("Try 3"). There is no limit: the point of a retake
  /// is to keep going until the document reads.
  final Map<ScanDocumentType, int> captureAttempts;

  /// The values the user confirmed for each document, as it was read.
  ///
  /// Keyed by document, then by the server's field name (`LicenseNumber`,
  /// `LicenseExpiry` as an ISO date, …). A document with an entry here has been
  /// read and checked, and the step lets the user move on. Not saved to disk:
  /// after a restart the photo is simply read again, which costs no try.
  final Map<ScanDocumentType, Map<String, String>> confirmed;

  /// Every confirmed value, across all documents, by field name.
  Map<String, String> get confirmedValues => {
    for (final values in confirmed.values) ...values,
  };

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
    bool? isEBike,
    Map<ScanDocumentType, CapturedDocument>? captured,
    Map<ScanDocumentType, int>? captureAttempts,
    Map<ScanDocumentType, Map<String, String>>? confirmed,
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
      isEBike: isEBike ?? this.isEBike,
      captured: captured ?? this.captured,
      captureAttempts: captureAttempts ?? this.captureAttempts,
      confirmed: confirmed ?? this.confirmed,
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
      isEBike: draft?.isEBike,
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
        isEBike: state.isEBike,
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
  /// Without this, someone who gave up at the document step would leave three
  /// photographs and an affiliation on the phone, and the next person to
  /// register on it would find them restored into their own application. A
  /// shared phone is not the unusual case on a campus.
  void startFresh() {
    _touched = true;
    state = state.copyWith(
      affiliation: Affiliation.student,
      isEBike: false,
      captured: const {},
      captureAttempts: const {},
      confirmed: const {},
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

  void setIsEBike(bool isEBike) {
    _touched = true;
    state = state.copyWith(isEBike: isEBike);
    _persist();
  }

  /// A new photo replaces the old one, and whatever was confirmed from the old
  /// one no longer describes it.
  void setCaptured(ScanDocumentType type, CapturedDocument document) {
    _touched = true;
    state = state.copyWith(
      captured: {...state.captured, type: document},
      // Only so the user can see how many photos they have taken. There is no
      // limit: a document is retaken until it reads.
      captureAttempts: {
        ...state.captureAttempts,
        type: (state.captureAttempts[type] ?? 0) + 1,
      },
      confirmed: {...state.confirmed}..remove(type),
    );
    _persist();
  }

  /// Gives back the try a photo used.
  ///
  /// For a document that read perfectly well and was refused for being expired:
  /// the tries are for photographs that would not read, and photographing a
  /// different, valid document is not a second attempt at the first.
  void forgiveAttempt(ScanDocumentType type) {
    final attempts = state.captureAttempts[type] ?? 0;
    if (attempts == 0) return;
    state = state.copyWith(
      captureAttempts: {...state.captureAttempts, type: attempts - 1},
    );
    _persist();
  }

  /// Records the values the user agreed to for one document.
  void setConfirmed(ScanDocumentType type, Map<String, String> values) {
    _touched = true;
    state = state.copyWith(confirmed: {...state.confirmed, type: values});
  }

  /// Forgets the photos once they have been submitted, so a second pass through
  /// the flow — a re-application, or a back-out and restart — does not upload
  /// last time's images.
  void clearCaptured() {
    _touched = true;
    state = state.copyWith(
      captured: const {},
      captureAttempts: const {},
      confirmed: const {},
    );
    unawaited(_store.clear());
  }

  void clearSession() {
    state = state.copyWith(clearSession: true, isOAuthFlow: false);
  }
}
