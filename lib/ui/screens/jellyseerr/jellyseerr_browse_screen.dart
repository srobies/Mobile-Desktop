import 'package:flutter/material.dart';

import '../../widgets/navigation_layout.dart';

class JellyseerrBrowseScreen extends StatelessWidget {
  final String? filterId;
  final String? filterName;
  final String? mediaType;
  final String? filterType;

  const JellyseerrBrowseScreen({
    super.key,
    this.filterId,
    this.filterName,
    this.mediaType,
    this.filterType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NavigationLayout(
        showBackButton: true,
        child: const Center(
          child: Text('Jellyseerr browse results will appear here'),
        ),
      ),
    );
  }
}
