import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/domain/entities/game.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:arena_ops/app/router/app_nav.dart';
import 'package:arena_ops/features/games/presentation/controls_sheet.dart';
import 'package:arena_ops/features/new_session/presentation/new_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which games are playable on a system, before starting a session (spec §5).
///
/// Availability is **per system** (a disc that stopped working on GHOST is
/// marked there, with a note saying why). It is changed on the admin web, so
/// this list is read-only. Opens the game's controls too, and starts a session.
Future<void> showViewGamesSheet(BuildContext context, Resource resource) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _ViewGamesSheet(resource: resource),
    ),
  );
}

class _ViewGamesSheet extends ConsumerWidget {
  const _ViewGamesSheet({required this.resource});
  final Resource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arena = context.arena;
    final theme = Theme.of(context);
    final games =
        ref.watch(gamesForResourceProvider(resource.id)).value ?? const [];
    // Playable first, then the rest alphabetically.
    final sorted = [...games]..sort((a, b) {
        if (a.status.isPlayable == b.status.isPlayable) {
          return a.game.name.compareTo(b.game.name);
        }
        return a.status.isPlayable ? -1 : 1;
      });
    final playable = sorted.where((g) => g.status.isPlayable).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(resource.name, style: theme.textTheme.titleLarge),
          Text(
            '$playable of ${sorted.length} games playable on this system',
            style: ArenaType.caption.copyWith(color: arena.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      'No active games in the library yet.',
                      style: ArenaType.body.copyWith(color: arena.textMuted),
                    ),
                  )
                : ListView(
                    children: [
                      for (final g in sorted)
                        _GameRow(
                          resource: resource,
                          game: g.game,
                          status: g.status,
                          notes: g.notes,
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: FilledButton.icon(
              onPressed: resource.status.isBookable
                  ? () {
                      Navigator.of(context).pop();
                      AppNav.to(
                        context,
                        NewSessionScreen(initialResource: resource),
                      );
                    }
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: Text('Start session on ${resource.name}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameRow extends ConsumerWidget {
  const _GameRow({
    required this.resource,
    required this.game,
    required this.status,
    this.notes,
  });

  final Resource resource;
  final Game game;
  final GameAvailability status;

  /// Why it has this status here ("disc scratched"); kept when the status changes.
  final String? notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arena = context.arena;
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        status.isPlayable ? Icons.check_circle : Icons.cancel_outlined,
        color: status.isPlayable ? arena.primary : arena.textSubtle,
      ),
      title: Text(game.name),
      subtitle: Text(
        '${PlayerMode.labelOf(game.playModes)}'
        '${game.maxLocalPlayers > 1 ? ' · up to ${game.maxLocalPlayers}' : ''}'
        '${status.isPlayable ? '' : ' · ${status.label}'}'
        '${notes == null || notes!.isEmpty ? '' : ' · $notes'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Controls',
            icon: const Icon(Icons.sports_esports_outlined),
            onPressed: () => showControlsSheet(context, game.id),
          ),
        ],
      ),
      textColor: status.isPlayable ? null : theme.disabledColor,
    );
  }
}
