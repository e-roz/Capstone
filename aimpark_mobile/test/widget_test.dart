import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aimpark_mobile/main.dart';

void main() {
  testWidgets('App starts on login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AimParkApp()));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
  });
}
