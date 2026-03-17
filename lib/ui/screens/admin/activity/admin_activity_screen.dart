import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

enum _ActivityFilter { all, user, system }

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  final List<ActivityLogEntry> _entries = [];
  final ScrollController _scrollController = ScrollController();
  _ActivityFilter _filter = _ActivityFilter.all;
  bool _isLoading = false;
  bool _hasMore = true;
  int _totalCount = 0;
  String? _error;

  static const _pageSize = 30;

  AdminSystemApi get _api =>
      GetIt.instance<MediaServerClient>().adminSystemApi;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _api.getActivityLog(
        startIndex: _entries.length,
        limit: _pageSize,
        hasUserId: _filter == _ActivityFilter.all
            ? null
            : _filter == _ActivityFilter.user,
      );
      setState(() {
        _entries.addAll(result.items);
        _totalCount = result.totalRecordCount;
        _hasMore = _entries.length < _totalCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _changeFilter(_ActivityFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _entries.clear();
      _hasMore = true;
      _totalCount = 0;
    });
    _loadPage();
  }

  Future<void> _refresh() async {
    setState(() {
      _entries.clear();
      _hasMore = true;
      _totalCount = 0;
    });
    await _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              ..._ActivityFilter.values.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _filter == f,
                      label: Text(_filterLabel(f)),
                      onSelected: (_) => _changeFilter(f),
                    ),
                  )),
              const Spacer(),
              if (_totalCount > 0)
                Text('${_entries.length} of $_totalCount',
                    style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildBody(theme)),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_entries.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty && _error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load activity log: $_error'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(child: Text('No activity entries'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _entries.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _entries.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _ActivityTile(entry: _entries[index]);
        },
      ),
    );
  }

  String _filterLabel(_ActivityFilter f) {
    switch (f) {
      case _ActivityFilter.all:
        return 'All';
      case _ActivityFilter.user:
        return 'User Activity';
      case _ActivityFilter.system:
        return 'System Events';
    }
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityLogEntry entry;
  const _ActivityTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: _SeverityBadge(severity: entry.severity),
      title: Text(
        entry.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.shortOverview != null) ...[
            const SizedBox(height: 2),
            Text(
              entry.shortOverview!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _timeAgo(entry.date),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      onTap: () => _showDetail(context),
    );
  }

  void _showDetail(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _SeverityBadge(severity: entry.severity),
                  const SizedBox(width: 8),
                  Text(entry.severity),
                  const Spacer(),
                  Text(
                    _formatDateTime(entry.date),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (entry.overview != null) ...[
                const SizedBox(height: 12),
                Text(entry.overview!),
              ],
              if (entry.shortOverview != null &&
                  entry.shortOverview != entry.overview) ...[
                const SizedBox(height: 8),
                Text(entry.shortOverview!,
                    style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Text('Type: ${entry.type}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_p(local.month)}-${_p(local.day)} '
        '${_p(local.hour)}:${_p(local.minute)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _severityStyle(severity);
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, size: 18, color: color),
    );
  }

  (Color, IconData) _severityStyle(String severity) {
    switch (severity) {
      case 'Error':
        return (Colors.red, Icons.error);
      case 'Warning':
      case 'Warn':
        return (Colors.orange, Icons.warning);
      case 'Information':
        return (Colors.blue, Icons.info);
      case 'Debug':
      case 'Trace':
        return (Colors.grey, Icons.bug_report);
      default:
        return (Colors.blue, Icons.info);
    }
  }
}
