// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:music_app/core/platform/music_permission_handler.dart';
// import 'package:music_app/screens/music/provider/music_provider.dart';
// import 'package:music_app/screens/music/provider/music_state.dart';
// import 'package:music_app/screens/music/widgets/music_content_view.dart';
// import 'package:music_app/screens/music/widgets/music_empty_view.dart';
// import 'package:music_app/screens/music/widgets/music_error_view.dart';
// import 'package:music_app/screens/music/widgets/music_loading_view.dart';
// import 'package:music_app/screens/music/widgets/music_permission_dialog.dart';

// class MusicScreen extends ConsumerStatefulWidget {
//   const MusicScreen({super.key});

//   @override
//   ConsumerState<MusicScreen> createState() => _MusicScreenState();
// }

// class _MusicScreenState extends ConsumerState<MusicScreen> with WidgetsBindingObserver {
//   bool _hasCheckedPermission = false;
//   bool _hasAutoHiddenChrome = false;

//   late final MusicPermissionHandler _permissionHandler;
//   ProviderSubscription<MusicState>? _musicStateSubscription;

//   @override
//   void initState() {
//     super.initState();
//     _permissionHandler = ref.read(musicPermissionHandlerProvider);
//     WidgetsBinding.instance.addObserver(this);
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) {
//         _checkNotificationPermission();
//       }
//     });

//     _musicStateSubscription = ref.listenManual<MusicState>(musicStateProvider, (previous, next) {
//       if (next.currentTrack?['isPlaying'] != true) {
//         _hasAutoHiddenChrome = false;
//       }
//     });
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _musicStateSubscription?.close();
//     super.dispose();
//   }

//   // 앱이 다시 활성화될 때 (설정에서 돌아올 때)
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);

//     if (state == AppLifecycleState.resumed) {
//       _recheckPermissionAfterSettings();
//     }
//   }

//   Future<void> _recheckPermissionAfterSettings() async {
//     if (!mounted) return;

//     if (!_permissionHandler.supportsNotificationPermission) {
//       return;
//     }

//     await Future.delayed(const Duration(milliseconds: 500));
//     if (!mounted) return;

//     final hasPermission = await _permissionHandler.checkNotificationPermission();

//     if (hasPermission && mounted) {
//       debugPrint('✅ Permission granted! Auto-refreshing...');

//       // 권한이 허용되면 즉시 새로고침
//       ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('권한이 허용되었습니다! 음악 정보를 불러옵니다.'),
//           backgroundColor: Colors.green,
//           duration: Duration(seconds: 2),
//         ),
//       );
//     }
//   }

//   Future<void> _checkNotificationPermission() async {
//     if (_hasCheckedPermission || !mounted) return;
//     _hasCheckedPermission = true;

//     if (!_permissionHandler.supportsNotificationPermission) {
//       return;
//     }

//     final hasPermission = await _permissionHandler.checkNotificationPermission();

//     debugPrint('🔐 Initial permission check: $hasPermission');

//     if (!hasPermission && mounted) {
//       // 권한이 없으면 다이얼로그 표시
//       Future.delayed(const Duration(milliseconds: 500), () {
//         if (mounted) {
//           _showPermissionDialog();
//         }
//       });
//     } else if (hasPermission && mounted) {
//       // 권한이 있으면 바로 새로고침
//       ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
//     }
//   }

