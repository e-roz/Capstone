import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/incident_stage.dart';

/// Where a report is on its way: Submitted → Under review → Resolved.
///
/// Three steps, drawn as a line with a node on each. Steps already reached are
/// filled in the brand colour with a tick, the current one wears its stage's own
/// colour and is labelled in bold, and the ones still ahead are an empty ring. A
/// report that ends as *dismissed* shows its last step as "Closed", in grey.
///
/// A withdrawn report is not on this path at all — the reporter stepped off it —
/// so it gets no tracker; the caller shows a plain end-state instead.
///
/// There is no history behind this. The server keeps the date a report was made
/// and the date it last changed, and nothing in between, so the tracker shows only
/// where it stands and never a made-up date for each step.
class IncidentProgress extends StatelessWidget {
  const IncidentProgress({super.key, required this.stage})
      : assert(stage != IncidentStage.withdrawn);

  final IncidentStage stage;

  /// How many of the three steps are reached, counting the current one.
  int get _reached => switch (stage) {
        IncidentStage.submitted => 1,
        IncidentStage.underReview => 2,
        IncidentStage.resolved || IncidentStage.dismissed => 3,
        IncidentStage.withdrawn => 0,
      };

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Submitted',
      'Under review',
      stage == IncidentStage.dismissed ? 'Closed' : 'Resolved',
    ];

    return Semantics(
      container: true,
      label: 'Progress: ${stage.label}. Step $_reached of 3.',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0)
                  Expanded(child: _Connector(filled: i < _reached)),
                _Node(
                  state: i + 1 < _reached
                      ? _NodeState.done
                      : i + 1 == _reached
                          ? _NodeState.current
                          : _NodeState.ahead,
                  intent: stage.intent,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Text(
                    labels[i],
                    textAlign: i == 0
                        ? TextAlign.start
                        : i == 2
                            ? TextAlign.end
                            : TextAlign.center,
                    style: context.text.labelMedium?.copyWith(
                      color: i + 1 == _reached
                          ? context.tokens.text.primary
                          : context.tokens.text.secondary,
                      fontWeight:
                          i + 1 == _reached ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _NodeState { done, current, ahead }

class _Node extends StatelessWidget {
  const _Node({required this.state, required this.intent});

  final _NodeState state;
  final StatusIntent intent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);

    return switch (state) {
      _NodeState.done => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: t.brand.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded,
              size: AppSizes.iconMd, color: t.brand.onSolid),
        ),
      _NodeState.current => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: c.solid,
            shape: BoxShape.circle,
            // A soft halo in the stage's colour, so "you are here" is the
            // loudest thing on the line.
            boxShadow: [
              BoxShadow(color: c.solid.withValues(alpha: 0.25), spreadRadius: 4),
            ],
          ),
          child: Icon(Icons.circle, size: 10, color: t.brand.onSolid),
        ),
      _NodeState.ahead => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: t.surface.card,
            shape: BoxShape.circle,
            border: Border.all(color: t.border.control, width: 2),
          ),
        ),
    };
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: filled ? t.brand.primary : t.border.normal,
        borderRadius: AppRadius.fullAll,
      ),
    );
  }
}
