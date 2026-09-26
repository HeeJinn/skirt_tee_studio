/// Where the shop's cloud lives, passed in at build time so nothing about the
/// project is committed to this public repo:
///
///     cd apps/desktop
///     flutter run -d windows --dart-define-from-file=../../cloud.json
///
/// See cloud.example.json at the repo root. A build without them simply runs offline-only.
class CloudConfig {
  const CloudConfig({required this.supabaseUrl, required this.supabasePublishableKey, required this.powerSyncUrl});

  static const fromEnvironment = CloudConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    powerSyncUrl: String.fromEnvironment('POWERSYNC_URL'),
  );

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String powerSyncUrl;

  bool get isComplete => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty && powerSyncUrl.isNotEmpty;
}
