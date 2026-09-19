import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/jwt_utils.dart';
import '../core/utils/responsive.dart';
import '../router/destinations.dart';
import '../providers/auth_provider.dart';
import '../providers/incidents_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/registrations_provider.dart';
import '../providers/security_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/violations_provider.dart';
import '../theme/theme.dart';

/// The panel's frame: a light top bar carrying the workspace mark, a
/// segmented pill for the four destination groups, and the account menu —
/// with a second row of pill tabs for whichever group is active.
///
/// Replaces the dark left rail. Seventeen destinations do not fit one row of
/// pills, which is why the nav is two-tier rather than a literal copy of a
/// five-tab reference: the top row picks a *group*, the second row picks a
/// *screen* within it, and a badge on either tells you where the queued work
/// is without opening it.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final location = GoRouterState.of(context).matchedLocation;
    final token = ref.watch(authNotifierProvider).valueOrNull;
    final email = token == null ? null : JwtUtils.getEmail(token);

    // Admin while the token is still loading. The router refuses every route
    // in that state anyway, so this only decides what the frame draws for the
    // one frame before it resolves.
    final role = token == null
        ? StaffRole.admin
        : JwtUtils.staffRole(token) ?? StaffRole.admin;
    final groups = navGroupsFor(role);
    final activeGroup = _groupFor(location, groups);

    if (context.isCompact) {
      final items = [for (final g in groups) ...g.items];
      final selected = _flatIndex(location, items);
      return Scaffold(
        appBar: AppBar(
          backgroundColor: t.surface.card,
          foregroundColor: t.text.primary,
          elevation: 0,
          title: Text(
            items.isEmpty ? 'AimPark' : items[selected].label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        drawer: Drawer(
          backgroundColor: t.surface.card,
          child: SafeArea(
            child: _DrawerNav(
              groups: groups,
              location: location,
              email: email,
              onSelect: (route) {
                Navigator.pop(context);
                context.go(route);
              },
              onLogout: _logout,
            ),
          ),
        ),
        body: widget.child,
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _TopBar(
            groups: groups,
            activeGroup: activeGroup,
            location: location,
            email: email,
            onLogout: _logout,
          ),
          if (activeGroup != null && activeGroup.items.length > 1)
            _SubNav(group: activeGroup, location: location),
          Divider(height: 1, color: t.border.normal),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  NavGroup? _groupFor(String location, List<NavGroup> groups) {
    for (final g in groups) {
      if (g.items.any((i) => location.startsWith(i.route))) return g;
    }
    return groups.isEmpty ? null : groups.first;
  }

  int _flatIndex(String location, List<NavItem> items) {
    for (var i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].route)) return i;
    }
    return 0;
  }

  Future<void> _logout() async {
    final t = context.tokens;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: SizedBox(
          width: ctx.dialogWidth(360),
          child: const Text('You will need to sign in again to get back into the '
              'admin panel.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: t.status.danger.solid),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go('/login');
  }
}

/// Work waiting behind a destination, or null if it does not track any. Kept
/// as a hook widget rather than a plain function so each caller only watches
/// the providers its own route needs.
class _BadgeWatcher extends ConsumerWidget {
  const _BadgeWatcher({required this.route, required this.builder});

  final String route;
  final Widget Function(BuildContext context, int? badge) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = switch (route) {
      '/incidents' when ref.watch(staffRoleProvider) == StaffRole.security =>
        ref.watch(openIncidentCountProvider).valueOrNull,
      '/incidents' => switch ((
          ref.watch(openIncidentCountProvider).valueOrNull,
          ref.watch(pendingAppealCountProvider).valueOrNull,
        )) {
          (null, null) => null,
          (final a, final b) => (a ?? 0) + (b ?? 0),
        },
      '/pending' => ref.watch(pendingRegistrationsProvider).valueOrNull?.length,
      '/visitors' => ref.watch(visitorsOnSiteCountProvider).valueOrNull,
      '/notifications' => ref.watch(unreadInboxCountProvider).valueOrNull,
      _ => null,
    };
    return builder(context, badge);
  }
}

int? _groupBadge(NavGroup group, WidgetRef ref) {
  int? total;
  for (final item in group.items) {
    final b = switch (item.route) {
      '/incidents' when ref.watch(staffRoleProvider) == StaffRole.security =>
        ref.watch(openIncidentCountProvider).valueOrNull,
      '/incidents' => switch ((
          ref.watch(openIncidentCountProvider).valueOrNull,
          ref.watch(pendingAppealCountProvider).valueOrNull,
        )) {
          (null, null) => null,
          (final a, final b) => (a ?? 0) + (b ?? 0),
        },
      '/pending' => ref.watch(pendingRegistrationsProvider).valueOrNull?.length,
      '/visitors' => ref.watch(visitorsOnSiteCountProvider).valueOrNull,
      '/notifications' => ref.watch(unreadInboxCountProvider).valueOrNull,
      _ => null,
    };
    if (b != null) total = (total ?? 0) + b;
  }
  return total;
}

// ── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.groups,
    required this.activeGroup,
    required this.location,
    required this.email,
    required this.onLogout,
  });

  final List<NavGroup> groups;
  final NavGroup? activeGroup;
  final String location;
  final String? email;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    return Container(
      height: AppSizes.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      color: t.surface.card,
      child: Row(
        children: [
          const _BrandMark(),
          const SizedBox(width: AppSpacing.x6),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _GroupPills(
                  groups: groups,
                  activeGroup: activeGroup,
                  location: location,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x6),
          _NotificationBell(active: location.startsWith('/notifications')),
          const SizedBox(width: AppSpacing.x3),
          _AccountChip(email: email, onLogout: onLogout),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => context.go('/dashboard'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: t.brand.primary,
              borderRadius: AppRadii.smAll,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.local_parking, size: AppSizes.iconMd, color: t.text.onBrand),
          ),
          const SizedBox(width: AppSpacing.x2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('AimPark', style: text.titleSmall),
              Text(
                'STI Baliuag',
                style: text.labelSmall?.copyWith(color: t.text.tertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The primary segmented control: one pill per destination group. Selecting a
/// multi-screen group jumps to its first destination and reveals [_SubNav];
/// selecting a single-screen group (Overview) just navigates.
class _GroupPills extends ConsumerWidget {
  const _GroupPills({
    required this.groups,
    required this.activeGroup,
    required this.location,
  });

  final List<NavGroup> groups;
  final NavGroup? activeGroup;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface.muted,
        borderRadius: AppRadii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final group in groups)
            _GroupPill(
              group: group,
              selected: identical(group, activeGroup),
              badge: _groupBadge(group, ref),
            ),
        ],
      ),
    );
  }
}

