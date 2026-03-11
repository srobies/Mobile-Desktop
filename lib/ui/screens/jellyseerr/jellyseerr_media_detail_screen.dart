import 'package:flutter/material.dart';

import '../../widgets/navigation_layout.dart';

class JellyseerrMediaDetailScreen extends StatelessWidget {
  final String itemId;

  const JellyseerrMediaDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NavigationLayout(
        showBackButton: true,
        child: const Center(
          child: Text('Jellyseerr media details will appear here'),
        ),
      ),
    );
  }
}
