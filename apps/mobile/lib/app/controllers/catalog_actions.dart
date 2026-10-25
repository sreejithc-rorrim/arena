/// Application-layer writes to the arena's configuration: opening hours,
/// billing rules, the rate card, holidays, stations, the game library and its
/// per-station compatibility, and the physical controller inventory.
///
/// Every screen that changes one of these comes through here, so the
/// permission check sits underneath the UI where every caller has to pass —
/// the same rules the server's `op_*` functions apply:
///
/// * everything is **`settings`** (settings.save, policy.save, rate.*,
///   holiday.*, resource.*, game.*, controller.upsert / set_status);
/// * walking a pad to another station *for now* (a loan) or back home is
///   **`start` or `settings`** — it is a floor job; re-homing a pad for good
///   is **`settings`** (controller.move).
///
/// Reads stay on the providers; nothing here prices or plans sessions.
library;

import 'package:arena_ops/app/auth/auth_controller.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/time/business_calendar.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/auth/permission_guard.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/entities/game.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/pricing/billing_policy.dart';
import 'package:arena_ops/domain/pricing/rate.dart';
import 'package:arena_ops/domain/repositories/catalog_repository.dart';
import 'package:arena_ops/domain/repositories/controller_inventory_writer.dart';
import 'package:arena_ops/domain/repositories/session_repository.dart';
import 'package:arena_ops/domain/repositories/user_repository.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class CatalogActions {
  CatalogActions({
    required this.catalog,
    required this.inventory,
    required this.sessions,
    required this.clock,
    this.guard = const PermissionGuard(null),
    this.users,
  });

  final CatalogRepository catalog;

  /// Staff profiles (Settings → Staff & roles); null where not wired.
  final UserRepository? users;

  /// Pad moves and the RIFT mode lock.
  final ControllerInventoryWriter inventory;

  /// Read to refuse taking an occupied station out of service.
  final SessionRepository sessions;
  final Clock clock;

  /// Who is signed in. Defaults to "nobody", so a caller that forgets to pass
  /// it is refused rather than quietly allowed.
  final PermissionGuard guard;

  static const _uuid = Uuid();

  /// Whether the signed-in user may change configuration — for deciding what
  /// to *show* (e.g. editable compatibility on the floor's View games sheet).
  /// The writes below check again regardless.
  bool get canChangeSettings => guard.allows(Permission.settings);

  /// Whether they may walk a pad to another station for now, or back home.
  bool get canLendControllers =>
      guard.allowsAny(const [Permission.start, Permission.settings]);

  Future<Result<T>> _settings<T>(Future<T> Function() write) async {
    final denied = guard.check(Permission.settings);
    if (denied != null) return Err(denied);
    return Ok(await write());
  }

  // --- trading rules ---------------------------------------------------------

  Future<Result<void>> saveBusinessHours(BusinessHours hours) =>
      _settings(() => catalog.saveBusinessHours(hours));

  Future<Result<void>> savePolicy(BillingPolicy policy) =>
      _settings(() => catalog.savePolicy(policy));

  /// Create or replace one rate (activity + band + controller count).
  Future<Result<void>> saveRate(Rate rate) =>
      _settings(() => catalog.upsertRate(rate));

  Future<Result<void>> deleteRate({
    required String activityCode,
    required Band band,
    required int? controllerCount,
  }) => _settings(
    () => catalog.deleteRate(
      activityCode: activityCode,
      band: band,
      controllerCount: controllerCount,
    ),
  );

  Future<Result<void>> saveHoliday(Holiday holiday) =>
      _settings(() => catalog.upsertHoliday(holiday));

  Future<Result<void>> deleteHoliday(IstDate day) =>
      _settings(() => catalog.deleteHoliday(day));

  // --- stations --------------------------------------------------------------

  Future<Result<Resource>> saveStation(Resource resource) =>
      _settings(() => catalog.upsertResource(resource));

  /// Save a staff profile: name, permissions, active, and (local mode) a new
  /// device PIN. Needs `settings`. Nobody changes their own permissions or
  /// active flag — the server refuses that too (staff.update), since a
  /// Settings holder could otherwise grant themselves owner-level access. In
  /// cloud mode people join only by invitation from the dashboard, so only
  /// existing members can be edited here.
  Future<Result<AppUser>> saveStaff(AppUser user, {String? newPin}) async {
    final denied = guard.check(Permission.settings);
    if (denied != null) return Err(denied);
    final repo = users;
    if (repo == null) {
      return const Err(Failure(
        message: 'Staff cannot be changed on this device.',
        code: 'not_available',
      ));
    }
    if (guard.actor?.id == user.id) {
      final before = await repo.getById(user.id);
      if (before != null &&
          (before.active != user.active ||
              !before.perms.containsAll(user.perms) ||
              !user.perms.containsAll(before.perms))) {
        return const Err(Failure(
          message: 'You cannot change your own access.',
          fix: 'Ask another person with Settings access to do it.',
          code: 'own_access',
        ));
      }
    }
    try {
      return Ok(await repo.upsert(user, newPin: newPin));
    } on UnsupportedError catch (e) {
      return Err(Failure(
        message: e.message ?? 'That cannot be done here.',
        code: 'invite_only',
      ));
    }
  }

  /// Take a station in or out of service. Refused while someone is on it:
  /// taking it away would strand a live session.
  Future<Result<void>> setStationStatus(
    Resource station,
    ResourceStatus status,
  ) async {
    final denied = guard.check(Permission.settings);
    if (denied != null) return Err(denied);
    if (status != ResourceStatus.available) {
      final segments = await sessions.openSegments();
      final busy = segments.any((s) => s.resourceId == station.id);
      if (busy) {
        return Err(
          Failure(
            message: '${station.name} is in use.',
            fix: 'End or move that session first.',
            code: 'resource_busy',
          ),
        );
      }
    }
    await catalog.setResourceStatus(station.id, status);
    return const Ok(null);
  }

  /// Lock a dual-capability station (RIFT) to one activity, or clear it with
  /// [mode] = null. The inventory refuses it while the station is busy.
  Future<Result<void>> setStationMode(String resourceId, String? mode) async {
    final denied = guard.check(Permission.settings);
    if (denied != null) return Err(denied);
    return inventory.setResourceMode(resourceId, mode);
  }

  // --- game library ----------------------------------------------------------

  /// Save a game and, with it, its status on each station in
  /// [compatibility] (resource id → availability). Only stations whose status
  /// actually changed are written, each keeping its note, so saving the form
  /// never undoes a newer change made elsewhere to a station left as it was,
  /// nor wipes the note that explains a status.
  Future<Result<Game>> saveGame(
    Game game, {
    Map<String, GameAvailability> compatibility = const {},
  }) => _settings(() async {
    final stored = {
      for (final c in await catalog.compatibility())
        if (c.gameId == game.id) c.resourceId: c,
    };
    final saved = await catalog.upsertGame(game);
    for (final e in compatibility.entries) {
      final was = stored[e.key];
      // No row means not installed (a game is never globally available).
      if ((was?.status ?? GameAvailability.notInstalled) == e.value) continue;
      await catalog.setCompatibility(game.id, e.key, e.value, notes: was?.notes);
    }
    return saved;
  });

  Future<Result<void>> setGameActive(String id, {required bool active}) =>
      _settings(() => catalog.setGameActive(id, active: active));

  /// A game's status on ONE station ("disc scratched on GHOST").
  Future<Result<void>> setCompatibility(
    String gameId,
    String resourceId,
    GameAvailability status, {
    String? notes,
  }) => _settings(
    () => catalog.setCompatibility(gameId, resourceId, status, notes: notes),
  );

  Future<Result<void>> replaceControls(
    String gameId,
    List<GameControl> controls,
  ) => _settings(() => catalog.replaceControls(gameId, controls));

  // --- controller inventory --------------------------------------------------

  /// Labels are what staff are told to carry ("HEX-1"), so two pads must never
  /// share one. Case-insensitive.
  Future<Failure?> _labelProblem(String label, {String? except}) async {
    if (label.trim().isEmpty) {
      return const Failure(
        message: 'A controller needs a label.',
        fix: 'Use what is written on the pad, like HEX-3.',
        code: 'label_required',
      );
    }
    final wanted = label.trim().toLowerCase();
    final taken = (await catalog.controllers()).any(
      (c) => c.id != except && c.label.toLowerCase() == wanted,
    );
    if (!taken) return null;
    return Failure(
      message: 'A controller is already labelled ${label.trim()}.',
      code: 'label_taken',
    );
  }

  /// Add a new pad, standing at (and belonging to) [resourceId].
  Future<Result<Controller>> addController({
    required String label,
    required String resourceId,
  }) async {
    final denied = guard.check(Permission.settings);
    if (denied != null) return Err(denied);
    final problem = await _labelProblem(label);
    if (problem != null) return Err(problem);
    return Ok(
      await catalog.upsertController(
        Controller(
          id: _uuid.v4(),
          label: label.trim(),
          homeResourceId: resourceId,
          currentResourceId: resourceId,
          updatedAt: clock.now(),
        ),
      ),
    );
  }

  Future<Result<Controller>> renameController(
    Controller controller,
    String label,
  ) async {
    final denied = guard.check(Permission.settings);
    if (denied != null) return Err(denied);
    final problem = await _labelProblem(label, except: controller.id);
    if (problem != null) return Err(problem);
    return Ok(
      await catalog.upsertController(
        controller.copyWith(label: label.trim(), updatedAt: clock.now()),
      ),
    );
  }

  /// Make [homeResourceId] the pad's home station. Re-homing onto the station
  /// it already stands at settles any loan; a pad still on loan elsewhere now
  /// returns to its NEW home.
  Future<Result<Controller>> setControllerHome(
    Controller controller,
    String homeResourceId,
  ) {
    final settled = homeResourceId == controller.currentResourceId;
    return _settings(
      () => catalog.upsertController(
        controller.copyWith(
          homeResourceId: homeResourceId,
          loanReturnTo: settled || controller.loanReturnTo == null
              ? null
              : homeResourceId,
          loanSessionRef: settled ? null : controller.loanSessionRef,
          updatedAt: clock.now(),
        ),
      ),
    );
  }

  /// Mark a pad usable / faulty / missing / retired / unavailable.
  Future<Result<void>> setControllerStatus(
    String id,
    ControllerStatus status, {
    String? notes,
  }) => _settings(() => catalog.setControllerStatus(id, status, notes: notes));

  /// Walk [controller] to [toResourceId]. A "loan" back to its own home is
  /// just a return, so it is recorded as one. Loans and returns are a floor
  /// job (`start` or `settings`); a permanent re-home needs `settings`.
  Future<Result<void>> moveController({
    required Controller controller,
    required String toResourceId,
    required ControllerMoveKind kind,
    String? loanSessionRef,
  }) async {
    final effective = toResourceId == controller.homeResourceId
        ? ControllerMoveKind.returnHome
        : kind;
    final denied = effective == ControllerMoveKind.permanent
        ? guard.check(Permission.settings)
        : guard.checkAny(const [Permission.start, Permission.settings]);
    if (denied != null) return Err(denied);
    return inventory.moveController(
      controllerId: controller.id,
      toResourceId: toResourceId,
      kind: effective,
      loanSessionRef: loanSessionRef,
    );
  }

  /// Walk a pad back to its home station.
  Future<Result<void>> returnHome(Controller controller) => moveController(
    controller: controller,
    toResourceId: controller.homeResourceId,
    kind: ControllerMoveKind.returnHome,
  );

  /// Records the walk home for each of [ids] (borrowed pads ticked on a bill
  /// sheet, after their session has ended). Returns how many were recorded.
  Future<int> returnPadsHome(Iterable<String> ids) async {
    final pads = {for (final c in await catalog.controllers()) c.id: c};
    var done = 0;
    for (final id in ids) {
      final pad = pads[id];
      if (pad == null) continue;
      if ((await returnHome(pad)).isOk) done++;
    }
    return done;
  }
}

final catalogActionsProvider = Provider<CatalogActions>(
  (ref) => CatalogActions(
    catalog: ref.watch(catalogRepositoryProvider),
    inventory: ref.watch(controllerAllocationRepositoryProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    clock: ref.watch(clockProvider),
    guard: PermissionGuard(ref.watch(authControllerProvider)),
    users: ref.watch(userRepositoryProvider),
  ),
);
