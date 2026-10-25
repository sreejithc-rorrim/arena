import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/time/duration_format.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/core/widgets/arena_badge.dart';
import 'package:arena_ops/domain/reports/report_models.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:flutter/material.dart';

/// Every session in the reported window, newest first (brief §13 "Session and
/// customer history"). Rows are the persisted sessions — stations and games
/// come from the segments actually played, so a session that moved shows both.
class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key, required this.report});

  final ArenaReport report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session history')),
      body: SessionHistoryBody(report: report),
    );
  }
}

/// The searchable list itself, so the Reports tab and the floor's Session log
/// show exactly the same rows.
class SessionHistoryBody extends StatefulWidget {
  const SessionHistoryBody({
    super.key,
    required this.report,
    this.showMoney = true,
  });

  final ArenaReport report;

  /// Billed / collected / pending per bill. Off for someone without bill, money
  /// or reports access (the server keeps payment rows from them the same way).
  final bool showMoney;

  @override
  State<SessionHistoryBody> createState() => _SessionHistoryBodyState();
}

class _SessionHistoryBodyState extends State<SessionHistoryBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    final q = _query.trim().toLowerCase();
    final rows = q.isEmpty
        ? widget.report.history
        : widget.report.history
            .where((h) =>
                h.customerName.toLowerCase().contains(q) ||
                h.resources.any((r) => r.toLowerCase().contains(q)) ||
                h.games.any((g) => g.toLowerCase().contains(q)))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Customer, station or game',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Text(
                      widget.report.history.isEmpty
                          ? 'No sessions in '
                              '${widget.report.range.label.toLowerCase()}.'
                          : 'Nothing matches "$_query".',
                      textAlign: TextAlign.center,
                      style: ArenaType.body.copyWith(color: arena.textMuted),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) =>
                      _HistoryTile(row: rows[i], showMoney: widget.showMoney),
                ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.row, required this.showMoney});
  final SessionHistoryRow row;
  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    final (Color color, String label) = switch (row.paymentStatus) {
      PaymentStatus.paid => (arena.primary, 'Paid'),
      PaymentStatus.partial => (arena.warning, 'Partial'),
      PaymentStatus.unpaid => (arena.danger, 'Pending'),
      PaymentStatus.waived => (arena.textSubtle, 'Waived'),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: arena.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: arena.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArenaType.label.copyWith(color: arena.text),
                ),
              ),
              if (showMoney) StatusDotLabel(label: label, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              '${IstTime.format12(row.startedAt)}'
                  '${row.endedAt == null ? '' : ' – ${IstTime.format12(row.endedAt!)}'}',
              formatMinutesLabel(Duration(minutes: row.playedMinutes)),
              if (row.resources.isNotEmpty) row.resources.join(' → '),
            ].join(' · '),
            style: ArenaType.caption.copyWith(color: arena.textMuted),
          ),
          if (row.games.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              row.games.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ArenaType.caption.copyWith(color: arena.textSubtle),
            ),
          ],
          if (showMoney) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _money(arena, 'Billed', row.billedPaise, arena.text),
                const SizedBox(width: AppSpacing.lg),
                _money(arena, 'Collected', row.collectedPaise, arena.primary),
                if (row.pendingPaise > 0) ...[
                  const SizedBox(width: AppSpacing.lg),
                  _money(arena, 'Pending', row.pendingPaise, arena.warning),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _money(ArenaColors arena, String label, int paise, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ArenaType.caption.copyWith(color: arena.textSubtle)),
        Text(
          Paise(paise).display,
          style: AppTextStyles.mono(ArenaType.label).copyWith(color: color),
        ),
      ],
    );
  }
}
