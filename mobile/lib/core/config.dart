/// App configuration — change baseUrl for production deployment.
class AppConfig {
  // Production server
  static const String baseUrl = 'https://rcsthcs.click/api';
  static const String baseUrlWeb = 'https://rcsthcs.click/api';

  // Local dev (uncomment for local testing):
  // static const String baseUrl = 'http://10.0.2.2:8000/api';
  // static const String baseUrlWeb = 'http://localhost:8000/api';

  static const String appName = 'Habit Tracker AI';
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration chatTimeout = Duration(seconds: 60);
  static const int notificationPollIntervalSeconds = 60;
}

