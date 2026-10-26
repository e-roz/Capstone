import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../account/presentation/providers/account_provider.dart';
import '../../data/models/payment.dart';
import '../../data/payments_capabilities.dart';
import '../providers/payments_provider.dart';

/// What is owed, first; every bill underneath.
///
/// The tab where a person pays used to open on a flat list of bills with no total
/// on it. Now a summary sits on top — how much, across how many, whether entry is
/// blocked — with the button to start paying, and the bills are split into **To
/// pay** and **Paid**, so the ones that need action are not buried under the ones
/// that do not.
class PaymentsListScreen extends ConsumerStatefulWidget {
  const PaymentsListScreen({super.key}) : _inline = false;

  /// The bottom-nav destination: an inline title and no back arrow.
  ///
  /// This screen is reached two ways — as the Payments tab, and as
  /// `/home/user/payments` pushed from Account or from a payment's detail
  /// screen. The two need different chrome, and getting it wrong is not
  /// cosmetic: a pushed screen built as a tab has no way back out.
  const PaymentsListScreen.tab({super.key}) : _inline = true;

  final bool _inline;

  @override
  ConsumerState<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

/// Which kind of bill the list is narrowed to.
enum _TypeFilter {
  all('All'),
  parking('Parking fees'),
  fines('Fines');

  const _TypeFilter(this.label);
  final String label;

  bool matches(Payment p) => switch (this) {
        _TypeFilter.all => true,
        _TypeFilter.parking => !p.isViolation,
        _TypeFilter.fines => p.isViolation,
      };
}

class _PaymentsListScreenState extends ConsumerState<PaymentsListScreen>
    with WidgetsBindingObserver {
  bool _isPayingAll = false;
  _TypeFilter _filter = _TypeFilter.all;

  /// Paid history is cut to the latest few until asked for. It only ever grows,
  /// and a screen that opens on fifteen identical rows hides the one that
  /// matters, which is whatever is at the top.
  bool _showAllPaid = false;
  static const _paidPageSize = 10;

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

  /// Coming back from the payment page is the moment to ask what happened. The
  /// phone is told nothing by the payment itself — the provider reports to the
  /// server — so what it can do is look again when it is back in front.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(paymentsNotifierProvider.notifier).refreshQuietly();
    }
  }

  Future<void> _openBill(String paymentId) async {
    await context.push('/home/user/payments/$paymentId');
    // Back from the bill, which may well have just been paid.
    if (mounted) {
      ref.read(paymentsNotifierProvider.notifier).refreshQuietly();
    }
  }

  Future<void> _payAll() async {
    setState(() => _isPayingAll = true);
    try {
      final checkout = await ref
          .read(paymentsRepositoryProvider)
          .startCheckoutAll();
      final opened = await launchUrl(
        Uri.parse(checkout.checkoutUrl),
        mode: LaunchMode.inAppBrowserView,
      );
      if (!opened) throw Exception('Could not open the payment page.');
      if (mounted) {
        ref.read(paymentsNotifierProvider.notifier).refreshQuietly();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isPayingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Future<void> refresh() =>
        ref.read(paymentsNotifierProvider.notifier).refresh();

    final entryBlocked =
        ref.watch(accessStatusProvider).valueOrNull?.isEntryBlockedByBalance ??
        false;

    final body = AsyncView(
      value: ref.watch(paymentsNotifierProvider),
      onRefresh: refresh,
      errorTitle: "Couldn't load your payments",
      loading: const Padding(
        padding: kScreenListPadding,
        child: AppRowSkeleton(),
      ),
      isEmpty: (result) => result.payments.isEmpty,
      empty: const AppEmptyState(
        icon: Icons.payments_rounded,
        title: 'No payments yet',
        message: 'Parking fees and penalties will show up here.',
      ),
      data: (result) {
        final all = result.payments;

        // What still needs doing, most pressing first: the bill that has been
        // waiting longest, or is due soonest, leads.
        final owed = all.where((p) => !p.isPaid && !p.isWaived).toList()
          ..sort(
            (a, b) =>
                a.createdAt.compareTo(b.createdAt),
          );
        final settled = all.where((p) => p.isPaid || p.isWaived).toList()
          ..sort(
            (a, b) =>
                (b.paidAt ?? b.createdAt).compareTo(a.paidAt ?? a.createdAt),
          );

        // The summary is about everything owed, whatever the chips say: narrowing
        // the list must not make a debt look smaller.
        final payable = owed.where((p) => p.isPayable).toList();
        final paidOnly = all.where((p) => p.isPaid).toList();
        final paidTotal = paidOnly.fold<double>(0, (s, p) => s + p.amountDue);

        final toPay = owed.where(_filter.matches).toList();
        final paid = settled.where(_filter.matches).toList();
        final shownPaid = _showAllPaid || paid.length <= _paidPageSize
            ? paid
            : paid.take(_paidPageSize).toList();

        // Filtering only means something when there is more than one kind.
        final hasBothKinds =
            all.any((p) => p.isViolation) && all.any((p) => !p.isViolation);

        return ListView(
          padding: kScreenListPadding,
          children: [
            if (widget._inline) const AppScreenTitle(title: 'Payments'),
            _Summary(
              payable: payable,
              processing: owed.where((p) => p.isProcessing).length,
              entryBlocked: entryBlocked,
              isPayingAll: _isPayingAll,
              paidTotal: paidTotal,
              paidCount: paidOnly.length,
              onPayOldest: () => _openBill(payable.first.paymentId),
              onPayAll: _payAll,
            ),
            if (hasBothKinds) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final f in _TypeFilter.values)
                    SelectableChip(
                      label: f.label,
                      selected: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                ],
              ),
            ],
            if (toPay.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              AppSectionHeader(title: 'To pay · ${toPay.length}'),
              AppRowGroup(
                children: [
                  for (final p in toPay)
                    _PaymentRow(
                      payment: p,
                      onTap: () => _openBill(p.paymentId),
                    ),
                ],
              ),
            ],
            // History in day groups, newest first: seven bills on one day read as
            // one day, not seven "Oct 11"s.
            for (final day in _byDay(shownPaid)) ...[
              const SizedBox(height: AppSpacing.lg),
              AppSectionHeader(title: day.label),
              AppRowGroup(
                children: [
                  for (final p in day.payments)
                    _PaymentRow(
                      payment: p,
                      onTap: () => _openBill(p.paymentId),
                    ),
                ],
              ),
            ],
            if (!_showAllPaid && paid.length > _paidPageSize) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                child: AppTextLink(
                  label: 'Show older payments',
                  onTap: () => setState(() => _showAllPaid = true),
                ),
              ),
            ],
            if (toPay.isEmpty && paid.isEmpty && _filter != _TypeFilter.all) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                _filter == _TypeFilter.fines
                    ? 'No fines to show.'
                    : 'No parking fees to show.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ],
          ],
        );
      },
    );

    return widget._inline
        ? AppScreen.tab(body: body)
        // The same link can open the list itself (a payment with no bill id), so
        // it gets the same way home.
        : AppScreen(
            title: 'Payments',
            fallbackBackRoute: '/home/user?tab=payments',
            body: body,
          );
  }
}

