import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../data/models/aggregated_item.dart';
import '../../data/services/cast/cast_service.dart';
import '../../data/services/cast/cast_target.dart';

Future<void> showRemotePlayToSessionDialog(
  BuildContext context, {
  required AggregatedItem item,
  List<AggregatedItem>? queueItems,
  int? startPositionTicks,
  int? audioStreamIndex,
  int? subtitleStreamIndex,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final castService = GetIt.instance<CastService>();

  final picked = await showModalBottomSheet<CastTarget>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _CastTargetSheet(
      stream: castService.discoverTargetsStreamed(item),
    ),
  );

  if (picked == null || !context.mounted) return;

  try {
    await castService.playToTarget(
      picked,
      item: item,
      queueItems: queueItems,
      startPositionTicks: startPositionTicks,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
    );
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Casting started on selected device')),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to start casting: $e')),
    );
  }
}

class _CastTargetSheet extends StatefulWidget {
  final Stream<CastTarget> stream;
  const _CastTargetSheet({required this.stream});

  @override
  State<_CastTargetSheet> createState() => _CastTargetSheetState();
}

class _CastTargetSheetState extends State<_CastTargetSheet> {
  final _targets = <CastTarget>[];
  StreamSubscription<CastTarget>? _sub;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(
      (target) {
        if (mounted) setState(() => _targets.add(target));
      },
      onDone: () {
        if (mounted) setState(() => _done = true);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = !_done;

    if (loading && _targets.isEmpty) {
      return const SafeArea(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_done && _targets.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No remote playback devices available')),
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListView.separated(
            shrinkWrap: true,
            itemCount: _targets.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final target = _targets[index];
              return ListTile(
                leading: Icon(_iconForTargetKind(target.kind)),
                title: Text(target.title),
                subtitle: target.subtitle.isNotEmpty ? Text(target.subtitle) : null,
                onTap: () => Navigator.of(context).pop(target),
              );
            },
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

IconData _iconForTargetKind(CastTargetKind kind) {
  return switch (kind) {
    CastTargetKind.jellyfinSession => Icons.cast,
    CastTargetKind.googleCast => Icons.cast_connected,
    CastTargetKind.airPlay => Icons.airplay,
    CastTargetKind.dlna => Icons.router,
  };
}