//   void _showPermissionDialog() {
//     if (!mounted) return;

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => MusicPermissionDialog(
//         onLater: () {
//           if (mounted) {
//             Navigator.pop(context);
//           }
//         },
//         onOpenSettings: () async {
//           if (!mounted) return;

//           Navigator.pop(context);

//           await _permissionHandler.requestNotificationPermission();
//         },
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final state = ref.watch(musicStateProvider);
//     final supportsPermission = _permissionHandler.supportsNotificationPermission;
//     late final Widget content;

//     if (state.isLoading && state.currentTrack == null) {
//       content = MusicLoadingView(
//         message: '음악 정보를 불러오는 중...',
//         showPermissionHelp: supportsPermission,
//         onPermissionHelp: _showPermissionDialog,
//       );
//     } else if (state.errorMessage != null) {
//       content = MusicErrorView(
//         message: state.errorMessage!,
//         onRetry: () {
//           if (mounted) {
//             ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
//           }
//         },
//         showPermissionAction: supportsPermission,
//         onPermissionSettings: _showPermissionDialog,
//       );
//     } else if (state.currentTrack == null) {
//       content = MusicEmptyView(
//         message: supportsPermission ? 'Spotify, YouTube Music 등에서\n음악을 재생해주세요' : 'Apple Music, Spotify 등에서\n음악을 재생해주세요',
//         onRefresh: () {
//           if (mounted) {
//             ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
//           }
//         },
//         showPermissionAction: supportsPermission,
//         onPermissionCheck: _showPermissionDialog,
//       );
//     } else {
//       content = MusicContentView(
//         state: state,
//         onSeek: (value) => ref.read(musicStateProvider.notifier).seek(value),
//         onSeekEnd: () => ref.read(musicStateProvider.notifier).refreshDelayed(forceImageUpdate: false),
//         onPlayPause: () => ref.read(musicStateProvider.notifier).togglePlayPause(),
//         onNext: () => ref.read(musicStateProvider.notifier).nextTrack(),
//         onPrevious: () => ref.read(musicStateProvider.notifier).previousTrack(),
//         onRefresh: () {
//           if (mounted) {
//             ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
//           }
//         },
//         showPermissionAction: supportsPermission,
//         onPermissionSettings: _showPermissionDialog,
//       );
//     }

//     return content;
//   }
// }

import 'dart:io';
import 'dart:ui';
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      _recheckPermissionAfterSettings();
    }
  }

  Future<void> _recheckPermissionAfterSettings() async {
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // final controller = ref.read(musicControllerProvider);
    final hasPermission = await ref.read(musicPermissionHandlerProvider).checkNotificationPermission();

    if (hasPermission && mounted) {
      debugPrint('✅ Permission granted! Auto-refreshing...');

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

    // final controller = ref.read(musicControllerProvider);
    final hasPermission = await ref.read(musicPermissionHandlerProvider).checkNotificationPermission();

    debugPrint('🔐 Initial permission check: $hasPermission');

    if (!hasPermission && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showPermissionDialog();
        }
      });
    } else if (hasPermission && mounted) {
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
            Text('재생 중인 음악 정보를 가져오려면\n알림 접근 권한이 필요합니다.', style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            Text('설정 방법:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

              await ref.read(musicPermissionHandlerProvider).requestNotificationPermission();
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
              Platform.isAndroid ? '음악 정보를 불러오는 중...' : '음악 정보를 불러오는 중...',
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
              Platform.isAndroid ? 'Spotify, YouTube Music 등에서\n음악을 재생해주세요' : 'Apple Music, Spotify 등에서\n음악을 재생해주세요',
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Theme.of(context).scaffoldBackgroundColor, Colors.grey[100]!],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 8),

              Flexible(flex: 5, child: _buildAlbumArt(state)),

              const SizedBox(height: 24),
              _buildTrackInfo(state),

              const SizedBox(height: 20),
              _buildProgressBar(ref, state),

              const SizedBox(height: 24),
              _buildControlButtons(context, ref, state),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(MusicState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 사용 가능한 공간에 맞춰 크기 조정
        final size = constraints.maxWidth.clamp(250.0, 350.0);

        return Center(
          child: Hero(
            tag: 'album_art',
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                    spreadRadius: -5,
                  ),
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 60,
                    offset: const Offset(0, 30),
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 배경 블러 효과
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.grey[300]!, Colors.grey[400]!],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 실제 앨범 아트
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(aspectRatio: 1.0, child: _buildThumbnailImage(state)),
                    ),
                  ),
                  // 글래스모피즘 오버레이
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 반짝이는 효과
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.0)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).primaryColor.withOpacity(0.3), Theme.of(context).primaryColor.withOpacity(0.1)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note_rounded, size: 100, color: Colors.white.withOpacity(0.8)),
            const SizedBox(height: 16),
            Text(
              'No Artwork',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackInfo(MusicState state) {
    return Column(
      children: [
        Text(
          state.currentTrack!['title'] ?? 'Unknown Title',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Text(
          state.currentTrack!['artist'] ?? 'Unknown Artist',
          style: TextStyle(fontSize: 18, color: Colors.grey[700], fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          state.currentTrack!['album'] ?? 'Unknown Album',
          style: TextStyle(fontSize: 15, color: Colors.grey[500], fontWeight: FontWeight.w400),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressBar(WidgetRef ref, MusicState state) {
    final currentTime = (state.currentTrack!['currentTime'] as num?)?.toDouble() ?? 0.0;
    final duration = (state.currentTrack!['duration'] as num?)?.toDouble() ?? 1.0;
    final safeDuration = duration > 0 ? duration : 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: Theme.of(context).primaryColor,
              inactiveTrackColor: Colors.grey[300],
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              thumbColor: Theme.of(context).primaryColor,
              overlayColor: Theme.of(context).primaryColor.withOpacity(0.2),
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
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(currentTime),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatDuration(safeDuration),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, WidgetRef ref, MusicState state) {
    final isPlaying = state.currentTrack!['isPlaying'] == true;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous button
        _buildControlButton(
          icon: Icons.skip_previous_rounded,
          size: 48,
          onPressed: () => ref.read(musicStateProvider.notifier).previousTrack(),
        ),
        const SizedBox(width: 24),
        // Play/Pause button
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)],
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref.read(musicStateProvider.notifier).togglePlayPause(),
              customBorder: const CircleBorder(),
              child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Next button
        _buildControlButton(
          icon: Icons.skip_next_rounded,
          size: 48,
          onPressed: () => ref.read(musicStateProvider.notifier).nextTrack(),
        ),
      ],
    );
  }

  Widget _buildControlButton({required IconData icon, required double size, required VoidCallback onPressed}) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[200]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(icon, size: size, color: Colors.grey[800]),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          icon: Icons.refresh_rounded,
          label: '새로고침',
          onPressed: () {
            if (mounted) {
              ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
            }
          },
        ),
        if (Platform.isAndroid) ...[
          const SizedBox(width: 16),
          _buildActionButton(
            icon: Icons.settings_rounded,
            label: '권한',
            onPressed: () {
              if (mounted) {
                _showPermissionDialog();
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey[600],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
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
