/// [MyBillsRepository] straight against the server: the day's own bills come
/// from the my_bills RPC; an edit goes to sync_push at once as `bill.adjust`
/// (its id doubles as the op id and the difference row's id).
library;

import 'dart:async';

import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/data/remote/online_failures.dart';
import 'package:arena_ops/data/remote/bill_failures.dart';
import 'package:arena_ops/data/remote/online_calls.dart';
import 'package:arena_ops/data/sync/sync_transport.dart';
import 'package:arena_ops/domain/bills/my_bill.dart';
import 'package:arena_ops/domain/repositories/my_bills_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseMyBillsRepository implements MyBillsRepository {
  SupabaseMyBillsRepository({
    required this._client,
    required this._transport,
    required this.arenaId,
    required this.deviceId,
    this.onChanged,
    this.timeout = const Duration(seconds: 20),
  });

  final SupabaseClient _client;
  final SyncTransport _transport;
  final String arenaId;
  final Future<String> Function() deviceId;

  /// Called after the server recorded a change (to nudge other devices).
  final void Function()? onChanged;
  final Duration timeout;

  @override
  Future<Result<List<MyBill>>> forDay(IstDate day) async {
    final res = await onlineRead(_client, () async {
      final rows = await _client
          .rpc('my_bills', params: {'p_arena': arenaId, 'p_day': day.iso})
          .timeout(timeout);
      return [
        for (final r in rows as List)
          MyBill.fromJson(Map<String, dynamic>.from(r as Map)),
      ];
    }, loadFailed: BillFailures.loadFailed);
    return _reworded(res);
  }

  @override
  Future<Result<String>> adjust(BillAdjustCommand cmd) async {
    final res = await pushNow(
      _transport,
      arenaId: arenaId,
      deviceId: await deviceId(),
      opId: cmd.id,
      kind: 'bill.adjust',
      payload: cmd.toPayload(),
      rejected: BillFailures.rejected,
    );
    if (res.isOk) onChanged?.call();
    return _reworded(switch (res) {
      Ok(value: final r) => Ok(r['payment_status'] as String? ?? 'paid'),
      Err(failure: final f) => Err(f),
    });
  }

  @override
  Future<Result<int>> quote({
    required String resourceId,
    required String activityCode,
    int? controllerCount,
    required DateTime from,
    required DateTime to,
  }) async {
    // Like onlineRead, but a refusal keeps its code (no_rate, invalid_time…).
    if (_client.auth.currentSession == null) {
      return const Err(OnlineFailures.signedOut);
    }
    try {
      final r = await _client
          .rpc(
            'session_quote',
            params: {
              'p_arena': arenaId,
              'p_resource': resourceId,
              'p_activity': activityCode,
              'p_controllers': controllerCount,
              'p_from': from.toUtc().toIso8601String(),
              'p_to': to.toUtc().toIso8601String(),
            },
          )
          .timeout(timeout);
      return Ok(((r as Map)['total'] as num).toInt());
    } on TimeoutException {
      return const Err(BillFailures.offline);
    } on AuthRetryableFetchException {
      return const Err(BillFailures.offline);
    } on PostgrestException catch (e) {
      debugPrint('session_quote refused: ${e.code} ${e.message}');
      return Err(
        BillFailures.rejected(
          e.code == '42501' ? 'forbidden' : e.message,
          e.hint,
        ),
      );
    } on Exception catch (e) {
      debugPrint('session_quote failed: $e');
      return const Err(BillFailures.offline);
    }
  }

  @override
  Future<Result<int>> record(MissedBillCommand cmd) async {
    final res = await pushNow(
      _transport,
      arenaId: arenaId,
      deviceId: await deviceId(),
      opId: cmd.id,
      kind: 'session.record',
      payload: cmd.toPayload(),
      rejected: BillFailures.rejected,
    );
    if (res.isOk) onChanged?.call();
    return _reworded(switch (res) {
      Ok(value: final r) => Ok((r['billed_amount_paise'] as num).toInt()),
      Err(failure: final f) => Err(f),
    });
  }

  /// The shared offline failure is generic; bills say it in their own words.
  Result<T> _reworded<T>(Result<T> res) => switch (res) {
    Err(failure: final f) when f.code == BillFailures.offline.code => const Err(
      BillFailures.offline,
    ),
    _ => res,
  };
}
