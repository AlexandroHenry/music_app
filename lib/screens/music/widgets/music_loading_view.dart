import 'package:flutter/material.dart';

class MusicLoadingView extends StatelessWidget {
  const MusicLoadingView({
    super.key,
    required this.message,
    required this.showPermissionHelp,
    this.onPermissionHelp,
  });

  final String message;
  final bool showPermissionHelp;
  final VoidCallback? onPermissionHelp;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (showPermissionHelp) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onPermissionHelp,
              child: const Text('권한이 필요한가요?'),
            ),
          ],
        ],
      ),
    );
  }
}
