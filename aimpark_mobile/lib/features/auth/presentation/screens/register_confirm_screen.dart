import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ocr/ocr_payload.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/document_spec.dart';
import '../../data/models/scan_result.dart';
import '../../data/registration_preflight.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import '../widgets/plate_verdict_card.dart';
import '../widgets/scanned_field.dart';
import '../widgets/vehicle_color_picker.dart';

/// The last screen: what was read, plus the two things no document can say.
///
/// Most of this is still editable, which is why extraction accuracy is not
/// load-bearing — a field the rules missed is typed once here rather than
/// chased through retake after retake, and both readings are kept so a reviewer
/// can see where the person disagreed with the machine.
///
/// The plate is the exception. It is what the gate camera matches on, so it is
/// shown read-only and comes from the receipt: a hand-typed plate proves
/// nothing about the vehicle, while the receipt and the photograph of the metal
/// agreeing does. Where they disagree the fix offered is another photograph,
/// not a keyboard.
class RegisterConfirmScreen extends ConsumerStatefulWidget {
  const RegisterConfirmScreen({super.key, required this.result});

  final ScanResult result;

  @override
  ConsumerState<RegisterConfirmScreen> createState() =>
      _RegisterConfirmScreenState();
}

class _RegisterConfirmScreenState extends ConsumerState<RegisterConfirmScreen> {
  late final TextEditingController _studentNumber;
  late final TextEditingController _studentName;
  late final TextEditingController _section;
  late final TextEditingController _semester;
  late final TextEditingController _licenseName;

  DateTime? _licenseExpiry;
  DateTime? _registrationExpiry;

  /// Keys match the API's `VehicleType` enum names exactly — slot allocation
  /// matches a user's vehicle against a slot's type. The facility only has
  /// two-wheel and four-wheel bays, so Van and Truck were never offered.
  static const _vehicleTypes = <String, String>{
    'Car': 'Car',
    'Motorcycle': 'Motorcycle',
  };

  static const _vehicleIcons = <String, IconData>{
    'Car': Icons.directions_car_rounded,
    'Motorcycle': Icons.two_wheeler_rounded,
  };

  String? _vehicleType;
  String? _color;
  bool _isSubmitting = false;

  /// The two pickers are the only inputs here that a flushbar had to speak for,
  /// and it spoke from the top of a screen they sit halfway down.
  String? _vehicleTypeError;
  String? _colorError;

  ExtractedValues get _extracted => widget.result.extracted;

  @override
  void initState() {
    super.initState();
    _studentNumber = TextEditingController(text: _extracted.studentNumber);
    _studentName = TextEditingController(text: _extracted.studentName);
    _section = TextEditingController(text: _extracted.section);
    _semester = TextEditingController(text: _extracted.semester);
    _licenseName = TextEditingController(text: _extracted.licenseName);
    _licenseExpiry = _extracted.licenseExpiry;
    _registrationExpiry = _extracted.registrationExpiry;

    // The pre-flight compares the two names, and the dates already rebuild this
    // screen through their own onChanged. Without these, correcting a misread
    // name would leave the mismatch warning standing over the correction.
    _studentName.addListener(_onCheckedValueChanged);
    _licenseName.addListener(_onCheckedValueChanged);
  }

  void _onCheckedValueChanged() => setState(() {});

  @override
  void dispose() {
    _studentName.removeListener(_onCheckedValueChanged);
    _licenseName.removeListener(_onCheckedValueChanged);
    _studentNumber.dispose();
    _studentName.dispose();
    _section.dispose();
    _semester.dispose();
    _licenseName.dispose();
    super.dispose();
  }

  /// Back to the plate photo, keeping the other three photographs.
  void _retakePlatePhoto() => _retakeDocument(ScanDocumentType.platePhoto);

  /// Back to the receipt, which is where the plate comes from.
  ///
  /// Offered when nothing was read at all. The server refuses a submission with
  /// no plate while attempts remain — there is no vehicle to register without
  /// one — so this is the way forward rather than a suggestion.
  void _retakeReceiptPhoto() => _retakeDocument(ScanDocumentType.officialReceipt);

