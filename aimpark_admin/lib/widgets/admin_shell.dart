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
    final items = [for (final g in groups) ...g.items];
    final selected = _selectedIndex(location, items);

    // On a phone a sidebar would leave almost nothing for content, so
    // navigation moves behind a hamburger instead.
    if (context.isCompact) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: t.surface.sidebar,
          foregroundColor: t.text.onDark,
          elevation: 0,
          title: Text(
            items[selected].label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: t.text.onDark),
          ),
        ),
        drawer: Drawer(
          backgroundColor: t.surface.sidebar,
          child: SafeArea(
            child: _SidebarBody(
              collapsed: false,
              selected: selected,
              email: email,
              groups: groups,
              onSelect: (route) {
                Navigator.pop(context);
                context.go(route);
              },
              onLogout: _logout,
              // The drawer is already dismissible; a collapse toggle inside it
              // would be a control with nothing to do.
              onToggleCollapse: null,
            ),
          ),
        ),
        body: widget.child,
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
              selected: selected,
              email: email,
              groups: groups,
              onSelect: context.go,
              onLogout: _logout,
              // Forced collapse isn't the admin's choice, so don't offer a
              // toggle that the next resize would override.
              onToggleCollapse: context.isMedium
                  ? null
                  : () => setState(() => _collapsed = !_collapsed),
            ),
          ),
          Expanded(child: widget.child),
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
        content: const SizedBox(
          width: 360,
          child: Text('You will need to sign in again to get back into the '
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

  int _selectedIndex(String location, List<NavItem> items) {
    // Longest-prefix first would matter if routes nested; they don't here.
    for (var i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].route)) return i;
    }
    return 0; // default to the first destination this role has
  }
}

/// The sidebar's contents, independent of what is holding them — the wide
/// layout puts this in a fixed-width column, the phone layout puts the very
/// same widget in a `Drawer`. That sharing is why the two can never drift.
class _SidebarBody extends StatelessWidget {
  const _SidebarBody({
    required this.collapsed,
    required this.selected,
    required this.email,
    required this.groups,
    required this.onSelect,
    required this.onLogout,
    required this.onToggleCollapse,
  });

  final bool collapsed;
  final int selected;
  final String? email;

  /// Already filtered to what this account may open — see `navGroupsFor`.
  final List<NavGroup> groups;
  final ValueChanged<String> onSelect;
  final Future<void> Function() onLogout;

  /// Null hides the collapse control entirely.
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // The flat index the shell computed has to be matched back up with the
    // grouped structure, counting destinations as they are laid out.
    var index = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WorkspaceChip(collapsed: collapsed, onToggle: onToggleCollapse),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.x2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in groups) ...[
                  if (group.label case final label?)
                    _GroupLabel(label: label, collapsed: collapsed)
                  else
                    const SizedBox(height: AppSpacing.x2),
                  for (final item in group.items)
                    _NavTile(
                      item: item,
                      selected: index++ == selected,
                      collapsed: collapsed,
                      onTap: () => onSelect(item.route),
                    ),
                ],
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: t.border.onSidebar),
        _UserChip(collapsed: collapsed, email: email, onLogout: onLogout),
      ],
    );
  }
}

