import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/notification.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

/// What an administrator may *send*. Everything else is raised by the system
/// itself and cannot be broadcast by hand. A broadcast always reaches everyone.
const _types = ['Announcement', 'PolicyUpdate'];

const _titleMax = 60;
const _messageMax = 200;

/// Human wording for the API's enum names — `PolicyUpdate` is a value, not a
/// phrase, and it should not be what an administrator reads. Every name the API
/// can still return stays here, because rows written before the broadcast form
/// was narrowed to two types are still in the log.
const _typeLabels = <String, String>{
  'Announcement': 'Announcement',
  'PolicyUpdate': 'Policy update',
  'ParkingAvailability': 'Parking availability',
  'System': 'System',
  'Violation': 'Violation',
  'Payment': 'Payment',
  'Incident': 'Incident',
  'Account': 'Account',
  'Parking': 'Parking',
  'Reminder': 'Reminder',
};

const _typeHints = <String, String>{
  'Announcement': 'News, events, reminders',
  'PolicyUpdate': 'Rules, fees, schedules',
};

IconData _typeIcon(String type) => switch (type) {
      'Announcement' => Icons.campaign_outlined,
      'PolicyUpdate' => Icons.description_outlined,
      _ => Icons.notifications_outlined,
    };

/// One screen, two jobs.
///
/// A guard cannot send, so the inbox is all they get: the only place on the
/// desktop panel they can read what the system and the administrators have told
/// them. An administrator gets the same inbox — a new registration, renewal,
/// appeal or incident lands there — and a second view of the announcements they
/// have sent, with the Broadcast button.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSecurity = ref.watch(staffRoleProvider) == StaffRole.security;

    return AppPage(
      title: 'Notifications',
      subtitle: isSecurity
          ? 'What the system and your administrators have sent you.'
          : 'What needs you, and the announcements you’ve sent.',
      actions: [
        if (!isSecurity)
          FilledButton.icon(
            icon: const Icon(Icons.campaign_outlined, size: AppSizes.iconSm),
            label: const Text('Broadcast'),
            onPressed: () => showBroadcastDialog(context, ref),
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(inboxProvider);
            ref.invalidate(notificationListProvider);
          },
        ),
      ],
      body: isSecurity
          ? const _InboxList()
          : _AdminBody(onBroadcast: () => showBroadcastDialog(context, ref)),
    );
  }
}

/// The administrator's two views of the one screen. Inbox first: it is what
/// arrives without being asked for, and what the bell is counting.
class _AdminBody extends StatefulWidget {
  const _AdminBody({required this.onBroadcast});

  final VoidCallback onBroadcast;

  @override
  State<_AdminBody> createState() => _AdminBodyState();
}

class _AdminBodyState extends State<_AdminBody> {
  bool _showSent = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Inbox')),
            ButtonSegment(value: true, label: Text('Sent')),
          ],
          selected: {_showSent},
          onSelectionChanged: (s) => setState(() => _showSent = s.first),
        ),
        const SizedBox(height: AppSpacing.gutter),
        Expanded(
          child: _showSent
              ? _SentList(onBroadcast: widget.onBroadcast)
              : const _InboxList(),
        ),
      ],
    );
  }
}

/// Everything addressed to a guard, newest first. No category filter: with a
/// handful of kinds and a single 50-row request there is nothing to narrow.
class _InboxList extends ConsumerWidget {
  const _InboxList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The bell checks for new items on its own; when its count moves, this list
    // is out of date too.
    ref.listen(unreadInboxCountProvider, (previous, next) {
      if (previous?.valueOrNull != next.valueOrNull) {
        ref.invalidate(inboxProvider);
      }
    });

    return AsyncView(
      value: ref.watch(inboxProvider),
      onRetry: () => ref.invalidate(inboxProvider),
      loading: const SkeletonList(),
      isEmpty: (page) => page.notifications.isEmpty,
      empty: const AppEmptyState(
        icon: Icons.inbox_outlined,
        title: 'Nothing for you yet',
        message: 'New registrations, appeals and incidents, announcements, and '
            'anything the system raises about your account, will appear here.',
      ),
      data: (page) => _GroupedList(
        items: page.notifications,
        cardFor: (item) {
          void markRead() => ref
              .read(inboxActionsProvider.notifier)
              .markRead(item.notificationId)
              .then((_) => ref.invalidate(unreadInboxCountProvider));

          final route = item.data['route'];
          return _NotificationCard(
            item: item,
            onMarkRead: item.isRead ? null : markRead,
            // Opens the page it is about, and clears the dot on the way.
            onOpen: route == null || route.isEmpty
                ? null
                : () {
                    if (!item.isRead) markRead();
                    context.go(route);
                  },
          );
        },
      ),
    );
  }
}

