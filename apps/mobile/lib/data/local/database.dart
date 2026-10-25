import 'package:arena_ops/data/local/converters.dart';
import 'package:arena_ops/domain/auth/pin_credential.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'database.g.dart';

// Drift row data classes are suffixed `Row` so they never clash with the pure
// domain entities (Customer, Session, ...). Repositories map Row → entity.

@DataClassName('CustomerRow')
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get lastVisitAt => dateTime().nullable()();

  /// A walk-in who never registered (brief §12).
  BoolColumn get isGuest => boolean().withDefault(const Constant(false))();

  /// Year of birth given at registration; null when not given (v15).
  IntColumn get birthYear => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ActivityRow')
class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  BoolColumn get usesControllers => boolean()();
  BoolColumn get usesGames => boolean()();
  TextColumn get durationModel => text()();

  /// Retired in v16: an activity pricing flag older builds billed by (time-of-
  /// day prices are pricing rules now). The column stays so device files made
  /// by those builds keep opening and inserting; nothing reads it. Filled in
  /// Dart because the old column has no SQL default.
  BoolColumn get legacyHappyHourEligible => boolean()
      .named('happy_hour_eligible')
      .clientDefault(() => false)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// v17: overtime allowed free past a session's booked end when it ends on
  /// this type (Activity.overtimeGraceMinutes). Part of the pricing snapshot.
  IntColumn get overtimeGraceMinutes =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ResourceRow')
