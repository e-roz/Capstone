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

  // Admin – Audit Logs
  static const auditLogs = '/api/admin/audit-logs';
}