/// The broadcast log: what this panel has sent out.
class _SentList extends ConsumerWidget {
  const _SentList({required this.onBroadcast});

  final VoidCallback onBroadcast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(notificationListProvider),
      onRetry: () => ref.invalidate(notificationListProvider),
      loading: const SkeletonList(),
      isEmpty: (page) => page.notifications.isEmpty,
      empty: AppEmptyState(
        icon: Icons.campaign_outlined,
        title: 'Nothing sent yet',
        message: 'Announcements and policy updates you send reach everyone, '
            'and are listed here, most recent first.',
        action: FilledButton.icon(
          icon: const Icon(Icons.campaign_outlined, size: AppSizes.iconSm),
          label: const Text('Broadcast'),
          onPressed: onBroadcast,
        ),
      ),
      data: (page) => Column(
        children: [
          Expanded(
            child: _GroupedList(
              items: page.notifications,
              cardFor: (item) => _NotificationCard(item: item, sent: true),
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          AppPagination(
            page: page.page,
            pageSize: page.pageSize,
            total: page.totalCount,
            itemLabel: 'notifications',
            onPage:
                ref.read(notificationsQueryNotifierProvider.notifier).setPage,
          ),
        ],
      ),
    );
  }
}

/// Newest first, under "Today", "This week" and "Earlier" headings, so a log
/// that grows past a screen can still be scanned by when rather than read top
/// to bottom.
class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.items, required this.cardFor});

  final List<NotificationItem> items;
  final Widget Function(NotificationItem item) cardFor;

  static String _bucket(DateTime when) {
    final now = DateTime.now();
    final day = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    final age = today.difference(day).inDays;
    if (age <= 0) return 'Today';
    if (age < 7) return 'This week';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final rows = <Widget>[];
    String? current;
    for (final item in items) {
      final bucket = _bucket(item.createdAt.toLocal());
      if (bucket != current) {
        current = bucket;
        rows.add(Padding(
          padding: EdgeInsets.only(
            top: rows.isEmpty ? 0 : AppSpacing.x4,
            bottom: AppSpacing.x2,
          ),
          child: Text(
            bucket,
            style: text.labelMedium?.copyWith(color: t.text.tertiary),
          ),
        ));
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.gutter),
        child: cardFor(item),
      ));
    }

    return ListView(children: rows);
  }
}

Future<void> showBroadcastDialog(BuildContext context, WidgetRef ref) async {
  final draft = await showDialog<_BroadcastDraft>(
    context: context,
    builder: (_) => const _BroadcastDialog(),
  );

  if (draft == null || !context.mounted) return;
  final msg = await ref.read(notificationActionsProvider.notifier).broadcast(
        title: draft.title,
        message: draft.message,
        type: draft.type,
      );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg ?? 'Notification broadcast.')));
  ref.invalidate(notificationListProvider);
}

class _BroadcastDraft {
  const _BroadcastDraft(this.title, this.message, this.type);

  final String title;
  final String message;
  final String type;
}

class _BroadcastDialog extends StatefulWidget {
  const _BroadcastDialog();

  @override
  State<_BroadcastDialog> createState() => _BroadcastDialogState();
}