/// How much is owed, in one card.
///
/// Which button it offers follows from what is owed — and says so:
///
/// * one bill — "Pay now";
/// * several — "Pay oldest bill", the one that has waited longest, and, once the
///   server can take a single payment for all of them, "Pay all";
/// * nothing — a plain "all paid" note, with no button to press.
///
/// Both pay buttons go to the bill and straight on to the payment page, so paying
/// never needs a trip through the bill first.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.payable,
    required this.processing,
    required this.entryBlocked,
    required this.isPayingAll,
    required this.paidTotal,
    required this.paidCount,
    required this.onPayOldest,
    required this.onPayAll,
  });

  /// Everything paid so far and how many payments that was. Shown on the "all
  /// paid up" card, the one place a total of the history has room.
  final double paidTotal;
  final int paidCount;

  /// The bills that can be paid right now, oldest first. Empty when there are
  /// none.
  final List<Payment> payable;

  /// How many bills have a checkout open and are waiting for the provider.
  final int processing;

  /// The server says unpaid bills are currently stopping this account at the gate.
  /// Only ever true when the server has said so.
  final bool entryBlocked;

  final bool isPayingAll;
  final VoidCallback onPayOldest;
  final VoidCallback onPayAll;

  @override
  Widget build(BuildContext context) {
    if (payable.isEmpty) {
      return processing > 0
          ? AppAlertCard(
              intent: StatusIntent.info,
              eyebrow: processing == 1
                  ? '1 payment in progress'
                  : '$processing payments in progress',
              message:
                  'Waiting for the payment provider to confirm. This '
                  'updates by itself when it does.',
            )
          : AppAlertCard(
              intent: StatusIntent.success,
              eyebrow: 'All paid up',
              message: 'Nothing is due right now.',
              child: paidCount == 0
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                          height: AppSpacing.md,
                          color: context.tokens.border.subtle,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                'Paid so far',
                                style: context.text.bodySmall,
                              ),
                            ),
                            Text(
                              Formatters.peso(paidTotal),
                              style: AppTypography.tabular(
                                context.text.titleLarge!,
                              ),
                            ),
                            Text(
                              paidCount == 1
                                  ? ' · 1 payment'
                                  : ' · $paidCount payments',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
            );
    }

    final total = payable.fold<double>(0, (sum, p) => sum + p.amountDue);
    final many = payable.length > 1;

    return AppAlertCard(
      intent: entryBlocked ? StatusIntent.danger : StatusIntent.warning,
      eyebrow: 'Total due',
      message: entryBlocked
          ? "You can't enter until this is paid."
          : null,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: many ? 'Pay oldest bill' : 'Pay now',
            onPressed: isPayingAll ? null : onPayOldest,
          ),
          // Only offered when the server can actually do it. See
          // `kPayAllAvailable` for what that takes.
          if (many && kPayAllAvailable) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Pay all ${Formatters.peso(total)}',
              style: AppButtonStyle.secondary,
              isLoading: isPayingAll,
              onPressed: isPayingAll ? null : onPayAll,
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A Wrap, so at a large text size the caption drops under the amount
          // instead of pushing it off the card.
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                Formatters.peso(total),
                style: AppTypography.tabular(context.text.headlineLarge!),
              ),
              Text(
                many ? 'across ${payable.length} bills' : 'for 1 bill',
                style: context.text.bodySmall,
              ),
            ],
          ),
          if (processing > 0) ...[
            const SizedBox(height: 2),
            Text(
              processing == 1
                  ? '1 more is being paid now'
                  : '$processing more are being paid now',
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.onTap});

  final Payment payment;
  final VoidCallback onTap;

  /// "Oct 9 · 8:44 AM–8:45 AM · 1m" — when the visit was and how long it ran,
  /// which is what tells seven ₱20 bills apart. A fine, or a bill with no session
  /// behind it, falls back to the date it was raised.
  String get _when {
    // The API sends UTC; shown as the user's own clock, like Home does.
    if (payment.isViolation) {
      return 'Issued ${Formatters.dateShort(payment.createdAt.toLocal())}';
    }
    final entry = payment.entryTime?.toLocal();
    if (entry == null) return Formatters.date(payment.createdAt.toLocal());

    final exit = payment.exitTime?.toLocal();
    final times = exit == null
        ? Formatters.time(entry)
        : '${Formatters.time(entry)}–${Formatters.time(exit)}';
    return '${Formatters.dateShort(entry)} · $times · '
        '${Formatters.duration(Duration(minutes: payment.durationMinutes))}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isViolation = payment.isViolation;
    final intent = StatusIntents.payment(payment.status);

    // The tile says what the bill is — blue for parking, red for a fine, as on
    // Account — and the text says where it stands. It used to be tinted by
    // status, which turned every paid row green and left a fine looking exactly
    // like a parking fee.
    final (tileBg, tileFg) = isViolation
        ? (t.status.danger.bg, t.status.danger.fg)
        : (t.accent.subtle, t.accent.subtleText);

    // A settled bill needs no badge: the section already says Paid, and fifteen
    // identical badges are noise. It gets a tick and how it was paid, which is
    // what someone checking a payment looks for. A badge stays on anything still
    // moving — Pending, Overdue, Processing.
    final settled = payment.isPaid || payment.isWaived;

    return AppListRow(
      leading: Container(
        width: AppSizes.rowIcon,
        height: AppSizes.rowIcon,
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(
          isViolation ? Icons.gavel_rounded : Icons.local_parking_rounded,
          size: AppSizes.iconMd,
          color: tileFg,
        ),
      ),
      title: isViolation
          ? 'Violation fine'
          : 'Parking fee',
      subtitle: _when,
      // The status sits under the name beside the deadline, not pinned to the far
      // end of the row: a badge there cannot shrink, and at a large text size it
      // squeezed the title or ran off the screen.
      note: settled
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  payment.isPaid
                      ? Icons.check_rounded
                      : Icons.remove_circle_outline_rounded,
                  size: AppSizes.iconSm,
                  color: payment.isPaid
                      ? t.status.success.fg
                      : t.text.secondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    payment.isWaived ? 'Waived' : (payment.method ?? 'Paid'),
                    style: context.text.bodySmall?.copyWith(
                      color: payment.isPaid ? t.status.success.fg : null,
                    ),
                  ),
                ),
              ],
            )
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppStatusBadge(label: payment.status, intent: intent),
                if (payment.dueLabel != null)
                  Text(
                    payment.dueLabel!,
                    style: context.text.bodySmall,
                  ),
              ],
            ),
      trailing: Text(
        Formatters.peso(payment.amountDue),
        style: AppTypography.tabular(context.text.titleSmall!),
      ),
      onTap: onTap,
    );
  }
}

/// One day of settled bills, under a heading like "Today · Oct 11".
class _Day {
  _Day(this.label) : payments = [];

  final String label;
  final List<Payment> payments;
}

/// Splits [bills], already newest first, into one group per calendar day they
/// were paid on (the day they were raised, for a waived one that was never paid).
List<_Day> _byDay(List<Payment> bills) {
  final days = <_Day>[];
  DateTime? current;

  for (final p in bills) {
    final when = (p.paidAt ?? p.createdAt).toLocal();
    final key = DateTime(when.year, when.month, when.day);

    if (current != key) {
      current = key;
      final rel = Formatters.relativeDay(when);
      // "Today" and "Yesterday" say nothing about which date; add it.
      final isRelative = rel == 'Today' || rel == 'Yesterday';
      days.add(
        _Day(isRelative ? '$rel · ${Formatters.dateShort(when)}' : rel),
      );
    }
    days.last.payments.add(p);
  }
  return days;
}