  void _retakeDocument(ScanDocumentType type) {
    final specs = DocumentSpec.forAffiliation(
      ref.read(registrationNotifierProvider).affiliation,
    );
    final index = specs.indexWhere((spec) => spec.type == type);
    if (index < 0) return;
    context.go('/register/documents/$index');
  }

  /// Whether a field the rules could not read is still exactly that: unread.
  ///
  /// [ScannedField] and [ScannedDateField] clear their own warning as soon as
  /// the user answers it, but nothing stopped them submitting with one still
  /// outstanding — the button never checked, only the eye did. This runs the
  /// same [fieldStillMissing] predicate over the fields that matter for this
  /// affiliation right before the request goes out.
  bool _hasUnresolvedFlags(bool isStudent) {
    final checks = [
      fieldStillMissing(
        _extracted.flagFor('StudentName'),
        _studentName.text.trim().isEmpty,
      ),
      fieldStillMissing(
        _extracted.flagFor('LicenseName'),
        _licenseName.text.trim().isEmpty,
      ),
      fieldStillMissing(
        _extracted.flagFor('LicenseExpiry'),
        _licenseExpiry == null,
      ),
      fieldStillMissing(
        _extracted.flagFor('RegistrationExpiry'),
        _registrationExpiry == null,
      ),
      if (isStudent) ...[
        fieldStillMissing(
          _extracted.flagFor('StudentNumber'),
          _studentNumber.text.trim().isEmpty,
        ),
        fieldStillMissing(
          _extracted.flagFor('Section'),
          _section.text.trim().isEmpty,
        ),
        fieldStillMissing(
          _extracted.flagFor('Semester'),
          _semester.text.trim().isEmpty,
        ),
      ],
    ];

    return checks.any((missing) => missing);
  }

