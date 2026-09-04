import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'app_card.dart';
import 'app_data_table.dart';

/// Skeleton loading states — the shape a screen will take, filled with
/// shimmering placeholder bones, shown in place of [AppLoadingState]'s spinner
/// while an [AsyncView] is waiting on its first page of data.
///
/// Pick the variant that matches what `data:` actually builds ([SkeletonTable]
/// for an [AppDataTable], [SkeletonMetricRow] for a [MetricCard] row,
/// [SkeletonList] for tiles, [SkeletonDetail] for a form-shaped page,
/// [SkeletonBlock] for anything else, such as a chart). Every one of them
/// already wraps its bones in [AppShimmer] — don't nest another one around
/// them, and don't wrap real chrome (an [AppCard]'s or [AppCardSurface]'s own
/// background/border/shadow) inside one either: [AppShimmer] recolours
/// everything with alpha in its subtree, so a card's opaque background caught
/// inside it gets painted over by the sweep too and the card reads as one
/// undifferentiated blob instead of distinct bones sitting on a static card.

/// A gradient band that sweeps left to right, recolouring whatever opaque
/// shapes sit beneath it — normally a cluster of [SkeletonBone]s — so they
/// read as "loading" rather than as flat static grey boxes. Every composite
/// below starts its own [AppShimmer] at roughly the same moment (initial
/// build), which is enough for multiple instances on one screen to stay in
/// visible sync without threading a single controller across widgets.
class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // A gradient band sweeps from -1..2 across the bones' own alpha shape
        // (srcATop keeps their rounded-rect alpha, replaces the colour), so
        // every bone lights up together as the band passes over it.
        final dx = _controller.value * 3 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(dx - 1, 0),
            end: Alignment(dx + 1, 0),
            colors: [t.surface.muted, t.surface.hover, t.surface.muted],
            stops: const [0.4, 0.5, 0.6],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// One placeholder shape — a rounded rectangle standing in for a line of text,
/// an icon, or any other bit of content not yet loaded.
class SkeletonBone extends StatelessWidget {
  const SkeletonBone({
    super.key,
    this.width,
    this.height = 12,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: t.surface.muted,
        borderRadius: borderRadius ?? BorderRadius.circular(height / 3),
      ),
    );
  }
}

/// A rectangular placeholder for content with no finer shape worth drawing —
/// a chart, a map, an image.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.height = 220, this.borderRadius});

  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SkeletonBone(
        width: double.infinity,
        height: height,
        borderRadius: borderRadius ?? AppRadii.mdAll,
      ),
    );
  }
}

/// Stands in for an [AppDataTable]: a header bar plus [rows] of cells sized to
/// [columnWidths] (or a sensible default — a wide first column, narrower
/// ones after), inside the same [AppCardSurface] chrome the real table uses.
class SkeletonTable extends StatelessWidget {
  const SkeletonTable({
    super.key,
    this.columns = 5,
    this.rows = 8,
    this.columnWidths,
  });

  final int columns;
  final int rows;
  final List<double>? columnWidths;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final widths = columnWidths ??
        List.generate(columns, (i) => i == 0 ? 150.0 : 90.0);

    // The real AppDataTable scrolls horizontally instead of shrinking its
    // columns below their natural width, so the skeleton has to make the same
    // trade — a fixed-width Row with no scroll parent overflows the moment the
    // page is narrower than the sum of these column widths.
    final contentWidth =
        widths.fold(0.0, (sum, w) => sum + w) + AppSpacing.x6 * widths.length;

    Widget row({required bool header}) => Row(
          children: [
            for (final w in widths) ...[
              SkeletonBone(width: w, height: header ? 10 : 12),
              const SizedBox(width: AppSpacing.x6),
            ],
          ],
        );

    return AppCardSurface(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: contentWidth),
          // The card's own background/border/shadow live in AppCardSurface,
          // outside this shimmer — only the header bar and the row bones
          // beneath it are bones, so only they get swept.
          child: AppShimmer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: AppSizes.tableHeaderHeight,
                  color: t.surface.muted,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.cellPaddingX),
                  child: row(header: true),
                ),
                for (var r = 0; r < rows; r++)
                  Container(
                    height: AppSizes.tableRowHeight,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.cellPaddingX),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: t.border.subtle)),
                    ),
                    child: row(header: false),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stands in for a row of [MetricCard]s — an icon square, a value-sized bone
/// and a label-sized bone, [count] of them wrapped the way the real row wraps.
class SkeletonMetricRow extends StatelessWidget {
  const SkeletonMetricRow({
    super.key,
    this.count = 4,
    this.width = AppSizes.metricCardWidth,
  });

  final int count;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.gutter,
      runSpacing: AppSpacing.gutter,
      children: [
        for (var i = 0; i < count; i++)
          AppCard(
            width: width,
            // Each tile's own AppCard background/border/shadow sits outside
            // its shimmer, so the card reads as a static tile with three
            // distinct bones sweeping across it, not one blurred rectangle.
            child: AppShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const SkeletonBone(
                        width: 32,
                        height: 32,
                        borderRadius: AppRadii.smAll,
                      ),
                      const Spacer(),
                      const SkeletonBone(width: 48, height: 22),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  const SkeletonBone(width: 90, height: 10),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Stands in for a list of tiles — a leading icon circle plus a title and
/// subtitle line — for screens whose loaded content is [ListTile]-shaped
/// rather than tabular (notifications, activity feeds).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCardSurface(
      // The surface's own background/border/shadow sits outside this
      // shimmer — only the per-row bones inside get swept.
      child: AppShimmer(
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardPadding,
                  vertical: AppSpacing.x3,
                ),
                decoration: i == 0
                    ? null
                    : BoxDecoration(
                        border:
                            Border(top: BorderSide(color: t.border.subtle)),
                      ),
                child: Row(
                  children: [
                    const SkeletonBone(
                      width: 36,
                      height: 36,
                      borderRadius: AppRadii.fullAll,
                    ),
                    const SizedBox(width: AppSpacing.x4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBone(width: 240 - (i % 3) * 30, height: 12),
                          const SizedBox(height: AppSpacing.x2),
                          SkeletonBone(width: 140 - (i % 2) * 20, height: 10),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x4),
                    const SkeletonBone(width: 60, height: 10),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for a form-shaped detail page — [sections] card-like groups, each
/// with a title bone and [fieldsPerSection] label/value pairs. Matches the
/// [AppSectionCard] rhythm the real detail screens use.
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({
    super.key,
    this.sections = 2,
    this.fieldsPerSection = 4,
  });

  final int sections;
  final int fieldsPerSection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var s = 0; s < sections; s++) ...[
          if (s > 0) const SizedBox(height: AppSpacing.sectionGap),
          AppCard(
            // Each section's own AppCard chrome sits outside its shimmer, for
            // the same reason as SkeletonMetricRow above.
            child: AppShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBone(width: 140, height: 16),
                  const SizedBox(height: AppSpacing.x5),
                  for (var f = 0; f < fieldsPerSection; f++) ...[
                    if (f > 0) const SizedBox(height: AppSpacing.x4),
                    SkeletonBone(width: 80 + (f % 3) * 20, height: 10),
                    const SizedBox(height: AppSpacing.x2),
                    SkeletonBone(
                      width: f.isEven ? 220.0 : 160.0,
                      height: 14,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
