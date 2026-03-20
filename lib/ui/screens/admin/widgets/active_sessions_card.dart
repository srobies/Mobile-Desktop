import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import 'session_detail_sheet.dart';

class ActiveSessionsCard extends StatefulWidget {
  const ActiveSessionsCard({super.key});

  @override
  State<ActiveSessionsCard> createState() => _ActiveSessionsCardState();
}

class _ActiveSessionsCardState extends State<ActiveSessionsCard> {
  late final SessionApi _sessionApi;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  bool _fetching = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sessionApi = GetIt.instance<MediaServerClient>().sessionApi;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final sessions = await _sessionApi.getSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      _fetching = false;
    }
  }

  void _openDetail(Map<String, dynamic> session) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SessionDetailSheet(session: session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Active Sessions', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (_loading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Text('${_sessions.length}', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text('Failed to load sessions', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            else if (!_loading && _sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No active sessions')),
              )
            else
              ..._sessions.map((session) {
                final userName = session['UserName'] as String? ?? 'Unknown';
                final client = session['Client'] as String? ?? '';
                final device = session['DeviceName'] as String? ?? '';
                final nowPlaying = session['NowPlayingItem'] as Map<String, dynamic>?;
                final playState = session['PlayState'] as Map<String, dynamic>?;
                final isPaused = playState?['IsPaused'] as bool? ?? false;
                final transcodingInfo = session['TranscodingInfo'] as Map<String, dynamic>?;

                return InkWell(
                  onTap: () => _openDetail(session),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(userName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              Text(
                                nowPlaying != null
                                    ? '${nowPlaying['Name'] ?? ''}${isPaused ? ' (Paused)' : ''}'
                                    : '$client · $device',
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (transcodingInfo != null)
                          Tooltip(
                            message: 'Transcoding',
                            child: Icon(Icons.swap_horiz, size: 16, color: theme.colorScheme.secondary),
                          )
                        else if (nowPlaying != null)
                          Tooltip(
                            message: 'Direct Play',
                            child: Icon(Icons.play_circle_outline, size: 16, color: theme.colorScheme.primary),
                          ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.outline),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

