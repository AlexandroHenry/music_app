import 'package:flutter/material.dart';

class MusicErrorView extends StatelessWidget {
  const MusicErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.showPermissionAction,
    this.onPermissionSettings,
  });

  final String message;
  final VoidCallback onRetry;
  final bool showPermissionAction;
  final VoidCallback? onPermissionSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
          if (showPermissionAction) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onPermissionSettings,
              child: const Text('권한 설정'),
            ),
          ],
        ],
      ),
    );
  }
}