class _BroadcastDialogState extends State<_BroadcastDialog> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _type = _types.first;

  @override
  void initState() {
    super.initState();
    // The phone preview mirrors what is typed, so it has to repaint per key.
    _titleCtrl.addListener(() => setState(() {}));
    _messageCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _BroadcastDraft(
        _titleCtrl.text.trim(),
        _messageCtrl.text.trim(),
        _type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final typeColors =
        t.status.of(StatusIntents.notificationType(_type));

    return AlertDialog(
      // The tile takes the colour of the chosen type, so the dialog already
      // reads as "announcement" or "policy update" before anything is typed.
      title: Row(
        children: [
          AnimatedContainer(
            duration: AppMotion.fast,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: typeColors.bg,
              borderRadius: AppRadii.mdAll,
              border: Border.all(color: typeColors.border),
            ),
            child: Icon(_typeIcon(_type), size: 18, color: typeColors.fg),
          ),
          const SizedBox(width: AppSpacing.x3),
          const Text('New broadcast'),
        ],
      ),
      content: SizedBox(
        width: context.dialogWidth(480),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppRequiredNote(),
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: _titleMax,
                  decoration: const InputDecoration(
                    label: AppFieldLabel('Title', isRequired: true),
                    hintText: 'Gate 2 closed this Saturday',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: AppSpacing.x2),
                TextFormField(
                  controller: _messageCtrl,
                  maxLength: _messageMax,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    label: AppFieldLabel('Message', isRequired: true),
                    hintText: 'Use Gate 1 on Saturday, Oct 11.',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a message'
                      : null,
                ),
                const SizedBox(height: AppSpacing.x3),
                Text('Type', style: text.labelMedium),
                const SizedBox(height: AppSpacing.x2),
                Row(
                  children: [
                    for (final type in _types) ...[
                      Expanded(
                        child: _TypeOption(
                          type: type,
                          selected: _type == type,
                          onTap: () => setState(() => _type = type),
                        ),
                      ),
                      if (type != _types.last)
                        const SizedBox(width: AppSpacing.x3),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  'How it looks on a phone',
                  style: text.labelSmall?.copyWith(color: t.text.tertiary),
                ),
                const SizedBox(height: AppSpacing.x2),
                _PhonePreview(
                  type: _type,
                  title: _titleCtrl.text.trim(),
                  message: _messageCtrl.text.trim(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.send_outlined, size: AppSizes.iconSm),
          label: const Text('Send to everyone'),
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(StatusIntents.notificationType(type));

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.mdAll,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: selected ? c.bg : t.surface.card,
          borderRadius: AppRadii.mdAll,
          border: Border.all(
            color: selected ? c.solid : t.border.normal,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Each option keeps its own colour while unselected, so the two
            // can be told apart at a glance and the choice reads as picking a
            // colour as much as a word.
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: AppRadii.smAll,
                border: Border.all(color: c.border),
              ),
              child: Icon(_typeIcon(type), size: 18, color: c.fg),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_typeLabels[type] ?? type, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    _typeHints[type] ?? '',
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stand-in for the push the phone will show, so the sender sees the title
/// cut where the phone will cut it before it cannot be taken back.
class _PhonePreview extends StatelessWidget {
  const _PhonePreview({
    required this.type,
    required this.title,
    required this.message,
  });

  final String type;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(StatusIntents.notificationType(type));

    return AnimatedContainer(
      duration: AppMotion.fast,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: t.brand.primary,
              borderRadius: AppRadii.smAll,
            ),
            child: Icon(Icons.local_parking, size: 16, color: t.text.onBrand),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AimPark · now',
                  style: text.labelSmall?.copyWith(color: t.text.tertiary),
                ),
                Text(
                  title.isEmpty ? 'Your title appears here' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    color: title.isEmpty ? t.text.tertiary : null,
                  ),
                ),
                Text(
                  message.isEmpty ? 'Your message appears here.' : message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: message.isEmpty
                        ? t.text.tertiary
                        : t.text.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    this.onMarkRead,
    this.onOpen,
    this.sent = false,
  });

  final NotificationItem item;

  /// Opens the page the notification is about; null when it is about nothing
  /// in particular.
  final VoidCallback? onOpen;

  /// Null on anything already read, and in the sent log where "read" is a fact
  /// about somebody else. Present, it renders the unread dot and the control
  /// that clears it.
  final VoidCallback? onMarkRead;

  /// True in the sent log, where the line under the message names the sender
  /// and the audience. In an inbox neither is news to the reader.
  final bool sent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final intent = StatusIntents.notificationType(item.type);
    final c = t.status.of(intent);
    final when = DateFormat('MMM d, HH:mm').format(item.createdAt.toLocal());

    final meta = sent
        ? [
            'Sent by ${item.sentByName ?? 'an administrator'}',
            item.targetRole ?? 'Everyone',
            when,
          ].join(' · ')
        : when;

    return AppCard(
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: AppRadii.mdAll,
              border: Border.all(color: c.border),
            ),
            child: Icon(_typeIcon(item.type), size: 20, color: c.fg),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // A filled dot rather than bold text: the title is already
                    // the heaviest thing in the row, so weight cannot also
                    // carry "unread" without the two fighting.
                    if (onMarkRead != null)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: t.brand.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(item.title, style: text.titleSmall),
                    StatusPill.of(
                      _typeLabels[item.type] ?? item.type,
                      intent: intent,
                      dense: true,
                      showDot: false,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.labelGap),
                  child: Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x2),
                  child: Text(
                    meta,
                    style: text.labelSmall?.copyWith(color: t.text.tertiary),
                  ),
                ),
              ],
            ),
          ),
          if (onMarkRead != null) ...[
            const SizedBox(width: AppSpacing.x3),
            TextButton(onPressed: onMarkRead, child: const Text('Mark read')),
          ],
        ],
      ),
    );
  }
}
