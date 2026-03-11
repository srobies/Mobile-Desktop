import 'package:flutter/material.dart';

import '../../widgets/navigation_layout.dart';

class JellyseerrPersonScreen extends StatelessWidget {
  final String personId;

  const JellyseerrPersonScreen({super.key, required this.personId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NavigationLayout(
        showBackButton: true,
        child: const Center(
          child: Text('Jellyseerr person details will appear here'),
        ),
      ),
    );
  }
}
