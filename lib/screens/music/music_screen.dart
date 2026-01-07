import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/screens/music/provider/music_provider.dart';
import 'package:music_app/screens/music/provider/music_state.dart';

class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicStateProvider);

    if (state.isLoading && state.currentTrack == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (state.currentTrack == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('재생 중인 음악이 없습니다', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('음악 앱에서 음악을 재생해주세요', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true),
              child: const Text('새로고침'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildAlbumArt(state),
            const SizedBox(height: 32),
            _buildTrackInfo(state),
            const SizedBox(height: 24),
            _buildProgressBar(ref, state),
            const SizedBox(height: 32),
            _buildControlButtons(context, ref, state),
            const SizedBox(height: 16),
            // 새로고침 버튼 추가
            TextButton.icon(
              onPressed: () => ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('이미지 새로고침'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumArt(MusicState state) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _buildThumbnailImage(state),
      ),
    );
  }

  Widget _buildThumbnailImage(MusicState state) {
    // 캐시된 썸네일 사용
    if (state.cachedThumbnail != null && state.cachedThumbnail!.isNotEmpty) {
      return Image.memory(
        state.cachedThumbnail!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('🖼️ Image error: $error');
          return _buildPlaceholder();
        },
      );
    }

    debugPrint('⚠️ No cached thumbnail, showing placeholder');
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.music_note, size: 100, color: Colors.grey[600]),
    );
  }

  Widget _buildTrackInfo(MusicState state) {
    return Column(
      children: [
        Text(
          state.currentTrack!['title'] ?? 'Unknown Title',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          state.currentTrack!['artist'] ?? 'Unknown Artist',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          state.currentTrack!['album'] ?? 'Unknown Album',
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressBar(WidgetRef ref, MusicState state) {
    final currentTime = (state.currentTrack!['currentTime'] as num?)?.toDouble() ?? 0.0;
    final duration = (state.currentTrack!['duration'] as num?)?.toDouble() ?? 1.0;
    final safeDuration = duration > 0 ? duration : 1.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: currentTime.clamp(0.0, safeDuration),
            max: safeDuration,
            onChanged: (value) {
              ref.read(musicStateProvider.notifier).seek(value);
            },
            onChangeEnd: (value) {
              ref.read(musicStateProvider.notifier).refreshDelayed(forceImageUpdate: false);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(currentTime), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(_formatDuration(safeDuration), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons(BuildContext context, WidgetRef ref, MusicState state) {
    final isPlaying = state.currentTrack!['isPlaying'] == true;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          iconSize: 48,
          onPressed: () => ref.read(musicStateProvider.notifier).previousTrack(),
        ),
        const SizedBox(width: 20),
        Container(
          decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
          child: IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            iconSize: 48,
            onPressed: () => ref.read(musicStateProvider.notifier).togglePlayPause(),
          ),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(Icons.skip_next),
          iconSize: 48,
          onPressed: () => ref.read(musicStateProvider.notifier).nextTrack(),
        ),
      ],
    );
  }

  String _formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) {
      return '0:00';
    }
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}