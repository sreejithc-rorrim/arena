/// Shared plumbing for the online-only staff features (profile, terms, my bills):
/// reads through RLS with the network failures worded once, and ops sent
/// straight to sync_push (no outbox) with the transport's failures mapped.
library;

import 'dart:async';

import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/data/remote/online_failures.dart';
import 'package:arena_ops/data/sync/sync_transport.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Runs [body] as the signed-in person; a missing session, no network or a
/// refused query become the matching [Failure] ([loadFailed] for a refusal).
Future<Result<T>> onlineRead<T>(
  SupabaseClient client,
  Future<T> Function() body, {
  Failure loadFailed = OnlineFailures.loadFailed,
}) async {
  // Never call as anon: without a session the request would carry only the
  // publishable key and be refused.
  if (client.auth.currentSession == null) {
    return const Err(OnlineFailures.signedOut);
  }
  try {
    return Ok(await body());
  } on TimeoutException {
    return const Err(OnlineFailures.offline);
  } on AuthRetryableFetchException {
    return const Err(OnlineFailures.offline);
  } on PostgrestException catch (e) {
    debugPrint('online read refused: ${e.code} ${e.message}');
    return Err(loadFailed);
  } on Exception catch (e) {
    // SocketException, http ClientException and friends: no response.
    debugPrint('online read failed: $e');
    return const Err(OnlineFailures.offline);
  }
}

/// Sends one op now and returns its result, or the failure [rejected] words
/// for its refusal code. The op id makes a resend replay, never repeat.
Future<Result<Map<String, dynamic>>> pushNow(
  SyncTransport transport, {
  required String arenaId,
  required String deviceId,
  required String opId,
  required String kind,
  required Map<String, dynamic> payload,
  required Failure Function(String? code, String? detail) rejected,
}) async {
  final List<OpResult> results;
  try {
    results = await transport.push(
        arenaId, [(opId: opId, kind: kind, payload: payload)], deviceId);
  } on SyncOfflineException {
    return const Err(OnlineFailures.offline);
  } on SyncAuthException catch (e) {
    return Err(e.revoked ? OnlineFailures.accessOff : OnlineFailures.signedOut);
  } on PostgrestException catch (e) {
    debugPrint('$kind failed: ${e.code} ${e.message}');
    return Err(rejected(e.code, null));
  }
  final r = results.single;
  return switch (r.status) {
    'applied' => Ok(r.result ?? const {}),
    'retry' => const Err(OnlineFailures.busy),
    _ => Err(rejected(r.error, r.detail)),
  };
}
