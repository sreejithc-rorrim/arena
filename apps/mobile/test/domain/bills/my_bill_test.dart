/// My bills as the server sends them (my_bills, the `_sales` summary): a
/// missed bill carries today's price (`quoted_paise`) next to what was paid.
library;

import 'package:arena_ops/domain/bills/my_bill.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _bill({
  required int billed,
  List<Map<String, dynamic>> payments = const [],
  int? quoted,
  bool sendQuoted = true,
}) => {
  'kind': 'single',
  'id': 'a2800000-0000-0000-0000-000000000002',
  'at': '2026-10-01T06:30:00Z',
  'started_at': '2026-10-01T05:30:00Z',
  'ended_at': '2026-10-01T06:30:00Z',
  'status': 'completed',
  'payment_status': 'paid',
  'customer': 'Kiran',
  'guest': false,
  'stations': ['VOID'],
  'games': <String>[],
  'billed_paise': billed,
  'paid_paise': payments.fold<int>(0, (s, p) => s + (p['amount_paise'] as int)),
  'methods': {'cash': billed},
  'payments': payments,
  if (sendQuoted) 'quoted_paise': quoted,
};

Map<String, dynamic> _pay(int amount, String? note) => {
  'id': 'p-$amount',
  'at': '2026-10-01T06:30:00Z',
  'amount_paise': amount,
  'method': 'cash',
  'note': note,
  'reason': note == null ? null : 'Old rate',
  'by': 'Owner',
};

void main() {
  test('a missed bill paid less: today\'s price, the amount paid and the '
      'difference', () {
    final b = MyBill.fromJson(
      _bill(billed: 10000, payments: [_pay(10000, 'Added later')], quoted: 15000),
    );
    expect(b.addedLater, isTrue);
    expect(b.billedPaise, 10000);
    expect(b.quotedPaise, 15000);
    expect(b.addedLaterPaise, 10000);
    expect(b.paidDifferencePaise, -5000);
  });

  test('a ₹0 missed bill has no payment but is still added later, the whole '
      'price off', () {
    final b = MyBill.fromJson(_bill(billed: 0, quoted: 15000));
    expect(b.addedLater, isTrue, reason: 'marked by its price');
    expect(b.addedLaterPaise, 0);
    expect(b.paidDifferencePaise, -15000);
  });

  test('a later edit does not change what was paid when it was added', () {
    final b = MyBill.fromJson(
      _bill(
        billed: 12000,
        payments: [_pay(10000, 'Added later'), _pay(2000, 'Bill edited')],
        quoted: 15000,
      ),
    );
    expect(b.addedLaterPaise, 10000);
    expect(b.paidDifferencePaise, -5000);
    expect(b.edits.single.amountPaise, 2000);
  });

  test('a bill played on the floor has no price and no difference', () {
    final b = MyBill.fromJson(_bill(billed: 15000, payments: [_pay(15000, null)]));
    expect(b.addedLater, isFalse);
    expect(b.quotedPaise, isNull);
    expect(b.paidDifferencePaise, 0);
  });

  test('a missed bill from before the price was kept (or an older server) '
      'shows no difference', () {
    final b = MyBill.fromJson(
      _bill(
        billed: 15000,
        payments: [_pay(15000, 'Added later')],
        sendQuoted: false,
      ),
    );
    expect(b.addedLater, isTrue);
    expect(b.quotedPaise, isNull);
    expect(b.paidDifferencePaise, 0);
  });
}
