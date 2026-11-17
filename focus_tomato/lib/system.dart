import 'package:flutter/services.dart';

/// Thin wrapper over the Android side (MainActivity.kt). Every call fails soft,
/// so the timer still works if a phone refuses a permission.
class SystemBridge {
  static const _ch = MethodChannel('focus_tomato/system');

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // tests / non-Android
    } on PlatformException {
      return null;
    }
  }

  Future<bool> hasDndAccess() async => await _call<bool>('hasDndAccess') ?? false;
  Future<void> openDndSettings() => _call('openDndSettings');
  Future<bool> setDnd(bool on) async => await _call<bool>('setDnd', {'on': on}) ?? false;
  Future<void> requestNotificationPermission() => _call('requestNotificationPermission');

  Future<void> scheduleEnd(DateTime at, String title, String body) =>
      _call('scheduleEnd', {'atMillis': at.millisecondsSinceEpoch, 'title': title, 'body': body});
  Future<void> cancelEnd() => _call('cancelEnd');
  Future<void> completeNow(String title, String body) => _call('completeNow', {'title': title, 'body': body});
}
