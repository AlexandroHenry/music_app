import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MusicController {
  static const platform = MethodChannel('com.yourapp/music_control');

  Future<Map<String, dynamic>?> getNowPlayingInfo() async {
    try {
      final result = await platform.invokeMethod('getNowPlayingInfo');
      if (result == null) {
        debugPrint('⚠️ getNowPlayingInfo returned null');
        return null;
      }

      final info = Map<String, dynamic>.from(result);
      debugPrint('📱 Got track info: ${info['title']} - ${info['artist']}');

      if (info['thumbnail'] != null) {
        debugPrint('📷 Thumbnail present in response');
      } else {
        debugPrint('⚠️ No thumbnail in response');
      }

      return info;
    } on PlatformException catch (e) {
      debugPrint('❌ Platform exception: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting now playing info: $e');
      return null;
    }
  }

  Future<void> togglePlayPause() async {
    try {
      await platform.invokeMethod('togglePlayPause');
      debugPrint('⏯️ Toggle play/pause');
    } catch (e) {
      debugPrint('❌ Error toggling play/pause: $e');
    }
  }

  Future<void> nextTrack() async {
    try {
      await platform.invokeMethod('nextTrack');
      debugPrint('⏭️ Next track');
    } catch (e) {
      debugPrint('❌ Error skipping to next track: $e');
    }
  }

  Future<void> previousTrack() async {
    try {
      await platform.invokeMethod('previousTrack');
      debugPrint('⏮️ Previous track');
    } catch (e) {
      debugPrint('❌ Error going to previous track: $e');
    }
  }

  Future<void> seek(double seconds) async {
    try {
      await platform.invokeMethod('seek', {'seconds': seconds});
    } catch (e) {
      debugPrint('❌ Error seeking: $e');
    }
  }

  Stream<Map<String, dynamic>> get onMusicInfoChanged {
    return const EventChannel(
      'com.yourapp/music_events',
    ).receiveBroadcastStream().map((event) {
      debugPrint('📡 Event received from native');
      return Map<String, dynamic>.from(event);
    });
  }

  // Platform-specific permission handling moved to MusicPermissionHandler.
}
