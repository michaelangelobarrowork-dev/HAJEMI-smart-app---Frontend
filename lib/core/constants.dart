class ApiConstants {
  ApiConstants._();

  // Backend base URL – local network IP
  static const baseUrl = 'http://192.168.1.38:8000';

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

  // Household
  static const householdCreate = '/household/create';
  static const householdJoin   = '/household/join';
  static const householdLeave  = '/household/leave';

  // Logs
  static const logs = '/logs';
}

class StorageKeys {
  StorageKeys._();
  static const accessToken  = 'access_token';
  static const refreshToken = 'refresh_token';
}
