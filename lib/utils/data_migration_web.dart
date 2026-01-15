import 'dart:html' as html;

/// Web implementation of local storage helper
class LocalStorageHelper {
  Future<String?> getString(String key) async {
    return html.window.localStorage[key];
  }

  Future<void> setString(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  Future<void> remove(String key) async {
    html.window.localStorage.remove(key);
  }
}