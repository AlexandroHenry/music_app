import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../provider/music_state.dart';

class MusicContentView extends StatelessWidget {
  const MusicContentView({
    super.key,
    required this.state,
    required this.onSeek,
    required this.onSeekEnd,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onRefresh,
    required this.showPermissionAction,
    this.onPermissionSettings,
  });

  final MusicState state;
  final ValueChanged<double> onSeek;
  final VoidCallback onSeekEnd;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onRefresh;
  final bool showPermissionAction;
  final VoidCallback? onPermissionSettings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _AlbumArt(thumbnail: state.cachedThumbnail),
            const SizedBox(height: 32),
            _TrackInfo(track: state.currentTrack!),
            const SizedBox(height: 24),
            _ProgressBar(
              track: state.currentTrack!,
              onSeek: onSeek,
              onSeekEnd: onSeekEnd,
            ),
            const SizedBox(height: 32),
            _ControlButtons(
              isPlaying: state.currentTrack!['isPlaying'] == true,
              onPrevious: onPrevious,
              onPlayPause: onPlayPause,
              onNext: onNext,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('새로고침'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
            if (showPermissionAction) ...[
              TextButton.icon(
                onPressed: onPermissionSettings,
                icon: const Icon(Icons.settings, size: 20),
                label: const Text('권한 설정'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.thumbnail});

  final Uint8List? thumbnail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _ThumbnailImage(thumbnail: thumbnail),
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({required this.thumbnail});

  final Uint8List? thumbnail;

  @override
  Widget build(BuildContext context) {
    if (thumbnail != null && thumbnail!.isNotEmpty) {
      return Image.memory(
        thumbnail!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('🖼️ Image error: $error');
          return const _Placeholder();
        },
      );
    }

    debugPrint('⚠️ No cached thumbnail, showing placeholder');
    return const _Placeholder();
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.music_note, size: 100, color: Colors.grey[600]),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.track});

  final Map<String, dynamic> track;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          track['title'] ?? 'Unknown Title',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          track['artist'] ?? 'Unknown Artist',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          track['album'] ?? 'Unknown Album',
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.track,
    required this.onSeek,
    required this.onSeekEnd,
  });

  final Map<String, dynamic> track;
  final ValueChanged<double> onSeek;
  final VoidCallback onSeekEnd;

  @override
  Widget build(BuildContext context) {
    final currentTime = (track['currentTime'] as num?)?.toDouble() ?? 0.0;
    final duration = (track['duration'] as num?)?.toDouble() ?? 1.0;
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
            onChanged: onSeek,
            onChangeEnd: (_) => onSeekEnd(),
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

class _ControlButtons extends StatelessWidget {
  const _ControlButtons({
    required this.isPlaying,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
  });

  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          iconSize: 48,
          onPressed: onPrevious,
        ),
        const SizedBox(width: 20),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            iconSize: 48,
            onPressed: onPlayPause,
          ),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(Icons.skip_next),
          iconSize: 48,
          onPressed: onNext,
        ),
      ],
    );
  }
}
