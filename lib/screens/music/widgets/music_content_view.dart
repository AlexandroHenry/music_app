import 'dart:typed_data';

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
    final resolvedThumbnail = _resolveThumbnail(state);

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          SizedBox(
            width: MediaQuery.of(context).size.width,
            child: _AlbumCarousel(
              thumbnail: resolvedThumbnail,
              onNext: onNext,
              onPrevious: onPrevious,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
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
        ],
      ),
    );
  }
}

Uint8List? _resolveThumbnail(MusicState state) {
  final cached = state.cachedThumbnail;
  if (cached != null && cached.isNotEmpty) {
    return cached;
  }

  final raw = state.currentTrack?['thumbnail'];
  if (raw is Uint8List) {
    return raw;
  }
  if (raw is List<int>) {
    return Uint8List.fromList(raw);
  }

  return null;
}

class _AlbumCarousel extends StatefulWidget {
  const _AlbumCarousel({
    required this.thumbnail,
    required this.onNext,
    required this.onPrevious,
  });

  final Uint8List? thumbnail;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  State<_AlbumCarousel> createState() => _AlbumCarouselState();
}

class _AlbumCarouselState extends State<_AlbumCarousel> {
  static const double _viewportFraction = 0.72;
  static const Duration _snapBackDuration = Duration(milliseconds: 220);

  late final PageController _controller;
  bool _isAnimatingBack = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: 1,
      viewportFraction: _viewportFraction,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSwipe(int index) async {
    if (_isAnimatingBack || !mounted) {
      return;
    }

    if (index == 0) {
      widget.onPrevious();
    } else if (index == 2) {
      widget.onNext();
    } else {
      return;
    }

    _isAnimatingBack = true;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    await _controller.animateToPage(
      1,
      duration: _snapBackDuration,
      curve: Curves.easeOutCubic,
    );
    _isAnimatingBack = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth.clamp(0.0, 320.0);

        return SizedBox(
          height: side,
          child: PageView.builder(
            controller: _controller,
            itemCount: 3,
            onPageChanged: _handleSwipe,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final page = _controller.hasClients && _controller.position.haveDimensions
                      ? (_controller.page ?? _controller.initialPage.toDouble())
                      : _controller.initialPage.toDouble();
                  final distance = (page - index).abs().clamp(0.0, 1.0);
                  final scale = 0.86 + (1.0 - distance) * 0.14;
                  final opacity = 0.55 + (1.0 - distance) * 0.45;

                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: SizedBox.square(
                    dimension: index == 1 ? side : side * 0.84,
                    child: _AlbumCard(
                      thumbnail: widget.thumbnail,
                      label: index == 0 ? '이전곡' : index == 2 ? '다음곡' : null,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.thumbnail,
    required this.label,
  });

  final Uint8List? thumbnail;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ThumbnailImage(thumbnail: thumbnail),
            if (label != null)
              Container(
                color: Colors.black.withOpacity(0.25),
                alignment: Alignment.center,
                child: Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
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
