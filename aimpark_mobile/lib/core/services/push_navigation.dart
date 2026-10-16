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
    // "Your licence expires in 30 days" and the like.
    'profile' || 'documents' => '/home/user/documents',
    _ => '/home/user/notifications',
  };
}

/// Where tapping a row in the notifications list should go, or null when there
/// is nowhere better than the list the user is already on.
///
/// The record it names when the notification carries one; otherwise the list
/// for its kind, which is all an older row (written before the server kept the
/// data) can offer. Announcements and anything else about nothing in particular
/// stay put.
String? routeForNotification(String type, Map<String, String> data) {
  final route = routeForPush(data);
  if (route != '/home/user/notifications') return route;

  return switch (type.toLowerCase()) {
    'violation' => '/home/user/violations',
    'payment' => '/home/user/payments',
    'incident' => '/home/user/incidents',
    _ => null,
  };
}
