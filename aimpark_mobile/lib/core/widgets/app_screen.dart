import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The screen skeleton every page sits in: canvas background, a safe area, and
/// either a flat app bar or an inline title.
///
/// Eighteen screens repeated `Scaffold(backgroundColor: AppColors.bgPage,
/// appBar: AppBar(backgroundColor: AppColors.bgPage, elevation: 0, title:
/// Text('...', style: AppTextStyles.h3)))` verbatim. That is how the canvas
/// colour ended up hardcoded in eighteen files, and it is why the app could not
/// have a dark mode without touching every one of them. Everything now goes
/// through here, so a new screen is aligned for free.
///
/// Do not reintroduce a bare `Scaffold`: the canvas must come from
/// `t.surface.canvas` or the screen will be the one white rectangle in an
/// otherwise dark app.
///
/// Two title styles, and the difference is not cosmetic:
///
/// * [AppScreen] — an app bar with a back arrow. For anything pushed onto the
///   stack, where the user needs a way out.
/// * [AppScreen.tab] — no app bar; the title scrolls with the content as its
///   first line. For the four bottom-nav destinations, which have nowhere to go
///   back *to*, and where a fixed bar would spend 56dp saying so.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.body,
    this.title,
    this.actions = const [],
    this.floatingActionButton,
    this.bottomBar,
    this.showBack = true,
    this.onBack,
    this.background,
  }) : _inline = false;

  /// A bottom-nav destination: no app bar, no back arrow.
  const AppScreen.tab({
    super.key,
    required this.body,
    this.floatingActionButton,
    this.bottomBar,
    this.background,
  })  : title = null,
        actions = const [],
        showBack = false,
        onBack = null,
        _inline = true;

  final Widget body;

  /// Shown in the app bar. Null renders a bar with only the back arrow, which
  /// is right for a screen whose content carries its own heading.
  final String? title;

  final List<Widget> actions;
  final Widget? floatingActionButton;

  /// Pinned below [body] — a submit button that must stay reachable while the
  /// content above it scrolls.
  final Widget? bottomBar;

  final bool showBack;

  /// Where the back arrow goes.
  ///
  /// Needed by any screen reached with `go` rather than `push`: there is no
  /// route beneath it, so Flutter's automatic back arrow renders and then does
  /// nothing when tapped. Sign-in is the case — it is entered with `go` from
  /// the welcome screen and has to `go` back.
  final VoidCallback? onBack;

  /// Overrides the canvas. Only for screens that are deliberately a different
  /// surface, such as the welcome screen sitting on card white.
  final Color? background;

  final bool _inline;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: background ?? t.surface.canvas,
      appBar: _inline
          ? null
          : AppBar(
              automaticallyImplyLeading: showBack && onBack == null,
              leading: onBack == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onBack,
                      tooltip: 'Back',
                    ),
              backgroundColor: background ?? t.surface.canvas,
              title: title == null ? null : Text(title!),
              actions: actions,
            ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: SafeArea(
        // The app bar already consumed the top inset; consuming it twice adds a
        // visible gap under the bar on notched phones.
        top: _inline,
        child: Align(
          alignment: Alignment.topCenter,
          // The design is drawn at 412dp. Left unbounded, every card stretches
          // to whatever the window happens to be — on a desktop build a payment
          // row becomes a metre of white with an amount marooned at the far
          // right. [AppSizes.contentMaxWidth] was defined for exactly this and
          // had never been applied anywhere; this is the one place that reaches
          // every screen at once.
          //
          // It is a no-op on a phone, where the viewport is already narrower.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.contentMaxWidth,
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// The bar that holds a screen's one committing action, pinned above the
/// keyboard and the home indicator.
///
/// For [AppScreen.bottomBar]. A submit button that lives at the end of a long
/// form is a button the user has to go and find after they have finished
/// filling the form in — and on the incident report, which is a category grid,
/// three fields and three photo slots long, "find it" meant a scroll.
///
/// It draws its own surface and hairline so the content scrolling underneath
/// passes behind something solid rather than up to the button's edge.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: t.surface.canvas,
        border: Border(top: BorderSide(color: t.border.subtle)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.md,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The standard padding for a screen's scrolling content.
///
/// Extra room at the bottom so the last row clears the bottom nav and the home
/// indicator — three screens had a final card you could not fully see.
const EdgeInsets kScreenListPadding = EdgeInsets.fromLTRB(
  AppSpacing.screenPadding,
  AppSpacing.screenPadding,
  AppSpacing.screenPadding,
  AppSpacing.listBottomPadding,
);

/// A vertically centred, width-capped, scrollable column.
///
/// The shape of every screen that is a single form rather than a list —
/// welcome, sign-in, the email and OTP steps. Four screens each built their own
/// `Center` + `SingleChildScrollView` + `ConstrainedBox(maxWidth: 400)`, and
/// two of them left the cap off, so the sign-in fields stretched edge to edge
/// on a tablet.
///
/// Scrollable rather than a plain `Center`: a form that fits comfortably with
/// the keyboard down will not fit with it up, and a `Column` that overflows
/// paints the yellow stripes rather than scrolling.
class AppFormBody extends StatelessWidget {
  const AppFormBody({
    super.key,
    required this.children,
    this.maxWidth = 400,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final double maxWidth;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A heading above a group of rows, with optional trailing action.
///
/// Every screen was writing `Text('Quick Actions', style: AppTextStyles.h3)`
/// followed by a hand-picked `SizedBox`, and the gap underneath was 8 on four
/// screens and 12 on three others.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.headingGap),
  });

  final String title;
  final String? subtitle;

  /// A "See all" link or similar, aligned right of the title.
  final Widget? action;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // An eyebrow, not a heading. A section header's job is to separate two
        // groups of cards, and at 18px semibold it was competing with the card
        // titles inside the group it was meant to be labelling — so "Recent
        // activity" read louder than the sessions underneath it.
        Text(title.toUpperCase(), style: context.text.labelSmall),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.labelGap),
          Text(subtitle!, style: context.text.bodySmall),
        ],
      ],
    );

    return Padding(
      padding: padding,
      child: action == null
          ? titleBlock
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: AppSpacing.sm),
                action!,
              ],
            ),
    );
  }
}

/// A screen's own heading, rendered inline at the top of its content.
///
/// Distinct from [AppSectionHeader], which is an eyebrow that separates groups
/// *within* a screen. Both used to be the same widget, so shrinking section
/// headers to 11px uppercase also shrank "History" and "Alerts" — the titles of
/// two whole tabs — into captions.
///
/// Inline rather than in an [AppBar] because a tab has no app bar to put it in,
/// and because the design scrolls the title away with the content instead of
/// pinning it.
class AppScreenTitle extends StatelessWidget {
  const AppScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
  });

  final String title;
  final String? subtitle;

  /// Sits to the trailing side of the title — an avatar button, a refresh.
  final Widget? action;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: context.text.headlineLarge),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.labelGap),
          Text(subtitle!, style: context.text.bodyMedium?.copyWith(
            color: context.tokens.text.secondary,
          )),
        ],
      ],
    );

    return Padding(
      padding: padding,
      child: action == null
          ? titleBlock
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: AppSpacing.sm),
                action!,
              ],
            ),
    );
  }
}
