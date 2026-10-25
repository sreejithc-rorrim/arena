/// Writes server rows (the sync feed, or a whole refetched entity) into the
/// device's Drift database.
///
/// The server and the device share row ids (the device generates them and the
/// server keeps them), so applying a row is an upsert by id. A few tables are
/// keyed differently on the device and are matched on their natural key
/// instead: rates (activity, band, controllers), holidays (day), links
/// (station, activity), per-station game availability (game, station),
/// settings (key) and the staff list (account id).
///
/// Device-local columns are never overwritten: a member's PIN hash and lockout
/// state, and a booking's reminder status (each device schedules its own).
///
/// Rows are written as companions built with `toCompanion(false)`: a server
/// null (a segment re-opened by a rollback, a loan cleared by a return) must
/// overwrite the device's value, and Drift's data-class upsert would skip it.
///
/// Every method must run inside the caller's Drift transaction.
library;

import 'dart:convert';

import 'package:arena_ops/data/local/database.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

/// One server row from the feed: its published table name and its columns.
typedef ServerRow = ({String table, Map<String, dynamic> row});

/// Settings keys that are arena-wide (and so synced). Every other key in the
/// Drift settings table is device-local and never touched by sync.
const sharedSettingKeys = {
  'business_hours',
  'floor_options',
  'venue_profile',
  'discount_options',
};

/// Tables that make up the owner's configuration — replaced wholesale when an
/// owner edit is refused, so the device converges on the server's catalog.
const catalogTables = {
  'activities', 'resources', 'resource_activities', 'controllers',
  'game_categories', 'games', 'game_resources', 'game_controls', 'rates',
  'billing_policies', 'holidays', 'settings', 'staff_profiles',
  'pricing_rules',
};

class SyncApplier {
  SyncApplier(this._db);
  final AppDatabase _db;

  // ---------------------------------------------------------------- the feed

  /// Applies a page of feed changes ({t, r} maps). Closed segments,
  /// assignments and allocations go first, so a station or pad that changed
  /// hands within the page never trips the device's one-open-row indexes.
  ///
  /// A row in the feed is the server's CURRENT row (sync_pull reads the live
  /// tables), so it outranks any tombstone for the same key in the page: that
  /// tombstone is from a delete the same or an earlier transaction undid by
  /// re-inserting (game.replace_controls re-inserts unchanged control ids; a
  /// holiday or station link removed and added back). Applying it after the
  /// upsert would wipe a row the server still has.
  Future<void> applyChanges(List<Map<String, dynamic>> changes) async {
    final rows = <ServerRow>[];
    final tombstones = <ServerRow>[];
    for (final c in changes) {
      final t = c['t'] as String;
      final r = Map<String, dynamic>.from(c['r'] as Map);
      if (t == '_tombstone') {
        tombstones.add((
          table: r['table'] as String,
          row: Map<String, dynamic>.from(r['row'] as Map),
        ));
      } else {
        rows.add((table: t, row: r));
      }
    }
    final live = {
      for (final x in rows) ?rowKey(x.table, x.row),
    };
    await applyRows(rows);
    for (final t in tombstones) {
      if (live.contains(rowKey(t.table, t.row))) continue;
      await _delete(t.table, t.row);
    }
  }

  /// The identity [_delete] removes a row by, or null for tables whose
  /// tombstones the device ignores.
  @visibleForTesting
  static String? rowKey(String table, Map<String, dynamic> r) =>
      switch (table) {
        'rates' || 'game_controls' || 'games' || 'activities' ||
        'pricing_rules' =>
          '$table:${r['id']}',
        'holidays' => 'holidays:${r['day']}',
        'game_resources' => 'game_resources:${r['game_id']}:${r['resource_id']}',
        'resource_activities' =>
          'resource_activities:${r['resource_id']}:${r['activity_id']}',
        'settings' => 'settings:${r['key']}',
        'staff_profiles' => 'staff_profiles:${r['user_id']}',
        _ => null,
      };

  /// Upserts server rows, closings first.
  Future<void> applyRows(List<ServerRow> rows) async {
    bool opens(ServerRow x) =>
        const {'session_segments', 'controller_allocations'}
            .contains(x.table) &&
        x.row['ended_at'] == null;
    for (final x in rows.where((x) => !opens(x))) {
      await upsert(x.table, x.row);
    }
    for (final x in rows.where(opens)) {
      await upsert(x.table, x.row);
    }
  }