class _GroupPill extends StatefulWidget {
  const _GroupPill({required this.group, required this.selected, this.badge});

  final NavGroup group;
  final bool selected;
  final int? badge;

  @override
  State<_GroupPill> createState() => _GroupPillState();
}

class _GroupPillState extends State<_GroupPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final label = widget.group.label ?? widget.group.items.first.label;
    final hasWork = (widget.badge ?? 0) > 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.group.items.first.route),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          decoration: BoxDecoration(
            color: widget.selected
                ? t.surface.card
                : _hovered
                    ? t.surface.hover
                    : Colors.transparent,
            borderRadius: AppRadii.fullAll,
            boxShadow: widget.selected ? AppElevation.sm : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: text.labelLarge?.copyWith(
                  color: widget.selected ? t.text.primary : t.text.secondary,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (hasWork) ...[
                const SizedBox(width: AppSpacing.x1),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: t.status.danger.solid,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The second row: pill tabs for whichever group [_GroupPills] has selected.
/// A plain underline rather than a filled pill, so the two rows read as
/// primary/secondary rather than as two copies of the same control.
class _SubNav extends ConsumerWidget {
  const _SubNav({required this.group, required this.location});

  final NavGroup group;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      color: t.surface.canvas,
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in group.items)
              _BadgeWatcher(
                route: item.route,
                builder: (context, badge) => _SubTab(
                  item: item,
                  selected: location.startsWith(item.route),
                  badge: badge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubTab extends StatefulWidget {
  const _SubTab({required this.item, required this.selected, this.badge});

  final NavItem item;
  final bool selected;
  final int? badge;

  @override
  State<_SubTab> createState() => _SubTabState();
}

class _SubTabState extends State<_SubTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final hasWork = (widget.badge ?? 0) > 0;
    final color = widget.selected
        ? t.text.primary
        : _hovered
            ? t.text.primary
            : t.text.secondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.item.route),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          margin: const EdgeInsets.only(right: AppSpacing.x5),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.selected ? t.brand.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.selected ? widget.item.selectedIcon : widget.item.icon,
                size: AppSizes.iconSm,
                color: color,
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                widget.item.label,
                style: text.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (hasWork) ...[
                const SizedBox(width: AppSpacing.x2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: t.status.danger.bg,
                    borderRadius: AppRadii.fullAll,
                  ),
                  child: Text(
                    widget.badge! > 99 ? '99+' : '${widget.badge}',
                    style: text.labelSmall?.copyWith(color: t.status.danger.fg),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final unread = ref.watch(unreadInboxCountProvider).valueOrNull ?? 0;

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.go('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        smallSize: 8,
        backgroundColor: t.status.danger.solid,
        child: Icon(
          active ? Icons.notifications : Icons.notifications_outlined,
          color: active ? t.text.primary : t.text.secondary,
        ),
      ),
    );
  }
}

class _AccountChip extends ConsumerWidget {
  const _AccountChip({required this.email, required this.onLogout});

  final String? email;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final role = ref.watch(staffRoleProvider);

    final address = email ?? '';
    final handle = address.contains('@') ? address.split('@').first : address;
    final name = handle.isEmpty ? 'Administrator' : handle;
    final initial = name.substring(0, 1).toUpperCase();

    final avatar = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: t.brand.subtle, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: text.labelSmall?.copyWith(
          color: t.brand.subtleText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return PopupMenuButton<void>(
      tooltip: 'Account',
      offset: const Offset(0, 8),
      color: t.surface.overlay,
      itemBuilder: (context) => [
        if (address.isNotEmpty)
          PopupMenuItem<void>(
            enabled: false,
            child: Row(
              children: [
                Icon(Icons.account_circle_outlined,
                    size: AppSizes.iconMd, color: t.text.secondary),
                const SizedBox(width: AppSpacing.x2),
                Flexible(
                  child: Text(
                    address,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: () => ref.read(themeModeProvider.notifier).state =
              dark ? ThemeMode.light : ThemeMode.dark,
          child: Row(
            children: [
              Icon(
                dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: AppSizes.iconSm,
                color: t.text.secondary,
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(dark ? 'Light theme' : 'Dark theme', style: text.bodyMedium),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: onLogout,
          child: Row(
            children: [
              Icon(Icons.logout, size: AppSizes.iconSm, color: t.status.danger.solid),
              const SizedBox(width: AppSpacing.x2),
              Text('Log out', style: text.bodyMedium?.copyWith(color: t.status.danger.solid)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: AppSpacing.x2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                role == StaffRole.security ? 'Security' : 'Administrator',
                style: text.labelSmall?.copyWith(color: t.text.tertiary),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.x1),
          Icon(Icons.expand_more, size: AppSizes.iconSm, color: t.text.tertiary),
        ],
      ),
    );
  }
}

// ── Compact (phone) drawer ───────────────────────────────────────────────────

class _DrawerNav extends StatelessWidget {
  const _DrawerNav({
    required this.groups,
    required this.location,
    required this.email,
    required this.onSelect,
    required this.onLogout,
  });

  final List<NavGroup> groups;
  final String location;
  final String? email;
  final ValueChanged<String> onSelect;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(AppSpacing.x4),
          child: _BrandMark(),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final group in groups) ...[
                if (group.label case final label?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x4, AppSpacing.x4, AppSpacing.x4, AppSpacing.x1),
                    child: Text(
                      label.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: t.text.tertiary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                for (final item in group.items)
                  ListTile(
                    leading: Icon(
                      location.startsWith(item.route) ? item.selectedIcon : item.icon,
                      color: location.startsWith(item.route)
                          ? t.brand.primary
                          : t.text.secondary,
                    ),
                    title: Text(
                      item.label,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: location.startsWith(item.route)
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    selected: location.startsWith(item.route),
                    selectedTileColor: t.brand.subtle,
                    onTap: () => onSelect(item.route),
                  ),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: t.border.normal),
        ListTile(
          leading: Icon(Icons.logout, color: t.status.danger.solid),
          title: Text('Log out', style: text.bodyMedium?.copyWith(color: t.status.danger.solid)),
          onTap: onLogout,
        ),
      ],
    );
  }
}
