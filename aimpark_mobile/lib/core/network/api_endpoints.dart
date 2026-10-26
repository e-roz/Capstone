class ApiEndpoints {
  ApiEndpoints._();

  static const initiateEmail = '/api/auth/register/initiate-email';
  static const verifyEmail = '/api/auth/register/verify-email';
  static const resendOtp = '/api/auth/register/resend-otp';
  static const completeProfile = '/api/auth/register/complete-profile';
  // Two calls, not one: the photos are read first and shown back to the user,
  // and only the values they confirm are committed. The vehicle is created from
  // what the second call confirms, so there is no separate vehicle endpoint in
  // registration any more.
  static const scanDocuments = '/api/auth/register/documents/scan';
  /// One document's OCR text, read as soon as it is photographed so the user
  /// sees what was read before the next document. Nothing is stored.
  static const readDocument = '/api/auth/register/documents/read';
  static const confirmDocuments = '/api/auth/register/documents/confirm';
  /// Where the flow learns whether a reviewer has asked for specific documents
  /// again, rather than assuming every visit to the document step wants all four.
  static const registrationStatus = '/api/auth/register/status';
  static const login = '/api/auth/login';
  static const logout = '/api/auth/logout';
  static const googleSignIn = '/api/auth/google/signin';
  // Two calls, and the first one answers the same way whether or not the
  // address has an account — so the app cannot use it to find out either, and
  // must move to the code screen regardless of what comes back.
  static const forgotPassword = '/api/auth/forgot-password';
  static const resetPassword = '/api/auth/reset-password';

  static const notifications = '/api/notifications';
  static const notificationsReadAll = '/api/notifications/read-all';

  static String notificationRead(String notificationId) =>
      '/api/notifications/$notificationId/read';
  static const deviceToken = '/api/notifications/device-token';

  static const parkingHistory = '/api/parking/history';
  static const parkingSlots = '/api/parking/slots';
  static const parkingRecommend = '/api/parking/recommend';
  static const parkingConfirmSlot = '/api/parking/confirm-slot';

  static const vehicles = '/api/vehicles';
  // A vehicle added after registration is proved the same way the first one was:
  // the receipt is read for the plate and the photo confirms it on the metal.
  // There is no endpoint that accepts a typed plate for this reason.
  static const vehicleScan = '/api/vehicles/documents/scan';
  static const vehicleConfirm = '/api/vehicles/documents/confirm';

  static const accountProfile = '/api/account/profile';
  static const changePassword = '/api/account/change-password';
  static const accessStatus = '/api/account/access-status';

  static const violations = '/api/violations';
  static String violationDetail(String violationId) => '/api/violations/$violationId';
  static String violationAppeal(String violationId) => '/api/violations/$violationId/appeal';

  static const payments = '/api/payments';
  static String paymentDetail(String paymentId) => '/api/payments/$paymentId';
  static String paymentCheckout(String paymentId) =>
      '/api/payments/$paymentId/checkout';

  /// One checkout for every bill that can be paid. Not built on the server yet;
  /// see `kPayAllAvailable`.
  static const paymentsCheckoutAll = '/api/payments/checkout-all';

  static const incidents = '/api/incidents';
  static String incidentDetail(String incidentId) => '/api/incidents/$incidentId';
  static String incidentWithdraw(String incidentId) =>
      '/api/incidents/$incidentId/withdraw';
}
