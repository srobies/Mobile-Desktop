import 'package:flutter/material.dart';

import '../../widgets/navigation_layout.dart';

class JellyseerrRequestsScreen extends StatelessWidget {
  const JellyseerrRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NavigationLayout(
        showBackButton: true,
        child: const Center(child: Text('Jellyseerr requests will appear here')),
      ),
    );
  }
}
