/// Pre-open protection for the on-device database.
///
/// The counter device holds the *only* copy of the day's takings, and Drift runs
/// its migration the instant [AppDatabase] opens the file. So the backup has to
/// be taken — and **verified** — before that open happens, not inside
/// `onUpgrade` where the schema change is already in flight and the file is
/// mid-transaction.
///
/// [DbSafety.protect] is therefore called from `main()` *before* the database is
/// constructed, and the app refuses to open a database that needs migrating when
/// no verified backup could be taken.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

/// What [DbSafety.protect] did.
enum DbProtectOutcome {
  /// No database file yet — a fresh install has nothing to lose.
  freshInstall,

  /// A new backup was taken and passed verification.
  backedUp,

  /// The current file is byte-identical to a backup that already exists.
  alreadyProtected,

  /// A copy was taken but could not be verified. The caller must not let a
  /// migration run.
  verificationFailed,
}

/// The result of a protection attempt — also the audit record of it.
class DbProtectReport {
  const DbProtectReport({
    required this.outcome,
    required this.appSchemaVersion,
    this.onDiskSchemaVersion,
    this.backupFile,
    this.rowCounts = const {},
    this.detail,
  });

  final DbProtectOutcome outcome;

  /// Schema version the running build expects.
  final int appSchemaVersion;

  /// Schema version found on disk; null on a fresh install.
  final int? onDiskSchemaVersion;

  /// The verified backup, when there is one.
  final File? backupFile;

  /// Key table counts read back out of the backup — proof it is readable, and
  /// the record of what was protected.
  final Map<String, int> rowCounts;

  /// Why verification failed, when it did.
  final String? detail;

  /// True when opening the database would run a migration.
  bool get migrationExpected =>
      onDiskSchemaVersion != null && onDiskSchemaVersion != appSchemaVersion;

  /// A migration is only allowed to proceed behind a verified backup.
  bool get safeToOpen => !migrationExpected || hasVerifiedBackup;

  bool get hasVerifiedBackup =>
      outcome == DbProtectOutcome.backedUp ||
      outcome == DbProtectOutcome.alreadyProtected;

  @override
  String toString() {
    final parts = <String>[
      'outcome=${outcome.name}',
      'app=v$appSchemaVersion',
      'disk=${onDiskSchemaVersion == null ? 'none' : 'v$onDiskSchemaVersion'}',
      'migrationExpected=$migrationExpected',
      'safeToOpen=$safeToOpen',
      if (backupFile != null) 'backup=${backupFile!.path}',
      if (rowCounts.isNotEmpty)
        'rows={${rowCounts.entries.map((e) => '${e.key}:${e.value}').join(',')}}',
      if (detail != null) 'detail=$detail',
    ];
    return 'DbProtectReport(${parts.join(' ')})';
  }
}

/// Takes and verifies backups of the local database.
class DbSafety {
  /// Tables whose counts are read back out of every backup. Chosen because
  /// losing a row in any of them loses money or history.
  static const verifiedTables = <String>[
    'sessions',
    'session_segments',
    'payments',
    'bookings',
    'customers',
    'users',
  ];

  /// Copy [dbFile] aside and prove the copy is sound, before anything opens the
  /// original.
  ///
  /// The live write-ahead log is copied with the database and then checkpointed
  /// *into the copy*, so a backup is a single self-contained file that includes
  /// transactions the main file had not absorbed yet. Nothing writes to the
  /// live database here.
  ///
  /// [keep] backups are retained, except that the newest backup of each distinct
  /// schema version is never pruned — that is the one that can still be read by
  /// the build it came from.
  ///
  /// Runs in a background isolate: the sqlite3 calls (integrity check, counts,
  /// checkpoint) are synchronous and read the whole file, and on iOS the UI
  /// isolate runs on the main thread, so doing this inline blocked the app at
  /// start.
  static Future<DbProtectReport> protect({
    required File dbFile,
    required int appSchemaVersion,
    required Directory backupDir,
    int keep = 10,
    String label = 'arena_ops',
  }) =>
      Isolate.run(
        () => _protect(
          dbFile: dbFile,
          appSchemaVersion: appSchemaVersion,
          backupDir: backupDir,
          keep: keep,
          label: label,
        ),
        debugName: 'DbSafety.protect',
      );

