import 'package:flutter/material.dart';

class MusicPermissionDialog extends StatelessWidget {
  const MusicPermissionDialog({
    super.key,
    required this.onLater,
    required this.onOpenSettings,
  });

  final VoidCallback onLater;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
        TextButton(onPressed: onLater, child: const Text('나중에')),
        ElevatedButton.icon(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings),
          label: const Text('설정 열기'),
        ),
      ],
    );
  }
}
