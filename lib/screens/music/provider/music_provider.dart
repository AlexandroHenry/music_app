import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:music_app/core/music_controller.dart';
import 'package:music_app/core/platform/music_permission_handler.dart';
import 'package:music_app/screens/music/provider/music_state.dart';

final musicControllerProvider = Provider<MusicController>((ref) => MusicController());
final musicPermissionHandlerProvider = Provider<MusicPermissionHandler>((ref) => MusicPermissionHandler());

final musicStateProvider = StateNotifierProvider<MusicStateNotifier, MusicState>(
  (ref) => MusicStateNotifier(ref.read(musicControllerProvider)),
);

class MusicStateNotifier extends StateNotifier<MusicState> {
  MusicStateNotifier(this._controller) : super(MusicState.initial) {
    _initialize();
  }

  final MusicController _controller;
  Timer? _updateTimer;
  StreamSubscription? _musicSubscription;
  bool _isDisposed = false;

  Future<void> _initialize() async {
    if (_isDisposed) return;

    await _loadCurrentTrack(forceImageUpdate: true);
    _listenToMusicChanges();
    _startPeriodicUpdate();
  }

  void _startPeriodicUpdate() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      // 재생 중일 때만 시간 정보 업데이트 (썸네일은 제외)
      if (state.currentTrack != null && state.currentTrack!['isPlaying'] == true) {
        _updatePlaybackTime();
      }
    });
  }

  // 재생 시간만 업데이트 (썸네일 제외)
  Future<void> _updatePlaybackTime() async {
    if (_isDisposed) return;

    try {
      final info = await _controller.getNowPlayingInfo();
      if (_isDisposed || info == null) return;

      final trackId = '${info['title']}_${info['artist']}';
      
      // 같은 곡이면 시간 정보만 업데이트
      if (trackId == state.cachedTrackId) {
        final updatedInfo = Map<String, dynamic>.from(state.currentTrack ?? {});
        updatedInfo['currentTime'] = info['currentTime'];
        updatedInfo['isPlaying'] = info['isPlaying'];
        
        // 썸네일은 기존 캐시 유지
        if (state.cachedThumbnail != null) {
          updatedInfo['thumbnail'] = state.cachedThumbnail;
        }

        state = state.copyWith(currentTrack: updatedInfo);
      } else {
        // 곡이 변경되었으면 전체 업데이트
        await _loadCurrentTrack(forceImageUpdate: true);
      }
    } catch (e) {
      debugPrint('Error updating playback time: $e');
    }
  }

  Future<void> refresh({bool forceImageUpdate = false}) async {
    if (_isDisposed) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    await _loadCurrentTrack(forceImageUpdate: forceImageUpdate);
  }

  void refreshDelayed({bool forceImageUpdate = false}) {
    if (_isDisposed) return;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isDisposed) {
        _loadCurrentTrack(forceImageUpdate: forceImageUpdate);
      }
    });
  }

  Future<void> togglePlayPause() async {
    if (_isDisposed) return;

    await _controller.togglePlayPause();
    // 재생/정지는 시간 정보만 업데이트
    await _updatePlaybackTime();
  }

  Future<void> nextTrack() async {
    if (_isDisposed) return;

    await _controller.nextTrack();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!_isDisposed) {
      await _loadCurrentTrack(forceImageUpdate: true);
    }
  }

  Future<void> previousTrack() async {
    if (_isDisposed) return;

    await _controller.previousTrack();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!_isDisposed) {
      await _loadCurrentTrack(forceImageUpdate: true);
    }
  }

  Future<void> seek(double seconds) async {
    if (_isDisposed) return;
    await _controller.seek(seconds);
  }

  Future<void> _loadCurrentTrack({bool forceImageUpdate = false}) async {
    if (_isDisposed) return;

    try {
      final info = await _controller.getNowPlayingInfo();

      if (_isDisposed) return;

      if (info == null) {
        if (state.isLoading && state.currentTrack == null) {
          await Future.delayed(const Duration(seconds: 1));

          if (_isDisposed) return;

          final retryInfo = await _controller.getNowPlayingInfo();
          if (retryInfo != null && !_isDisposed) {
            _processTrackInfo(retryInfo, forceImageUpdate);
            return;
          }
        }

        if (!_isDisposed) {
          state = state.copyWith(isLoading: false, currentTrack: null, errorMessage: null);
        }
        return;
      }

      if (!_isDisposed) {
        _processTrackInfo(info, forceImageUpdate);
      }
    } catch (e) {
      if (!_isDisposed) {
        debugPrint('Error loading track: $e');
        state = state.copyWith(isLoading: false, errorMessage: '음악 정보를 불러올 수 없습니다: $e');
      }
    }
  }

  void _processTrackInfo(Map<String, dynamic> info, bool forceImageUpdate) {
    if (_isDisposed) return;

    final trackId = '${info['title']}_${info['artist']}';
    Uint8List? cachedThumbnail = state.cachedThumbnail;
    String? cachedTrackId = state.cachedTrackId;

    // 곡이 변경되었거나 강제 업데이트일 때만 썸네일 갱신
    if (forceImageUpdate || trackId != cachedTrackId) {
      debugPrint('🎵 Track changed or force update: $trackId');
      cachedTrackId = trackId;
      
      // 썸네일 추출
      final newThumbnail = _extractThumbnail(info['thumbnail']);
      
      // 새로운 썸네일이 있으면 갱신, 없으면 기존 유지
      if (newThumbnail != null && newThumbnail.isNotEmpty) {
        cachedThumbnail = newThumbnail;
        debugPrint('✅ Thumbnail updated: ${cachedThumbnail.length} bytes');
      } else if (cachedThumbnail != null) {
        debugPrint('⚠️ New thumbnail unavailable, keeping cached');
      } else {
        debugPrint('❌ No thumbnail available');
      }
    }

    final updatedInfo = Map<String, dynamic>.from(info);
    
    // 항상 캐시된 썸네일 사용
    if (cachedThumbnail != null) {
      updatedInfo['thumbnail'] = cachedThumbnail;
    }

    if (!_isDisposed) {
      state = state.copyWith(
        isLoading: false,
        currentTrack: updatedInfo,
        errorMessage: null,
        cachedThumbnail: cachedThumbnail,
        cachedTrackId: cachedTrackId,
      );
    }
  }

  Uint8List? _extractThumbnail(dynamic thumbnail) {
    if (thumbnail == null) {
      debugPrint('⚠️ Thumbnail is null');
      return null;
    }

    try {
      if (thumbnail is Uint8List) {
        debugPrint('✅ Thumbnail is Uint8List: ${thumbnail.length} bytes');
        return thumbnail;
      } else if (thumbnail is List<int>) {
        debugPrint('✅ Thumbnail is List<int>, converting...');
        return Uint8List.fromList(thumbnail);
      } else {
        debugPrint('⚠️ Thumbnail type: ${thumbnail.runtimeType}');
        return thumbnail as Uint8List?;
      }
    } catch (e) {
      debugPrint('❌ Error extracting thumbnail: $e');
      return null;
    }
  }

  void _listenToMusicChanges() {
    _musicSubscription?.cancel();
    _musicSubscription = _controller.onMusicInfoChanged.listen(
      (info) {
        if (_isDisposed) return;

        final trackId = '${info['title']}_${info['artist']}';
        debugPrint('📻 Music change event: $trackId');

        if (trackId != state.cachedTrackId) {
          debugPrint('🔄 New track detected, forcing image update');
          _loadCurrentTrack(forceImageUpdate: true);
        } else {
          // 같은 곡이면 시간 정보만 업데이트
          if (!_isDisposed) {
            final updatedInfo = Map<String, dynamic>.from(info);
            // 기존 캐시된 썸네일 유지
            if (state.cachedThumbnail != null) {
              updatedInfo['thumbnail'] = state.cachedThumbnail;
            }
            state = state.copyWith(currentTrack: updatedInfo);
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Music info stream error: $error');
      },
    );
  }

  @override
  void dispose() {
    debugPrint('🗑️ MusicStateNotifier disposing...');
    _isDisposed = true;

    _updateTimer?.cancel();
    _updateTimer = null;

    _musicSubscription?.cancel();
    _musicSubscription = null;

    super.dispose();
    debugPrint('🗑️ MusicStateNotifier disposed');
  }
}