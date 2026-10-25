/// Loads a [PadBoard] — the controller inventory as seen from one station —
/// from the repositories, so the session actions validate a [ControllerChoice]
/// against exactly the same picture the picker shows.
library;

import 'package:arena_ops/domain/repositories/catalog_repository.dart';
import 'package:arena_ops/domain/repositories/controller_allocation_reader.dart';
import 'package:arena_ops/domain/repositories/session_repository.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';

class PadBoardLoader {
  const PadBoardLoader({
    required this.catalog,
    required this.sessions,
    this.pads,
    this.selection = const PadSelection(),
  });

  final CatalogRepository catalog;
  final SessionRepository sessions;
  final ControllerAllocationReader? pads;
  final PadSelection selection;

  Future<PadBoard> load({
    required String resourceId,
    String? resourceName,
    Set<String> keepIds = const {},
    String? exceptOccupantId,
  }) async {
    final resources = await catalog.resources();
    final names = {for (final r in resources) r.id: r.name};
    final activities = await catalog.activities();
    final usesControllers = {
      for (final a in activities)
        if (a.usesControllers) a.code,
    };
    final open =
        await pads?.openPadAllocations() ?? const <OpenPadAllocation>[];
    // The segment being changed is not "someone else" holding pads.
    final occupants = [
      for (final s in await sessions.openSegments())
        if (s.id != exceptOccupantId)
          StationOccupant(
            id: s.id,
            resourceId: s.resourceId,
            usesControllers: usesControllers.contains(s.activityCode),
          ),
    ];
    return selection.board(
      resourceId: resourceId,
      resourceName: resourceName ?? names[resourceId] ?? resourceId,
      controllers: await catalog.controllers(),
      open: open,
      resourceNames: names,
      busyStations: PadSelection.untrackedBusyStations(
        occupants: occupants,
        open: open,
      ),
      keepIds: keepIds,
    );
  }
}
