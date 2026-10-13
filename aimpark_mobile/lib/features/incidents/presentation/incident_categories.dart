import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The categories a user can file a report under, by the name the API expects
/// mapped to the label shown on screen.
///
/// The key is what gets sent — sending the label instead is what made every
/// category except "Other" fail server-side validation. Kept in one place so the
/// report form, the edit form and the lists cannot drift into offering, or
/// showing, different words for the same thing.
const kIncidentCategories = <String, String>{
  'Vandalism': 'Vandalism',
  'Theft': 'Theft',
  'Accident': 'Accident',
  'BlockedSlot': 'Blocked Slot',
  'SuspiciousActivity': 'Suspicious Activity',
  'Other': 'Other',
};

/// One icon per category, for the chips and for the rows in the list.
const kIncidentCategoryIcons = <String, IconData>{
  'Vandalism': Icons.format_paint_rounded,
  'Theft': Icons.shopping_bag_rounded,
  'Accident': Icons.car_crash_rounded,
  'BlockedSlot': Icons.block_rounded,
  'SuspiciousActivity': Icons.visibility_rounded,
  'Other': Icons.more_horiz_rounded,
};

/// The hue each category wears, so a report is recognisable by its colour as
/// well as its word — on the form, and later in the list and on the report itself.
///
/// These are hues, not verdicts: nothing about a vandalism report is "a
/// warning". They were chosen to be told apart at a glance, and red is kept for
/// accidents, where something has gone wrong.
const kIncidentCategoryIntents = <String, StatusIntent>{
  'Vandalism': StatusIntent.warning,
  'Theft': StatusIntent.brand,
  'Accident': StatusIntent.danger,
  'BlockedSlot': StatusIntent.info,
  'SuspiciousActivity': StatusIntent.success,
  'Other': StatusIntent.neutral,
};

StatusIntent incidentCategoryIntent(String apiName) =>
    kIncidentCategoryIntents[apiName] ?? StatusIntent.neutral;

/// Categories that exist on older reports but are no longer offered. They still
/// have to read properly, so they get labels here rather than appearing as
/// `VehicleDamage`.
const _legacyLabels = <String, String>{
  'Safety': 'Safety',
  'VehicleDamage': 'Vehicle Damage',
};

const _legacyIcons = <String, IconData>{
  'Safety': Icons.health_and_safety_rounded,
  'VehicleDamage': Icons.car_repair_rounded,
};

/// The words to show for an API category name. An unknown one is split at its
/// capitals rather than shown raw, so a category added on the server before the
/// app learns it still reads as "Lost Item" and not "LostItem".
String incidentCategoryLabel(String apiName) =>
    kIncidentCategories[apiName] ??
    _legacyLabels[apiName] ??
    apiName.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (_) => ' ',
    );

IconData incidentCategoryIcon(String apiName) =>
    kIncidentCategoryIcons[apiName] ??
    _legacyIcons[apiName] ??
    Icons.report_rounded;
