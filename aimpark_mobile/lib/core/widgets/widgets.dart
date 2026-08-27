/// The component kit.
///
/// One import — `import '../../../../core/widgets/widgets.dart';` — gives a
/// screen everything it should need, alongside `core/theme/theme.dart` for the
/// tokens.
///
/// If you find yourself building something out of raw `Container`s that another
/// screen will also want, add it here rather than privately. Every private
/// `_PaymentTile`, `_HistoryTile` and `_ViolationTile` in this codebase started
/// as a one-screen convenience, and by the time there were eight of them they
/// no longer agreed on the gap between the icon and the text.
library;

export 'app_avatar.dart';
export 'app_bottom_nav.dart';
export 'app_button.dart';
export 'app_card.dart';
export 'app_list_row.dart';
export 'app_loading_bar.dart';
export 'app_notice.dart';
export 'app_progress_bar.dart';
export 'app_screen.dart';
export 'app_skeleton.dart';
export 'app_state_views.dart';
export 'app_status_badge.dart';
export 'app_text_field.dart';
export 'async_view.dart';
export 'celebration_dialog.dart';
export 'good_standing_meter.dart';
export 'selectable_chip.dart';
export 'stat_pill.dart';
export 'step_progress_bar.dart';
