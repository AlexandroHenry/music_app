import 'dart:io';

import 'android_music_permission_handler.dart';
import 'ios_music_permission_handler.dart';

abstract class MusicPermissionHandler {
  bool get supportsNotificationPermission;

  Future<bool> checkNotificationPermission();
  Future<void> requestNotificationPermission();

  factory MusicPermissionHandler() {
    if (Platform.isAndroid) {
      return AndroidMusicPermissionHandler();
    }

    return IosMusicPermissionHandler();
  }
}
