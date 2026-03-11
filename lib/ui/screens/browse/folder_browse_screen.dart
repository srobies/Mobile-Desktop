import 'package:flutter/material.dart';

import '../../widgets/navigation_layout.dart';

class FolderBrowseScreen extends StatelessWidget {
  final String folderId;

  const FolderBrowseScreen({super.key, required this.folderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NavigationLayout(
        showBackButton: true,
        child: const Center(child: Text('Folder contents will appear here')),
      ),
    );
  }
}
