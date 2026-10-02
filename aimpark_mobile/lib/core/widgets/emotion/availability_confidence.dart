import 'package:flutter/material.dart';

import '../../theme/emotion/emotion.dart';

/// The three-state "availability confidence" concept from brief §3, shared
/// by every brief §8 component that shows a lot's fullness — this header,
/// and later the slot map cell. Mapping a raw slot count onto one of these
/// three is a domain decision (thresholds likely differ per lot), so it
/// stays out of this file and out of whatever widget consumes it; each only
/// renders whichever value it's handed.
enum AvailabilityConfidence {
  /// Comfortable — plenty of space.
  open,

  /// Filling up — the emotional state; the user decides whether to hurry.
  /// The most important state in the system; see brief §3.
  filling,

  /// Full — muted brick, not alarm red.
  full;

  /// The colour brief §3 assigns to this state. Status only (see
  /// [EmotionTokens.avail]'s doc comment) — never bind this to anything
  /// tappable.
  Color colorOf(EmotionTokens e) => switch (this) {
        AvailabilityConfidence.open => e.avail.open,
        AvailabilityConfidence.filling => e.avail.filling,
        AvailabilityConfidence.full => e.avail.full,
      };

  /// A fixed, one/two-word state name — "Filling up" is brief §7's own
  /// wording. Unlike a full status sentence (counts, pluralisation), this
  /// carries no variable data, so unlike [AvailabilityHeader.statusLine] it
  /// is safe to own here rather than push out to every caller. Exists so a
  /// small widget (the slot map cell) can satisfy brief §9's "pair every
  /// availability colour with a label" without needing a whole sentence.
  String get label => switch (this) {
        AvailabilityConfidence.open => 'Open',
        AvailabilityConfidence.filling => 'Filling up',
        AvailabilityConfidence.full => 'Full',
      };
}
