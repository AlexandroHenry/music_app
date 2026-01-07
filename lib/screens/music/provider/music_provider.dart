import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:music_app/core/music_controller.dart';
import 'package:music_app/screens/music/provider/music_state.dart';

final musicControllerProvider = Provider<MusicController>((ref) => MusicController());

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

  // 초기화를 비동기로 처리
  Future<void> _initialize() async {
    await _loadCurrentTrack(forceImageUpdate: true);
    _listenToMusicChanges();
    _startPeriodicUpdate();
  }

  void _startPeriodicUpdate() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.currentTrack != null && state.currentTrack!['isPlaying'] == true) {
        _loadCurrentTrack(forceImageUpdate: false);
      }
    });
  }

  Future<void> refresh({bool forceImageUpdate = false}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await _loadCurrentTrack(forceImageUpdate: forceImageUpdate);
  }

  void refreshDelayed({bool forceImageUpdate = false}) {
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadCurrentTrack(forceImageUpdate: forceImageUpdate);
    });
  }

  Future<void> togglePlayPause() async {
    await _controller.togglePlayPause();
    // 즉시 상태 업데이트
    await _loadCurrentTrack(forceImageUpdate: false);
  }

  Future<void> nextTrack() async {
    await _controller.nextTrack();
    // 곡 변경 시 이미지 강제 업데이트
    await Future.delayed(const Duration(milliseconds: 800));
    await _loadCurrentTrack(forceImageUpdate: true);
  }

  Future<void> previousTrack() async {
    await _controller.previousTrack();
    // 곡 변경 시 이미지 강제 업데이트
    await Future.delayed(const Duration(milliseconds: 800));
    await _loadCurrentTrack(forceImageUpdate: true);
  }

  Future<void> seek(double seconds) async {
    await _controller.seek(seconds);
  }

  Future<void> _loadCurrentTrack({bool forceImageUpdate = false}) async {
    try {
      final info = await _controller.getNowPlayingInfo();
      
      if (info == null) {
        // 재시도 로직 추가 (첫 로드 실패 시)
        if (state.isLoading && state.currentTrack == null) {
          await Future.delayed(const Duration(seconds: 1));
          final retryInfo = await _controller.getNowPlayingInfo();
          if (retryInfo != null) {
            _processTrackInfo(retryInfo, forceImageUpdate);
            return;
          }
        }
        
        state = state.copyWith(isLoading: false, currentTrack: null, errorMessage: null);
        return;
      }

      _processTrackInfo(info, forceImageUpdate);
    } catch (e) {
      debugPrint('Error loading track: $e');
      state = state.copyWith(isLoading: false, errorMessage: '음악 정보를 불러올 수 없습니다: $e');
    }
  }

  void _processTrackInfo(Map<String, dynamic> info, bool forceImageUpdate) {
    final trackId = '${info['title']}_${info['artist']}';
    Uint8List? cachedThumbnail = state.cachedThumbnail;
    String? cachedTrackId = state.cachedTrackId;

    // 곡이 변경되었거나 강제 업데이트일 때
    if (forceImageUpdate || trackId != cachedTrackId) {
      debugPrint('🎵 Track changed or force update: $trackId');
      cachedTrackId = trackId;
      cachedThumbnail = _extractThumbnail(info['thumbnail']);
      
      if (cachedThumbnail != null) {
        debugPrint('✅ Thumbnail cached: ${cachedThumbnail.length} bytes');
      } else {
        debugPrint('❌ No thumbnail available');
      }
    }

    final updatedInfo = Map<String, dynamic>.from(info);
    if (cachedThumbnail != null) {
      updatedInfo['thumbnail'] = cachedThumbnail;
    }

    state = state.copyWith(
      isLoading: false,
      currentTrack: updatedInfo,
      errorMessage: null,
      cachedThumbnail: cachedThumbnail,
      cachedTrackId: cachedTrackId,
    );
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
        final trackId = '${info['title']}_${info['artist']}';
        debugPrint('📻 Music change event: $trackId');
        
        if (trackId != state.cachedTrackId) {
          debugPrint('🔄 New track detected, forcing image update');
          _loadCurrentTrack(forceImageUpdate: true);
        } else {
          // 같은 곡이면 재생 위치만 업데이트
          state = state.copyWith(currentTrack: info);
        }
      },
      onError: (error) {
        debugPrint('❌ Music info stream error: $error');
      },
    );
  }

  @override
  void dispose() {
    debugPrint('🗑️ MusicStateNotifier disposed');
    _updateTimer?.cancel();
    _musicSubscription?.cancel();
    super.dispose();
  }
}