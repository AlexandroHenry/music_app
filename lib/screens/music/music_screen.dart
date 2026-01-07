import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/screens/music/provider/music_provider.dart';
import 'package:music_app/screens/music/widgets/music_content_view.dart';
import 'package:music_app/screens/music/widgets/music_empty_view.dart';
import 'package:music_app/screens/music/widgets/music_error_view.dart';
import 'package:music_app/screens/music/widgets/music_loading_view.dart';

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
        _checkNotificationPermission();
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
    
    if (state == AppLifecycleState.resumed) {
      _recheckPermissionAfterSettings();
    }
  }

  Future<void> _recheckPermissionAfterSettings() async {
    if (!mounted) return;

    final permissionHandler = ref.read(musicPermissionHandlerProvider);
    if (!permissionHandler.supportsNotificationPermission) {
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final hasPermission = await permissionHandler.checkNotificationPermission();

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

  Future<void> _checkNotificationPermission() async {
    if (_hasCheckedPermission || !mounted) return;
    _hasCheckedPermission = true;

    final permissionHandler = ref.read(musicPermissionHandlerProvider);
    if (!permissionHandler.supportsNotificationPermission) {
      return;
    }

    final hasPermission = await permissionHandler.checkNotificationPermission();

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
              
              await ref.read(musicPermissionHandlerProvider).requestNotificationPermission();
              
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
    final permissionHandler = ref.watch(musicPermissionHandlerProvider);
    final supportsPermission = permissionHandler.supportsNotificationPermission;

    if (state.isLoading && state.currentTrack == null) {
      return MusicLoadingView(
        message: '음악 정보를 불러오는 중...',
        showPermissionHelp: supportsPermission,
        onPermissionHelp: _showPermissionDialog,
      );
    }

    if (state.errorMessage != null) {
      return MusicErrorView(
        message: state.errorMessage!,
        onRetry: () {
          if (mounted) {
            ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
          }
        },
        showPermissionAction: supportsPermission,
        onPermissionSettings: _showPermissionDialog,
      );
    }

    if (state.currentTrack == null) {
      return MusicEmptyView(
        message: supportsPermission
            ? 'Spotify, YouTube Music 등에서\n음악을 재생해주세요'
            : 'Apple Music, Spotify 등에서\n음악을 재생해주세요',
        onRefresh: () {
          if (mounted) {
            ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
          }
        },
        showPermissionAction: supportsPermission,
        onPermissionCheck: _showPermissionDialog,
      );
    }

    return MusicContentView(
      state: state,
      onSeek: (value) => ref.read(musicStateProvider.notifier).seek(value),
      onSeekEnd: () => ref.read(musicStateProvider.notifier).refreshDelayed(forceImageUpdate: false),
      onPlayPause: () => ref.read(musicStateProvider.notifier).togglePlayPause(),
      onNext: () => ref.read(musicStateProvider.notifier).nextTrack(),
      onPrevious: () => ref.read(musicStateProvider.notifier).previousTrack(),
      onRefresh: () {
        if (mounted) {
          ref.read(musicStateProvider.notifier).refresh(forceImageUpdate: true);
        }
      },
      showPermissionAction: supportsPermission,
      onPermissionSettings: _showPermissionDialog,
    );
  }
}
