class ApiEndpoints {
  ApiEndpoints._();

  static const initiateEmail = '/api/auth/register/initiate-email';
  static const verifyEmail = '/api/auth/register/verify-email';
  static const resendOtp = '/api/auth/register/resend-otp';
  static const completeProfile = '/api/auth/register/complete-profile';
  static const registerVehicle = '/api/auth/register/vehicle';
  static const uploadDocuments = '/api/auth/register/documents';
  static const login = '/api/auth/login';
  static const logout = '/api/auth/logout';
  static const googleSignIn = '/api/auth/google/signin';

  static const notifications = '/api/notifications';
  static String notificationRead(String notificationId) =>
      '/api/notifications/$notificationId/read';
  static const deviceToken = '/api/notifications/device-token';

  static const parkingHistory = '/api/parking/history';
  static const parkingSlots = '/api/parking/slots';
  static const parkingRecommend = '/api/parking/recommend';

  static const accountProfile = '/api/account/profile';
  static const changePassword = '/api/account/change-password';
  static const accessStatus = '/api/account/access-status';

  static const violations = '/api/violations';
  static String violationDetail(String violationId) => '/api/violations/$violationId';
  static String violationAppeal(String violationId) => '/api/violations/$violationId/appeal';

  static const payments = '/api/payments';
  static String paymentDetail(String paymentId) => '/api/payments/$paymentId';
  static String paymentPay(String paymentId) => '/api/payments/$paymentId/pay';

  static const incidents = '/api/incidents';
  static String incidentDetail(String incidentId) => '/api/incidents/$incidentId';
  static String incidentWithdraw(String incidentId) =>
      '/api/incidents/$incidentId/withdraw';
}
