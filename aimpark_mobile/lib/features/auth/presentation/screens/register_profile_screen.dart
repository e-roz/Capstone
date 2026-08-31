import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/jwt_utils.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../router/registration_back_stack.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import '../widgets/registration_step_scaffold.dart';
import 'terms_screen.dart';

class RegisterProfileScreen extends ConsumerStatefulWidget {
  const RegisterProfileScreen({super.key});

  @override
  ConsumerState<RegisterProfileScreen> createState() =>
      _RegisterProfileScreenState();
}

class _RegisterProfileScreenState extends ConsumerState<RegisterProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _initialized = false;
  bool _acceptedTerms = false;
  Affiliation _affiliation = Affiliation.student;

  /// True when this step is being revisited from the document step rather than
  /// reached on the way to it — the account already exists, and this form now
  /// edits it instead of creating it.
  ///
  /// Read from the stored token rather than passed in: the app can be relaunched
  /// straight onto this route, and a flag handed over by the previous screen
  /// would be gone by then.
  bool _isRevisit = false;

  /// True while the saved name and affiliation are being fetched.
  bool _isPreparing = true;

  /// One message per field, so each problem is stated where it can be fixed.
  ///
  /// The screen used to raise the first failure it found in a bar across the
  /// top: a form with an empty surname, a short password and unread terms told
  /// the user about the surname, waited for them to fix it and submit again,
  /// then told them about the password. Three round trips to learn what one
  /// glance could have said.
  String? _firstNameError;
  String? _lastNameError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _termsError;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  /// Works out whether this is a first pass or a revisit, and fills the form
  /// from the server in the second case.
  ///
  /// The values have to come from the server: completing the profile clears the
  /// local draft's session, and an app relaunched mid-registration never held
  /// the name at all. A revisit that could not read them would present an empty
  /// form whose Save would overwrite a good name with nothing, so a failed read
  /// returns to the document step instead of showing the form.
  Future<void> _prepare() async {
    final repo = ref.read(authRepositoryProvider);
    final token = await repo.getToken();

    final revisit = token != null &&
        JwtUtils.isValid(token) &&
        JwtUtils.isRegistrationOnly(token) &&
        JwtUtils.getRegistrationStep(token) == 'DocumentUpload';

    if (!revisit) {
      if (mounted) setState(() => _isPreparing = false);
      return;
    }

    try {
      final response = await repo.registrationStatus();
      final data = response.data as Map<String, dynamic>;

      final fullName = data['fullName']?.toString().trim() ?? '';
      final parts = fullName.split(' ')..removeWhere((p) => p.isEmpty);

      if (!mounted) return;
      setState(() {
        _isRevisit = true;
        _isPreparing = false;
        _initialized = true;
        if (parts.isNotEmpty) {
          _firstNameController.text = parts.first;
          _lastNameController.text = parts.sublist(1).join(' ');
        }
        _affiliation = Affiliation.fromWire(data['affiliation']?.toString()) ??
            ref.read(registrationNotifierProvider).affiliation;
        // Accepted once already, and the server has the timestamp. Shown ticked
        // rather than hidden so the link to read them again stays where it was.
        _acceptedTerms = true;
      });
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
      context.jumpRegistrationStep('/register/documents/0');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Pre-fill name fields from Google display name on first render.
  void _maybeInitFromOAuth(RegistrationState regState) {
    if (_initialized) return;
    _initialized = true;
    if (regState.isOAuthFlow && regState.googleDisplayName != null) {
      final parts = regState.googleDisplayName!.trim().split(' ');
      _firstNameController.text = parts.first;
      if (parts.length > 1) {
        _lastNameController.text = parts.sublist(1).join(' ');
      }
    }
  }

  /// Checks every field and reports all of them at once.
  ///
  /// [noPassword] covers both cases where there is no password on this form: a
  /// Google account never sets one, and a revisit is editing an account whose
  /// password is already set and is not changed here.
  bool _validate(bool noPassword) {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _firstNameError = firstName.isEmpty ? 'Enter your first name.' : null;
      _lastNameError = lastName.isEmpty ? 'Enter your last name.' : null;

      _passwordError = noPassword
          ? null
          : password.length < 8
              ? 'Use at least 8 characters.'
              : null;

      // Only worth raising once the password itself is acceptable — telling
      // someone their confirmation does not match a password that is too short
      // anyway sends them to fix the wrong field.
      _confirmPasswordError = noPassword || password.length < 8
          ? null
          : password != confirmPassword
              ? 'This does not match the password above.'
              : null;

      // The server rejects this too — checked here so the user is told before
      // filling in a form and losing it to a 400.
      _termsError =
          _acceptedTerms ? null : 'Accept the Terms & Conditions to continue.';
    });

    return _firstNameError == null &&
        _lastNameError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _termsError == null;
  }

  Future<void> _submit(bool noPassword) async {
    if (!_validate(noPassword)) return;

    setState(() => _isLoading = true);

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      final body = <String, dynamic>{
        'fullName': '$firstName $lastName',
        'acceptedTerms': _acceptedTerms,
        'affiliation': _affiliation.wireName,
      };
      if (!noPassword) {
        body['password'] = _passwordController.text;
      }

      ref.read(registrationNotifierProvider.notifier).setAffiliation(_affiliation);

      final repo = ref.read(authRepositoryProvider);
      final response = await repo.completeProfile(body);
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String?;

      if (token == null || token.isEmpty) {
        throw Exception('No authentication token returned.');
      }

      // A fresh registration-only token either way. On a revisit it says the
      // same step it already said, and is stored for the same reason: it is the
      // one the next request will be made with.
      await repo.saveToken(token);
      await repo.clearSessionToken();
      ref.read(registrationNotifierProvider.notifier).clearSession();

      if (mounted) {
        context.goRegistrationStep('/register/documents/0');
      }
    } catch (e) {
      if (mounted) {
        showApiError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to show until it is known whether this form creates an account or
    // edits one — the two differ by a heading, two password fields and where
    // back goes, and flashing the wrong one first is worse than a short wait.
    // Matches the document step's own loading frame, back arrow included: there
    // is nothing to go back to until the answer lands.
    if (_isPreparing) {
      return const RegistrationStepScaffold(
        step: 3,
        title: 'Your Profile',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final regState = ref.watch(registrationNotifierProvider);
    final isOAuth = regState.isOAuthFlow;
    final noPassword = isOAuth || _isRevisit;

    // Pre-fill on first build when coming from Google sign-in
    _maybeInitFromOAuth(regState);

    return RegistrationStepScaffold(
      step: 3,
      title: 'Your Profile',
      // Back is left to the flow's history, which knows which of the two ways
      // in was taken. Naming a destination here is what broke it: a revisit was
      // sent back to the documents it had just come from, so back moved
      // forwards and the steps before this one became unreachable.
      busy: _isLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RegistrationStepHeading(
            title: _isRevisit ? 'Edit your profile' : 'Complete your profile',
            subtitle: _isRevisit
                ? 'Changing what you are here changes which documents we ask '
                    'for on the next screen.'
                : null,
          ),
          AppTextField(
            label: 'First Name',
            controller: _firstNameController,
            enabled: !_isLoading,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            errorText: _firstNameError,
            onChanged: (_) {
              if (_firstNameError != null) {
                setState(() => _firstNameError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Last Name',
            controller: _lastNameController,
            enabled: !_isLoading,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
            errorText: _lastNameError,
            onChanged: (_) {
              if (_lastNameError != null) {
                setState(() => _lastNameError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          // Decides which document proves affiliation at the upload step: a
          // registration form for students, a school ID for everyone else.
          AppChipGroup<Affiliation>(
            label: 'I am a…',
            options: {
              for (final option in Affiliation.values) option: option.label,
            },
            value: _affiliation,
            enabled: !_isLoading,
            onChanged: (value) => setState(() => _affiliation = value),
          ),
          // Password fields: only on a first pass, and only for a local
          // (non-OAuth) registration. A revisit is not where a password gets
          // changed — the server ignores one sent here, and offering the field
          // would promise something it does not do.
          if (!noPassword) ...[
            const SizedBox(height: AppSpacing.md),
            AppPasswordField(
              label: 'Password',
              controller: _passwordController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              helperText: 'At least 8 characters.',
              errorText: _passwordError,
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppPasswordField(
              label: 'Confirm Password',
              controller: _confirmPasswordController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _confirmPasswordError,
              onChanged: (_) {
                if (_confirmPasswordError != null) {
                  setState(() => _confirmPasswordError = null);
                }
              },
              onSubmitted: (_) => _isLoading ? null : _submit(false),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _TermsCheckbox(
            value: _acceptedTerms,
            errorText: _termsError,
            onChanged: (v) => setState(() {
              _acceptedTerms = v;
              if (v) _termsError = null;
            }),
            onReadTerms: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _isRevisit ? 'Save changes' : 'Continue',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : () => _submit(noPassword),
          ),
        ],
      ),
    );
  }
}

/// The terms agreement. A checkbox rather than an "I agree" button, because the
/// server records `TermsAcceptedAt` against a deliberate act and the link to
/// read them has to sit right next to it.
class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    required this.onReadTerms,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onReadTerms;

  /// Shown under the sentence, in the same red as a field error.
  ///
  /// Unread terms are the one requirement on this form with nothing to type,
  /// so a bar at the top of the screen was the only thing that ever pointed at
  /// them — and it pointed from the far end of the form.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sized down and de-padded so the checkbox sits level with the first
        // line of text rather than floating above it.
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            isError: errorText != null,
            onChanged: (v) => onChanged(v ?? false),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Tapping the words toggles the box too — a 24px target is the
                // smallest thing on the screen and the sentence beside it is
                // what people actually aim at.
                GestureDetector(
                  onTap: () => onChanged(!value),
                  child: Text('I agree to the ', style: context.text.bodySmall),
                ),
                GestureDetector(
                  onTap: onReadTerms,
                  child: Text(
                    'Terms & Conditions',
                    style: context.text.bodySmall?.copyWith(
                      color: t.brand.subtleText,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: t.brand.subtleText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (errorText == null) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        const SizedBox(height: AppSpacing.xs),
        Text(
          errorText!,
          style: context.text.labelSmall?.copyWith(color: t.status.danger.fg),
        ),
      ],
    );
  }
}
