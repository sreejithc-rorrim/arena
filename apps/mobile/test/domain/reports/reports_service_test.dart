/// Brief §16 #19 — reports and exports match the persisted records.
///
/// The service is fed exactly the rows a database would hold and every figure
/// is asserted against those rows by hand, so a report can never drift into
/// plausible-but-invented numbers.
library;

import 'package:arena_ops/core/time/business_calendar.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/domain/entities/customer.dart';
import 'package:arena_ops/domain/entities/payment.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/reports/report_models.dart';
import 'package:arena_ops/domain/reports/reports_service.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pricing_fixtures.dart';

void main() {
  const service = ReportsService();

  // Tuesday 2026-10-06, a trading day.
  final day = tuesdayDate;

  Session session({
    required String id,
    required String customerId,
    required DateTime start,
    required DateTime end,
    required int billed,
    PaymentStatus status = PaymentStatus.paid,
  }) =>
      Session(
        id: id,
        customerId: customerId,
        status: SessionStatus.completed,
        paymentStatus: status,
        startedAt: start,
        scheduledEndAt: end,
        actualEndedAt: end,
        pricingSnapshot: currentSnapshot().toJson(),
        billedAmountPaise: billed,
        createdAt: start,
        updatedAt: end,
      );

  SessionSegment segment({
    required String id,
    required String sessionId,
    required String resourceId,
    required DateTime start,
    required DateTime end,
    String? gameId,
    int? controllers = 1,
  }) =>
      SessionSegment(
        id: id,
        sessionId: sessionId,
        index: 0,
        resourceId: resourceId,
        activityCode: 'PS5',
        gameId: gameId,
        controllerCount: controllers,
        startedAt: start,
        endedAt: end,
        createdAt: start,
      );

  SessionCharge charge({
    required String sessionId,
    required DateTime start,
    required DateTime end,
    required int amount,
    String band = 'standard',
    String activity = 'PS5',
  }) =>
      SessionCharge(
        id: 'c-$sessionId-${start.millisecondsSinceEpoch}',
        sessionId: sessionId,
        segmentIndex: 0,
        bandCode: band,
        activityCode: activity,
        resourceId: 'hex',
        controllerCount: 1,
        segmentStart: start,
        segmentEnd: end,
        playedMinutes: end.difference(start).inMinutes,
        billedMinutes: end.difference(start).inMinutes,
        unitMinutes: 60,
        unitPricePaise: 15000,
        amountPaise: amount,
      );

  Payment payment({
    required String sessionId,
    required int amount,
    required DateTime at,
    PaymentMethod method = PaymentMethod.cash,
    bool isRefund = false,
  }) =>
      Payment(
        id: 'p-$sessionId-${at.millisecondsSinceEpoch}-${method.code}',
        sessionId: sessionId,
        amountPaise: amount,
        method: method,
        isRefund: isRefund,
        createdAt: at,
      );

  ReportInput input({
    required ReportRange range,
    List<Session> sessions = const [],
    List<SessionSegment> segments = const [],
    List<SessionCharge> charges = const [],
    List<Payment> payments = const [],
    List<Customer> customers = const [],
  }) =>
      ReportInput(
        range: range,
        sessions: sessions,
        segments: segments,
        charges: charges,
        payments: payments,
        customers: customers,
        resources: const [
          Resource(id: 'hex', name: 'HEX', kind: ResourceKind.station),
          Resource(id: 'void', name: 'VOID', kind: ResourceKind.station),
        ],
        gameNames: const {'g1': 'EA FC 25', 'g2': 'GTA V'},
        activityNames: const {'PS5': 'PlayStation 5', 'POOL': 'Pool'},
        calendar: BusinessCalendar(),
      );

  final customer = Customer(
    id: 'c1',
    name: 'Kabir',
    createdAt: ist(2026, 10, 6, 14, 0),
    updatedAt: ist(2026, 10, 6, 14, 0),
  );

  group('money totals come from the stored rows', () {
    test('billed, collected, pending and waived are each their own sum', () {
      final range = ReportRange.today(day);
      final s1 = session(
        id: 's1',
        customerId: 'c1',
        start: ist(2026, 10, 6, 18, 0),
        end: ist(2026, 10, 6, 19, 0),
        billed: 15000,
        status: PaymentStatus.partial,
      );
      final s2 = session(
        id: 's2',
        customerId: 'c1',
        start: ist(2026, 10, 6, 19, 0),
        end: ist(2026, 10, 6, 20, 0),
        billed: 28000,
        status: PaymentStatus.waived,
      );

      final report = service.build(input(
        range: range,
        sessions: [s1, s2],
        payments: [
          // ₹100 of the ₹150 bill was collected.
          payment(sessionId: 's1', amount: 10000, at: ist(2026, 10, 6, 19, 1)),
        ],
        customers: [customer],
      ));

      expect(report.billedPaise, 43000, reason: '₹150 + ₹280');
      expect(report.collectedPaise, 10000);
      expect(report.waivedPaise, 28000);
      // Pending excludes what was deliberately waived.
      expect(report.pendingPaise, 43000 - 10000 - 28000);
      expect(report.sessionCount, 2);
      expect(report.uniqueCustomers, 1);
    });

    test('a refund row reduces what was collected', () {
      final report = service.build(input(
        range: ReportRange.today(day),
        sessions: [
          session(
            id: 's1',
            customerId: 'c1',
            start: ist(2026, 10, 6, 18, 0),
            end: ist(2026, 10, 6, 19, 0),
            billed: 15000,
          ),
        ],
        payments: [
          payment(sessionId: 's1', amount: 15000, at: ist(2026, 10, 6, 19, 0)),
          payment(
            sessionId: 's1',
            amount: -5000,
            at: ist(2026, 10, 6, 19, 30),
            isRefund: true,
          ),
        ],
        customers: [customer],
      ));

      expect(report.collectedPaise, 10000);
      expect(report.refundedPaise, 5000);
    });

    test('payments split across methods sum per method and in total', () {
      final report = service.build(input(
        range: ReportRange.today(day),
        sessions: [
          session(
            id: 's1',
            customerId: 'c1',
            start: ist(2026, 10, 6, 18, 0),
            end: ist(2026, 10, 6, 19, 0),
            billed: 28000,
          ),
        ],
        payments: [
          payment(
            sessionId: 's1',
            amount: 20000,
            at: ist(2026, 10, 6, 19, 0),
            method: PaymentMethod.upi,
          ),
          payment(
            sessionId: 's1',
            amount: 8000,
            at: ist(2026, 10, 6, 19, 1),
          ),
        ],
        customers: [customer],
      ));

      final upi = report.byMethod.firstWhere((m) => m.label == 'UPI');
      final cash = report.byMethod.firstWhere((m) => m.label == 'Cash');
      expect(upi.paise, 20000);
      expect(cash.paise, 8000);
      expect(report.collectedPaise, 28000);
      // Every method is listed so the breakdown keeps a stable shape.
      expect(report.byMethod.length, PaymentMethod.values.length);
    });

    test('a session that ended outside the window is excluded', () {
      final report = service.build(input(
        range: ReportRange.today(day),
        sessions: [
          session(
            id: 'yesterday',
            customerId: 'c1',
            start: ist(2026, 10, 5, 18, 0),
            end: ist(2026, 10, 5, 19, 0),
            billed: 99900,
          ),
        ],
        customers: [customer],
      ));

      expect(report.billedPaise, 0);
      expect(report.sessionCount, 0);
      expect(report.isEmpty, isTrue);
    });
  });

  group('time, utilisation and games come from the segments', () {
    test('gaming minutes add up the segments actually played', () {
      final report = service.build(input(
        range: ReportRange.today(day),
        segments: [
          segment(
            id: 'seg1',
            sessionId: 's1',
            resourceId: 'hex',
            start: ist(2026, 10, 6, 18, 0),
            end: ist(2026, 10, 6, 19, 0),
            gameId: 'g1',
          ),
          segment(
            id: 'seg2',
            sessionId: 's1',
            resourceId: 'void',
            start: ist(2026, 10, 6, 19, 0),
            end: ist(2026, 10, 6, 19, 30),
            gameId: 'g1',
          ),
        ],
      ));

      expect(report.gamingMinutes, 90);
      expect(report.gamingHours, 1.5);

      final hex = report.resourceUsage.firstWhere((r) => r.resourceId == 'hex');
      final vd = report.resourceUsage.firstWhere((r) => r.resourceId == 'void');
      expect(hex.playedMinutes, 60);
      expect(vd.playedMinutes, 30);

      // Tue–Sun 2–11 PM = 9 open hours = 540 minutes.
      expect(hex.openMinutes, 540);
      expect(hex.utilisation, closeTo(60 / 540, 0.0001));

      // The same session used both stations — it counts once on each.
      expect(hex.sessions, 1);
      expect(vd.sessions, 1);

      // One game across both stations: 90 minutes, one session.
      expect(report.topGames.single.gameName, 'EA FC 25');
      expect(report.topGames.single.playedMinutes, 90);
      expect(report.topGames.single.sessions, 1);
    });

    test('a segment spanning midnight is split across both days', () {
      final late = segment(
        id: 'seg1',
        sessionId: 's1',
        resourceId: 'hex',
        start: ist(2026, 10, 6, 23, 30),
        end: ist(2026, 10, 7, 0, 30),
      );

      final tuesday = service.build(
        input(range: ReportRange.today(day), segments: [late]),
      );
      final wednesday = service.build(
        input(range: ReportRange.today(day.addDays(1)), segments: [late]),
      );

      expect(tuesday.gamingMinutes, 30, reason: '23:30 → midnight');
      expect(wednesday.gamingMinutes, 30, reason: 'midnight → 00:30');
    });

    test('a still-open segment is counted only up to the end of the window', () {
      final report = service.build(input(
        range: ReportRange.today(day),
        segments: [
          SessionSegment(
            id: 'seg-open',
            sessionId: 's1',
            index: 0,
            resourceId: 'hex',
            activityCode: 'PS5',
            controllerCount: 1,
            startedAt: ist(2026, 10, 6, 22, 0),
            endedAt: null,
            createdAt: ist(2026, 10, 6, 22, 0),
          ),
        ],
      ));

      // 22:00 → IST midnight, never into tomorrow.
      expect(report.gamingMinutes, 120);
    });

    test('a disabled station is left out of average utilisation', () {
      final report = service.build(ReportInput(
        range: ReportRange.today(day),
        sessions: const [],
        segments: [
          segment(
            id: 'seg1',
            sessionId: 's1',
            resourceId: 'hex',
            start: ist(2026, 10, 6, 14, 0),
            end: ist(2026, 10, 6, 23, 0),
          ),
        ],
        charges: const [],
        payments: const [],
        customers: const [],
        resources: const [
          Resource(id: 'hex', name: 'HEX', kind: ResourceKind.station),
          Resource(
            id: 'void',
            name: 'VOID',
            kind: ResourceKind.station,
            status: ResourceStatus.disabled,
          ),
        ],
        gameNames: const {},
        activityNames: const {},
        calendar: BusinessCalendar(),
      ));

      // HEX was busy all 540 open minutes; VOID is disabled so it is not a
      // zero dragging the average down.
      expect(report.averageUtilisation, closeTo(1.0, 0.0001));
    });
  });

  group('revenue splits come from the immutable charge rows', () {
    test('by activity and by price band', () {
      final report = service.build(input(
        range: ReportRange.today(day),
        charges: [
          charge(
            sessionId: 's1',
            start: ist(2026, 10, 6, 16, 30),
            end: ist(2026, 10, 6, 17, 0),
            amount: 6000,
            // A charge written by an older build under a retired band code.
            band: 'off_peak',
          ),
          charge(
            sessionId: 's1',
            start: ist(2026, 10, 6, 17, 0),
            end: ist(2026, 10, 6, 17, 30),
            amount: 7500,
          ),
          charge(
            sessionId: 's2',
            start: ist(2026, 10, 6, 18, 0),
            end: ist(2026, 10, 6, 19, 0),
            amount: 27500,
            activity: 'POOL',
          ),
        ],
      ));

      final ps5 = report.byActivity.firstWhere((m) => m.label == 'PlayStation 5');
      final pool = report.byActivity.firstWhere((m) => m.label == 'Pool');
      expect(ps5.paise, 13500);
      expect(pool.paise, 27500);

      // Standard first, then retired codes labelled from the stored code.
      expect(report.byBand.map((m) => m.label), ['Standard', 'Off peak']);
      final retired = report.byBand.firstWhere((m) => m.label == 'Off peak');
      final standard = report.byBand.firstWhere((m) => m.label == 'Standard');
      expect(retired.paise, 6000);
      expect(standard.paise, 7500 + 27500);
    });
  });

  group('per-day and history', () {
    test('a week report attributes each session to its own day', () {
      final range = ReportRange.week(day); // 2026-09-30 → 2026-10-06
      final report = service.build(input(
        range: range,
        sessions: [
          session(
            id: 's1',
            customerId: 'c1',
            start: ist(2026, 10, 5, 18, 0),
            end: ist(2026, 10, 5, 19, 0),
            billed: 15000,
          ),
          session(
            id: 's2',
            customerId: 'c1',
            start: ist(2026, 10, 6, 18, 0),
            end: ist(2026, 10, 6, 19, 0),
            billed: 28000,
          ),
        ],
        payments: [
          payment(sessionId: 's1', amount: 15000, at: ist(2026, 10, 5, 19, 0)),
          payment(sessionId: 's2', amount: 28000, at: ist(2026, 10, 6, 19, 0)),
        ],
        customers: [customer],
      ));

      expect(report.byDay.length, 7);
      final mon = report.byDay.firstWhere((d) => d.day == const IstDate(2026, 10, 5));
      final tue = report.byDay.firstWhere((d) => d.day == const IstDate(2026, 10, 6));
      expect(mon.billedPaise, 15000);
      expect(tue.billedPaise, 28000);
      expect(mon.collectedPaise, 15000);
      // Day totals must reconcile with the headline figure.
      expect(
        report.byDay.fold<int>(0, (a, d) => a + d.billedPaise),
        report.billedPaise,
      );
    });

    test('history lists every station and game a session used', () {
      final report = service.build(input(
        range: ReportRange.today(day),
        sessions: [
          session(
            id: 's1',
            customerId: 'c1',
            start: ist(2026, 10, 6, 18, 0),
            end: ist(2026, 10, 6, 19, 30),
            billed: 22500,
            status: PaymentStatus.partial,
          ),
        ],
        segments: [
          segment(
            id: 'seg1',
            sessionId: 's1',
            resourceId: 'hex',
            start: ist(2026, 10, 6, 18, 0),
            end: ist(2026, 10, 6, 19, 0),
            gameId: 'g1',
          ),
          segment(
            id: 'seg2',
            sessionId: 's1',
            resourceId: 'void',
            start: ist(2026, 10, 6, 19, 0),
            end: ist(2026, 10, 6, 19, 30),
            gameId: 'g2',
          ),
        ],
        payments: [
          payment(sessionId: 's1', amount: 10000, at: ist(2026, 10, 6, 19, 30)),
        ],
        customers: [customer],
      ));

      final row = report.history.single;
      expect(row.customerName, 'Kabir');
      expect(row.resources, ['HEX', 'VOID']);
      expect(row.games, ['EA FC 25', 'GTA V']);
      expect(row.playedMinutes, 90);
      expect(row.billedPaise, 22500);
      expect(row.collectedPaise, 10000);
      expect(row.pendingPaise, 12500);
      expect(row.paymentStatus, PaymentStatus.partial);
    });
  });
}
