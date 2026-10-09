import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../violations/presentation/providers/violations_provider.dart';
import '../../data/models/payment.dart';
import '../providers/payments_provider.dart';

class PaymentDetailScreen extends ConsumerStatefulWidget {
  const PaymentDetailScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  ConsumerState<PaymentDetailScreen> createState() =>
      _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends ConsumerState<PaymentDetailScreen>
    with WidgetsBindingObserver {
  /// A checkout is being opened, or the browser is being launched.
  bool _isStarting = false;

  /// Asking the server whether the money landed.
  bool _isChecking = false;

  /// The payer was sent to the provider during this visit to the screen.
  ///
  /// Only used to decide whether to celebrate. Coming back to a bill that was
  /// already paid yesterday should not throw confetti.
  bool _sentToProvider = false;

  /// The checkout being shown as a QR code, if the payer chose that route.
  ///
  /// Only the newest one is worth showing: opening another replaces it on the
  /// server, and the old code stops working there too.
  Checkout? _qr;

  /// Quietly asks whether a QR checkout has been paid.
  ///
  /// The payer is scanning with another phone, so this one never leaves the
  /// foreground — the "came back from the browser" check on resume never fires,
  /// and without this the bill would sit on "waiting" after it was paid.
  Timer? _qrPoll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _qrPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the provider's page is the moment to ask what happened.
  ///
  /// The app is not told anything by the payment itself — the provider reports
  /// to the server, not to the phone. What the phone knows is that it was in
  /// the background and now it is not, which is exactly when the answer is
  /// worth asking for.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final payment = ref
        .read(paymentDetailProvider(widget.paymentId))
        .valueOrNull;
    if (payment == null || payment.isPaid) return;
    if (!_sentToProvider && !payment.isProcessing) return;

    unawaited(_checkForSettlement());
  }

  /// Opens a fresh checkout and hands it to [deliver] — the browser, or a QR
  /// code — then makes the screen say the bill is Processing.
  Future<void> _startCheckout(
    Future<void> Function(Checkout checkout) deliver,
  ) async {
    setState(() => _isStarting = true);
    try {
      final checkout = await ref
          .read(paymentsRepositoryProvider)
          .startCheckout(widget.paymentId);

      await deliver(checkout);

      _sentToProvider = true;

      // The bill is Processing from the moment the checkout opens, and this
      // screen has to say so — otherwise someone who backs out of GCash returns
      // to a Pay button and pays twice.
      ref.invalidate(paymentDetailProvider(widget.paymentId));
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _pay() => _startCheckout((checkout) async {
    // A browser checkout replaces any QR: the server only honours the newest
    // one, so leaving the old code up would show a code that no longer works.
    _stopQr();

    final opened = await launchUrl(
      Uri.parse(checkout.checkoutUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw Exception('Could not open the payment page.');
    }
  });

  Future<void> _showQr() => _startCheckout((checkout) async {
    if (!mounted) return;
    setState(() => _qr = checkout);
    _startQrPolling();
  });

  void _stopQr() {
    _qrPoll?.cancel();
    _qrPoll = null;
    if (_qr != null && mounted) setState(() => _qr = null);
  }

  void _startQrPolling() {
    _qrPoll?.cancel();
    _qrPoll = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || _isChecking) return;

      try {
        // Straight to the repository rather than invalidating the provider:
        // refreshing the screen every few seconds would flash it for nothing
        // while nothing has changed.
        final payment = await ref
            .read(paymentsRepositoryProvider)
            .getDetail(widget.paymentId);

        if (!mounted || !payment.isPaid) return;

        _stopQr();
        ref.invalidate(paymentDetailProvider(widget.paymentId));
        _onSettled(payment);
      } catch (_) {
        // A missed check costs nothing; the next one is four seconds away.
      }
    });
  }

  /// Asks the server whether the settlement has arrived yet.
  ///
  /// Tried a few times rather than once. The provider's callback and the payer
  /// pressing "back to the app" are two different journeys, and on a slow
  /// connection the second one wins by a second or two — a single check would
  /// report "still waiting" to somebody who has already paid.
  Future<void> _checkForSettlement() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      for (var attempt = 0; attempt < 4; attempt++) {
        ref.invalidate(paymentDetailProvider(widget.paymentId));

        Payment payment;
        try {
          payment = await ref.read(
            paymentDetailProvider(widget.paymentId).future,
          );
        } catch (_) {
          // A failed read here is not worth a red bar: the screen is already
          // showing the bill, and the next attempt or a pull-to-refresh will
          // get it. Only the last attempt has anything to say, and what it says
          // is "still waiting".
          break;
        }

        if (payment.isPaid) {
          _onSettled(payment);
          return;
        }

        if (attempt < 3) {
          await Future<void>.delayed(const Duration(seconds: 2));
          if (!mounted) return;
        }
      }

