import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'registration_provider.g.dart';

class RegistrationState {
  const RegistrationState({
    this.registrationSessionId,
    this.email,
  });

  final String? registrationSessionId;
  final String? email;

  RegistrationState copyWith({
    String? registrationSessionId,
    String? email,
    bool clearSession = false,
  }) {
    return RegistrationState(
      registrationSessionId:
          clearSession ? null : registrationSessionId ?? this.registrationSessionId,
      email: email ?? this.email,
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

  void clearSession() {
    state = state.copyWith(clearSession: true);
  }
}
