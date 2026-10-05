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
import 'site_update_banner.dart';
import 'visitor_registration_watcher.dart';

/// The panel's frame: a grouped indigo sidebar on the left, and a slim top bar
/// over the page carrying where-you-are and the account controls.
///
/// Replaces the two-tier pill nav. That nav showed only group names and hid
/// every page behind a second row, which clipped at 1024px and dropped whole
/// groups off-screen at 768px. A sidebar lists every destination this account
/// may open, all at once, with a count beside wherever work is waiting.
///
/// Below [Breakpoints.medium] the sidebar shrinks to an icon rail; below
/// [Breakpoints.compact] it moves into a drawer behind a hamburger.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  /// Manual collapse. Below the medium breakpoint the sidebar collapses
  /// regardless, so this only decides the wide case.
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
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

    // Wraps both layouts at the same spot, so resizing the window does not
    // drop a visitor form that is open.
    return VisitorRegistrationWatcher(
      child: _frame(context, location, email, groups),
    );
  }

  Widget _frame(BuildContext context, String location, String? email,
      List<NavGroup> groups) {
    final t = context.tokens;

    // On a phone even the icon rail would leave almost nothing for content, so
    // navigation moves behind a hamburger instead.
    if (context.isCompact) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: t.surface.card,
          foregroundColor: t.text.primary,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: Border(bottom: BorderSide(color: t.border.normal)),
          titleSpacing: 0,
          // The breadcrumb, not the page name: the page already shows its own
          // title right below, and repeating it read as a stutter.
          title: _Breadcrumb(groups: groups, location: location),
          actions: [
            _NotificationBell(active: _matches(location, '/notifications')),
            _AccountChip(email: email, onLogout: _logout, compact: true),
            const SizedBox(width: AppSpacing.x3),
          ],
        ),
        drawer: Drawer(
          backgroundColor: t.surface.sidebar,
          child: SafeArea(
            child: _SidebarBody(
              collapsed: false,
              location: location,
              groups: groups,
              onSelect: (route) {
                Navigator.pop(context);
                context.go(route);
              },
              // The drawer is already dismissible; a collapse toggle inside it
              // would be a control with nothing to do.
              onToggleCollapse: null,
            ),
          ),
        ),
        body: Column(
          children: [
            const SiteUpdateBanner(),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    final collapsed = _collapsed || context.isMedium;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            width: collapsed
                ? AppSizes.sidebarCollapsed
                : AppSizes.sidebarExpanded,
            color: t.surface.sidebar,
            child: _SidebarBody(
              collapsed: collapsed,
              location: location,
              groups: groups,
              onSelect: context.go,
              // Forced collapse isn't the admin's choice, so don't offer a
              // toggle that the next resize would override.
              onToggleCollapse: context.isMedium
                  ? null
                  : () => setState(() => _collapsed = !_collapsed),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  groups: groups,
                  location: location,
                  email: email,
                  onLogout: _logout,
                ),
                const SiteUpdateBanner(),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Confirms before signing out.
  ///
  /// "Log out" sits one item below "Dark theme" in the same small menu, so a
  /// mis-click ended the session and threw away whatever queue the reviewer was
  /// part-way through. The dialog costs a keystroke and prevents that.
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

/// Whether [location] is [route] or a page beneath it (`/users/42`).
///
/// A bare `startsWith` is not enough: `/gate-devices` starts with `/gate`, so a
/// guard on Devices saw Gate Check highlighted instead.
bool _matches(String location, String route) =>
    location == route || location.startsWith('$route/');

/// The group and destination [location] belongs to, or null if none matches.
(NavGroup, NavItem)? _destinationFor(String location, List<NavGroup> groups) {
  for (final group in groups) {
    for (final item in group.items) {
      if (_matches(location, item.route)) return (group, item);
    }
  }
  return null;
}

/// Work waiting behind a destination, or null if it does not track any.
///
/// One lookup for the sidebar, the rail and the drawer, so a count can never
/// show in one of them and not the others.
int? _navBadge(String route, WidgetRef ref) => switch (route) {
      // Appeals are only counted for somebody who may open them. Watching that
      // provider as Security fired a request the API answers with 403, on every
      // screen, because the sidebar is always mounted.
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

// ── Sidebar ─────────────────────────────────────────────────────────────────

/// The sidebar's contents, independent of what is holding them — the wide
/// layout puts this in a fixed-width column, the phone layout puts the very
/// same widget in a `Drawer`. That sharing is why the two can never drift.
///
/// Every destination stays visible under a static group title, so any page is
/// one click away. Collapsible groups were tried and dropped: they cost a
/// second click for every page outside the open group, which is most of them
/// for an admin jumping between queues all day.
class _SidebarBody extends StatelessWidget {
  const _SidebarBody({
    required this.collapsed,
    required this.location,
    required this.groups,
    required this.onSelect,
    required this.onToggleCollapse,
  });

  final bool collapsed;
  final String location;

  /// Already filtered to what this account may open — see `navGroupsFor`.
  final List<NavGroup> groups;
  final ValueChanged<String> onSelect;

  /// Null hides the collapse control entirely.
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final selected = _destinationFor(location, groups)?.$2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WorkspaceChip(
          collapsed: collapsed,
          onToggle: onToggleCollapse,
          onHome: () => onSelect('/dashboard'),
        ),
        Expanded(
          // Scrolls on its own, so a short window never pushes destinations
          // out of reach.
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in groups) ...[
                  if (group.label case final label?)
                    collapsed ? const _RailDivider() : _GroupLabel(label: label),
                  for (final item in group.items)
                    _NavTile(
                      item: item,
                      selected: identical(item, selected),
                      collapsed: collapsed,
                      onTap: () => onSelect(item.route),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The workspace identity block in the top-left: brand mark, which site this
/// is, and the control that collapses the sidebar.
class _WorkspaceChip extends StatelessWidget {
  const _WorkspaceChip({
    required this.collapsed,
    required this.onToggle,
    required this.onHome,
  });

  final bool collapsed;
  final VoidCallback? onToggle;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final mark = Tooltip(
      message: 'Overview',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onHome,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: t.brand.primary,
              borderRadius: AppRadii.smAll,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.local_parking,
              size: AppSizes.iconMd,
              color: t.text.onBrand,
            ),
          ),
        ),
      ),
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Column(
          children: [
            mark,
            if (onToggle != null) ...[
              const SizedBox(height: AppSpacing.x2),
              _SidebarIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Expand sidebar',
                onTap: onToggle!,
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4, AppSpacing.x4, AppSpacing.x2, AppSpacing.x2),
      child: Row(
        children: [
          mark,
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AimPark',
                  style: text.titleSmall?.copyWith(color: t.text.onDark),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'STI Baliuag',
                  style: text.labelSmall?.copyWith(color: t.text.onDarkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onToggle != null)
            _SidebarIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Collapse sidebar',
              onTap: onToggle!,
            ),
        ],
      ),
    );
  }
}

/// In the icon rail there is no room for group names, so the grouping is
/// carried by a rule instead — losing it entirely would leave a long stack of
/// identical-looking icons.
class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
      child: Divider(
          height: 1, thickness: 1, color: context.tokens.border.onSidebar),
    );
  }
}

