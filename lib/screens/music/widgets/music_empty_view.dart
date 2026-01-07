import 'package:flutter/material.dart';

class MusicEmptyView extends StatelessWidget {
  const MusicEmptyView({
    super.key,
    required this.message,
    required this.onRefresh,
    required this.showPermissionAction,
    this.onPermissionCheck,
  });

  final String message;
  final VoidCallback onRefresh;
  final bool showPermissionAction;
  final VoidCallback? onPermissionCheck;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('재생 중인 음악이 없습니다', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('새로고침'),
          ),
          if (showPermissionAction) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onPermissionCheck,
              child: const Text('권한 확인'),
            ),
          ],
        ],
      ),
    );
  }
}
