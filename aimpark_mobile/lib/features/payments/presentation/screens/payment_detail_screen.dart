import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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

    final payment = ref.read(paymentDetailProvider(widget.paymentId)).valueOrNull;
    if (payment == null || payment.isPaid) return;
    if (!_sentToProvider && !payment.isProcessing) return;

    unawaited(_checkForSettlement());
  }

  Future<void> _pay() async {
    setState(() => _isStarting = true);
    try {
      final checkout =
          await ref.read(paymentsRepositoryProvider).startCheckout(widget.paymentId);

      final opened = await launchUrl(
        Uri.parse(checkout.checkoutUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('Could not open the payment page.');
      }

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
          payment = await ref.read(paymentDetailProvider(widget.paymentId).future);
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

    unawaited(CelebrationDialog.show(
      context,
      title: 'Payment Complete',
      message: 'Thanks for settling up!',
    ));
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
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(payment.source, style: context.text.headlineSmall),
                      AppStatusBadge(
                        label: payment.status,
                        intent: StatusIntents.payment(payment.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (payment.slotCode != null)
                    AppDetailRow(label: 'Slot', value: payment.slotCode!),
                  AppDetailRow(
                    label: 'Duration',
                    value: Formatters.duration(
                      Duration(minutes: payment.durationMinutes),
                    ),
                  ),
                  AppDetailRow(
                    label: 'Rate',
                    value:
                        '${Formatters.peso(payment.ratePerHourApplied)}/hr',
                  ),
                  AppDetailRow(
                    label: 'Created',
                    value: Formatters.date(payment.createdAt),
                  ),
                  if (payment.dueAt != null)
                    AppDetailRow(
                      label: 'Due by',
                      value: Formatters.date(payment.dueAt!),
                      intent:
                          payment.isOverdue ? StatusIntent.danger : null,
                    ),
                  if (payment.paidAt != null)
                    AppDetailRow(
                      label: 'Paid',
                      value: Formatters.date(payment.paidAt!),
                      intent: StatusIntent.success,
                    ),
                  if (payment.method != null)
                    AppDetailRow(label: 'Method', value: payment.method!),
                  // The half of a receipt that is worth having: the number both
                  // sides can look the payment up by if it is ever disputed.
                  if (payment.referenceNumber != null)
                    AppDetailRow(
                      label: 'Reference',
                      value: payment.referenceNumber!,
                    ),
                ],
              ),
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
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Check payment status',
                isLoading: _isChecking,
                onPressed: _isChecking ? null : _checkForSettlement,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Pay again',
                style: AppButtonStyle.ghost,
                onPressed: _isStarting || _isChecking ? null : _pay,
              ),
            ] else if (!payment.isPaid)
              AppButton(
                label: 'Pay ${Formatters.peso(payment.amountDue)}',
                isLoading: _isStarting,
                onPressed: _isStarting ? null : _pay,
              ),
          ],
        ),
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
      color: t.brand.primary,
      borderColor: t.brand.pressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount Due',
            style: context.text.labelLarge?.copyWith(color: t.brand.onSolid),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.peso(payment.amountDue),
            style: AppTypography.tabular(
              context.text.displayLarge!.copyWith(color: t.brand.onSolid),
            ),
          ),
          if (payment.dueLabel != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  payment.isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.schedule_rounded,
                  size: AppSizes.iconSm,
                  color: t.brand.onSolid,
                ),
                const SizedBox(width: 6),
                Text(
                  payment.dueLabel!,
                  style: context.text.labelLarge?.copyWith(
                    // Overdue reads at full strength on the card; a deadline
                    // still ahead sits quieter than the amount above it.
                    color: payment.isOverdue
                        ? t.brand.onSolid
                        : t.text.onDarkMuted,
                    fontWeight:
                        payment.isOverdue ? FontWeight.w800 : FontWeight.w600,
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