      if (mounted && _sentToProvider) {
        showAppMessage(
          context,
          'No payment received yet. If you have just paid, give it a moment and '
          'check again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  /// Everything a settled bill changes, and the one dialog that says so.
  void _onSettled(Payment payment) {
    _stopQr();

    // Paying moves more than this one screen. Only the detail provider used to
    // be invalidated, so the payments list, the violation the fine belongs to
    // and the standing meter on Home all kept serving what they had cached
    // before the payment — the fine looked unpaid everywhere but here until the
    // app was restarted.
    ref.invalidate(paymentsNotifierProvider);
    ref.invalidate(violationsNotifierProvider);
    if (payment.violationId != null) {
      ref.invalidate(violationDetailProvider(payment.violationId!));
    }

    if (!mounted || !_sentToProvider) return;
    _sentToProvider = false;

    unawaited(
      CelebrationDialog.show(
        context,
        title: 'Payment Complete',
        message: 'Thanks for settling up!',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Payment Detail',
      body: AsyncView(
        value: ref.watch(paymentDetailProvider(widget.paymentId)),
        onRefresh: () {
          ref.invalidate(paymentDetailProvider(widget.paymentId));
          return ref.read(paymentDetailProvider(widget.paymentId).future);
        },
        errorTitle: "Couldn't load this payment",
        data: (payment) => ListView(
          padding: kScreenListPadding,
          children: [
            _AmountCard(payment: payment),
            const SizedBox(height: AppSpacing.md),
            AppFactsCard(
              title: 'How this was calculated',
              facts: [
                if (payment.slotCode != null)
                  AppFact('Slot', payment.slotCode!),
                AppFact(
                  'Duration',
                  Formatters.duration(
                    Duration(minutes: payment.durationMinutes),
                  ),
                ),
                AppFact(
                  'Rate',
                  '${Formatters.peso(payment.ratePerHourApplied)}/hr',
                ),
                AppFact('Created', Formatters.date(payment.createdAt)),
                if (payment.dueAt != null)
                  AppFact(
                    'Due by',
                    Formatters.date(payment.dueAt!),
                    intent: payment.isOverdue ? StatusIntent.danger : null,
                  ),
                if (payment.paidAt != null)
                  AppFact(
                    'Paid',
                    Formatters.date(payment.paidAt!),
                    intent: StatusIntent.success,
                  ),
                if (payment.method != null) AppFact('Method', payment.method!),
                // The half of a receipt that is worth having: the number both
                // sides can look the payment up by if it is ever disputed.
                if (payment.referenceNumber != null)
                  AppFact('Reference', payment.referenceNumber!),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (payment.isProcessing) ...[
              AppNotice(
                title: 'Waiting for confirmation',
                message: payment.provider?.toLowerCase() == 'simulated'
                    ? 'This is a test payment — no real money moves. Finish it '
                          'on the payment page, then check again.'
                    : 'Finish the payment on the provider page. This bill '
                          'settles as soon as they confirm it.',
                intent: StatusIntent.info,
              ),
              if (_qr != null) ...[
                const SizedBox(height: AppSpacing.md),
                _QrCard(checkout: _qr!),
              ],
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Check payment status',
                isLoading: _isChecking,
                onPressed: _isChecking ? null : _checkForSettlement,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: _qr == null ? 'Show QR code' : 'New QR code',
                style: AppButtonStyle.ghost,
                onPressed: _isStarting || _isChecking ? null : _showQr,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Pay again',
                style: AppButtonStyle.ghost,
                onPressed: _isStarting || _isChecking ? null : _pay,
              ),
            ] else if (!payment.isPaid) ...[
              AppButton(
                label: 'Pay ${Formatters.peso(payment.amountDue)}',
                isLoading: _isStarting,
                onPressed: _isStarting ? null : _pay,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Pay with QR code',
                style: AppButtonStyle.ghost,
                onPressed: _isStarting ? null : _showQr,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A checkout address drawn as a QR code, to be scanned from another phone.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.checkout});

  final Checkout checkout;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.x5),
      child: Column(
        children: [
          Text('SCAN TO PAY', style: context.text.labelSmall),
          const SizedBox(height: AppSpacing.md),
          // Black on white with a margin, whatever the app theme is: a code
          // drawn in brand colours or on a dark card is the kind a camera
          // fails to read, and a payment is the wrong place to find out.
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              // Keyed on the address so a new checkout always redraws the code,
              // and so a test can tell which checkout is on screen.
              key: ValueKey(checkout.checkoutUrl),
              data: checkout.checkoutUrl,
              size: 220,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            Formatters.peso(checkout.amountDue),
            style: AppTypography.tabular(context.text.titleLarge!),
          ),
          const SizedBox(height: 4),
          Text(
            checkout.isSimulated
                ? 'Scan with another phone to open the test payment page. '
                      'No real money moves.'
                : 'Scan with GCash, Maya, or your phone camera.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        ],
      ),
    );
  }
}

/// The one number this screen exists to show, on a full-bleed brand card.
class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.isPaid ? 'AMOUNT PAID' : 'AMOUNT DUE',
                  style: context.text.labelSmall,
                ),
              ),
              AppStatusBadge(
                label: payment.status,
                intent: StatusIntents.payment(payment.status),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // White card, black figure. This was a solid indigo panel with the
          // amount reversed out of it, which made the one number on the screen
          // the user might dispute the hardest thing on it to read — and put a
          // brand colour behind a charge, which reads as a promotion.
          Text(
            Formatters.peso(payment.amountDue),
            style: AppTypography.tabular(context.text.displayLarge!),
          ),
          const SizedBox(height: 2),
          Text(payment.source, style: context.text.bodySmall),
          if (payment.dueLabel != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  payment.isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.schedule_rounded,
                  size: AppSizes.iconSm,
                  color: payment.isOverdue
                      ? t.status.danger.fg
                      : t.text.secondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    payment.dueLabel!,
                    style: context.text.bodySmall?.copyWith(
                      // Overdue reads at full strength; a deadline still ahead
                      // sits quieter than the amount above it.
                      color: payment.isOverdue
                          ? t.status.danger.fg
                          : t.text.secondary,
                      fontWeight: payment.isOverdue ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
