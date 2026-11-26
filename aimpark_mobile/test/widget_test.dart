import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aimpark_mobile/main.dart';

void main() {
  testWidgets('With no saved session the app opens on the welcome screen', (
    WidgetTester tester,
  ) async {
    // A common Android phone (411×914), not the test's default 800×600
    // landscape window.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    // Nobody signed in: no token on the device.
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: AimParkApp()));

    // The splash stays up for at least 1.7 s and its loader spins forever, so
    // step the clock past it instead of waiting for the app to settle.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
