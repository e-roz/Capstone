import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aimpark_mobile/core/camera/capture_spec.dart';
import 'package:aimpark_mobile/core/camera/document_review_screen.dart';
import 'package:aimpark_mobile/core/ocr/document_check.dart';
import 'package:aimpark_mobile/core/ocr/document_scanner.dart';
import 'package:aimpark_mobile/core/theme/theme.dart';

const _spec = CaptureSpec(
  label: "Driver's licence",
  instruction: 'Keep the whole card in the frame.',
  aspectRatio: 1.58,
);

Future<void> _open(
  WidgetTester tester, {
  required bool retakesSpent,
  DocumentIssue? issue,
}) async {
  // The photo is never opened: a path that does not exist stays "loading" under
  // the test clock, which is all this screen's buttons need.
  final photo = CapturedDocument(
    file: File('does-not-exist.jpg'),
    payload: null,
    issue: issue,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: DocumentReviewScreen(
        photo: photo,
        spec: _spec,
        retakesSpent: retakesSpent,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('offers Retake while tries remain', (tester) async {
    await _open(tester, retakesSpent: false, issue: DocumentIssue.blurry);

    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Use this photo'), findsOneWidget);
  });

  testWidgets('has no Retake once the tries are spent', (tester) async {
    await _open(tester, retakesSpent: true, issue: DocumentIssue.blurry);

    // Otherwise a document could be retaken round and round from this screen,
    // and the three-try limit would never be reached.
    expect(find.text('Retake'), findsNothing);
    expect(find.text('Use this photo'), findsOneWidget);
    expect(find.textContaining('That was your last try'), findsOneWidget);
  });

  testWidgets('a photo that reads well with no tries left just continues', (
    tester,
  ) async {
    await _open(tester, retakesSpent: true);

    expect(find.text('Retake'), findsNothing);
    expect(find.text('Use this photo'), findsOneWidget);
    expect(find.textContaining('could read this one'), findsOneWidget);
  });
}
