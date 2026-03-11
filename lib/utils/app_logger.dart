import 'package:flutter/foundation.dart';

// Enable verbose app logs only when explicitly requested:
// flutter run --dart-define=VERBOSE_LOGS=true
const bool _verboseLogs =
    bool.fromEnvironment('VERBOSE_LOGS', defaultValue: false);

void logVerbose(String message) {
  if (_verboseLogs) {
    debugPrint(message);
  }
}

void logError(String message) {
  debugPrint(message);
}
