/// Where a tapped push should land, read off the data the server sends with it.
///
/// The server puts the id of the thing the notification is about in the data
/// (`paymentId`, `violationId`, `incidentId`), or a `screen` name for pushes
/// that are about a place rather than a record. Anything unrecognised opens the
/// alerts list, which always has the notification in it — a tap should never
/// do nothing.
String routeForPush(Map<String, String> data) {
  final paymentId = data['paymentId'];
  if (paymentId != null && paymentId.isNotEmpty) {
    return '/home/user/payments/$paymentId';
  }

  final violationId = data['violationId'];
  if (violationId != null && violationId.isNotEmpty) {
    return '/home/user/violations/$violationId';
  }

  final incidentId = data['incidentId'];
  if (incidentId != null && incidentId.isNotEmpty) {
    return '/home/user/incidents/$incidentId';
  }

  return switch (data['screen']) {
    'parking-slots' => '/home/user/parking-slots',
    'parking-history' => '/home/user/parking-history',
    'violations' => '/home/user/violations',
    _ => '/home/user/notifications',
  };
}
