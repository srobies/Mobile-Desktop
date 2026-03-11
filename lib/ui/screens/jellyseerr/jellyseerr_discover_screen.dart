import 'package:flutter/material.dart';

import '../../widgets/navigation_layout.dart';

class JellyseerrDiscoverScreen extends StatelessWidget {
  const JellyseerrDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NavigationLayout(
        showBackButton: true,
        child: const Center(child: Text('Jellyseerr discover will appear here')),
      ),
    );
  }
}
