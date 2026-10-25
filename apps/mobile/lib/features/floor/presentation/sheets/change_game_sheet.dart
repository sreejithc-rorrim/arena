import 'package:arena_ops/app/controllers/session_actions.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/widgets/app_toast.dart';
import 'package:arena_ops/domain/entities/game.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:arena_ops/features/games/presentation/no_games_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Change the game within the current segment's system (spec §11). Only games
/// playable on the current system are offered. Creates a new segment.
Future<void> showChangeGameSheet(BuildContext context, ActiveSession active) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _ChangeGameSheet(active: active),
    ),
  );
}

class _ChangeGameSheet extends ConsumerStatefulWidget {
  const _ChangeGameSheet({required this.active});
  final ActiveSession active;

  @override
  ConsumerState<_ChangeGameSheet> createState() => _ChangeGameSheetState();
}

class _ChangeGameSheetState extends ConsumerState<_ChangeGameSheet> {
  bool _busy = false;

  ActiveSession get active => widget.active;

  @override
  Widget build(BuildContext context) {
    final current = active.current;
    final theme = Theme.of(context);
    final resName = {
          for (final r in ref.watch(resourcesProvider).value ?? []) r.id: r.name,
        }[current.resourceId] ??
        current.resourceId;
    final playable = (ref.watch(gamesForResourceProvider(current.resourceId)).value ?? [])
        .where((g) => g.status.isPlayable)
        .map((g) => g.game)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Change game', style: theme.textTheme.titleLarge),
                    Text('Playable on $resName',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: playable.isEmpty
                ? NoGamesState(
                    resourceName: resName,
                  )
                : ListView(
                    children: [
                      for (final g in playable)
                        ListTile(
                          leading: const Icon(Icons.videogame_asset_outlined),
                          title: Text(g.name),
                          subtitle: Text(PlayerMode.labelOf(g.playModes)),
                          selected: g.id == current.gameId,
                          enabled: !_busy,
                          onTap: () => _change(g),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _change(Game g) async {
    if (_busy || g.id == active.current.gameId) return;
    setState(() => _busy = true);
    final r = await ref.read(sessionActionsProvider).changeGame(
          session: active.session,
          current: active.current,
          gameId: g.id,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    r.fold(
      (_) {
        Navigator.of(context).pop();
        showToast(context, 'Now playing ${g.name}');
      },
      (f) => showFailure(context, f),
    );
  }
}
