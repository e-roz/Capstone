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

  // Admin – Users
  static const users = '/api/admin/users';
  static String suspendUser(String userId) =>
      '/api/admin/users/$userId/suspend';
  static String unsuspendUser(String userId) =>
      '/api/admin/users/$userId/unsuspend';
  static String archiveUser(String userId) => '/api/admin/users/$userId';
  static String restoreUser(String userId) =>
      '/api/admin/users/$userId/restore';
  static String assignRfid(String userId) =>
      '/api/admin/users/$userId/assign-rfid';
  static String revokeRfid(String userId) =>
      '/api/admin/users/$userId/revoke-rfid';

  // Admin – Audit Logs
  static const auditLogs = '/api/admin/audit-logs';

  // Admin – Parking
  static const parkingSlots = '/api/admin/parking/slots';
  static String slotStatus(String slotId) =>
      '/api/admin/parking/slots/$slotId/status';
  static const logParkingEntry = '/api/admin/parking/log-entry';
  static const logParkingExit = '/api/admin/parking/log-exit';
  static const activeParkingSessions = '/api/admin/parking/active-sessions';

  // Admin – Payments
  static const payments = '/api/admin/payments';
  static const paymentRates = '/api/admin/payments/rates';

  // Admin – Violations
  static const violations = '/api/admin/violations';
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

  // Admin – Reports
  static const reportsSummary = '/api/admin/reports/summary';
  static const reportsOccupancyTrend = '/api/admin/reports/occupancy-trend';
  static const reportsPeakHours = '/api/admin/reports/peak-hours';
  static const reportsViolationsBreakdown = '/api/admin/reports/violations-breakdown';
  static const reportsRevenueTrend = '/api/admin/reports/revenue-trend';
}
