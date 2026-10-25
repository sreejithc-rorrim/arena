/// Value types for the owner reports (brief §13). Every figure here is derived
/// from persisted rows — sessions, segments, immutable charge rows and payment
/// rows — never from a dashboard constant or a live UI timer.
library;

import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:meta/meta.dart';

/// The window a report covers, as an inclusive range of IST business days.
@immutable
class ReportRange {
  const ReportRange({required this.from, required this.to, required this.label});

  /// First business day in the window.
  final IstDate from;

  /// Last business day in the window (inclusive).
  final IstDate to;

  /// What to show in the UI and write into the export ("Today", "This week").
  final String label;

  DateTime get startUtc => from.startOfDayUtc();

  /// Exclusive end — IST midnight after [to].
  DateTime get endUtc => to.endOfDayUtc();

  /// Every business day in the window, ascending.
  List<IstDate> get days {
    final out = <IstDate>[];
    var d = from;
    while (d.compareTo(to) <= 0) {
      out.add(d);
      d = d.addDays(1);
    }
    return out;
  }

  int get dayCount => days.length;

  static ReportRange today(IstDate today) =>
      ReportRange(from: today, to: today, label: 'Today');

  /// The 7 days ending today (inclusive).
  static ReportRange week(IstDate today) => ReportRange(
        from: today.addDays(-6),
        to: today,
        label: 'This week',
      );

  /// The 30 days ending today (inclusive).
  static ReportRange month(IstDate today) => ReportRange(
        from: today.addDays(-29),
        to: today,
        label: 'This month',
      );

  static ReportRange custom(IstDate from, IstDate to) => ReportRange(
        from: from,
        to: to,
        label: from == to ? from.iso : '${from.iso} → ${to.iso}',
      );

  @override
  bool operator ==(Object other) =>
      other is ReportRange &&
      other.from == from &&
      other.to == to &&
      other.label == label;

  @override
  int get hashCode => Object.hash(from, to, label);
}

/// One labelled money figure with the count behind it.
@immutable
class MoneyRow {
  const MoneyRow({required this.label, required this.paise, this.count = 0});
  final String label;
  final int paise;
  final int count;

  Paise get amount => Paise(paise);
}

/// Per-resource usage over the window.
@immutable
class ResourceUsage {
  const ResourceUsage({
    required this.resourceId,
    required this.resourceName,
    required this.playedMinutes,
    required this.openMinutes,
    required this.sessions,
  });

  final String resourceId;
  final String resourceName;
  final int playedMinutes;

  /// Minutes the centre was open in the window — the denominator for
  /// utilisation. Zero when the centre never opened (then [utilisation] is 0).
  final int openMinutes;
  final int sessions;

  /// Played ÷ open hours, 0..1. Can exceed 1 only if a session ran outside
  /// operating hours, which the availability rules normally prevent.
  double get utilisation =>
      openMinutes == 0 ? 0 : playedMinutes / openMinutes;

  double get playedHours => playedMinutes / 60.0;
}

/// One game's play time over the window.
@immutable
class GamePlay {
  const GamePlay({
    required this.gameId,
    required this.gameName,
    required this.playedMinutes,
    required this.sessions,
  });

  final String gameId;
  final String gameName;
  final int playedMinutes;
  final int sessions;

  double get playedHours => playedMinutes / 60.0;
}

/// One business day's takings.
@immutable
class DayTotals {
  const DayTotals({
    required this.day,
    required this.billedPaise,
    required this.collectedPaise,
    required this.sessions,
    required this.gamingMinutes,
  });

  final IstDate day;
  final int billedPaise;
  final int collectedPaise;
  final int sessions;
  final int gamingMinutes;
}

/// A single finished session as it appears in the history/export.
@immutable
class SessionHistoryRow {
  const SessionHistoryRow({
    required this.sessionId,
    required this.customerName,
    required this.startedAt,
    required this.endedAt,
    required this.resources,
    required this.games,
    required this.playedMinutes,
    required this.billedPaise,
    required this.collectedPaise,
    required this.paymentStatus,
  });

  final String sessionId;
  final String customerName;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Every station used, in order — a session that moved shows both.
  final List<String> resources;
  final List<String> games;
  final int playedMinutes;
  final int billedPaise;
  final int collectedPaise;
  final PaymentStatus paymentStatus;

  int get pendingPaise =>
      paymentStatus == PaymentStatus.waived ? 0 : billedPaise - collectedPaise;
}

/// The complete report for one window. Every list is already sorted for
/// display, so the UI and the spreadsheet export read the same numbers.
@immutable
class ArenaReport {
  const ArenaReport({
    required this.range,
    required this.billedPaise,
    required this.collectedPaise,
    required this.waivedPaise,
    required this.refundedPaise,
    required this.sessionCount,
    required this.gamingMinutes,
    required this.uniqueCustomers,
    required this.newCustomers,
    required this.byActivity,
    required this.byMethod,
    required this.byBand,
    required this.byDay,
    required this.resourceUsage,
    required this.topGames,
    required this.history,
  });

  final ReportRange range;

  /// Billed = the sum of stored final bills for sessions that ended in the
  /// window. Running sessions are not billed yet and are excluded.
  final int billedPaise;

  /// Collected = the sum of payment rows timestamped in the window, net of
  /// refunds (a refund is a negative row).
  final int collectedPaise;
  final int waivedPaise;
  final int refundedPaise;

  final int sessionCount;
  final int gamingMinutes;
  final int uniqueCustomers;
  final int newCustomers;

  final List<MoneyRow> byActivity;
  final List<MoneyRow> byMethod;
  final List<MoneyRow> byBand;
  final List<DayTotals> byDay;
  final List<ResourceUsage> resourceUsage;
  final List<GamePlay> topGames;
  final List<SessionHistoryRow> history;

  /// Pending = billed that is neither collected nor waived.
  int get pendingPaise => billedPaise - collectedPaise - waivedPaise;

  double get gamingHours => gamingMinutes / 60.0;

  Paise get billed => Paise(billedPaise);
  Paise get collected => Paise(collectedPaise);
  Paise get pending => Paise(pendingPaise);
  Paise get waived => Paise(waivedPaise);

  /// Average utilisation across every resource that was open at all.
  double get averageUtilisation {
    final counted = resourceUsage.where((r) => r.openMinutes > 0).toList();
    if (counted.isEmpty) return 0;
    return counted.fold<double>(0, (a, r) => a + r.utilisation) / counted.length;
  }

  bool get isEmpty => sessionCount == 0 && collectedPaise == 0;
}
