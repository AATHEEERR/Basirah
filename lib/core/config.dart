/// Build-time configuration.
///
///   flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
///   flutter build web --dart-define=API_BASE=https://basirah-api.onrender.com
///
/// Without API_BASE the app still works fully offline: curated answers,
/// referral and abstention come from the on-device router.
abstract final class AppConfig {
  static const apiBase = String.fromEnvironment('API_BASE');
  static bool get hasApi => apiBase.isNotEmpty;
  static const version = '1.0.0';
}
