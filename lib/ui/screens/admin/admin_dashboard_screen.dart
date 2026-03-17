import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import 'widgets/server_info_card.dart';
import 'widgets/server_paths_card.dart';
import 'widgets/active_sessions_card.dart';
import 'widgets/activity_log_card.dart';
import 'widgets/server_actions_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final MediaServerClient _client;
  Map<String, dynamic>? _systemInfo;
  StorageInfo? _storageInfo;
  List<Map<String, dynamic>>? _sessions;
  ActivityLogResult? _activityLog;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _client = GetIt.instance<MediaServerClient>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _client.systemApi.getSystemInfo(),
        _client.adminSystemApi.getStorageInfo(),
        _client.sessionApi.getSessions(),
        _client.adminSystemApi.getActivityLog(limit: 10),
      ]);
      if (!mounted) return;
      setState(() {
        _systemInfo = results[0] as Map<String, dynamic>;
        _storageInfo = results[1] as StorageInfo;
        _sessions = results[2] as List<Map<String, dynamic>>;
        _activityLog = results[3] as ActivityLogResult;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load dashboard', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ServerInfoCard(systemInfo: _systemInfo!),
          const SizedBox(height: 16),
          ServerActionsCard(
            client: _client,
            canSelfRestart: _systemInfo!['CanSelfRestart'] as bool? ?? false,
            onActionComplete: _loadData,
          ),
          const SizedBox(height: 16),
          ActiveSessionsCard(sessions: _sessions!),
          const SizedBox(height: 16),
          ActivityLogCard(activityLog: _activityLog!),
          const SizedBox(height: 16),
          ServerPathsCard(storageInfo: _storageInfo!),
        ],
      ),
    );
  }
}
