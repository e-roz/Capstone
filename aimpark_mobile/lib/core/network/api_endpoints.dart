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
}