  static Future<DbProtectReport> _protect({
    required File dbFile,
    required int appSchemaVersion,
    required Directory backupDir,
    required int keep,
    required String label,
  }) async {
    if (!dbFile.existsSync()) {
      return DbProtectReport(
        outcome: DbProtectOutcome.freshInstall,
        appSchemaVersion: appSchemaVersion,
      );
    }

    await backupDir.create(recursive: true);

    // Stage the copy under a temporary name: the schema version goes in the
    // final filename, and it is only trustworthy once read out of the copy.
    final staging = File('${backupDir.path}/.staging-$label.sqlite');
    await _deleteQuietly(staging);

    int? onDiskVersion;
    var rowCounts = <String, int>{};
    try {
      await dbFile.copy(staging.path);
      // The -wal holds committed transactions that are not in the main file
      // yet; without it a backup can be missing the last sessions and payments.
      for (final suffix in const ['-wal', '-shm']) {
        final side = File('${dbFile.path}$suffix');
        if (side.existsSync()) {
          await side.copy('${staging.path}$suffix');
        }
      }

      // Open the *copy*. A plain sqlite3 open carries no Drift schema version,
      // so it recovers the WAL without ever running a migration.
      final db = sqlite3.open(staging.path);
      try {
        onDiskVersion = db.userVersion;
        final integrity = db.select('PRAGMA integrity_check;');
        final verdict =
            integrity.isEmpty ? 'empty' : '${integrity.first.values.first}';
        if (verdict != 'ok') {
          return DbProtectReport(
            outcome: DbProtectOutcome.verificationFailed,
            appSchemaVersion: appSchemaVersion,
            onDiskSchemaVersion: onDiskVersion,
            detail: 'integrity_check: $verdict',
          );
        }
        rowCounts = _countTables(db);
        // Fold the WAL in so the kept file stands alone.
        db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      } finally {
        db.close();
      }

      for (final suffix in const ['-wal', '-shm']) {
        await _deleteQuietly(File('${staging.path}$suffix'));
      }

      // Already have this exact state on disk? Keep the existing backup.
      final twin = await _identicalExisting(backupDir, staging, label);
      if (twin != null) {
        await _deleteQuietly(staging);
        return DbProtectReport(
          outcome: DbProtectOutcome.alreadyProtected,
          appSchemaVersion: appSchemaVersion,
          onDiskSchemaVersion: onDiskVersion,
          backupFile: twin,
          rowCounts: rowCounts,
        );
      }

      // Second-resolution stamps can collide (two opens in the same second, or
      // a test loop), and renaming onto an existing backup would destroy it.
      final stamp = _stamp();
      var target =
          File('${backupDir.path}/$label-v$onDiskVersion-${stamp}Z.sqlite');
      for (var n = 1; target.existsSync(); n++) {
        target = File(
            '${backupDir.path}/$label-v$onDiskVersion-${stamp}Z-$n.sqlite');
      }
      await staging.rename(target.path);

      await _prune(backupDir, label: label, keep: keep);

      return DbProtectReport(
        outcome: DbProtectOutcome.backedUp,
        appSchemaVersion: appSchemaVersion,
        onDiskSchemaVersion: onDiskVersion,
        backupFile: target,
        rowCounts: rowCounts,
      );
    } on Object catch (e) {
      await _deleteQuietly(staging);
      for (final suffix in const ['-wal', '-shm']) {
        await _deleteQuietly(File('${staging.path}$suffix'));
      }
      return DbProtectReport(
        outcome: DbProtectOutcome.verificationFailed,
        appSchemaVersion: appSchemaVersion,
        onDiskSchemaVersion: onDiskVersion,
        detail: '$e',
      );
    }
  }

