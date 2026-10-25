/// My bills: the closed bills the signed-in staff member started, as the
/// server's my_bills RPC returns them (the admin Sales summary, `_sales`), and
/// the command that changes one's total (sync op `bill.adjust`).
library;

import 'package:arena_ops/domain/value/enums.dart';

class MyBill {
  const MyBill({
    required this.kind,
    required this.id,
    required this.closedAt,
    required this.startedAt,
    required this.endedAt,
    required this.status,
    required this.paymentStatus,
    required this.customer,
    required this.guest,
    required this.stations,
    required this.games,
    required this.billedPaise,
    required this.paidPaise,
    required this.methods,
    required this.edits,
    this.addedLater = false,
  });

  factory MyBill.fromJson(Map<String, dynamic> j) {
    DateTime? at(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String).toUtc();
    List<String> names(String k) => [
      for (final n in (j[k] as List? ?? const [])) '$n',
    ];
    final ledger = [
      for (final p in (j['payments'] as List? ?? const []))
        Map<String, dynamic>.from(p as Map),
    ];
    return MyBill(
      kind: j['kind'] as String,
      id: j['id'] as String,
      closedAt: at('at')!,
      startedAt: at('started_at')!,
      endedAt: at('ended_at'),
      status: j['status'] as String,
      paymentStatus: j['payment_status'] as String,
      customer: j['customer'] as String?,
      guest: j['guest'] == true,
      stations: names('stations'),
      games: names('games'),
      billedPaise: (j['billed_paise'] as num?)?.toInt(),
      paidPaise: (j['paid_paise'] as num?)?.toInt() ?? 0,
      methods: [
        for (final e in (j['methods'] as Map? ?? const {}).entries)
          if ((e.value as num) > 0) e.key as String,
      ],
      edits: [
        for (final p in ledger)
          if (p['note'] == 'Bill edited')
            BillEdit(
              at: DateTime.parse(p['at'] as String).toUtc(),
              amountPaise: (p['amount_paise'] as num).toInt(),
              reason: p['reason'] as String?,
              by: p['by'] as String?,
            ),
      ],
      addedLater: ledger.any((p) => p['note'] == 'Added later'),
    );
  }

  /// Always `single` (a sessions row).
  final String kind;
  final String id;

  /// When it closed (ended, or voided).
  final DateTime closedAt;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// `completed` or `voided`.
  final String status;

  /// `unpaid`, `partial`, `paid` or `waived`.
  final String paymentStatus;
  final String? customer;
  final bool guest;
  final List<String> stations;
  final List<String> games;
  final int? billedPaise;

  /// Net of the payments ledger (refunds negative).
  final int paidPaise;

  /// Payment methods with money in on this bill (method codes).
  final List<String> methods;

  /// Earlier total changes that moved money ('Bill edited' ledger rows).
  final List<BillEdit> edits;

  /// Added afterwards as a missed bill (session.record).
  final bool addedLater;

  bool get isVoided => status == 'voided';
  bool get isWaived => paymentStatus == 'waived';

  /// What op_bill_adjust accepts: an ended, non-voided, non-waived bill.
  bool get canEdit => status == 'completed' && !isWaived && billedPaise != null;
}

class BillEdit {
  const BillEdit({
    required this.at,
    required this.amountPaise,
    this.reason,
    this.by,
  });

  final DateTime at;

  /// Positive: extra collected. Negative: given back.
  final int amountPaise;
  final String? reason;
  final String? by;
}

/// Sets a closed bill's total. The server records the difference to what was
/// collected as one payment or refund by [method]; [id] is the op id and that
/// row's id, so a resend replays.
class BillAdjustCommand {
  const BillAdjustCommand({
    required this.id,
    required this.bill,
    required this.newTotalPaise,
    required this.reason,
    this.method,
  });

  final String id;
  final MyBill bill;
  final int newTotalPaise;
  final String reason;

  /// How the difference was paid or given back; needed when it is not zero.
  final PaymentMethod? method;

  int get differencePaise => newTotalPaise - bill.paidPaise;

  Map<String, dynamic> toPayload() => {
    'scope': 'single',
    'parent_id': bill.id,
    'billed_amount_paise': newTotalPaise,
    'reason': reason.trim(),
    'payment_id': id,
    if (method != null) 'method': method!.code,
    // What staff saw: the server refuses the edit as stale if either moved.
    'expected_billed_paise': bill.billedPaise,
    'expected_paid_paise': bill.paidPaise,
  };
}

/// Adds a single session that was played but never started in the app (sync
/// op `session.record`): the server prices it on the current price list,
/// refuses any difference from [billedPaise] (the price the caller was shown),
/// and records it paid in full by [method]. [id] is the session id and the op
/// id, [paymentId] the payment row's, so a resend replays.
class MissedBillCommand {
  const MissedBillCommand({
    required this.id,
    required this.paymentId,
    required this.customerId,
    required this.resourceId,
    required this.activityCode,
    this.gameId,
    this.controllerCount,
    required this.startedAt,
    required this.endedAt,
    required this.method,
    required this.billedPaise,
    required this.reason,
  });

  final String id;
  final String paymentId;
  final String customerId;
  final String resourceId;
  final String activityCode;
  final String? gameId;
  final int? controllerCount;
  final DateTime startedAt;
  final DateTime endedAt;
  final PaymentMethod method;
  final int billedPaise;
  final String reason;

  Map<String, dynamic> toPayload() => {
        'session_id': id,
        'payment_id': paymentId,
        'customer_id': customerId,
        'resource_id': resourceId,
        'activity_code': activityCode,
        if (gameId != null) 'game_id': gameId,
        if (controllerCount != null) 'controller_count': controllerCount,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'method': method.code,
        'billed_amount_paise': billedPaise,
        'reason': reason.trim(),
      };
}
