import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../notifications/presentation/providers/push_registration_provider.dart';
import '../../data/models/scan_result.dart';
import '../../data/registration_preflight.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import 'registration_submitted_screen.dart';
import '../widgets/registration_step_scaffold.dart';
import '../widgets/scanned_field.dart';

/// The last screen: what was read, plus the two things no document can say.
///
/// What the OCR read is locked, and changing it takes a confirmation. Both
/// readings are kept, so a reviewer can see where the person disagreed with the
/// machine. A value the server could not read after the allowed retakes is open
/// to type, and is shown to the reviewer as typed. The plate is no different:
/// there is no photograph of the physical plate to corroborate it, so a
/// correction here is shown to the reviewer the same way a corrected name is.
class RegisterConfirmScreen extends ConsumerStatefulWidget {
  const RegisterConfirmScreen({
    super.key,
    required this.result,
    this.confirmed = const {},
  });

  final ScanResult result;

  /// What the user already checked on each document's own sheet, by field
  /// name. Wins over [result]'s reading, which is the same text read again.
  final Map<String, String> confirmed;

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
  late final TextEditingController _licenseNumber;
  late final TextEditingController _plateNumber;
  late final TextEditingController _color;

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

  /// Whether the type came off the receipt. A read type is changed only after
  /// the same question every other read value asks.
  bool _vehicleTypeLocked = false;
  bool _isSubmitting = false;

  /// The type chip group is the only input here that a flushbar has to speak
  /// for — every other field, colour included, is now free text with the
  /// same "we couldn't read this" flag every other field already uses.
  String? _vehicleTypeError;

  ExtractedValues get _extracted => widget.result.extracted;

  bool get _isEBike => ref.read(registrationNotifierProvider).isEBike;

  /// The value the user checked for [field], or what the scan read.
  String? _start(String field, String? read) {
    final checked = widget.confirmed[field];
    return checked != null && checked.isNotEmpty ? checked : read;
  }

  DateTime? _startDate(String field, DateTime? read) {
    final checked = widget.confirmed[field];
    return (checked == null ? null : DateTime.tryParse(checked)) ?? read;
  }

  @override
  void initState() {
    super.initState();
    _studentNumber = TextEditingController(
      text: _start('StudentNumber', _extracted.studentNumber),
    );
    _studentName = TextEditingController(
      text: _start('StudentName', _extracted.studentName),
    );
    _section = TextEditingController(text: _start('Section', _extracted.section));
    _semester = TextEditingController(
      text: _start('Semester', _extracted.semester),
    );
    _licenseName = TextEditingController(
      text: _start('LicenseName', _extracted.licenseName),
    );
    _licenseNumber = TextEditingController(
      text: _start('LicenseNumber', _extracted.licenseNumber),
    );
    _plateNumber = TextEditingController(
      text: _start('PlateNumber', _extracted.plateNumber),
    );
    _color = TextEditingController(text: _start('Color', _extracted.color));
    _licenseExpiry = _startDate('LicenseExpiry', _extracted.licenseExpiry);
    _registrationExpiry = _startDate(
      'RegistrationExpiry',
      _extracted.registrationExpiry,
    );

    // Pre-filled from the receipt, same as every other field on this screen —
    // still a tap away from changing, never forced.
    _vehicleType = _vehicleTypes.containsKey(_extracted.vehicleType)
        ? _extracted.vehicleType
        : null;
    _vehicleTypeLocked = _vehicleType != null;

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
    _licenseNumber.dispose();
    _plateNumber.dispose();
    _color.dispose();
    super.dispose();
  }

