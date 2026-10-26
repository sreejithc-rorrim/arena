/// Changing the total of a bill you started (`bill_edit`). The server re-checks
/// the permission and that the bill is yours, records the difference as one
/// payment or refund, and audits the change with the comment.
library;

import 'package:arena_ops/app/auth/auth_controller.dart';
import 'package:arena_ops/app/providers/my_bills_providers.dart';
import 'package:arena_ops/core/money/rupee_input.dart';
import 'package:arena_ops/core/monitoring/app_telemetry.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/auth/permission_guard.dart';
import 'package:arena_ops/domain/bills/my_bill.dart';
import 'package:arena_ops/domain/repositories/my_bills_repository.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class BillEditActions {
  BillEditActions({
    required this.bills,
    this.guard = const PermissionGuard(null),
  });

  final MyBillsRepository bills;
  final PermissionGuard guard;

  static const _uuid = Uuid();

  /// A new edit; keep it to send again after a dropped connection.
  BillAdjustCommand prepare({
    required MyBill bill,
    required int newTotalPaise,
    required String reason,
    PaymentMethod? method,
  }) {
    final diff = newTotalPaise - bill.paidPaise;
    return BillAdjustCommand(
      id: _uuid.v4(),
      bill: bill,
      newTotalPaise: newTotalPaise,
      reason: reason,
      method: diff == 0 ? null : method,
    );
  }

  /// Returns the bill's payment status after the change.
  Future<Result<String>> adjust(BillAdjustCommand cmd) async {
    final denied = guard.check(Permission.billEdit);
    if (denied != null) return Err(denied);
    if (!cmd.bill.canEdit) {
      return const Err(
        Failure(
          message: 'This bill cannot be edited.',
          fix: 'Voided and waived bills keep their total.',
          code: 'not_editable',
        ),
      );
    }
    if (cmd.newTotalPaise < 0) {
      return const Err(
        Failure(
          message: 'That amount does not work.',
          fix: 'Enter the new total in rupees, 0 or more.',
          code: 'invalid_total',
        ),
      );
    }
    if (cmd.reason.trim().isEmpty) {
      return const Err(
        Failure(
          message: 'Say why the bill changes.',
          fix: 'Add a short comment.',
          code: 'reason_required',
        ),
      );
    }
    if (cmd.newTotalPaise == cmd.bill.billedPaise && cmd.differencePaise == 0) {
      return const Err(
        Failure(
          message: 'The bill is already that amount and paid.',
          fix: 'Enter a different amount.',
          code: 'same_total',
        ),
      );
    }
    if (cmd.differencePaise != 0 && cmd.method == null) {
      return const Err(
        Failure(
          message: 'Pick how the difference was paid or given back.',
          fix: 'Choose Cash, UPI, Card or Other.',
          code: 'invalid_method',
        ),
      );
    }
    final res = await bills.adjust(cmd);
    if (res.isOk) {
      AppTelemetry.addBreadcrumb(
        category: 'billing',
        message: 'bill_adjusted',
        data: {'billId': cmd.bill.id, 'scope': cmd.bill.kind},
      );
    }
    return res;
  }

  /// A new missed bill; keep it to send again after a dropped connection.
  MissedBillCommand prepareMissed({
    required String customerId,
    required String resourceId,
    required String activityCode,
    String? gameId,
    int? controllerCount,
    required DateTime startedAt,
    required DateTime endedAt,
    required PaymentMethod method,
    required int billedPaise,
    required int paidPaise,
    required String reason,
  }) => MissedBillCommand(
    id: _uuid.v4(),
    paymentId: _uuid.v4(),
    customerId: customerId,
    resourceId: resourceId,
    activityCode: activityCode,
    gameId: gameId,
    controllerCount: controllerCount,
    startedAt: startedAt,
    endedAt: endedAt,
    method: method,
    billedPaise: billedPaise,
    paidPaise: paidPaise,
    reason: reason,
  );

  /// Adds the missed bill; returns its total (the amount paid).
  Future<Result<int>> record(MissedBillCommand cmd) async {
    final denied = guard.check(Permission.billRecord);
    if (denied != null) return Err(denied);
    if (cmd.reason.trim().isEmpty) {
      return const Err(
        Failure(
          message: 'Say why the bill is added later.',
          fix: 'Add a short reason.',
          code: 'reason_required',
        ),
      );
    }
    if (cmd.paidPaise < 0 || cmd.paidPaise > maxRupeeInputPaise) {
      return const Err(
        Failure(
          message: 'Enter what the customer paid.',
          fix: rupeeInputError,
          code: 'invalid_total',
        ),
      );
    }
    if (!cmd.endedAt.isAfter(cmd.startedAt) ||
        cmd.endedAt.difference(cmd.startedAt) > const Duration(hours: 24)) {
      return const Err(
        Failure(
          message: 'Those times do not work.',
          fix: 'The end must be after the start, at most 24 hours later.',
          code: 'invalid_time',
        ),
      );
    }
    final res = await bills.record(cmd);
    if (res.isOk) {
      AppTelemetry.addBreadcrumb(
        category: 'billing',
        message: 'missed_bill_recorded',
        data: {'sessionId': cmd.id},
      );
    }
    return res;
  }
}

final billEditActionsProvider = Provider<BillEditActions>(
  (ref) => BillEditActions(
    bills: ref.watch(myBillsRepositoryProvider),
    guard: PermissionGuard(ref.watch(authControllerProvider)),
  ),
);
