import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/domain/entities/game.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:arena_ops/features/games/presentation/no_games_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pick a game that is PLAYABLE on [resourceId] (spec §6). Recent games first.
///
/// When a game isn't here (not added yet, or not marked playable on this
/// system), staff can jump straight to adding it or to the library — then come
/// back and pick it, without leaving the new-session flow.
Future<Game?> showGamePicker(
  BuildContext context, {
  required String resourceId,
  String? resourceName,
}) {
  return showModalBottomSheet<Game>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _GamePicker(
        resourceId: resourceId,
        resourceName: resourceName ?? resourceId,
      ),
    ),
  );
}

class _GamePicker extends ConsumerStatefulWidget {
  const _GamePicker({required this.resourceId, required this.resourceName});
  final String resourceId;
  final String resourceName;
  @override
  ConsumerState<_GamePicker> createState() => _GamePickerState();
}

class _GamePickerState extends ConsumerState<_GamePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playable = (ref.watch(gamesForResourceProvider(widget.resourceId)).value ?? [])
        .where((g) => g.status.isPlayable)
        .map((g) => g.game)
        .where((g) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return g.name.toLowerCase().contains(q) ||
          g.aliases.any((a) => a.toLowerCase().contains(q));
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
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
                    Text('Game', style: theme.textTheme.titleLarge),
                    Text('Playable on ${widget.resourceName}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search game',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: playable.isEmpty
                ? NoGamesState(
                    query: _query.trim(),
                    resourceName: widget.resourceName,
                  )
                : ListView.builder(
                    itemCount: playable.length,
                    itemBuilder: (_, i) {
                      final g = playable[i];
                      return ListTile(
                        leading: const Icon(Icons.videogame_asset_outlined),
                        title: Text(g.name),
                        subtitle: Text(
                          '${PlayerMode.labelOf(g.playModes)}'
                          '${g.maxLocalPlayers > 1 ? ' · up to ${g.maxLocalPlayers}' : ''}',
                        ),
                        onTap: () => Navigator.of(context).pop(g),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Pick an active game for an activity's platform — used by booking, where no
/// station is chosen yet. Watches the games list (so it never opens blank) with
/// a loading state, search, and the add-game / library fallback.
Future<Game?> showGamePickerForActivity(
  BuildContext context, {
  required String activityCode,
  required String activityLabel,
}) {
  return showModalBottomSheet<Game>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _ActivityGamePicker(
        activityCode: activityCode,
        activityLabel: activityLabel,
      ),
    ),
  );
}

class _ActivityGamePicker extends ConsumerStatefulWidget {
  const _ActivityGamePicker({required this.activityCode, required this.activityLabel});
  final String activityCode;
  final String activityLabel;
  @override
  ConsumerState<_ActivityGamePicker> createState() => _ActivityGamePickerState();
}

class _ActivityGamePickerState extends ConsumerState<_ActivityGamePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gamesAsync = ref.watch(activeGamesProvider);
    final playable = ref.watch(gamesPlayableForActivityProvider(widget.activityCode)).value;

    List<Game> filter(List<Game> all) {
      final q = _query.trim().toLowerCase();
      return all
          .where((g) => playable == null || playable.contains(g.id))
          .where((g) =>
              q.isEmpty ||
              g.name.toLowerCase().contains(q) ||
              g.aliases.any((a) => a.toLowerCase().contains(q)))
          .toList();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
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
                    Text('Game', style: theme.textTheme.titleLarge),
                    Text('For ${widget.activityLabel}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search game',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: gamesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Could not load games.')),
              data: (all) {
                final games = filter(all);
                if (games.isEmpty) {
                  return NoGamesState(
                    query: _query.trim(),
                    resourceName: widget.activityLabel,
                  );
                }
                return ListView.builder(
                  itemCount: games.length,
                  itemBuilder: (_, i) {
                    final g = games[i];
                    return ListTile(
                      leading: const Icon(Icons.videogame_asset_outlined),
                      title: Text(g.name),
                      subtitle: Text(
                        '${PlayerMode.labelOf(g.playModes)}'
                        '${g.maxLocalPlayers > 1 ? ' · up to ${g.maxLocalPlayers}' : ''}',
                      ),
                      onTap: () => Navigator.of(context).pop(g),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