  // ------------------------------------------------- entity rollback

  /// Makes the device's copy of one entity exactly the server's: upserts the
  /// server rows and drops local rows of that entity the server does not have
  /// (rows an op the server refused had written). [rows] empty = the server
  /// never had the entity at all.
  Future<void> replaceEntity(
      String type, String id, List<ServerRow> rows) async {
    Set<String> ids(String table) => {
          for (final x in rows)
            if (x.table == table) x.row['id'] as String,
        };
    switch (type) {
      case 'session':
        await (_db.delete(_db.payments)
              ..where((t) => t.sessionId.equals(id) & t.id.isNotIn(ids('payments'))))
            .go();
        await (_db.delete(_db.sessionCharges)
              ..where((t) =>
                  t.sessionId.equals(id) & t.id.isNotIn(ids('session_charges'))))
            .go();
        await (_db.delete(_db.sessionExtensions)
              ..where((t) => t.sessionId.equals(id) &
                  t.id.isNotIn(ids('session_extensions'))))
            .go();
        await (_db.delete(_db.controllerAllocations)
              ..where((t) => t.sessionId.equals(id) &
                  t.id.isNotIn(ids('controller_allocations'))))
            .go();
        await (_db.delete(_db.controllerMoves)
              ..where((t) => t.sessionRef.equals('s:$id') &
                  t.id.isNotIn(ids('controller_moves'))))
            .go();
        await (_db.delete(_db.sessionSegments)
              ..where((t) => t.sessionId.equals(id) &
                  t.id.isNotIn(ids('session_segments'))))
            .go();
        await (_db.delete(_db.sessions)
              ..where((t) => t.id.equals(id) & t.id.isNotIn(ids('sessions'))))
            .go();
      case 'controller':
        // Location + history are the pad's; who holds it belongs to sessions.
        await (_db.delete(_db.controllerMoves)
              ..where((t) => t.controllerId.equals(id) &
                  t.id.isNotIn(ids('controller_moves'))))
            .go();
      case 'customer':
        await (_db.delete(_db.customers)
              ..where((t) => t.id.equals(id) & t.id.isNotIn(ids('customers'))))
            .go();
      case 'booking':
        await (_db.delete(_db.bookings)
              ..where((t) => t.id.equals(id) & t.id.isNotIn(ids('bookings'))))
            .go();
    }
    await applyRows(rows);
  }

  /// Replaces the whole configuration (catalog tables) with the server's —
  /// after an owner edit was refused. [rows] is a full feed of those tables.
  Future<void> replaceCatalog(List<ServerRow> rows) async {
    Set<String> ids(String table) => {
          for (final x in rows)
            if (x.table == table) x.row['id'] as String,
        };
    await (_db.delete(_db.activities)..where((t) => t.id.isNotIn(ids('activities'))))
        .go();
    await (_db.delete(_db.resources)..where((t) => t.id.isNotIn(ids('resources'))))
        .go();
    await _db.delete(_db.resourceActivities).go();
    await (_db.delete(_db.gameCategories)
          ..where((t) => t.id.isNotIn(ids('game_categories'))))
        .go();
    await (_db.delete(_db.games)..where((t) => t.id.isNotIn(ids('games')))).go();
    await _db.delete(_db.gameResources).go();
    await (_db.delete(_db.gameControls)
          ..where((t) => t.id.isNotIn(ids('game_controls'))))
        .go();
    await _db.delete(_db.rates).go();
    await _db.delete(_db.pricingRules).go();
    await _db.delete(_db.holidays).go();
    await (_db.delete(_db.settings)
          ..where((t) => t.key.isIn(sharedSettingKeys)))
        .go();
    await (_db.delete(_db.controllers)
          ..where((t) => t.id.isNotIn(ids('controllers'))))
        .go();
    final members = {
      for (final x in rows)
        if (x.table == 'staff_profiles') x.row['user_id'] as String,
    };
    await (_db.delete(_db.users)..where((t) => t.id.isNotIn(members))).go();
    await applyRows([
      for (final x in rows)
        if (catalogTables.contains(x.table)) x,
    ]);
  }

  // ------------------------------------------------------------- rows

