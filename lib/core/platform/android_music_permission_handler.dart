import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'music_permission_handler.dart';

class AndroidMusicPermissionHandler implements MusicPermissionHandler {
  static const MethodChannel _platform = MethodChannel('com.yourapp/music_control');

  @override
  bool get supportsNotificationPermission => true;

  @override
  Future<bool> checkNotificationPermission() async {
    try {
      final result = await _platform.invokeMethod('checkNotificationPermission');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('❌ Error checking notification permission: $e');
      return false;
    }
  }

  @override
  Future<void> requestNotificationPermission() async {
    try {
      await _platform.invokeMethod('requestNotificationPermission');
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
    }
  }
}