  /// Re-verify a kept backup: it opens, it is sound, and it still reports the
  /// rows it was taken for. Used by the restore path and by the tests.
  static DbProtectReport verifyBackup(File backup, {int? appSchemaVersion}) {
    if (!backup.existsSync()) {
      return DbProtectReport(
        outcome: DbProtectOutcome.verificationFailed,
        appSchemaVersion: appSchemaVersion ?? -1,
        detail: 'missing: ${backup.path}',
      );
    }
    final db = sqlite3.open(backup.path);
    try {
      final version = db.userVersion;
      final integrity = db.select('PRAGMA integrity_check;');
      final verdict =
          integrity.isEmpty ? 'empty' : '${integrity.first.values.first}';
      if (verdict != 'ok') {
        return DbProtectReport(
          outcome: DbProtectOutcome.verificationFailed,
          appSchemaVersion: appSchemaVersion ?? version,
          onDiskSchemaVersion: version,
          detail: 'integrity_check: $verdict',
        );
      }
      return DbProtectReport(
        outcome: DbProtectOutcome.alreadyProtected,
        appSchemaVersion: appSchemaVersion ?? version,
        onDiskSchemaVersion: version,
        backupFile: backup,
        rowCounts: _countTables(db),
      );
    } on Object catch (e) {
      return DbProtectReport(
        outcome: DbProtectOutcome.verificationFailed,
        appSchemaVersion: appSchemaVersion ?? -1,
        detail: '$e',
      );
    } finally {
      db.close();
    }
  }

  /// Kept backups, newest first.
  static List<File> listBackups(Directory backupDir,
      {String label = 'arena_ops'}) {
    if (!backupDir.existsSync()) return const [];
    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.sqlite') &&
            f.uri.pathSegments.last.startsWith('$label-v'))
        .toList();
    files.sort((a, b) => b.uri.pathSegments.last
        .compareTo(a.uri.pathSegments.last)); // timestamped names sort by time
    return files;
  }

  /// Put [backup] back in place as the live database, after verifying it.
  ///
  /// The database being replaced is itself copied aside first, so a restore is
  /// never a one-way door.
  static Future<DbProtectReport> restore({
    required File backup,
    required File dbFile,
    required Directory backupDir,
    String label = 'arena_ops',
  }) async {
    final check = verifyBackup(backup);
    if (!check.hasVerifiedBackup) return check;

    if (dbFile.existsSync()) {
      await backupDir.create(recursive: true);
      var kept =
          File('${backupDir.path}/$label-replaced-${_stamp()}Z.sqlite');
      for (var n = 1; kept.existsSync(); n++) {
        kept = File(
            '${backupDir.path}/$label-replaced-${_stamp()}Z-$n.sqlite');
      }
      await dbFile.copy(kept.path);
    }
    // A stale -wal/-shm belonging to the replaced database would be applied on
    // top of the restored file and corrupt it.
    for (final suffix in const ['-wal', '-shm']) {
      await _deleteQuietly(File('${dbFile.path}$suffix'));
    }
    await dbFile.parent.create(recursive: true);
    await backup.copy(dbFile.path);
    return verifyBackup(dbFile);
  }

  static String _stamp() => DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(RegExp(r'[-:]'), '')
      .split('.')
      .first;

  static Map<String, int> _countTables(Database db) {
    final present = db
        .select("SELECT name FROM sqlite_master WHERE type='table';")
        .map((r) => '${r['name']}')
        .toSet();
    final counts = <String, int>{};
    for (final table in verifiedTables) {
      if (!present.contains(table)) continue;
      final row = db.select('SELECT COUNT(*) AS c FROM $table;');
      counts[table] = row.first['c'] as int;
    }
    return counts;
  }

  static Future<File?> _identicalExisting(
      Directory dir, File candidate, String label) async {
    final bytes = await candidate.readAsBytes();
    for (final existing in listBackups(dir, label: label)) {
      if (await existing.length() != bytes.length) continue;
      if (_sameBytes(await existing.readAsBytes(), bytes)) return existing;
    }
    return null;
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<void> _prune(Directory dir,
      {required String label, required int keep}) async {
    final all = listBackups(dir, label: label);
    if (all.length <= keep) return;
    // Never prune the newest backup of a schema version: it is the last file
    // the build that wrote it can still read.
    final newestPerVersion = <String, String>{};
    for (final f in all) {
      final name = f.uri.pathSegments.last;
      final version = RegExp(r'-v(\d+)-').firstMatch(name)?.group(1) ?? '?';
      newestPerVersion.putIfAbsent(version, () => name);
    }
    final protectedNames = newestPerVersion.values.toSet();
    for (final f in all.skip(keep)) {
      if (protectedNames.contains(f.uri.pathSegments.last)) continue;
      await _deleteQuietly(f);
    }
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } on Object {
      // Best effort: a leftover staging file is harmless.
    }
  }
}
