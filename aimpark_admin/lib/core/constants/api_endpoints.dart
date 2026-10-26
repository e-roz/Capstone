class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const login = '/api/auth/login';
  static const forgotPassword = '/api/auth/forgot-password';
  static const resetPassword = '/api/auth/reset-password';

  // Admin – Registrations
  static const pendingRegistrations = '/api/admin/registrations/pending';
  static String registrationDetail(String userId) =>
      '/api/admin/registrations/$userId';
  static String approveRegistration(String userId) =>
      '/api/admin/registrations/$userId/approve';
  static String rejectRegistration(String userId) =>
      '/api/admin/registrations/$userId/reject';

  /// Sends named documents back for another photograph. Not a rejection: the
  /// applicant keeps their place in the queue and their other documents, and
  /// there is no cooldown to sit out before they can answer.
  static String requestRetake(String userId) =>
      '/api/admin/registrations/$userId/request-retake';

  /// Records the in-person inspection of an e-bike and approves its owner.
  static String inspectEBike(String userId) =>
      '/api/admin/registrations/$userId/inspect-ebike';

  // Admin – Renewals of licences and registrations after approval
  static const adminRenewals = '/api/admin/renewals';
  static String approveRenewal(String id) => '/api/admin/renewals/$id/approve';
  static String rejectRenewal(String id) => '/api/admin/renewals/$id/reject';

  // Admin – Users
  static const users = '/api/admin/users';
  static String archiveUser(String userId) => '/api/admin/users/$userId';
  static String deleteUserDocuments(String userId) =>
      '/api/admin/users/$userId/documents';
  static String resetUserPassword(String userId) =>
      '/api/admin/users/$userId/reset-password';
  static String restoreUser(String userId) =>
      '/api/admin/users/$userId/restore';
  static String assignRfid(String userId) =>
      '/api/admin/users/$userId/assign-rfid';
  static String revokeRfid(String userId) =>
      '/api/admin/users/$userId/revoke-rfid';
  static const bulkRevokeRfid = '/api/admin/users/bulk-revoke-rfid';
  static const bulkArchive = '/api/admin/users/bulk-archive';

  /// Physical cards revoked from a user and not yet reissued — Free ones
  /// ready to hand to someone else, Blocked ones that must not be. Add
  /// `includeAssigned=true` to also get the cards users hold right now.
  static const rfidCards = '/api/admin/rfid-cards';

  /// Assign, revoke and reinstate events for one card, from the audit log.
  static String rfidCardHistory(String rfidTagId) =>
      '/api/admin/rfid-cards/${Uri.encodeComponent(rfidTagId)}/history';

  /// The last card tapped on the enrollment desk reader. Polled while the
  /// Assign RFID dialog is open so nobody has to type a UID. Returns null when
  /// nothing has been tapped recently.
  static const rfidLastScan = '/api/admin/rfid/last-scan';

  /// Who holds a card the panel read itself off the USB reader. Takes `tag`.
  static const rfidLookup = '/api/admin/rfid/lookup';

  // Admin – Audit Logs
  static const auditLogs = '/api/admin/audit-logs';

  // Admin – System Logs
  static const parkingLogs = '/api/admin/logs/parking';
  static const userActivityLogs = '/api/admin/logs/user-activity';
  static const systemErrorLogs = '/api/admin/logs/errors';

  // Admin – Parking
  static const parkingSlots = '/api/admin/parking/slots';
  static String slotStatus(String slotId) =>
      '/api/admin/parking/slots/$slotId/status';
  static String slotHistory(String slotId) =>
      '/api/admin/parking/slots/$slotId/history';
  static const logParkingEntry = '/api/admin/parking/log-entry';
  static const logParkingExit = '/api/admin/parking/log-exit';
  static const activeParkingSessions = '/api/admin/parking/active-sessions';
  static const wrongBayFlags = '/api/admin/parking/wrong-bay';
  static String reviewWrongBayFlag(String flagId) =>
      '/api/admin/parking/wrong-bay/$flagId/review';

  // Security: the guard's own endpoints. Entry and exit deliberately stay on
  // the parking routes above - the gate hardware posts to those too, and two
  // paths into one table is how they drift.
  static String securityTagLookup(String rfidTagId) =>
      '/api/security/tags/$rfidTagId';
  static const securityCardStatus = '/api/security/card-status';
  static const visitorPasses = '/api/security/visitor-passes';
  static String returnVisitorPass(String passId) =>
      '/api/security/visitor-passes/$passId/return';
  static String confirmVisitorCardReturned(String passId) =>
      '/api/security/visitor-passes/$passId/card-returned';

  /// Every visitor card and where it is, for the guard.
  static const securityVisitorCards = '/api/security/visitor-cards';

  /// Idle visitor cards tapped at a gate, waiting for the guard to fill in the
  /// visitor. Site server only.
  static const visitorRegistrations = '/api/site/visitor-registrations';
  static String visitorRegistration(String id) =>
      '/api/site/visitor-registrations/$id';

  // Admin – the cards set aside for lending to visitors.
  static const visitorCards = '/api/admin/visitor-cards';
  static String visitorCard(String rfidTagId) =>
      '/api/admin/visitor-cards/$rfidTagId';

  // Security: attempts the automatic RFID+ALPR check turned away.
  static String dismissGateAccessAttempt(String attemptId) =>
      '/api/security/gate-access-attempts/$attemptId/dismiss';

  // Admin – Gate Devices (RFID reader hardware)
  static const gateDevices = '/api/admin/gate-devices';
  static String revokeGateDevice(String deviceId) =>
      '/api/admin/gate-devices/$deviceId/revoke';

  // Security – USB gate readers plugged into the guard post's PC. Only the
  // site server answers these; the cloud says to use the guard post's panel.
  static const siteStatus = '/api/site/status';
  static const siteUpdateInstall = '/api/site/update/install';
  static const gateReaders = '/api/site/gate-readers';

  // A driver held at the exit with a fee to pay: the guard takes cash, or lets
  // them out still owing. Under /api/site so the guard post answers it itself,
  // even with the internet down.
  static String sitePaymentCash(String paymentId) =>
      '/api/site/payments/$paymentId/cash';
  static String sitePaymentRelease(String paymentId) =>
      '/api/site/payments/$paymentId/release';
  static const sitePaymentsCashSummary = '/api/site/payments/cash-summary';
  static String gateReader(String port) => '/api/site/gate-readers/$port';
  static String openGateReader(String port) =>
      '/api/site/gate-readers/$port/open';

  // Security – the boards behind an ESP-NOW hub: G1/G2 gates, S1/S2 sensors.
  static String hubNode(String port, String node) =>
      '/api/site/gate-readers/$port/nodes/$node';
  static String openHubNode(String port, String node) =>
      '/api/site/gate-readers/$port/nodes/$node/open';
  // Accept a board asking to join, and name it (G1, S2); remove a board.
  static String pairHub(String port) => '/api/site/gate-readers/$port/pair';
  static String hubBoard(String port, String node) =>
      '/api/site/gate-readers/$port/boards/$node';
  // Connection tests: the hub and every board, or one board; and the hub
  // console, every line over its cable (after = the last seq already shown).
  static String diagnoseHub(String port) =>
      '/api/site/gate-readers/$port/diagnose';
  static String diagnoseHubNode(String port, String node) =>
      '/api/site/gate-readers/$port/diagnose/$node';
  static String hubTraffic(String port, int after) =>
      '/api/site/gate-readers/$port/traffic?after=$after';
  // Development servers only: plays the hub's side, one line at a time.
  static String simulateHub(String port) =>
      '/api/site/gate-readers/$port/simulate';

  // Admin and Security – every device the guard post depends on. Site server only.
  static const deviceHealth = '/api/site/device-health';

  // Admin and Security – the guard post as the cloud sees it: connected or
  // not, when it last sent, and its latest device list. Cloud answers.
  static const siteLink = '/api/site-link';

  // Security – the Overview's live gate log and camera. Site server only.
  static const liveGateTaps = '/api/site/live-gate/taps';
  static String liveGateTapPhoto(String tapId) =>
      '/api/site/live-gate/taps/$tapId/photo';
  static const liveGateHistory = '/api/site/live-gate/history';
  static const liveGateCameras = '/api/site/live-gate/cameras';
  static String liveGateCamera(int gate) => '/api/site/live-gate/camera/$gate';

  // Admin – the Overview's search box and the profile it opens.
  static const adminSearch = '/api/admin/search';
  static const adminSearchProfile = '/api/admin/search/profile';

  // Admin – Payments
  static const payments = '/api/admin/payments';
  static const paymentsExport = '/api/admin/payments/export';
  static const paymentRates = '/api/admin/payments/rates';

  // Admin – Violations
  static const violations = '/api/admin/violations';
  static String violation(String violationId) =>
      '/api/admin/violations/$violationId';
  static String dismissViolation(String violationId) =>
      '/api/admin/violations/$violationId/dismiss';
  static String makeViolationAccountable(String violationId) =>
      '/api/admin/violations/$violationId/accountable';
  static const violationAppeals = '/api/admin/violations/appeals';
  static String decideAppeal(String appealId) =>
      '/api/admin/violations/appeals/$appealId/decide';

  // Admin – Policy Rules
  static const policyRules = '/api/admin/policy-rules';
  static String policyRule(String ruleId) => '/api/admin/policy-rules/$ruleId';

  // Admin – Incidents
  static const incidents = '/api/admin/incidents';
  static String incidentDetail(String incidentId) =>
      '/api/admin/incidents/$incidentId';
  static String startIncidentReview(String incidentId) =>
      '/api/admin/incidents/$incidentId/start-review';
  static String reviewIncident(String incidentId) =>
      '/api/admin/incidents/$incidentId/review';
  static String incidentFollowUps(String incidentId) =>
      '/api/admin/incidents/$incidentId/follow-ups';
  static String incidentFollowUpsSeen(String incidentId) =>
      '/api/admin/incidents/$incidentId/follow-ups/seen';

  // Admin – Notifications
  static const notifications = '/api/admin/notifications';

  // What the system itself pushed (a violation, a refused card, a due bill),
  // newest first. Distinct from the broadcast log above.
  static const systemNotifications = '/api/admin/notifications/system';

  // The staff member's own inbox, not the broadcast log above. Same endpoint
  // the mobile app reads, because a notification addressed to a Security
  // account is the same row as one addressed to a driver.
  static const myNotifications = '/api/notifications';
  static String markNotificationRead(String notificationId) =>
      '/api/notifications/$notificationId/read';

  // Filing a report as a member of staff. The user-facing route, deliberately:
  // an incident reported by a guard is the same kind of thing as one reported
  // from a phone, and the admin route only lists and reviews.
  static const reportIncident = '/api/incidents';

  // Admin – Backup & Restore
  static const backups = '/api/admin/backup';
  static String backupFile(String fileName) => '/api/admin/backup/$fileName';
  static const backupPreview = '/api/admin/backup/preview';
  static const backupRestore = '/api/admin/backup/restore';

  // Admin – Reports
  static const reportsSummary = '/api/admin/reports/summary';
  static const reportsOccupancyTrend = '/api/admin/reports/occupancy-trend';
  static const reportsPeakHours = '/api/admin/reports/peak-hours';
  static const reportsEntryExit = '/api/admin/reports/entry-exit';
  static const reportsViolationsBreakdown =
      '/api/admin/reports/violations-breakdown';
  static const reportsRevenueTrend = '/api/admin/reports/revenue-trend';
  static const reportsGateOutcomes = '/api/admin/reports/gate-outcomes';
  static const reportsPeakOccupancy = '/api/admin/reports/peak-occupancy';
}
