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

  // Admin – Users
  static const users = '/api/admin/users';
  static String suspendUser(String userId) =>
      '/api/admin/users/$userId/suspend';
  static String unsuspendUser(String userId) =>
      '/api/admin/users/$userId/unsuspend';
  static String markPaymentPaid(String paymentId) =>
      '/api/admin/payments/$paymentId/mark-paid';
  static String archiveUser(String userId) => '/api/admin/users/$userId';
  static String deleteUserDocuments(String userId) =>
      '/api/admin/users/$userId/documents';
  static String restoreUser(String userId) =>
      '/api/admin/users/$userId/restore';
  static String assignRfid(String userId) =>
      '/api/admin/users/$userId/assign-rfid';
  static String revokeRfid(String userId) =>
      '/api/admin/users/$userId/revoke-rfid';
  static const bulkRevokeRfid = '/api/admin/users/bulk-revoke-rfid';

  /// The pool of physical cards revoked from a user and not yet reissued —
  /// Free ones ready to hand to someone else, Blocked ones that must not be.
  static const rfidCards = '/api/admin/rfid-cards';

  /// The last card tapped on the enrollment desk reader. Polled while the
  /// Assign RFID dialog is open so nobody has to type a UID. Returns null when
  /// nothing has been tapped recently.
  static const rfidLastScan = '/api/admin/rfid/last-scan';

  // Admin – Audit Logs
  static const auditLogs = '/api/admin/audit-logs';

  // Admin – System Logs
  static const rfidAccessLogs = '/api/admin/logs/rfid-access';
  static const userActivityLogs = '/api/admin/logs/user-activity';
  static const systemErrorLogs = '/api/admin/logs/errors';

  // Admin – Parking
  static const parkingSlots = '/api/admin/parking/slots';
  static String slotStatus(String slotId) =>
      '/api/admin/parking/slots/$slotId/status';
  static const logParkingEntry = '/api/admin/parking/log-entry';
  static const logParkingExit = '/api/admin/parking/log-exit';
  static const activeParkingSessions = '/api/admin/parking/active-sessions';

  // Security: the guard's own endpoints. Entry and exit deliberately stay on
  // the parking routes above - the gate hardware posts to those too, and two
  // paths into one table is how they drift.
  static String securityTagLookup(String rfidTagId) =>
      '/api/security/tags/$rfidTagId';
  static const visitorPasses = '/api/security/visitor-passes';
  static String returnVisitorPass(String passId) =>
      '/api/security/visitor-passes/$passId/return';

  // Admin – Gate Devices (RFID reader hardware)
  static const gateDevices = '/api/admin/gate-devices';
  static String revokeGateDevice(String deviceId) =>
      '/api/admin/gate-devices/$deviceId/revoke';

  // Admin – Payments
  static const payments = '/api/admin/payments';
  static const paymentRates = '/api/admin/payments/rates';

  // Admin – Violations
  static const violations = '/api/admin/violations';
  static String violation(String violationId) =>
      '/api/admin/violations/$violationId';
  static String dismissViolation(String violationId) =>
      '/api/admin/violations/$violationId/dismiss';
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
  static String reviewIncident(String incidentId) =>
      '/api/admin/incidents/$incidentId/review';

  // Admin – Notifications
  static const notifications = '/api/admin/notifications';

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
  static const reportsViolationsBreakdown = '/api/admin/reports/violations-breakdown';
  static const reportsRevenueTrend = '/api/admin/reports/revenue-trend';
}
