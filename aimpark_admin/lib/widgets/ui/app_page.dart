import 'package:flutter/material.dart';

import '../../core/utils/responsive.dart';
import '../../theme/theme.dart';

/// The page skeleton every screen sits in: canvas background, consistent outer
/// padding, a title block, and a body that fills the rest.
///
/// Screens used to repeat `Scaffold(backgroundColor: const Color(0xFFF5F7FA),
/// body: Padding(padding: const EdgeInsets.all(24), ...))` verbatim, which is
/// how the canvas colour ended up hardcoded in eleven files — and why half the
/// panel was unreadable in dark mode. Every screen now goes through this, so a
/// new one is aligned with the rest for free. Do not reintroduce a bare
/// `Scaffold`: the canvas colour must come from `t.surface.canvas`.
///
/// ```dart
/// AppPage(
///   title: 'Payments',
///   subtitle: 'Outstanding balances and settled receipts.',
///   actions: [FilledButton.icon(...)],
///   body: AsyncView(...),
/// );
/// ```
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.toolbar,
    this.scrollable = false,
    this.maxWidth = AppSizes.contentMaxWidth,
    this.onBack,
  });

  final String title;
  final String? subtitle;

  /// Set on a detail screen reached from a list. The sidebar can get you back
  /// to the *module*, but not to the filtered queue you were working through,
  /// which is why a detail page still needs its own way out.
  final VoidCallback? onBack;

  /// Primary controls for the page, aligned right of the title.
  final List<Widget> actions;

  /// An optional second row — filters, search, tabs — below the title block.
  final Widget? toolbar;

  final Widget body;

  /// Set when [body] is a column of cards rather than something that manages
  /// its own scrolling (a table, a list).
  final bool scrollable;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pad = context.isCompact ? AppSpacing.x4 : AppSpacing.pagePadding;

    final header = AppPageHeader(
      title: title,
      subtitle: subtitle,
      actions: actions,
      onBack: onBack,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (toolbar != null) ...[
          const SizedBox(height: AppSpacing.x4),
          toolbar!,
        ],
        SizedBox(height: AppSpacing.headingGap),
        if (scrollable)
          Flexible(child: SingleChildScrollView(child: body))
        else
          Expanded(child: body),
      ],
    );

    return Scaffold(
      backgroundColor: t.surface.canvas,
      body: Padding(
        padding: EdgeInsets.all(pad),
        child: Align(
          // Centred, not left-aligned: the cap is there to stop a line of text
          // running the width of a monitor, and pinning it left spends the
          // whole remainder as one dead strip against the right edge.
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Title, optional one-line description, and right-aligned actions.
///
/// Below the compact breakpoint the actions wrap onto their own line — a plain
/// `Row` with a `Spacer` cannot shrink and paints the overflow stripes instead.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// See [AppPage.onBack].
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sits above the title rather than beside it: a back control level with
        // a 24px headline has to be square and large to not look like a bullet,
        // and at that size it competes with the page's real actions.
        if (onBack != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x1),
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: AppSizes.iconSm),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                foregroundColor: t.text.secondary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                minimumSize: const Size(0, AppSizes.controlHeightSm),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: text.bodySmall,
              ),
            ),
          ),
        Text(title, style: text.headlineSmall),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x1),
            child: Text(
              subtitle!,
              style: text.bodyMedium?.copyWith(color: t.text.secondary),
            ),
          ),
      ],
    );

    if (actions.isEmpty) return titleBlock;

    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: AppSpacing.x3),
          Wrap(
            spacing: AppSpacing.controlGap,
            runSpacing: AppSpacing.controlGap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: AppSpacing.x4),
        Wrap(
          spacing: AppSpacing.controlGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        ),
      ],
    );
  }
}