/// The workspace identity block every workspace tool puts in the top-left: brand
/// mark, who you are looking at, and the control that collapses the rail.
class _WorkspaceChip extends StatelessWidget {
  const _WorkspaceChip({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final mark = Container(
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
          AppSpacing.x3, AppSpacing.x4, AppSpacing.x2, AppSpacing.x4),
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

/// Section heading above a run of destinations. Collapsed, there is no room for
/// words, so the grouping is carried by a rule instead — losing the grouping
/// entirely would leave ten identical icons in a stack.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label, required this.collapsed});

  final String label;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
        child: Divider(height: 1, thickness: 1, color: t.border.onSidebar),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4, AppSpacing.x4, AppSpacing.x4, AppSpacing.x1),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: t.text.onDarkMuted,
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

  /// Work waiting behind this destination, or null if it does not track any.
  ///
  /// Looked up by route inside the tile rather than passed in, so the sidebar's
  /// builder stays a plain loop over [navGroups] and adding a badge to another
  /// destination is one case here.
  int? get _badge => switch (widget.item.route) {
        // Appeals are only counted for somebody who may open them. Watching
        // that provider as Security fired a request the API answers with 403,
        // on every screen, because the sidebar is always mounted.
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final badge = _badge;
    final hasWork = badge != null && badge > 0;

    final background = widget.selected
        ? t.surface.sidebarSelected
        : _hovered
            ? t.surface.sidebarHover
            : const Color(0x00000000);

    // Unselected labels sat at 70% white, which is where "barely noticeable"
    // came from. Selected stays pure white so the current page still stands out.
    final foreground =
        widget.selected || _hovered ? t.text.onDark : t.text.onDarkSubtle;

    final tile = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      // 40 rather than 36, with 2px between: the rail was legible but tiring
      // to scan, and testers reported the destinations as "barely noticeable".
      height: 40,
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2, vertical: 2),
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
          // instead — enough to say "something is here", which is the whole job
          // of the rail in that state.
          hasWork && widget.collapsed
              ? Badge(
                  smallSize: 8,
                  backgroundColor: t.status.danger.solid,
                  child: Icon(
                    widget.selected
                        ? widget.item.selectedIcon
                        : widget.item.icon,
                    size: AppSizes.iconMd,
                    color: foreground,
                  ),
                )
              : Icon(
                  widget.selected ? widget.item.selectedIcon : widget.item.icon,
                  size: AppSizes.iconMd,
                  color: foreground,
                ),
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
            // The count, so the rail says where the work is without the admin
            // opening each module to find out.
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          selected: widget.selected,
          label: widget.item.label,
          child: widget.collapsed
              // Collapsed, the icon is the only thing identifying the
              // destination, so the label has to be recoverable on hover.
              ? Tooltip(message: widget.item.label, child: tile)
              : tile,
        ),
      ),
    );
  }
}

/// Who is signed in, pinned to the bottom, with the account menu behind it.
class _UserChip extends ConsumerWidget {
  const _UserChip({
    required this.collapsed,
    required this.email,
    required this.onLogout,
  });

  final bool collapsed;
  final String? email;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;

    // The token carries an email and a role, never a display name, so the chip
    // shows the part of the address before the @ and falls back to the role.
    final address = email ?? '';
    final handle = address.contains('@') ? address.split('@').first : address;
    final name = handle.isEmpty ? 'Administrator' : handle;
    final initial = name.substring(0, 1).toUpperCase();

    final avatar = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: t.surface.sidebarSelected,
        borderRadius: AppRadii.fullAll,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: text.labelSmall?.copyWith(
          color: t.text.onDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return PopupMenuButton<void>(
      tooltip: 'Account',
      offset: const Offset(0, -8),
      color: t.surface.overlay,
      position: PopupMenuPosition.over,
      itemBuilder: (context) => [
        // An icon beside the address so the row reads as "this is your account"
        // rather than as a stray line of grey text above the controls.
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
              Icon(Icons.logout,
                  size: AppSizes.iconSm, color: t.status.danger.solid),
              const SizedBox(width: AppSpacing.x2),
              Text(
                'Log out',
                style: text.bodyMedium?.copyWith(color: t.status.danger.solid),
              ),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 0 : AppSpacing.x3,
          vertical: AppSpacing.x3,
        ),
        child: collapsed
            ? Center(child: Tooltip(message: name, child: avatar))
            : Row(
                children: [
                  avatar,
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: t.text.onDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // A caret says "this opens a menu"; the ellipsis reads as
                  // "there is more text here that did not fit".
                  Icon(Icons.expand_less,
                      size: AppSizes.iconMd, color: t.text.onDarkMuted),
                ],
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered ? t.surface.sidebarHover : const Color(0x00000000),
              borderRadius: AppRadii.smAll,
            ),
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
