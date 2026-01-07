import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/screens/music/provider/music_provider.dart';
import 'package:music_app/screens/music/provider/music_state.dart';

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> with WidgetsBindingObserver {
  bool _hasCheckedPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndroidPermission();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱이 다시 활성화될 때 (설정에서 돌아올 때)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      // 설정에서 돌아온 후 권한 재확인
      _recheckPermissionAfterSettings();
    }
  }

  Future<void> _recheckPermissionAfterSettings() async {
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final controller = ref.read(musicControllerProvider);
    final hasPermission = await controller.checkNotificationPermission();

    if (hasPermission && mounted) {
      debugPrint('✅ Permission granted! Auto-refreshing...');
      
      // 권한이 허용되면 즉시 새로고침
      ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('권한이 허용되었습니다! 음악 정보를 불러옵니다.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _checkAndroidPermission() async {
    if (_hasCheckedPermission || !Platform.isAndroid || !mounted) return;
    _hasCheckedPermission = true;

    final controller = ref.read(musicControllerProvider);
    final hasPermission = await controller.checkNotificationPermission();

    debugPrint('🔐 Initial permission check: $hasPermission');

    if (!hasPermission && mounted) {
      // 권한이 없으면 다이얼로그 표시
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showPermissionDialog();
        }
      });
    } else if (hasPermission && mounted) {
      // 권한이 있으면 바로 새로고침
      ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
    }
  }

  void _showPermissionDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.music_note, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('알림 접근 권한 필요'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '재생 중인 음악 정보를 가져오려면\n알림 접근 권한이 필요합니다.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '설정 방법:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '1. "설정 열기" 버튼 클릭\n'
              '2. "Music App" 찾기\n'
              '3. 토글 버튼 활성화 ✅',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('나중에'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (!mounted) return;

              Navigator.pop(context);
              
              await ref.read(musicControllerProvider).requestNotificationPermission();
              
              // 설정 화면으로 이동 후에는 didChangeAppLifecycleState에서 자동 처리됨
            },
            icon: const Icon(Icons.settings),
            label: const Text('설정 열기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicStateProvider);

    if (state.isLoading && state.currentTrack == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              Platform.isAndroid
                  ? '음악 정보를 불러오는 중...'
                  : '음악 정보를 불러오는 중...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    _showPermissionDialog();
                  }
                },
                child: const Text('권한이 필요한가요?'),
              ),
            ],
          ],
        ),
      );
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
              onPressed: () {
                if (mounted) {
                  ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
                }
              },
              child: const Text('다시 시도'),
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    _showPermissionDialog();
                  }
                },
                child: const Text('권한 설정'),
              ),
            ],
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
            Text(
              Platform.isAndroid
                  ? 'Spotify, YouTube Music 등에서\n음악을 재생해주세요'
                  : 'Apple Music, Spotify 등에서\n음악을 재생해주세요',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                if (mounted) {
                  ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    _showPermissionDialog();
                  }
                },
                child: const Text('권한 확인'),
              ),
            ],
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
            TextButton.icon(
              onPressed: () {
                if (mounted) {
                  ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
                }
              },
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('새로고침'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
            if (Platform.isAndroid) ...[
              TextButton.icon(
                onPressed: () {
                  if (mounted) {
                    _showPermissionDialog();
                  }
                },
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

  Widget _buildAlbumArt(MusicState state) {
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
        child: _buildThumbnailImage(state),
      ),
    );
  }

  Widget _buildThumbnailImage(MusicState state) {
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
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
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