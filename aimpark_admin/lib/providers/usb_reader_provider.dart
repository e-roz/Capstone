import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/web_serial.dart';

/// The enrollment reader plugged into this computer, if any.
///
/// Lives for the whole visit rather than per dialog: the admin connects once,
/// and every Assign dialog after that picks taps up without asking again.
final usbReaderProvider = ChangeNotifierProvider<UsbReader>((ref) => UsbReader());
