class ApiConstants {
  ApiConstants._();

  // Backend base URL – local network IP
  static const baseUrl = 'https://ultra-pond-cardinal.ngrok-free.dev/';

  // Auth
  static const register  = '/auth/register';
  static const verifyOtp = '/auth/verify-otp';
  static const resendOtp = '/auth/resend-otp';
  static const login     = '/auth/login';
  static const logout    = '/auth/logout';
  static const refresh   = '/auth/refresh';

  // Devices
  static const devices        = '/devices';
  static const devicesRegister = '/devices/register';

  // Users
  static const me             = '/users/me';
  static const updateUsername = '/users/me/username';
  static const updateEmail    = '/users/me/email';
  static const updatePassword = '/users/me/password';
  static const registerFcmToken = '/users/me/fcm-token';

  // Household
  static const household       = '/household';
  static const householdCreate = '/household/create';
  static const householdJoin   = '/household/join';
  static const householdLeave  = '/household/leave';

  // Detections
  static const gateDetections = '/gate';
  static const roomDetections = '/room';

  // Logs
  static const logs = '/logs';
}

class StorageKeys {
  StorageKeys._();
  static const accessToken  = 'access_token';
  static const refreshToken = 'refresh_token';
}
