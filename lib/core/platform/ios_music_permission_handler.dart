import 'music_permission_handler.dart';

class IosMusicPermissionHandler implements MusicPermissionHandler {
  @override
  bool get supportsNotificationPermission => false;

  @override
  Future<bool> checkNotificationPermission() async {
    return true;
  }

  @override
  Future<void> requestNotificationPermission() async {
    return;
  }
}
