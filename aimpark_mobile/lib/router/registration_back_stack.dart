import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A screen the user has already been on, and what it was shown with.
class VisitedStep {
  const VisitedStep(this.location, this.extra);

  /// The route, index and all: `/register/documents/2`.
  final String location;

  /// Whatever was handed to that route the first time round — the address the
  /// OTP screen names, the retake wording a document screen shows. Kept so a
  /// step returned to looks like the step that was left.
  final Object? extra;
}

/// Where the user has actually been in the registration flow.
///
/// Every step is entered with `go`, which replaces the route rather than
/// stacking it, so there is no Navigator history to pop and each screen had to
/// name its own way back by hand. Those names were guesses about how the user
/// had arrived, and the profile step's guess was wrong in the one case that
/// matters: reached by going back from the documents, its back arrow pointed
/// forward at the documents again. Back from step 4 went to step 3, and back
/// from step 3 went to step 4 — the flow bounced between the two and the steps
/// before them could not be reached at all.
///
/// So the path is recorded as it is walked instead of being guessed at. Back is
/// the reverse of however the user actually got here, all the way out to the
/// welcome screen.
class RegistrationBackStack {
  /// Longer than any sensible path through five steps, and a ceiling rather
  /// than a limit anyone should reach: a user who wanders between the profile
  /// and their documents for an afternoon walks back out through their own
  /// footsteps, and the oldest of them drop off the bottom rather than growing
  /// without end.
  static const _limit = 64;

  final _visited = <VisitedStep>[];

  bool get isEmpty => _visited.isEmpty;

  void record(String location, {Object? extra}) {
    _visited.add(VisitedStep(location, extra));
    if (_visited.length > _limit) _visited.removeAt(0);
  }

  /// The last screen visited, removed from the history as it is handed back —
  /// going back does not itself become somewhere to go back to.
  VisitedStep? takeLast() => _visited.isEmpty ? null : _visited.removeLast();

  void clear() => _visited.clear();
}

/// The one history the registration flow keeps.
///
/// Deliberately not a provider: the Dio client reaches for it from an error
/// interceptor that has a router and no `ref`, and nothing rebuilds when it
/// changes — it is read at the moment a back arrow is pressed and at no other
/// time.
final registrationBackStack = RegistrationBackStack();

extension RegistrationNavigation on BuildContext {
  /// Moves on to [location], remembering the screen being left.
  void goRegistrationStep(String location, {Object? extra}) {
    final current = GoRouter.of(this).routerDelegate.currentConfiguration;
    registrationBackStack.record(
      current.uri.toString(),
      extra: current.extra,
    );
    go(location, extra: extra);
  }

  /// Enters the flow at [location], forgetting any earlier attempt.
  ///
  /// The screen this is called from — the welcome screen, the sign-in form — is
  /// recorded, so the first step of a fresh registration goes back to where the
  /// user chose to start it.
  void startRegistration(String location, {Object? extra}) {
    registrationBackStack.clear();
    goRegistrationStep(location, extra: extra);
  }

  /// Corrects the current step to [location] without recording the one being
  /// left.
  ///
  /// For the screens nobody chose to be on: a route naming a document this pass
  /// does not want, a step abandoned because the server said it could not be
  /// loaded. Recording those would put a screen the user was moved off into the
  /// history and send them back to it.
  void jumpRegistrationStep(String location, {Object? extra}) {
    go(location, extra: extra);
  }

  /// Back to the screen the user came from.
  ///
  /// With nothing recorded — a registration resumed on a fresh launch, which
  /// opens straight onto the step the account is up to — back leaves for the
  /// welcome screen. Nothing is lost by it: the photographs are on disk and the
  /// token names the step, so signing in again returns to exactly here.
  void registrationBack() {
    final previous = registrationBackStack.takeLast();
    if (previous == null) {
      go('/login');
      return;
    }
    go(previous.location, extra: previous.extra);
  }
}
