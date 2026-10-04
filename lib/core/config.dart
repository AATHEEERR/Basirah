/// Build-time configuration.
///
///   flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
///   flutter build web --dart-define=API_BASE=https://basirah-api.onrender.com
///   flutter build web --dart-define=API_BASE=same-origin   (the server
///       serves the app too: one deployment, one link)
///
/// Without API_BASE the app still works fully offline: curated answers,
/// referral and abstention come from the on-device router.
abstract final class AppConfig {
  static const _apiBase = String.fromEnvironment('API_BASE');
  static String get apiBase => _apiBase == 'same-origin' ? Uri.base.origin : _apiBase;
  static bool get hasApi => _apiBase.isNotEmpty;
  static const version = '1.0.0';
}
