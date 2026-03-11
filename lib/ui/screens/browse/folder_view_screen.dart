import 'package:flutter/material.dart';

import '../../widgets/navigation_layout.dart';

class FolderViewScreen extends StatelessWidget {
  const FolderViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NavigationLayout(
        showBackButton: true,
        child: const Center(child: Text('Folder structure will appear here')),
      ),
    );
  }
}