/// A group's title above its destinations. Plain text, not a control — the
/// destinations under it are always showing.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4, AppSpacing.x3, AppSpacing.x4, AppSpacing.x1),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.tokens.text.onDarkMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

/// A destination. The selected state is an *inset* rounded block, not a
/// full-bleed bar: the 8px of sidebar left showing on either side is what makes
/// it read as a chip sitting in the rail rather than a highlighted table row.
class _NavTile extends ConsumerStatefulWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  ConsumerState<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends ConsumerState<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final badge = _navBadge(widget.item.route, ref);
    final hasWork = badge != null && badge > 0;

    final background = widget.selected
        ? t.surface.sidebarSelected
        : _hovered
            ? t.surface.sidebarHover
            : const Color(0x00000000);

    // Unselected labels at 70% white were reported as "barely noticeable", so
    // they sit at the subtle step; selected and hovered go to full white.
    final foreground =
        widget.selected || _hovered ? t.text.onDark : t.text.onDarkSubtle;

    final icon = Icon(
      widget.selected ? widget.item.selectedIcon : widget.item.icon,
      size: AppSizes.iconMd,
      color: foreground,
    );

    final tile = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      // 36: compact enough that the whole list fits a 900px-tall window, while
      // the inset selected block and full-white label keep it easy to spot.
      height: 36,
      padding: EdgeInsets.symmetric(
          horizontal: widget.collapsed ? 0 : AppSpacing.x2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        mainAxisAlignment: widget.collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          // Collapsed there is no room for a count, so the icon carries a dot
          // instead — enough to say "something is here".
          if (hasWork && widget.collapsed)
            Badge(
              smallSize: 8,
              backgroundColor: t.status.danger.solid,
              child: icon,
            )
          else
            icon,
          if (!widget.collapsed) ...[
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                widget.item.label,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            // The count, so the sidebar says where the work is without the
            // admin opening each page to find out.
            if (hasWork)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: t.status.danger.solid,
                  borderRadius: AppRadii.fullAll,
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: text.labelSmall?.copyWith(color: t.text.onDark),
                ),
              ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: hasWork
            ? '${widget.item.label}, $badge waiting'
            : widget.item.label,
        excludeSemantics: true,
        // InkWell rather than a bare GestureDetector, so the destination can be
        // reached with Tab and opened with Enter, and shows a focus highlight.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (h) => setState(() => _hovered = h),
            borderRadius: AppRadii.mdAll,
            hoverColor: const Color(0x00000000),
            splashColor: t.surface.sidebarHover,
            highlightColor: const Color(0x00000000),
            focusColor: t.surface.sidebarSelected,
            child: widget.collapsed
                // Collapsed, the icon is the only thing identifying the
                // destination, so the label has to be recoverable on hover.
                ? Tooltip(
                    message: widget.item.label,
                    preferBelow: false,
                    child: tile,
                  )
                : tile,
          ),
        ),
      ),
    );
  }
}

