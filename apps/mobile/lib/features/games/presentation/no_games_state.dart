import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Shared empty state for the game pickers (new session + change game). Games
/// and where they are playable are managed on the admin web, so it says who can
/// add the game there.
class NoGamesState extends StatelessWidget {
  const NoGamesState({
    super.key,
    required this.resourceName,
    this.query = '',
  });

  final String resourceName;
  final String query;

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videogame_asset_off_outlined,
                color: arena.textSubtle, size: 36),
            const SizedBox(height: AppSpacing.md),
            Text(
              query.isEmpty
                  ? 'No playable games on $resourceName'
                  : 'No match for "$query" on $resourceName',
              textAlign: TextAlign.center,
              style: ArenaType.h3.copyWith(color: arena.text, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ask the owner to add it or mark it playable here on the admin '
              'dashboard (Settings › Games).',
              textAlign: TextAlign.center,
              style: ArenaType.caption.copyWith(color: arena.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