class Resources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get status => text().withDefault(const Constant('available'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// For a dual-capability station (RIFT: PS5 *or* VR). Null = not mode-locked.
  /// When set to an activity code, only that activity may be allocated here.
  TextColumn get currentMode => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ResourceActivityRow')
class ResourceActivities extends Table {
  TextColumn get resourceId => text()();
  TextColumn get activityCode => text()();

  @override
  Set<Column> get primaryKey => {resourceId, activityCode};
}

/// Physical controllers, tracked as units (brief: Phase 2 of the PRD's
/// deferred serial tracking). Sessions keep their integer controller *count*
/// as the billing tier; these rows answer where each pad is and whether it
/// works.
@DataClassName('ControllerRow')
class Controllers extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()(); // 'HEX-1' — what is written on the pad
  TextColumn get homeResourceId => text()();
  TextColumn get currentResourceId => text()();
  TextColumn get status =>
      text().withDefault(const Constant('usable'))(); // ControllerStatus code
  TextColumn get notes => text().nullable()();

  /// Set while on loan: where to return it, and which session owes the return
  /// (`s:<sessionId>`). Both null for a permanent move.
  TextColumn get loanReturnTo => text().nullable()();
  TextColumn get loanSessionRef => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One physical controller held by one session for a stretch of time
/// (brief §3–§5). Append-only: a move or a change end-dates the open row and
/// opens a new one, so the per-pad timeline is never rewritten. [resourceId] is
/// the station the pad is being USED at, which can differ from the pad's
/// physical `currentResourceId` after a borrow. The partial unique index
/// `ux_one_open_allocation_per_controller` is the DB-level guarantee that a pad
/// is never in two active sessions at once (brief §4, §9).
@DataClassName('ControllerAllocationRow')
class ControllerAllocations extends Table {
  TextColumn get id => text()();
  TextColumn get controllerId => text()();
  TextColumn get scope => text()(); // 'single'
  TextColumn get sessionId => text().nullable()();
  TextColumn get segmentId => text().nullable()();
  TextColumn get resourceId => text()();
  TextColumn get activityCode => text()();
  TextColumn get gameId => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()(); // null = active
  TextColumn get requestId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Where a physical pad has been carried, and why (location history). One row
/// per physical move — an owner relocation, a staff borrow at session start /
/// mid-session, or a return. Append-only and separate from allocation: a pad
/// is only "moved" when one of these is written, never because it was picked.
/// [fromResourceId] is where it actually was (which may not be its home).
@DataClassName('ControllerMoveRow')
class ControllerMoves extends Table {
  TextColumn get id => text()();
  TextColumn get controllerId => text()();
  TextColumn get fromResourceId => text()();
  TextColumn get toResourceId => text()();
  TextColumn get kind => text()(); // ControllerMoveKind code
  TextColumn get sessionRef => text().nullable()(); // s:<id>
  DateTimeColumn get movedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GameCategoryRow')
class GameCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GameRow')
class Games extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get aliases => text().map(const StringListConverter())();
  TextColumn get categoryId => text().nullable()();
  TextColumn get platforms => text().map(const StringListConverter())();
  /// [PlayerMode] codes, one or more (server games.play_modes).
  TextColumn get playModes => text()
      .map(const StringListConverter())
      .withDefault(const Constant('["single"]'))();
  IntColumn get maxLocalPlayers => integer().withDefault(const Constant(1))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Game ↔ resource compatibility (spec §4). Absence of a row means the game is
/// not installed on that resource.
@DataClassName('GameResourceRow')
class GameResources extends Table {
  TextColumn get gameId => text()();
  TextColumn get resourceId => text()();
  TextColumn get status => text()(); // GameAvailability code

  /// Why this game is in this state on this system ("disc scratched").
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {gameId, resourceId};
}

@DataClassName('GameControlRow')
class GameControls extends Table {
  TextColumn get id => text()();
  TextColumn get gameId => text()();
  TextColumn get section => text()();
  TextColumn get action => text()();
  TextColumn get buttons => text().map(const StringListConverter())();
  TextColumn get explanation => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RateRow')
class Rates extends Table {
  TextColumn get id => text()();
  TextColumn get activityCode => text()();
  TextColumn get band => text()();
  IntColumn get controllerCount => integer().nullable()();
  IntColumn get unitMinutes => integer()();
  IntColumn get pricePaise => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The active billing policy, stored as one JSON row.
@DataClassName('BillingPolicyRow')
class BillingPolicies extends Table {
  TextColumn get id => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HolidayRow')
class Holidays extends Table {
  TextColumn get day => text()(); // IST ISO date
  TextColumn get name => text()();

  /// A public holiday (pricing rules can target or skip it). [closed]
  /// additionally means the centre does not trade that day (OWNER
  /// CONFIRMATION #26).
  BoolColumn get closed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {day};
}

/// A pricing rule (server `pricing_rules`, synced read-only): a day/time price
/// adjustment the owner defines on the dashboard. Active rows are frozen into
/// every new session's pricing snapshot (v16).
@DataClassName('PricingRuleRow')
class PricingRules extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// ISO weekdays (1 = Monday … 7 = Sunday).
  TextColumn get days => text().map(const IntListConverter())();
  IntColumn get startMin => integer()();
  IntColumn get endMin => integer()();
  TextColumn get holidayMode => text().withDefault(const Constant('any'))();

  /// IST ISO dates, inclusive; null = open-ended.
  TextColumn get validFrom => text().nullable()();
  TextColumn get validUntil => text().nullable()();

  /// Empty = every activity.
  TextColumn get activityCodes => text().map(const StringListConverter())();
  TextColumn get adjustKind => text()(); // percent | per_hour
  IntColumn get adjustValue => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row-per-key app configuration (opening hours today). Kept as JSON so
/// a new config block needs no migration of its own.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The parent session (spec §9). Per-segment config (resource/game/controllers)
/// lives in SessionSegments, not here.
@DataClassName('SessionRow')
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get bookingId => text().nullable()();
  TextColumn get customerId => text()();
  TextColumn get status => text()();
  TextColumn get paymentStatus => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get scheduledEndAt => dateTime()();
  DateTimeColumn get actualEndedAt => dateTime().nullable()();
  TextColumn get pricingSnapshot => text().map(const JsonMapConverter())();
  IntColumn get billedAmountPaise => integer().nullable()();
  TextColumn get voidReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One configuration stretch of a parent session (spec §9–§14). The open
/// segment has endedAt == null.
@DataClassName('SessionSegmentRow')
class SessionSegments extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  IntColumn get index => integer()();
  TextColumn get resourceId => text()();
  TextColumn get activityCode => text()();
  TextColumn get gameId => text().nullable()();
  IntColumn get controllerCount => integer().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SessionExtensionRow')
class SessionExtensions extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  IntColumn get addedMinutes => integer()();
  DateTimeColumn get oldEndAt => dateTime()();
  DateTimeColumn get newEndAt => dateTime()();
  IntColumn get addedAmountPaise => integer().withDefault(const Constant(0))();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SessionChargeRow')
class SessionCharges extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get segmentId => text().nullable()();
  IntColumn get segmentIndex => integer()();
  TextColumn get bandCode => text()();
  TextColumn get activityCode => text()();
  TextColumn get resourceId => text().nullable()();
  IntColumn get controllerCount => integer().nullable()();
  DateTimeColumn get segmentStart => dateTime()();
  DateTimeColumn get segmentEnd => dateTime()();
  IntColumn get playedMinutes => integer()();
  IntColumn get billedMinutes => integer()();
  IntColumn get unitMinutes => integer()();
  IntColumn get unitPricePaise => integer()();
  IntColumn get amountPaise => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A future reservation (spec §18). resourceId null = any compatible system.
@DataClassName('BookingRow')
class Bookings extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get activityCode => text()();
  TextColumn get gameId => text().nullable()();
  TextColumn get resourceId => text().nullable()();
  DateTimeColumn get scheduledStart => dateTime()();
  DateTimeColumn get scheduledEnd => dateTime()();
  IntColumn get playersRequired => integer().nullable()();
  IntColumn get controllerRequirement => integer().nullable()();
  TextColumn get status => text()();

  /// Walk-in party details when no customer record exists yet (spec §18).
  TextColumn get partyName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Whether a device reminder is currently scheduled for this booking.
  TextColumn get reminderStatus =>
      text().withDefault(const Constant('scheduled'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Staff/owner accounts for the PIN login (design: users with a PIN + perms).
///
/// The PIN itself is never stored. v11 replaced the old plaintext `pin` column
/// with a per-account salt + PBKDF2 hash, and added the failed-attempt fields
/// that rate-limit guessing at the keypad.
@DataClassName('UserRow')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get perms => text().map(const StringListConverter())();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Base64 salt / PBKDF2 hash / cost. Null only for an account whose PIN has
  /// never been set, which cannot sign in.
  TextColumn get pinSalt => text().nullable()();
  TextColumn get pinHash => text().nullable()();
  IntColumn get pinIterations => integer().nullable()();

  /// Consecutive wrong PINs, and the instant the account unlocks. Persisted, so
  /// force-quitting the app does not reset the lockout.
  IntColumn get failedAttempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntilAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The durable outbox for cloud sync (Phase 2). One row per operation that
/// must reach the server, written in the SAME transaction as the local change it
/// describes, so a crash can never leave a change without its op or an op
/// without its change. Rows are never deleted: an applied op is the audit trail
/// of what this device sent, and a rejected one is the only copy of what the
/// server refused (shown to staff until resolved).
///
/// Unused in local-only mode — nothing is ever enqueued there.
@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  /// Push order. The server applies a device's ops in exactly this order.
  IntColumn get seq => integer().autoIncrement()();

  /// Generated on this device; the server's idempotency key.
  TextColumn get opId => text().unique()();
  TextColumn get kind => text()(); // e.g. session.start, payment.record
  /// What the op is about, for rollback after a rejection:
  /// session | controller | customer | booking | catalog | staff.
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get payload => text()(); // JSON, exactly what sync_push receives

  /// pending → applied | rejected. A rejected op stays visible until resolved.
  TextColumn get status => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorDetail => text().nullable()();
  TextColumn get result => text().nullable()(); // server result JSON

  /// The device must refetch [entityType]/[entityId] from the server: its local
  /// copy was rolled forward by an op the server refused or adjusted.
  BoolColumn get needsRefetch => boolean().withDefault(const Constant(false))();

  /// Who did it on this device, for the conflicts list.
  TextColumn get actorId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
}

/// Sync bookkeeping (pull cursor, bound arena/user, device id) as key/value.
@DataClassName('SyncMetaRow')
class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The server version (`sync_xid`) this device last saw for an editable row,
/// sent back as `base_version` so the server can refuse an edit made on top of
/// a copy another device has since changed.
@DataClassName('SyncVersionRow')
class SyncVersions extends Table {
  TextColumn get entity => text()(); // server table name
  TextColumn get rowId => text()();
  TextColumn get version => text()();

  @override
  Set<Column> get primaryKey => {entity, rowId};
}

@DataClassName('PaymentRow')
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  IntColumn get amountPaise => integer()();
  TextColumn get method => text()();
  BoolColumn get isRefund => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Customers,
  Activities,
  Resources,
  ResourceActivities,
  Controllers,
  ControllerAllocations,
  ControllerMoves,
  GameCategories,
  Games,
  GameResources,
  GameControls,
  Rates,
  BillingPolicies,
  Holidays,
  Settings,
  PricingRules,
  Sessions,
  SessionSegments,
  SessionExtensions,
  SessionCharges,
  Payments,
  Bookings,
  Users,
  SyncOutbox,
  SyncMeta,
  SyncVersions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Readable without constructing (and therefore without opening) the
  /// database, so the pre-open backup in `main()` can compare it against what
  /// is on disk and decide whether a migration is about to run.
  static const expectedSchemaVersion = 19;

  @override
  int get schemaVersion => expectedSchemaVersion;

  // Enforce "one OPEN segment per resource" at the DB level (spec §24): a
  // resource hosts at most one in-progress segment. Also enforces RIFT PS5⊕VR
  // since RIFT is a single resource row.
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_one_open_segment_per_resource '
      'ON session_segments (resource_id) WHERE ended_at IS NULL',
    );
    // One price per (activity, band, controller count). COALESCE because
    // SQLite treats NULLs as distinct, which would let two "no controllers"
    // rows coexist and make pricing depend on row order.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_rate_per_combination '
      'ON rates (activity_code, band, COALESCE(controller_count, -1))',
    );
    // Reports and the floor both look sessions up by time; these keep that
    // from degrading into a table scan as history grows.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS ix_sessions_started ON sessions (started_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS ix_segments_session '
      'ON session_segments (session_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS ix_payments_created ON payments (created_at)',
    );
    // Allocation reads "usable controllers at this station" constantly.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS ix_controllers_at_station '
      'ON controllers (current_resource_id, status)',
    );
    // One physical controller in at most one active allocation (brief §4, §9):
    // the DB-level double-allocation guard, mirroring the open-segment index.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_one_open_allocation_per_controller '
      'ON controller_allocations (controller_id) WHERE ended_at IS NULL',
    );
    // The dashboard attributes open allocations to stations constantly.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS ix_alloc_open_by_resource '
      'ON controller_allocations (resource_id) WHERE ended_at IS NULL',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS ix_alloc_session ON controller_allocations (session_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS ix_moves_controller '
      'ON controller_moves (controller_id, moved_at)',
    );
    // The sync engine reads "what is still pending, in order" on every pass.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS ix_outbox_status ON sync_outbox (status, seq)',
    );
  }

  /// The version a migration rebuilt from, when it had to fall back to a
  /// rebuild instead of a sequential step. 0 on a clean sequential upgrade.
  ///
  /// `main()` reads this after opening so a rebuild is *reported* rather than
  /// passing silently — after one, the verified backup is the only other copy.
  int rebuiltFromVersion = 0;

  /// One step per version boundary: `_steps[n]` takes the schema from v`n` to
  /// v`n+1`. Steps must be additive — add a table, add a column, add an index —
  /// and must never drop or rewrite user rows.
  ///
  /// Adding a schema change means: bump [expectedSchemaVersion], add the step
  /// here, and add a case to `test/data/local/db_safety_test.dart` proving that
  /// sessions, segments and payments written at the old version are still
  /// readable afterwards.
  Map<int, Future<void> Function(Migrator m)> get _steps => {
        // v10 -> v11: stop storing staff PINs in the clear. Adds the salt/hash
        // columns and the failed-attempt fields, converts each existing PIN to
        // a salted hash, then drops the plaintext column. Every session,
        // booking and payment row is untouched.
        10: (m) async {
          await m.addColumn(users, users.pinSalt);
          await m.addColumn(users, users.pinHash);
          await m.addColumn(users, users.pinIterations);
          await m.addColumn(users, users.failedAttempts);
          await m.addColumn(users, users.lockedUntilAt);

          // The legacy column is gone from the Dart table, so it has to be read
          // raw. Accounts keep working: the PIN staff already know is hashed in
          // place rather than reset.
          final legacy = await customSelect(
            'SELECT id, pin FROM users',
            readsFrom: {users},
          ).get();
          for (final row in legacy) {
            final id = row.read<String>('id');
            final plain = row.read<String?>('pin') ?? '';
            final cred = plain.isEmpty ? null : PinCredential.create(plain);
            await (update(users)..where((t) => t.id.equals(id))).write(
              UsersCompanion(
                pinSalt: Value(cred?.salt),
                pinHash: Value(cred?.hash),
                pinIterations: Value(cred?.iterations),
                failedAttempts: const Value(0),
                lockedUntilAt: const Value(null),
              ),
            );
          }

          await customStatement('ALTER TABLE users DROP COLUMN pin');
          // Dropping the column frees the pages that held the plaintext but
          // leaves the bytes in the file; VACUUM rewrites it without them.
          // Deferred because VACUUM cannot run inside the migration's
          // transaction.
          _vacuumAfterMigration = true;
        },
        // v11 -> v12: physical controller allocation (brief §3–§5). ADDITIVE —
        // adds the controller_allocations table and resources.current_mode; no
        // existing session/payment/segment row is touched. The new indexes are
        // (re)created by _createIndexes() after the step loop.
        11: (m) async {
          await m.createTable(controllerAllocations);
          await m.addColumn(resources, resources.currentMode);
        },
        // v12 -> v13: controller location history (borrow / move / return).
        // ADDITIVE — one new append-only table; nothing existing is touched.
        12: (m) async {
          await m.createTable(controllerMoves);
        },
        // v13 -> v14: cloud sync bookkeeping (outbox, cursor, row versions).
        // ADDITIVE — three new tables, empty until the device is bound to a
        // cloud arena; no existing row is touched.
        13: (m) async {
          await m.createTable(syncOutbox);
          await m.createTable(syncMeta);
          await m.createTable(syncVersions);
        },
        // v14 -> v15: member birth year (customers.birth_year). ADDITIVE — one nullable
        // column; every existing customer keeps its row and reads as "not given".
        14: (m) async {
          await m.addColumn(customers, customers.birthYear);
        },
        // v15 -> v16: pricing rules (time-of-day prices). ADDITIVE — one new
        // table; no session, segment, charge or payment row is touched, and
        // the retired activity column stays. A cloud device rewinds its pull
        // cursor so the next sync re-reads the feed from the start: rule rows
        // the server sent before this build were skipped as an unknown table,
        // and without them every new session's snapshot would be refused.
        // Re-applying the feed is idempotent (server rows are upserted).
        15: (m) async {
          await m.createTable(pricingRules);
          await customStatement(
            "UPDATE sync_meta SET value = '0' WHERE key = 'pull_cursor'",
          );
        },
        // v16 -> v17: a station type's overtime grace. ADDITIVE — one column
        // with a default (0 = every overtime minute billed, as before); no
        // session, segment, charge or payment row is touched. A cloud device
        // rewinds its pull cursor so the next sync re-reads the types with
        // their grace: without it every new session's snapshot would carry 0
        // and be refused once an owner sets one.
        16: (m) async {
          await m.addColumn(activities, activities.overtimeGraceMinutes);
          await customStatement(
            "UPDATE sync_meta SET value = '0' WHERE key = 'pull_cursor'",
          );
        },
        // v17 -> v18: a game has one or more play modes (story, single, local,
        // online) instead of one player mode. Catalog only — no session,
        // segment, charge or payment row is touched. Each game's mode is
        // copied across (both = local and online), then the old column goes,
        // as on the server.
        17: (m) async {
          await m.addColumn(games, games.playModes);
          await customStatement(
            "UPDATE games SET play_modes = CASE player_mode "
            "WHEN 'local' THEN '[\"local\"]' "
            "WHEN 'online' THEN '[\"online\"]' "
            "WHEN 'both' THEN '[\"local\",\"online\"]' "
            "ELSE '[\"single\"]' END",
          );
          await customStatement('ALTER TABLE games DROP COLUMN player_mode');
        },
        // v18 -> v19: group sessions removed (owner-approved: their tables
        // are dropped). No session, segment, extension, charge, payment,
        // booking or customer row is touched. Pads held for a group player
        // (controller_allocations scope 'group') go with their groups, so no
        // pad stays "in use" by a group that no longer exists; every
        // single-session allocation is copied across unchanged while the
        // table is rebuilt without its group-only columns. Pad locations
        // (controllers, controller_moves) and the outbox are left as they are.
        18: (m) async {
          // Indexes on the columns being removed would break the rebuild.
          await customStatement('DROP INDEX IF EXISTS ix_alloc_group');
          await customStatement('DROP INDEX IF EXISTS ix_alloc_assignment');
          await customStatement(
            "DELETE FROM controller_allocations WHERE scope = 'group'",
          );
          await m.alterTable(TableMigration(controllerAllocations));
          for (final t in const [
            'group_payments',
            'group_charges',
            'group_extensions',
            'group_assignments',
            'group_sessions',
          ]) {
            await m.deleteTable(t);
          }
        },
      };

  /// Set by a migration step that needs the file rewritten once the migration's
  /// transaction has committed.
  bool _vacuumAfterMigration = false;

  /// The version boundaries [_steps] covers, for the test that guards against a
  /// gap in the chain (a gap falls through to the destructive rebuild).
  @visibleForTesting
  Set<int> get declaredMigrationSteps => _steps.keys.toSet();

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (m, from, to) async {
          for (var v = from; v < to; v++) {
            final step = _steps[v];
            if (step == null) {
              // No sequential path from a pre-release version. `main()` has
              // already taken and verified a full backup, so rebuilding is
              // recoverable — but it is recorded, not silent.
              rebuiltFromVersion = from;
              for (final table in allTables) {
                await m.deleteTable(table.actualTableName);
              }
              await m.createAll();
              await _createIndexes();
              return;
            }
            await step(m);
          }
          // Cheap and idempotent, and it closes the gap where an index added in
          // an earlier build never got created on this device.
          await _createIndexes();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA busy_timeout = 5000;');
          await customStatement('PRAGMA journal_mode = WAL;');
          // Referential integrity is per-connection in SQLite, so it has to be
          // asked for on every open, not declared once in the schema.
          await customStatement('PRAGMA foreign_keys = ON;');
          if (_vacuumAfterMigration) {
            _vacuumAfterMigration = false;
            // Runs here because the migration transaction has committed by now.
            // Failure is not fatal: the schema is already correct, the file just
            // keeps some dead bytes.
            try {
              await customStatement('VACUUM');
            } on Object catch (_) {}
          }
        },
      );
}
