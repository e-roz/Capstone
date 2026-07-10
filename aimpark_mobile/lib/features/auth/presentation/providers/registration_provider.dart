import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'registration_provider.g.dart';

class RegistrationState {
  const RegistrationState({
    this.registrationSessionId,
    this.email,
    this.isOAuthFlow = false,
    this.googleDisplayName,
  });

  final String? registrationSessionId;
  final String? email;

  /// True when the current registration was initiated via Google Sign-In.
  /// Used by [RegisterProfileScreen] to hide password fields and pre-fill name.
  final bool isOAuthFlow;

  /// The display name returned by Google, used to pre-fill the profile form.
  final String? googleDisplayName;

  RegistrationState copyWith({
    String? registrationSessionId,
    String? email,
    bool? isOAuthFlow,
    String? googleDisplayName,
    bool clearSession = false,
  }) {
    return RegistrationState(
      registrationSessionId:
          clearSession ? null : registrationSessionId ?? this.registrationSessionId,
      email: email ?? this.email,
      isOAuthFlow: isOAuthFlow ?? this.isOAuthFlow,
      googleDisplayName:
          clearSession ? null : googleDisplayName ?? this.googleDisplayName,
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

  void clearSession() {
    state = state.copyWith(clearSession: true, isOAuthFlow: false);
  }
}