  Future<void> upsert(String table, Map<String, dynamic> r) async {
    switch (table) {
      case 'arenas':
        await _meta('arena_name', r['name'] as String);
      case 'staff_profiles':
        await _db.into(_db.users).insert(
              UsersCompanion.insert(
                id: r['user_id'] as String,
                name: r['name'] as String,
                perms: _strings(r['perms']),
                active: Value(r['active'] as bool),
                sortOrder: Value(r['sort_order'] as int),
              ),
              // Keep this device's PIN + lockout: they never leave the device.
              onConflict: DoUpdate((_) => UsersCompanion(
                    name: Value(r['name'] as String),
                    perms: Value(_strings(r['perms'])),
                    active: Value(r['active'] as bool),
                    sortOrder: Value(r['sort_order'] as int),
                  )),
            );
      case 'activities':
        // No nullable columns, so a plain companion carries every server
        // value; the device's retired activity column keeps its own value.
        await _db.into(_db.activities).insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: r['id'] as String,
              code: r['code'] as String,
              name: r['name'] as String,
              usesControllers: r['uses_controllers'] as bool,
              usesGames: r['uses_games'] as bool,
              durationModel: r['duration_model'] as String,
              sortOrder: Value(r['sort_order'] as int),
              active: Value(r['active'] as bool),
              // Absent from an older server: no grace.
              overtimeGraceMinutes:
                  Value((r['overtime_grace_minutes'] as int?) ?? 0),
            ));
      case 'pricing_rules':
        await _db.into(_db.pricingRules).insertOnConflictUpdate(PricingRuleRow(
              id: r['id'] as String,
              name: r['name'] as String,
              priority: (r['priority'] as num).toInt(),
              active: r['active'] as bool,
              days: [for (final d in r['days'] as List) (d as num).toInt()],
              startMin: (r['start_min'] as num).toInt(),
              endMin: (r['end_min'] as num).toInt(),
              holidayMode: r['holiday_mode'] as String,
              validFrom: r['valid_from'] as String?,
              validUntil: r['valid_until'] as String?,
              activityCodes: _strings(r['activity_codes']),
              adjustKind: r['adjust_kind'] as String,
              adjustValue: (r['adjust_value'] as num).toInt(),
            ).toCompanion(false));
      case 'resources':
        await _db.into(_db.resources).insertOnConflictUpdate(ResourceRow(
              id: r['id'] as String,
              name: r['name'] as String,
              kind: r['kind'] as String,
              status: r['status'] as String,
              sortOrder: r['sort_order'] as int,
              currentMode: r['current_mode'] as String?,
            ).toCompanion(false));
      case 'resource_activities':
        await _db.into(_db.resourceActivities).insertOnConflictUpdate(
            ResourceActivityRow(
                resourceId: r['resource_id'] as String,
                activityCode: r['activity_code'] as String).toCompanion(false));
      case 'controllers':
        await _db.into(_db.controllers).insertOnConflictUpdate(ControllerRow(
              id: r['id'] as String,
              label: r['label'] as String,
              homeResourceId: r['home_resource_id'] as String,
              currentResourceId: r['current_resource_id'] as String,
              status: r['status'] as String,
              notes: r['notes'] as String?,
              loanReturnTo: r['loan_return_to'] as String?,
              loanSessionRef: r['loan_session_ref'] as String?,
              updatedAt: _at(r['updated_at'])!,
            ).toCompanion(false));
      case 'customers':
        await _db.into(_db.customers).insertOnConflictUpdate(CustomerRow(
              id: r['id'] as String,
              name: r['name'] as String,
              phone: r['phone'] as String?,
              notes: r['notes'] as String?,
              lastVisitAt: _at(r['last_visit_at']),
              isGuest: r['is_guest'] as bool,
              // Absent on a server without the column: "not given".
              birthYear: (r['birth_year'] as num?)?.toInt(),
              createdAt: _at(r['created_at'])!,
              updatedAt: _at(r['updated_at'])!,
            ).toCompanion(false));
        await _version('customers', r);
      case 'rates':
        // The device keys a price by (activity, band, controllers); a row it
        // wrote itself carries a local id. Replace whatever holds that key.
        final cc = r['controller_count'] as int?;
        await (_db.delete(_db.rates)
              ..where((t) =>
                  t.activityCode.equals(r['activity_code'] as String) &
                  t.band.equals(r['band'] as String) &
                  (cc == null
                      ? t.controllerCount.isNull()
                      : t.controllerCount.equals(cc)) &
                  t.id.equals(r['id'] as String).not()))
            .go();
        await _db.into(_db.rates).insertOnConflictUpdate(RateRow(
              id: r['id'] as String,
              activityCode: r['activity_code'] as String,
              band: r['band'] as String,
              controllerCount: cc,
              unitMinutes: r['unit_minutes'] as int,
              pricePaise: r['price_paise'] as int,
            ).toCompanion(false));
      case 'billing_policies':
        if (r['active'] != true) return;
        // The columns ARE BillingPolicy.toJson()'s keys.
        const keys = [
          'billing_unit', 'block_rounding', 'grace_minutes',
          'minimum_charge_minutes', 'early_exit', 'rounding_scope',
          'late_arrival', 'vr_unit_rounding', 'money_rounding_paise',
          'money_rounding_dir', 'payment_timing', 'allow_extend_past_close',
          'cleaning_gap_minutes',
        ];
        await _db.into(_db.billingPolicies).insertOnConflictUpdate(
            BillingPolicyRow(
                id: 'default', json: jsonEncode({for (final k in keys) k: r[k]})).toCompanion(false));
      case 'holidays':
        await _db.into(_db.holidays).insertOnConflictUpdate(HolidayRow(
              day: r['day'] as String,
              name: r['name'] as String,
              closed: r['closed'] as bool,
            ).toCompanion(false));
      case 'settings':
        final key = r['key'] as String;
        if (!sharedSettingKeys.contains(key)) return;
        await _db.into(_db.settings).insertOnConflictUpdate(
            SettingRow(key: key, json: jsonEncode(r['json'])).toCompanion(false));
      case 'game_categories':
        await _db.into(_db.gameCategories).insertOnConflictUpdate(GameCategoryRow(
              id: r['id'] as String,
              name: r['name'] as String,
              sortOrder: r['sort_order'] as int,
            ).toCompanion(false));
      case 'games':
        await _db.into(_db.games).insertOnConflictUpdate(GameRow(
              id: r['id'] as String,
              name: r['name'] as String,
              aliases: _strings(r['aliases']),
              categoryId: r['category_id'] as String?,
              platforms: _strings(r['platforms']),
              playModes: _strings(r['play_modes']),
              maxLocalPlayers: r['max_local_players'] as int,
              active: r['active'] as bool,
              lastPlayedAt: _at(r['last_played_at']),
            ).toCompanion(false));
      case 'game_resources':
        await _db.into(_db.gameResources).insertOnConflictUpdate(GameResourceRow(
              gameId: r['game_id'] as String,
              resourceId: r['resource_id'] as String,
              status: r['status'] as String,
              notes: r['notes'] as String?,
              updatedAt: _at(r['updated_at']),
            ).toCompanion(false));
      case 'game_controls':
        await _db.into(_db.gameControls).insertOnConflictUpdate(GameControlRow(
              id: r['id'] as String,
              gameId: r['game_id'] as String,
              section: r['section'] as String,
              action: r['action'] as String,
              buttons: _strings(r['buttons']),
              explanation: r['explanation'] as String?,
              notes: r['notes'] as String?,
              imageUrl: r['image_url'] as String?,
              sortOrder: r['sort_order'] as int,
            ).toCompanion(false));
      case 'bookings':
        final row = BookingsCompanion.insert(
          id: r['id'] as String,
          customerId: Value(r['customer_id'] as String?),
          activityCode: (r['activity_code'] as String?) ?? '',
          gameId: Value(r['game_id'] as String?),
          resourceId: Value(r['resource_id'] as String?),
          scheduledStart: _at(r['scheduled_start'])!,
          scheduledEnd: _at(r['scheduled_end'])!,
          playersRequired: Value(r['players_required'] as int?),
          controllerRequirement: Value(r['controller_requirement'] as int?),
          status: r['status'] as String,
          partyName: Value(r['party_name'] as String?),
          phone: Value(r['phone'] as String?),
          notes: Value(r['notes'] as String?),
          reminderStatus: Value(r['reminder_status'] as String),
          createdAt: _at(r['created_at'])!,
          updatedAt: _at(r['updated_at'])!,
        );
        // Everything but the reminder: this device decides its own reminders.
        await _db.into(_db.bookings).insert(row,
            onConflict:
                DoUpdate((_) => row.copyWith(reminderStatus: const Value.absent())));
        await _version('bookings', r);
      case 'sessions':
        await _db.into(_db.sessions).insertOnConflictUpdate(SessionRow(
              id: r['id'] as String,
              bookingId: r['booking_id'] as String?,
              customerId: r['customer_id'] as String,
              status: r['status'] as String,
              paymentStatus: r['payment_status'] as String,
              startedAt: _at(r['started_at'])!,
              scheduledEndAt: _at(r['scheduled_end_at'])!,
              actualEndedAt: _at(r['actual_ended_at']),
              pricingSnapshot:
                  Map<String, dynamic>.from(r['pricing_snapshot'] as Map),
              billedAmountPaise: r['billed_amount_paise'] as int?,
              voidReason: r['void_reason'] as String?,
              createdAt: _at(r['created_at'])!,
              updatedAt: _at(r['updated_at'])!,
            ).toCompanion(false));
      case 'session_segments':
        final row = SessionSegmentRow(
          id: r['id'] as String,
          sessionId: r['session_id'] as String,
          index: r['idx'] as int,
          resourceId: r['resource_id'] as String,
          activityCode: r['activity_code'] as String,
          gameId: r['game_id'] as String?,
          controllerCount: r['controller_count'] as int?,
          startedAt: _at(r['started_at'])!,
          endedAt: _at(r['ended_at']),
          createdAt: _at(r['created_at'])!,
        );
        if (row.endedAt == null) {
          // The server says this station is held by this segment. A different
          // open segment here is an older server row whose close lands in a
          // later page; close it provisionally so the index holds (the real
          // end arrives with that page and overwrites this).
          await (_db.update(_db.sessionSegments)
                ..where((t) =>
                    t.resourceId.equals(row.resourceId) &
                    t.endedAt.isNull() &
                    t.id.equals(row.id).not()))
              .write(SessionSegmentsCompanion(endedAt: Value(row.startedAt)));
        }
        await _db.into(_db.sessionSegments).insertOnConflictUpdate(row.toCompanion(false));
      case 'session_extensions':
        await _db.into(_db.sessionExtensions).insertOnConflictUpdate(
            SessionExtensionRow(
              id: r['id'] as String,
              sessionId: r['session_id'] as String,
              addedMinutes: r['added_minutes'] as int,
              oldEndAt: _at(r['old_end_at'])!,
              newEndAt: _at(r['new_end_at'])!,
              addedAmountPaise: r['added_amount_paise'] as int,
              reason: r['reason'] as String?,
              createdAt: _at(r['created_at'])!,
            ).toCompanion(false));
      case 'session_charges':
        await _db.into(_db.sessionCharges).insertOnConflictUpdate(SessionChargeRow(
              id: r['id'] as String,
              sessionId: r['session_id'] as String,
              segmentId: r['segment_id'] as String?,
              segmentIndex: r['segment_index'] as int,
              bandCode: r['band_code'] as String,
              activityCode: r['activity_code'] as String,
              resourceId: r['resource_id'] as String?,
              controllerCount: r['controller_count'] as int?,
              segmentStart: _at(r['segment_start'])!,
              segmentEnd: _at(r['segment_end'])!,
              playedMinutes: r['played_minutes'] as int,
              billedMinutes: r['billed_minutes'] as int,
              unitMinutes: r['unit_minutes'] as int,
              unitPricePaise: r['unit_price_paise'] as int,
              amountPaise: r['amount_paise'] as int,
            ).toCompanion(false));
      case 'payments':
        await _db.into(_db.payments).insertOnConflictUpdate(PaymentRow(
              id: r['id'] as String,
              sessionId: r['session_id'] as String,
              amountPaise: r['amount_paise'] as int,
              method: r['method'] as String,
              isRefund: r['kind'] == 'refund',
              note: r['note'] as String?,
              reason: r['reason'] as String?,
              createdAt: _at(r['created_at'])!,
            ).toCompanion(false));
      case 'controller_allocations':
        // Only single-session pads are kept on the device; a row of another
        // scope (group sessions were removed) is ignored.
        if (r['scope'] != 'single') return;
        final row = ControllerAllocationRow(
          id: r['id'] as String,
          controllerId: r['controller_id'] as String,
          scope: r['scope'] as String,
          sessionId: r['session_id'] as String?,
          segmentId: r['segment_id'] as String?,
          resourceId: r['resource_id'] as String,
          activityCode: r['activity_code'] as String,
          gameId: r['game_id'] as String?,
          startedAt: _at(r['started_at'])!,
          endedAt: _at(r['ended_at']),
          requestId: r['request_id'] as String?,
          createdAt: _at(r['created_at'])!,
        );
        if (row.endedAt == null) {
          // Same provisional close as segments: one open row per pad.
          await (_db.update(_db.controllerAllocations)
                ..where((t) =>
                    t.controllerId.equals(row.controllerId) &
                    t.endedAt.isNull() &
                    t.id.equals(row.id).not()))
              .write(ControllerAllocationsCompanion(endedAt: Value(row.startedAt)));
        }
        await _db.into(_db.controllerAllocations).insertOnConflictUpdate(row.toCompanion(false));
      case 'controller_moves':
        await _db.into(_db.controllerMoves).insertOnConflictUpdate(ControllerMoveRow(
              id: r['id'] as String,
              controllerId: r['controller_id'] as String,
              fromResourceId: r['from_resource_id'] as String,
              toResourceId: r['to_resource_id'] as String,
              kind: r['kind'] as String,
              sessionRef: r['session_ref'] as String?,
              movedAt: _at(r['moved_at'])!,
              createdAt: _at(r['created_at'])!,
            ).toCompanion(false));
      default:
        // A table this build does not know yet: ignore rather than fail.
        return;
    }
  }

  Future<void> _delete(String table, Map<String, dynamic> r) async {
    String? id() => r['id'] as String?;
    switch (table) {
      case 'rates':
        await (_db.delete(_db.rates)..where((t) => t.id.equals(id()!))).go();
      case 'holidays':
        await (_db.delete(_db.holidays)
              ..where((t) => t.day.equals(r['day'] as String)))
            .go();
      case 'pricing_rules':
        // Sessions already started keep the rule in their frozen snapshot.
        await (_db.delete(_db.pricingRules)..where((t) => t.id.equals(id()!)))
            .go();
      case 'game_controls':
        await (_db.delete(_db.gameControls)..where((t) => t.id.equals(id()!)))
            .go();
      case 'games':
        // game.delete removes only a game nothing ever used (a used one is
        // archived instead), so no session or booking here names it. Its
        // station statuses and control guide go with it (their own tombstones
        // follow too, but may land in a later page).
        await (_db.delete(_db.gameResources)..where((t) => t.gameId.equals(id()!)))
            .go();
        await (_db.delete(_db.gameControls)..where((t) => t.gameId.equals(id()!)))
            .go();
        await (_db.delete(_db.games)..where((t) => t.id.equals(id()!))).go();
      case 'activities':
        // activity.remove deletes only a type nothing ever used; its prices and
        // station links arrive as their own tombstones.
        await (_db.delete(_db.activities)..where((t) => t.id.equals(id()!)))
            .go();
      case 'game_resources':
        await (_db.delete(_db.gameResources)
              ..where((t) =>
                  t.gameId.equals(r['game_id'] as String) &
                  t.resourceId.equals(r['resource_id'] as String)))
            .go();
      case 'resource_activities':
        // The tombstone carries the activity's server id; the device keys the
        // link by the activity's code.
        final activity = await (_db.select(_db.activities)
              ..where((t) => t.id.equals(r['activity_id'] as String)))
            .getSingleOrNull();
        if (activity == null) return;
        await (_db.delete(_db.resourceActivities)
              ..where((t) =>
                  t.resourceId.equals(r['resource_id'] as String) &
                  t.activityCode.equals(activity.code)))
            .go();
      case 'settings':
        final key = r['key'] as String;
        if (!sharedSettingKeys.contains(key)) return;
        await (_db.delete(_db.settings)..where((t) => t.key.equals(key))).go();
      case 'staff_profiles':
        await (_db.delete(_db.users)
              ..where((t) => t.id.equals(r['user_id'] as String)))
            .go();
      default:
        // Floor history is append-only server-side; nothing else is deleted.
        return;
    }
  }

  Future<void> _version(String entity, Map<String, dynamic> r) async {
    final v = r['sync_xid'];
    if (v == null) return;
    await _db.into(_db.syncVersions).insertOnConflictUpdate(SyncVersionRow(
        entity: entity, rowId: r['id'] as String, version: '$v').toCompanion(false));
  }

  Future<void> _meta(String key, String value) => _db
      .into(_db.syncMeta)
      .insertOnConflictUpdate(SyncMetaRow(key: key, value: value).toCompanion(false));

  static DateTime? _at(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toUtc();

  static List<String> _strings(Object? v) =>
      v == null ? const [] : [for (final e in v as List) e as String];
}
