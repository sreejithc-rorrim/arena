/// Missed bills through the application actions: the amount the customer
/// actually paid travels to the server, and impossible amounts or a blank
/// comment never leave the device.
library;

import 'package:arena_ops/app/controllers/bill_edit_actions.dart';
import 'package:arena_ops/core/money/rupee_input.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/auth/permission_guard.dart';
import 'package:arena_ops/domain/bills/my_bill.dart';
import 'package:arena_ops/domain/repositories/my_bills_repository.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps what reaches the server; answers with the amount paid.
class _Bills implements MyBillsRepository {
  final recorded = <MissedBillCommand>[];

  @override
  Future<Result<List<MyBill>>> forDay(IstDate day) async => const Ok([]);

  @override
  Future<Result<String>> adjust(BillAdjustCommand cmd) async => const Ok('paid');

  @override
  Future<Result<int>> quote({
    required String resourceId,
    required String activityCode,
    int? controllerCount,
    required DateTime from,
    required DateTime to,
  }) async => const Ok(15000);

  @override
  Future<Result<int>> record(MissedBillCommand cmd) async {
    recorded.add(cmd);
    return Ok(cmd.paidPaise);
  }
}

void main() {
  late _Bills bills;
  late BillEditActions actions;

  setUp(() {
    bills = _Bills();
    actions = BillEditActions(
      bills: bills,
      guard: const PermissionGuard(
        AppUser(id: 'u2', name: 'Staff', perms: {Permission.billRecord}),
      ),
    );
  });

  MissedBillCommand missed({int paid = 10000, String reason = '  Old rate  '}) =>
      actions.prepareMissed(
        customerId: 'c1',
        resourceId: 'hex',
        activityCode: 'PS5',
        controllerCount: 1,
        startedAt: DateTime.utc(2026, 10, 2, 13, 30),
        endedAt: DateTime.utc(2026, 10, 2, 14, 30),
        method: PaymentMethod.cash,
        billedPaise: 15000,
        paidPaise: paid,
        reason: reason,
      );

  test('the payload carries the price shown, the amount paid and the trimmed '
      'comment', () {
    final p = missed().toPayload();
    expect(p['billed_amount_paise'], 15000);
    expect(p['paid_amount_paise'], 10000);
    expect(p['reason'], 'Old rate');
  });

  test('a bill at the amount paid is sent; its total is the amount paid', () async {
    final r = await actions.record(missed(paid: 17000));
    expect(r.valueOrNull, 17000);
    expect(bills.recorded.single.paidPaise, 17000);
  });

  test('nothing paid is a valid amount', () async {
    final r = await actions.record(missed(paid: 0));
    expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
  });

  test('a negative or impossibly large amount never leaves the device', () async {
    for (final paid in [-1, maxRupeeInputPaise + 1]) {
      final r = await actions.record(missed(paid: paid));
      expect(r.failureOrNull?.code, 'invalid_total', reason: '$paid');
    }
    expect(bills.recorded, isEmpty);
  });

  test('a missing or blank comment never leaves the device', () async {
    for (final reason in ['', '   ']) {
      final r = await actions.record(missed(reason: reason));
      expect(r.failureOrNull?.code, 'reason_required', reason: '"$reason"');
    }
    expect(bills.recorded, isEmpty);
  });
}
