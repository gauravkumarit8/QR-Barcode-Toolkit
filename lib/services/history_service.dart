/// Persists scan/generate history locally (SharedPreferences-backed).
/// No network calls — everything stays on-device, matching the app's
/// offline-first / no-data-collected Play Store Data Safety declaration.
class HistoryService {
  // TODO: implement add/get/delete/clear using shared_preferences,
  // storing a JSON-encoded list of {type, value, timestamp}.
}
