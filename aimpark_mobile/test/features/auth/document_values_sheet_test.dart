import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aimpark_mobile/core/theme/theme.dart';
import 'package:aimpark_mobile/features/auth/data/models/document_spec.dart';
import 'package:aimpark_mobile/features/auth/data/models/scan_result.dart';
import 'package:aimpark_mobile/features/auth/presentation/widgets/document_values_sheet.dart';

const _plateQuestion = 'Does your official receipt really have no plate number?';
const _yes = 'Yes, it has no plate number';

/// A receipt read back without a plate number: expiry and colour read, plate not.
DocumentReadResult _receiptWithoutPlate() => DocumentReadResult.fromJson({
  'documentType': 'OfficialReceipt',
  'diagnosis': {
    'documentType': 'OfficialReceipt',
    'reason': 'MissingFields',
    'message':
        "We couldn't read your plate number on the official receipt. "
        'Photograph it again, flat and in good light.',
  },
  'missingFields': ['plate number'],
  'extracted': {
    'registrationExpiry': '2027-05-31T00:00:00Z',
    'vehicleType': 'Motorcycle',
    'color': 'RED',
    'fieldsToCheck': [
      {'field': 'PlateNumber', 'reason': 'NotFound'},
    ],
  },
  'expiry': {
    'field': 'RegistrationExpiry',
    'date': '2027-05-31T00:00:00Z',
    'isExpired': false,
    'isCalculated': false,
    'blocks': false,
  },
});

/// The same receipt once the applicant has said it has no plate: nothing missing.
DocumentReadResult _receiptNoPlateAccepted() => DocumentReadResult.fromJson({
  'documentType': 'OfficialReceipt',
  'missingFields': <String>[],
  'extracted': {
    'registrationExpiry': '2027-05-31T00:00:00Z',
    'vehicleType': 'Motorcycle',
    'color': 'RED',
  },
  'expiry': {
    'field': 'RegistrationExpiry',
    'date': '2027-05-31T00:00:00Z',
    'isExpired': false,
    'isCalculated': false,
    'blocks': false,
  },
});

/// What the user decided, once they have.
class _Decision {
  DocumentSheetOutcome? outcome;
  bool decided = false;
}

/// Opens the sheet from a button, the way the document step does, and returns a
/// holder for whatever the user decides.
Future<_Decision> _openSheet(
  WidgetTester tester, {
  required DocumentReadResult result,
  required int attempt,
  bool noPlate = false,
}) async {
  final decision = _Decision();

  // Tall enough that nothing is scrolled out of reach of a tap.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                decision.outcome = await DocumentValuesSheet.show(
                  context,
                  spec: DocumentSpec.officialReceipt,
                  result: result,
                  attempt: attempt,
                  maxAttempts: 3,
                  noPlate: noPlate,
                );
                decision.decided = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return decision;
}

void main() {
  testWidgets('asks whether the receipt really has no plate before a retake', (
    tester,
  ) async {
    await _openSheet(tester, result: _receiptWithoutPlate(), attempt: 1);

    expect(find.text(_plateQuestion), findsOneWidget);
    expect(find.text(_yes), findsOneWidget);
    expect(find.textContaining('No, it has one. Take it again'), findsOneWidget);
  });

  testWidgets('"Yes" comes back as the no-plate answer and confirms nothing', (
    tester,
  ) async {
    final decision = await _openSheet(
      tester,
      result: _receiptWithoutPlate(),
      attempt: 1,
    );

    await tester.tap(find.text(_yes));
    await tester.pumpAndSettle();

    expect(decision.decided, isTrue);
    expect(decision.outcome!.isNoPlate, isTrue);
    expect(decision.outcome!.isRetake, isFalse);
    expect(decision.outcome!.values, isNull);
  });

  testWidgets('"No, it has one" is an ordinary retake, not a no-plate answer', (
    tester,
  ) async {
    final decision = await _openSheet(
      tester,
      result: _receiptWithoutPlate(),
      attempt: 1,
    );

    await tester.tap(find.textContaining('No, it has one. Take it again'));
    await tester.pumpAndSettle();

    expect(decision.decided, isTrue);
    expect(decision.outcome!.isRetake, isTrue);
    expect(decision.outcome!.isNoPlate, isFalse);
  });

  testWidgets('a receipt that is missing something else gets no plate question', (
    tester,
  ) async {
    final result = DocumentReadResult.fromJson({
      'documentType': 'OfficialReceipt',
      'diagnosis': {
        'documentType': 'OfficialReceipt',
        'reason': 'MissingFields',
        'message': "We couldn't read your colour on the official receipt.",
      },
      'missingFields': ['colour'],
      'extracted': {'plateNumber': '705TEY'},
    });

    await _openSheet(tester, result: result, attempt: 1);

    expect(find.text(_plateQuestion), findsNothing);
    expect(find.textContaining('Take it again'), findsOneWidget);
  });

  testWidgets('once the tries are spent the plate can be typed, or declared absent', (
    tester,
  ) async {
    await _openSheet(tester, result: _receiptWithoutPlate(), attempt: 3);

    // No retake question: typing is the way on, and the same answer stays
    // available as a quiet link rather than a second question.
    expect(find.text(_plateQuestion), findsNothing);
    expect(find.text('Plate number'), findsOneWidget);
    expect(find.text('My receipt has no plate number'), findsOneWidget);
  });

  testWidgets('the quiet link gives the same no-plate answer', (tester) async {
    final decision = await _openSheet(
      tester,
      result: _receiptWithoutPlate(),
      attempt: 3,
    );

    await tester.tap(find.text('My receipt has no plate number'));
    await tester.pumpAndSettle();

    expect(decision.outcome!.isNoPlate, isTrue);
  });

  testWidgets('with no plate declared, no plate number is asked for', (
    tester,
  ) async {
    await _openSheet(
      tester,
      result: _receiptNoPlateAccepted(),
      attempt: 1,
      noPlate: true,
    );

    expect(find.text('Plate number'), findsNothing);
    expect(find.text('No plate number'), findsOneWidget);
    expect(find.text('Registration expiry'), findsOneWidget);
    expect(find.text('Colour'), findsOneWidget);
    expect(find.text('This is correct'), findsOneWidget);
  });
}
