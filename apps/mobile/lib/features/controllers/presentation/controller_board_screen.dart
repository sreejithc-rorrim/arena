/// Owner resource + controller board (brief §7): every station's live status
/// and every physical controller's status, where it is, who/what it is on,
/// borrowed pads and their location, and reconciled in-use / available totals.
library;

import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/widgets/arena_badge.dart';
import 'package:arena_ops/core/widgets/arena_header.dart';
import 'package:arena_ops/core/widgets/arena_list.dart';
import 'package:arena_ops/data/local/local_controller_allocation_repository.dart';
import 'package:arena_ops/features/controllers/presentation/controller_choice_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Recomputes whenever the controller inventory or any live session changes,
/// so the board reflects allocations as they start and end.
final controllerBoardProvider =
    FutureProvider.autoDispose<ControllerDashboard>((ref) async {
  ref.watch(controllersProvider);
  ref.watch(activeSessionsProvider);
  return ref.watch(controllerAllocationRepositoryProvider).dashboard();
});

class ControllerBoardScreen extends ConsumerWidget {
  const ControllerBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arena = context.arena;
    final board = ref.watch(controllerBoardProvider);
    final resourceName = <String, String>{
      for (final r in ref.watch(resourcesProvider).value ?? const [])
        r.id: r.name,
    };
    final gameName = <String, String>{
      for (final g in ref.watch(allGamesProvider).value ?? const [])
        g.id: g.name,
    };

    return Scaffold(
      backgroundColor: arena.bg,
      // Opened from More (pushed): the back arrow takes the person back. No
      // title here — the large header below carries it.
      appBar: AppBar(
        backgroundColor: arena.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: board.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Could not load the board.',
                style: ArenaType.body.copyWith(color: arena.textMuted)),
          ),
          data: (d) => ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.x16),
            children: [
              ArenaScreenHeader(
                overline: 'Resources',
                title: 'Controller board',
                status: _Totals(total: d.total, inUse: d.inUse, available: d.available),
              ),
              // Loaned pads idle at the wrong station: record the walk back.
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.x5),
                child: BorrowedPadsNotice(),
              ),
              ArenaSectionLabel(
                label: 'Stations',
                trailing: '${d.stations.length}',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
                child: ArenaRowGroup(
                  children: [
                    for (final s in d.stations)
                      ArenaListRow(
                        icon: Icons.sports_esports_outlined,
                        title: s.name,
                        subtitle: _stationSubtitle(s),
                        chevron: false,
                        trailing: _stationBadge(context, s),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ArenaSectionLabel(
                label: 'Controllers',
                trailing: '${d.inUse} in use · ${d.available} free',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
                child: ArenaRowGroup(
                  children: [
                    for (final p in d.pads)
                      ArenaListRow(
                        icon: Icons.videogame_asset_outlined,
                        iconBackground: _padColor(context, p.state).withValues(alpha: 0.14),
                        iconColor: _padColor(context, p.state),
                        title: p.controller.label,
                        subtitle: _padSubtitle(p, resourceName, gameName),
                        chevron: false,
                        trailing: _PadBadge(
                          state: p.state,
                          color: _padColor(context, p.state),
                          borrowed: p.borrowed,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stationSubtitle(StationView s) {
    final mode = s.currentMode == null ? '' : '${s.currentMode} mode · ';
    return '$mode${s.inUseControllers} in use · ${s.usableControllers} usable';
  }

  Widget _stationBadge(BuildContext context, StationView s) {
    final arena = context.arena;
    // Stored status drives the badge; occupancy is shown in the subtitle.
    final (String label, Color color) = switch (s.status) {
      'maintenance' => ('Maintenance', arena.warning),
      'temporarily_unavailable' => ('Unavailable', arena.textSubtle),
      'disabled' => ('Disabled', arena.textSubtle),
      _ => s.inUseControllers > 0
          ? ('In use', arena.stPlaying)
          : ('Available', arena.success),
    };
    return StatusDotLabel(label: label, color: color);
  }

  String _padSubtitle(
    PadView p,
    Map<String, String> resourceName,
    Map<String, String> gameName,
  ) {
    final loc = resourceName[p.locationResourceId] ?? p.locationResourceId;
    final parts = <String>[];
    if (p.borrowed) {
      final home = resourceName[p.controller.homeResourceId] ?? p.controller.homeResourceId;
      parts.add('At $loc · home $home');
    } else {
      parts.add('At $loc');
    }
    final a = p.allocation;
    if (a != null) {
      const who = 'Session';
      final game = a.gameId == null ? '' : ' · ${gameName[a.gameId] ?? 'game'}';
      final where = resourceName[a.resourceId] ?? a.resourceId;
      parts.add('$who on $where$game');
    }
    return parts.join('  ·  ');
  }

  Color _padColor(BuildContext context, PadState state) {
    final arena = context.arena;
    return switch (state) {
      PadState.available => arena.success,
      PadState.inUse => arena.stPlaying,
      PadState.faulty => arena.danger,
      PadState.missing => arena.warning,
      PadState.retired => arena.textSubtle,
      PadState.unavailable => arena.textSubtle,
    };
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.total, required this.inUse, required this.available});
  final int total;
  final int inUse;
  final int available;

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    Widget cell(String n, String label, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, style: ArenaType.h1.copyWith(color: color)),
              Text(label.toUpperCase(),
                  style: ArenaType.micro.copyWith(color: arena.textSubtle)),
            ],
          ),
        );
    return Row(
      children: [
        cell('$inUse', 'In use', arena.stPlaying),
        cell('$available', 'Available', arena.success),
        cell('$total', 'Total pads', arena.text),
      ],
    );
  }
}

class _PadBadge extends StatelessWidget {
  const _PadBadge({required this.state, required this.color, required this.borrowed});
  final PadState state;
  final Color color;
  final bool borrowed;

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    final label = switch (state) {
      PadState.available => 'Available',
      PadState.inUse => 'In use',
      PadState.faulty => 'Faulty',
      PadState.missing => 'Missing',
      PadState.retired => 'Retired',
      PadState.unavailable => 'Unavailable',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusDotLabel(label: label, color: color),
        if (borrowed) ...[
          const SizedBox(height: 4),
          ArenaTag(
            label: 'BORROWED',
            foreground: arena.warning,
            background: arena.warningSoft,
          ),
        ],
      ],
    );
  }
}
