class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const login = '/api/auth/login';

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
  static String deleteUser(String userId) => '/api/admin/users/$userId';
  static String restoreUser(String userId) =>
      '/api/admin/users/$userId/restore';
}