/// A small ghost button that reads correctly on the sidebar's dark surface —
/// `IconButton` would inherit the light theme's foreground and disappear.
class _SidebarIconButton extends StatefulWidget {
  const _SidebarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_SidebarIconButton> createState() => _SidebarIconButtonState();
}

class _SidebarIconButtonState extends State<_SidebarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Tooltip(
      message: widget.tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hovered = h),
          borderRadius: AppRadii.smAll,
          hoverColor: t.surface.sidebarHover,
          focusColor: t.surface.sidebarSelected,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              widget.icon,
              size: AppSizes.iconSm,
              color: _hovered ? t.text.onDark : t.text.onDarkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top bar ─────────────────────────────────────────────────────────────────

/// The slim bar above the page: where you are on the left, the inbox and the
/// account menu on the right. Navigation itself lives in the sidebar.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.groups,
    required this.location,
    required this.email,
    required this.onLogout,
  });

  final List<NavGroup> groups;
  final String location;
  final String? email;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      height: AppSizes.topBarHeight,
      padding: const EdgeInsets.only(
          left: AppSpacing.pagePadding, right: AppSpacing.x4),
      decoration: BoxDecoration(
        color: t.surface.card,
        border: Border(bottom: BorderSide(color: t.border.normal)),
      ),
      child: Row(
        children: [
          Expanded(child: _Breadcrumb(groups: groups, location: location)),
          const SizedBox(width: AppSpacing.x4),
          _NotificationBell(active: _matches(location, '/notifications')),
          const SizedBox(width: AppSpacing.x3),
          _AccountChip(email: email, onLogout: onLogout),
        ],
      ),
    );
  }
}

/// `Group › Page` for the current route — Overview, which belongs to no group,
/// shows on its own. Small and quiet on purpose: the page's own title, just
/// below, is the heading; this only says where in the map that page sits.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.groups, required this.location});

  final List<NavGroup> groups;
  final String location;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final match = _destinationFor(location, groups);
    if (match == null) return const SizedBox.shrink();
    final (group, item) = match;

    final page = Text(
      item.label,
      overflow: TextOverflow.ellipsis,
      style: text.bodyMedium?.copyWith(
        color: t.text.primary,
        fontWeight: FontWeight.w600,
      ),
    );

    if (group.label == null) return page;

    return Semantics(
      label: '${group.label}, ${item.label}',
      excludeSemantics: true,
      child: Row(
        children: [
          Text(
            group.label!,
            style: text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
            child: Icon(Icons.chevron_right,
                size: AppSizes.iconSm, color: t.text.tertiary),
          ),
          Flexible(child: page),
        ],
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
  const _AccountChip({
    required this.email,
    required this.onLogout,
    this.compact = false,
  });

  final String? email;
  final Future<void> Function() onLogout;

  /// Avatar only, for the phone app bar where the name and role do not fit.
  final bool compact;

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
      position: PopupMenuPosition.under,
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
      child: compact
          ? avatar
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(width: AppSpacing.x2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name,
                        style: text.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      role == StaffRole.security ? 'Security' : 'Administrator',
                      style: text.labelSmall?.copyWith(color: t.text.tertiary),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.x1),
                Icon(Icons.expand_more,
                    size: AppSizes.iconSm, color: t.text.tertiary),
              ],
            ),
    );
  }
}
