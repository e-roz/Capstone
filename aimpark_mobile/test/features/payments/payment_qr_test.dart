import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:aimpark_mobile/core/theme/theme.dart';
import 'package:aimpark_mobile/features/payments/data/models/payment.dart';
import 'package:aimpark_mobile/features/payments/data/payments_repository.dart';
import 'package:aimpark_mobile/features/payments/presentation/providers/payments_provider.dart';
import 'package:aimpark_mobile/features/payments/presentation/screens/payment_detail_screen.dart';

const _checkoutUrl = 'https://api.example/api/payments/simulated/sim_abc';

/// Stands in for the server: a bill that is Pending, becomes Processing when a
/// checkout is opened, and Paid when the test says the payer scanned and paid.
class _FakePaymentsRepository extends PaymentsRepository {
  _FakePaymentsRepository() : super(Dio());

  String status = 'Pending';
  int checkoutsOpened = 0;

  Payment get _payment => Payment.fromJson({
    'paymentId': 'p1',
    'source': 'ViolationPenalty',
    'durationMinutes': 0,
    'ratePerHourApplied': 0,
    'amountDue': 20,
    'status': status,
    'createdAt': '2026-10-08T00:00:00Z',
    'dueAt': '2026-10-22T00:00:00Z',
    // What the real server sets the moment a payment lands.
    'paidAt': status == 'Paid' ? '2026-10-09T00:00:00Z' : null,
    'provider': status == 'Pending' ? null : 'Simulated',
  });

  @override
  Future<Payment> getDetail(String paymentId) async => _payment;

  @override
  Future<Checkout> startCheckout(String paymentId) async {
    checkoutsOpened++;
    status = 'Processing';
    return const Checkout(
      paymentId: 'p1',
      checkoutUrl: _checkoutUrl,
      provider: 'Simulated',
      amountDue: 20,
    );
  }
}

Future<void> _open(WidgetTester tester, _FakePaymentsRepository repo) async {
  // Tall enough that the buttons under the bill's facts are on screen; a tap on
  // something scrolled out of view lands on nothing.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [paymentsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PaymentDetailScreen(paymentId: 'p1'),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('a pending bill offers the QR code beside the normal Pay button', (
    tester,
  ) async {
    final repo = _FakePaymentsRepository();
    await _open(tester, repo);

    expect(find.text('Pay with QR code'), findsOneWidget);
    expect(find.textContaining('Pay ₱'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('choosing it draws the checkout address as a QR code', (
    tester,
  ) async {
    final repo = _FakePaymentsRepository();
    await _open(tester, repo);

    await tester.tap(find.text('Pay with QR code'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey(_checkoutUrl)), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(repo.checkoutsOpened, 1);
    // The bill says so, so nobody backs out and pays it twice.
    expect(find.text('Processing'), findsOneWidget);

    // Leave no timer running behind the test.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the code goes away by itself once the bill is paid', (
    tester,
  ) async {
    final repo = _FakePaymentsRepository();
    await _open(tester, repo);

    await tester.tap(find.text('Pay with QR code'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(QrImageView), findsOneWidget);

    // The payer scans on another phone and pays; this one is never touched.
    repo.status = 'Paid';
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(QrImageView), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