  /// Whether a field the rules could not read is still exactly that: unread.
  ///
  /// [ScannedField] and [ScannedDateField] clear their own warning as soon as
  /// the user answers it, but nothing stopped them submitting with one still
  /// outstanding — the button never checked, only the eye did. This runs the
  /// same [fieldStillMissing] predicate over the fields that matter for this
  /// affiliation right before the request goes out.
  bool _hasUnresolvedFlags(bool isStudent, bool isEBike) {
    final checks = [
      // Only a student's form carries a name of its own; everyone else's
      // comes from the licence below.
      if (isStudent)
        fieldStillMissing(
          _extracted.flagFor('StudentName'),
          _studentName.text.trim().isEmpty,
        ),
      fieldStillMissing(
        _extracted.flagFor('LicenseName'),
        _licenseName.text.trim().isEmpty,
      ),
      fieldStillMissing(
        _extracted.flagFor('LicenseNumber'),
        _licenseNumber.text.trim().isEmpty,
      ),
      fieldStillMissing(
        _extracted.flagFor('LicenseExpiry'),
        _licenseExpiry == null,
      ),
      // An e-bike has no receipt, so none of the receipt's fields exist.
      if (!isEBike) ...[
        fieldStillMissing(
          _extracted.flagFor('RegistrationExpiry'),
          _registrationExpiry == null,
        ),
        fieldStillMissing(
          _extracted.flagFor('PlateNumber'),
          _plateNumber.text.trim().isEmpty,
        ),
        fieldStillMissing(
          _extracted.flagFor('Color'),
          _color.text.trim().isEmpty,
        ),
      ],
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

  Future<void> _chooseVehicleType(String value) async {
    if (value == _vehicleType) return;

    if (_vehicleTypeLocked) {
      if (!await confirmEditingReadValue(context, 'vehicle type')) return;
      if (!mounted) return;
    }

    setState(() {
      _vehicleType = value;
      _vehicleTypeLocked = false;
      _vehicleTypeError = null;
    });
  }

  Future<void> _submit(bool isStudent, bool isEBike) async {
    // An e-bike's type is decided by the admin who inspects it.
    setState(() {
      _vehicleTypeError = !isEBike && _vehicleType == null ? 'Choose one.' : null;
    });
    if (_vehicleTypeError != null) return;

    if (_hasUnresolvedFlags(isStudent, isEBike)) {
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
      final response = await repo.confirmDocuments({
        'verificationId': widget.result.verificationId,
        if (isStudent) 'studentNumber': _studentNumber.text.trim(),
        if (isStudent) 'studentName': _studentName.text.trim(),
        if (isStudent) 'section': _section.text.trim(),
        if (isStudent) 'semester': _semester.text.trim(),
        'licenseName': _licenseName.text.trim(),
        'licenseNumber': _licenseNumber.text.trim(),
        'licenseExpiry': _licenseExpiry?.toIso8601String(),
        if (isEBike)
          'isEBike': true
        else ...{
          'plateNumber': _plateNumber.text.trim(),
          'registrationExpiry': _registrationExpiry?.toIso8601String(),
          'vehicleType': _vehicleType,
          'color': _color.text.trim(),
        },
      });

      // The server approves a clean application on the spot. Everything else
      // still waits for a reviewer, so this is read rather than assumed.
      final data = response.data;
      final approved = data is Map && data['approved'] == true;

      // Last use of the registration token: point this phone at the new
      // account so the review decision can reach it as a push.
      await ref
          .read(pushRegistrationProvider.notifier)
          .registerForPendingAccount();

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

      // A receipt screen rather than a dialog. The dialog said "You're all
      // set!", which was not true — nothing is set up until a reviewer
      // approves it — and it vanished on tap, leaving no record of what had
      // just been sent after a five-minute flow.
      //
      // The back stack is cleared on that screen's own way out rather than
      // here, so a user who backgrounds the app on the receipt still finds it
      // when they return.
      context.go(
        '/register/submitted',
        extra: RegistrationSummary(
          // The licence is the one source of the account's name.
          name: _licenseName.text.trim().isEmpty
              ? _studentName.text.trim()
              : _licenseName.text.trim(),
          email: ref.read(registrationNotifierProvider).email,
          affiliation: ref.read(registrationNotifierProvider).affiliation.label,
          plateNumber: isEBike ? null : _plateNumber.text.trim(),
          isEBike: isEBike,
          approved: approved,
        ),
      );
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
      registrationExpiry: _isEBike ? null : _registrationExpiry,
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
    final isEBike =
        ref.watch(registrationNotifierProvider.select((s) => s.isEBike));
    final live = !_isSubmitting;

    return RegistrationStepScaffold(
      step: 5,
      title: 'Check your details',
      busy: _isSubmitting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppNotice(
            title: 'Is this right?',
            message:
                'A lock means we read it from your document. If something '
                'looks wrong, tap it to change it. The admin will see '
                'anything you change.',
            intent: StatusIntent.info,
          ),
          const SizedBox(height: AppSpacing.lg),

          if (isEBike) ...[
            const AppNotice(
              title: 'One more step after this',
              message:
                  'Your e-bike has no plate or receipt, so an admin has to see '
                  'it in person. After you submit, bring your e-bike and your '
                  'documents to the admin office within 7 days.',
              intent: StatusIntent.warning,
            ),
            const SizedBox(height: AppSpacing.lg),
          ] else ...[
            AppSectionHeader(
              title: 'Your vehicle',
              subtitle:
                  'Read from your receipt — check they match before you '
                  'submit.',
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
            ),
            AppChipGroup<String>(
              label: 'Type',
              options: _vehicleTypes,
              icons: _vehicleIcons,
              value: _vehicleType,
              enabled: live,
              errorText: _vehicleTypeError,
              onChanged: _chooseVehicleType,
            ),
            const SizedBox(height: AppSpacing.md),
            ScannedField(
              label: 'Colour',
              controller: _color,
              flag: _extracted.flagFor('Color'),
              enabled: live,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

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
          ],

          // The name on the licence becomes the account's name, for everyone.
          const AppSectionHeader(title: 'From your licence'),
          ScannedField(
            label: 'Name on licence',
            controller: _licenseName,
            flag: _extracted.flagFor('LicenseName'),
            enabled: live,
          ),
          ScannedField(
            label: 'Licence number',
            controller: _licenseNumber,
            flag: _extracted.flagFor('LicenseNumber'),
            enabled: live,
            textCapitalization: TextCapitalization.characters,
          ),
          ScannedDateField(
            label: 'Licence expiry',
            value: _licenseExpiry,
            flag: _extracted.flagFor('LicenseExpiry'),
            enabled: live,
            onChanged: (d) => setState(() => _licenseExpiry = d),
          ),

          if (!isEBike) ...[
            const AppSectionHeader(title: 'From your receipt'),
            ScannedField(
              label: 'Plate number',
              controller: _plateNumber,
              flag: _extracted.flagFor('PlateNumber'),
              enabled: live,
              textCapitalization: TextCapitalization.characters,
            ),
            ScannedDateField(
              label: 'Registration expiry',
              value: _registrationExpiry,
              flag: _extracted.flagFor('RegistrationExpiry'),
              enabled: live,
              onChanged: (d) => setState(() => _registrationExpiry = d),
            ),
          ],

          // Sits immediately above the button rather than at the top of the
          // screen: these are read against the values as they finally stand, and
          // the last thing before submitting is where "are you sure" belongs.
          ..._preflightNotices(),

          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Submit registration',
            isLoading: _isSubmitting,
            onPressed: live ? () => _submit(isStudent, isEBike) : null,
          ),
        ],
      ),
    );
  }
}