  Future<void> _submit(bool isStudent) async {
    setState(() {
      _vehicleTypeError = _vehicleType == null ? 'Choose one.' : null;
      _colorError = _color == null ? 'Choose one.' : null;
    });
    if (_vehicleTypeError != null || _colorError != null) return;

    if (_hasUnresolvedFlags(isStudent)) {
      showAppMessage(
        context,
        'Fill in the fields marked in red before submitting.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.confirmDocuments({
        'verificationId': widget.result.verificationId,
        if (isStudent) 'studentNumber': _studentNumber.text.trim(),
        'studentName': _studentName.text.trim(),
        if (isStudent) 'section': _section.text.trim(),
        if (isStudent) 'semester': _semester.text.trim(),
        'licenseName': _licenseName.text.trim(),
        'licenseExpiry': _licenseExpiry?.toIso8601String(),
        // Echoed back exactly as read. The server compares it against its own
        // stored reading, so altering it here would be recorded as an edit
        // rather than quietly accepted.
        'plateNumber': _extracted.plateNumber,
        'registrationExpiry': _registrationExpiry?.toIso8601String(),
        'vehicleType': _vehicleType,
        'color': _color,
      });

      // The registration token is spent. It was only ever a pass through the
      // remaining steps, and holding it would leave the app in the state the
      // router now guards against: a token that is not a session, still naming
      // the document step it came from. Approval is what issues a real one, and
      // that arrives by signing in.
      await repo.clearToken();

      if (!mounted) return;

      // The photos have done their job. Holding them would mean a second pass
      // through the flow re-uploading this attempt's images.
      ref.read(registrationNotifierProvider.notifier).clearCaptured();

      await CelebrationDialog.show(
        context,
        title: "You're all set!",
        message: 'Registration submitted — your account is pending review.',
      );
      if (mounted) context.go('/login/sign-in');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// The "this will get you rejected" block, or nothing when there is nothing
  /// to say.
  ///
  /// Advisory only — the button stays live. An applicant whose licence really
  /// has expired cannot fix it by editing a field, and refusing the submission
  /// would leave them stuck on this screen with no way forward and no reviewer
  /// to appeal to. OCR also misreads dates, so a hard block would occasionally
  /// refuse a perfectly valid application over a misread digit.
  List<Widget> _preflightNotices() {
    final findings = registrationPreflight(
      licenseExpiry: _licenseExpiry,
      registrationExpiry: _registrationExpiry,
      documentName: _studentName.text,
      licenseName: _licenseName.text,
    );

    if (findings.isEmpty) return const [];

    return [
      const SizedBox(height: AppSpacing.sm),
      AppSectionHeader(
        title: 'Before you submit',
        subtitle: findings.any((f) => f.isBlocking)
            ? 'These are the things a reviewer usually rejects. Worth sorting '
                'out now rather than after the wait.'
            : 'Nothing here stops you submitting — just worth a look.',
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      ),
      for (final finding in findings) ...[
        AppNotice(message: finding.message, intent: finding.intent),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isStudent =
        ref.watch(registrationNotifierProvider.select((s) => s.affiliation)) ==
            Affiliation.student;
    final live = !_isSubmitting;

    return AppScreen(
      title: 'Check your details',
      body: ListView(
        padding: kScreenListPadding,
        children: [
          AppSectionHeader(
            title: 'Is this right?',
            subtitle: 'This is what we read from your documents. Fix anything '
                'that looks wrong — it goes to the admin exactly as you leave '
                'it.',
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          ),

          PlateVerdictCard(
            plate: _extracted.plateNumber,
            seenInPhoto: _extracted.platePhotoNumber,
            agreement: _extracted.plateAgreement,
            onRetakePhoto: live ? _retakePlatePhoto : null,
            onRetakeReceipt: live ? _retakeReceiptPhoto : null,
          ),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(
            title: 'Your vehicle',
            subtitle: 'Neither of these is printed on the receipt, so they are '
                'the only two things left to tell us.',
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
          ),
          AppChipGroup<String>(
            label: 'Type',
            options: _vehicleTypes,
            icons: _vehicleIcons,
            value: _vehicleType,
            enabled: live,
            errorText: _vehicleTypeError,
            onChanged: (value) => setState(() {
              _vehicleType = value;
              _vehicleTypeError = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          VehicleColorPicker(
            selected: _color,
            errorText: _colorError,
            onSelected: live
                ? (name) => setState(() {
                      _color = name;
                      _colorError = null;
                    })
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),

          if (isStudent) ...[
            const AppSectionHeader(title: 'From your registration form'),
            ScannedField(
              label: 'Student number',
              controller: _studentNumber,
              flag: _extracted.flagFor('StudentNumber'),
              enabled: live,
              textCapitalization: TextCapitalization.characters,
            ),
            ScannedField(
              label: 'Full name',
              controller: _studentName,
              flag: _extracted.flagFor('StudentName'),
              enabled: live,
            ),
            ScannedField(
              label: 'Section',
              controller: _section,
              flag: _extracted.flagFor('Section'),
              enabled: live,
              textCapitalization: TextCapitalization.characters,
            ),
            ScannedField(
              label: 'Term',
              controller: _semester,
              flag: _extracted.flagFor('Semester'),
              enabled: live,
            ),
          ] else ...[
            const AppSectionHeader(title: 'Your name'),
            ScannedField(
              label: 'Full name',
              controller: _studentName,
              flag: _extracted.flagFor('StudentName'),
              enabled: live,
            ),
          ],

          const AppSectionHeader(title: 'From your licence'),
          ScannedField(
            label: 'Name on licence',
            controller: _licenseName,
            flag: _extracted.flagFor('LicenseName'),
            enabled: live,
          ),
          ScannedDateField(
            label: 'Licence expiry',
            value: _licenseExpiry,
            flag: _extracted.flagFor('LicenseExpiry'),
            enabled: live,
            onChanged: (d) => setState(() => _licenseExpiry = d),
          ),

          const AppSectionHeader(title: 'From your receipt'),
          ScannedDateField(
            label: 'Registration expiry',
            value: _registrationExpiry,
            flag: _extracted.flagFor('RegistrationExpiry'),
            enabled: live,
            onChanged: (d) => setState(() => _registrationExpiry = d),
          ),

          // Sits immediately above the button rather than at the top of the
          // screen: these are read against the values as they finally stand, and
          // the last thing before submitting is where "are you sure" belongs.
          ..._preflightNotices(),

          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Submit registration',
            isLoading: _isSubmitting,
            onPressed: live ? () => _submit(isStudent) : null,
          ),
        ],
      ),
    );
  }
}
