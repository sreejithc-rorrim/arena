import 'package:arena_ops/app/controllers/session_actions.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/monitoring/app_telemetry.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/time/duration_format.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/core/widgets/arena_badge.dart';
import 'package:arena_ops/domain/entities/booking.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/services/session_timer.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One station tile on the floor (design "Floor" cards). Renders either a live
/// session or a free / reserved / out-of-service station.
///
/// An occupied card answers, without a tap, every question the brief's floor
/// screen has to answer: **who** is playing, **what** game, on **how many
/// controllers**, **when it started**, **when it is due**, how much time is
/// left (or over) and the **bill so far**. The quick actions are always
/// present — not only once a session is ending — and the overflow reaches the
/// rest of the in-session actions.
class StationCard extends ConsumerWidget {
  const StationCard({
    super.key,
    required this.resource,
    this.active,
    this.nextBooking,
    this.onTap,
    this.onStart,
    this.onViewGames,
    this.onExtend,
    this.onBill,
    this.onPay,
    this.onMore,
  });

  final Resource resource;
  final ActiveSession? active;

  /// The next reservation for this resource, if any — drives the "Reserved"
  /// hint on a free card so staff don't start a session into a booking.
  final Booking? nextBooking;

  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onViewGames;
  final VoidCallback? onExtend;
  final VoidCallback? onBill;
  final VoidCallback? onPay;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arena = context.arena;
    if (active != null) return _occupied(context, ref, arena);
    return _free(context, ref, arena);
  }

  static final Set<String> _reportedAnomalies = <String>{};

  // --- occupied by a single session -----------------------------------------

  Widget _occupied(BuildContext context, WidgetRef ref, ArenaColors arena) {
    final a = active!;
    final session = a.session;
    final current = a.current;
    final now = ref.watch(nowProvider).value ?? ref.watch(clockProvider).now();
    final timer = SessionTimer(
      startedAt: session.startedAt,
      scheduledEndAt: session.scheduledEndAt,
      warnThreshold: ref.watch(warnThresholdProvider),
    );
    final anomaly = timer.detectAnomaly(now);
    if (anomaly != null && _reportedAnomalies.add('${session.id}:$anomaly')) {
      AppTelemetry.reportTimerAnomaly(
        sessionId: session.id,
        anomaly: anomaly,
        resourceId: current.resourceId,
        startedAt: session.startedAt,
        scheduledEndAt: session.scheduledEndAt,
      );
    }
    final visual = timer.state(now);

    final (Color accent, String badge) = switch (visual) {
      SessionVisualState.normal => (arena.stPlaying, 'Playing'),
      SessionVisualState.warning => (arena.stEnding, 'Ending'),
      SessionVisualState.overtime => (arena.stOvertime, 'Over time'),
    };
    final overtime = visual == SessionVisualState.overtime;

    final game = current.gameId == null
        ? null
        : ref.watch(gameByIdProvider(current.gameId!)).value;
    final customer = ref.watch(customerByIdProvider(session.customerId)).value;
    final bill = ref.watch(sessionActionsProvider).liveBill(a, now);

    return _shell(
      arena: arena,
      onTap: onTap,
      borderColor: accent,
      background: overtime ? arena.stOvertimeBg : arena.surface,
      pulse: overtime,
      children: [
        _headerRow(arena, badge, accent),
        const SizedBox(height: AppSpacing.md),
        _timerLine(arena, timer, now, overtime),
        const SizedBox(height: AppSpacing.sm),
        // Who is on this station — the brief's "occupied and by whom".
        _factLine(arena, customer?.displayName ?? 'Guest', null, strong: true),
        // What they are playing, on how many controllers.
        _factLine(
          arena,
          game?.name ?? (current.gameId == null ? 'No game' : '—'),
          current.controllerCount == null
              ? null
              : '${current.controllerCount} ctrl',
        ),
        // When it started and when it is due.
        _clockLine(arena, session.startedAt, session.scheduledEndAt),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(
              Paise(bill.total.value).display,
              style: AppTextStyles.mono(
                ArenaType.label,
              ).copyWith(color: bill.isIncomplete ? arena.warning : arena.text),
            ),
            Text(
              ' so far',
              style: ArenaType.caption.copyWith(color: arena.textMuted),
            ),
            if (bill.isIncomplete) ...[
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: 'Part of this session has no configured rate.',
                child: Icon(
                  Icons.error_outline,
                  size: 14,
                  color: arena.warning,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Quick actions are always available, not only when ending/overtime.
        Row(
          children: [
            Expanded(child: _quietButton(arena, 'Extend', onExtend)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _primaryButton(arena, 'Bill', onBill)),
            if (onMore != null) ...[
              const SizedBox(width: AppSpacing.sm),
              _iconButton(arena, Icons.more_horiz, onMore, 'More actions'),
            ],
          ],
        ),
      ],
    );
  }

  // --- free / reserved / out of service --------------------------------------

  Widget _free(BuildContext context, WidgetRef ref, ArenaColors arena) {
    final status = resource.status;
    final oos = !status.isBookable;
    final now = ref.watch(nowProvider).value ?? ref.watch(clockProvider).now();

    // "Reserved" is derived from the next booking, never stored on the row.
    final booking = nextBooking;
    final reservedSoon =
        !oos &&
        booking != null &&
        booking.scheduledStart.difference(now) <= const Duration(hours: 2);

    final (Color accent, String badge) = oos
        ? (arena.stOos, status.badge)
        : reservedSoon
        ? (arena.stEnding, 'Reserved')
        : (arena.stFree, 'Free');

    return _shell(
      arena: arena,
      onTap: oos ? null : onStart,
      borderColor: arena.border,
      background: oos ? arena.surfaceSunken : arena.surface,
      compact: true,
      children: [
        _headerRow(arena, badge, accent, dotColor: accent),
        const SizedBox(height: AppSpacing.md),
        if (oos) ...[
          Text(
            status.label,
            style: ArenaType.body.copyWith(color: arena.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            'Not available for play',
            style: ArenaType.caption.copyWith(color: arena.textSubtle),
          ),
        ] else ...[
          // The badge already says FREE / RESERVED, so a free card stays
          // compact — one line of context, then the actions. Only occupied
          // cards earn the taller layout.
          // Context and actions share one row, so an idle station costs as
          // little floor-screen height as possible.
          Row(
            children: [
              Expanded(
                child: Text(
                  reservedSoon
                      ? 'Held · ${IstTime.format12(booking.scheduledStart)}'
                      : (_rateLine(ref) ?? 'Ready to start'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ArenaType.caption.copyWith(
                    color: reservedSoon ? arena.stEnding : arena.textSubtle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (onViewGames != null) ...[
                _iconButton(
                  arena,
                  Icons.videogame_asset_outlined,
                  onViewGames,
                  'Games on this station',
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              _quietButton(arena, 'Start', onStart, icon: Icons.play_arrow),
            ],
          ),
        ],
      ],
    );
  }

  /// A short "₹150/h · up to 4" rate line for a free station (design).
  String? _rateLine(WidgetRef ref) {
    final code = resource.activityCodes.isEmpty
        ? null
        : resource.activityCodes.first;
    final snap = ref.watch(pricingSnapshotProvider).value;
    if (code == null || snap == null) return null;
    final activity = ref
        .watch(activitiesProvider)
        .value
        ?.firstWhereOrNull((a) => a.code == code);
    final usesCtrl = activity?.usesControllers ?? false;
    final rate = snap.rateFor(
      activityCode: code,
      band: Band.standard,
      controllerCount: usesCtrl ? 1 : null,
    );
    if (rate == null) return null;
    final unit = '/${formatPerUnit(rate.unitMinutes)}';
    return '${rate.price.display}$unit${usesCtrl ? ' · up to 4' : ''}';
  }

  // --- shared pieces ----------------------------------------------------------

  Widget _timerLine(
    ArenaColors arena,
    SessionTimer timer,
    DateTime now,
    bool overtime,
  ) {
    final text = overtime
        ? '+${formatClock(timer.overtime(now))}'
        : formatClock(timer.remaining(now));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            style: ArenaType.timer.copyWith(
              fontSize: 34,
              color: overtime ? arena.stOvertime : arena.text,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            overtime ? 'over' : 'left',
            style: ArenaType.caption.copyWith(color: arena.textMuted),
          ),
        ),
      ],
    );
  }

  /// `Kabir` + optional trailing chip like `2 ctrl`.
  Widget _factLine(
    ArenaColors arena,
    String text,
    String? trailing, {
    bool strong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: strong
                  ? ArenaType.label.copyWith(color: arena.text)
                  : ArenaType.caption.copyWith(color: arena.textMuted),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              trailing,
              style: AppTextStyles.mono(ArenaType.caption)
                  .copyWith(color: arena.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// `7:00 PM → 8:00 PM` — started at and due at, so staff never have to open
  /// the session to answer "when did they start?".
  Widget _clockLine(ArenaColors arena, DateTime startedAt, DateTime dueAt) {
    return Text(
      '${IstTime.format12(startedAt)} → ${IstTime.format12(dueAt)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.mono(ArenaType.caption)
          .copyWith(color: arena.textSubtle),
    );
  }

  Widget _headerRow(
    ArenaColors arena,
    String badge,
    Color accent, {
    Color? dotColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            resource.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ArenaType.h3.copyWith(color: arena.text, fontSize: 20),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: StatusDotLabel(label: badge, color: accent),
        ),
      ],
    );
  }

  Widget _shell({
    required ArenaColors arena,
    required List<Widget> children,
    required Color borderColor,
    required Color background,
    VoidCallback? onTap,
    bool compact = false,
    bool pulse = false,
  }) {
    final content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
    if (pulse) {
      return _OvertimePulse(
        from: arena.surface,
        to: background,
        borderColor: borderColor,
        child: content,
      );
    }
    // AnimatedContainer so the accent + tint glide between states (free →
    // playing → ending → over time) instead of snapping, like the prototype.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _quietButton(
    ArenaColors arena,
    String label,
    VoidCallback? onTap, {
    IconData? icon,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          backgroundColor: arena.surfaceRaised,
          side: BorderSide(color: arena.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
        label: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: ArenaType.label.copyWith(fontSize: 15),
        ),
      ),
    );
  }

  Widget _primaryButton(ArenaColors arena, String label, VoidCallback? onTap) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: ArenaType.label.copyWith(fontSize: 15),
        ),
      ),
    );
  }

  Widget _iconButton(
    ArenaColors arena,
    IconData icon,
    VoidCallback? onTap,
    String tooltip,
  ) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Tooltip(
        message: tooltip,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            backgroundColor: arena.surfaceRaised,
            side: BorderSide(color: arena.borderStrong),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
          ),
          child: Icon(icon, size: 18, color: arena.text),
        ),
      ),
    );
  }
}

/// The over-time card's tint, pulsing between [from] and [to] for as long as
/// the session stays over time, so it keeps catching the eye on a busy floor
/// (a one-off glide is easy to miss). Holds [to] when the system asks for
/// reduced motion.
class _OvertimePulse extends StatefulWidget {
  const _OvertimePulse({
    required this.from,
    required this.to,
    required this.borderColor,
    required this.child,
  });

  final Color from;
  final Color to;
  final Color borderColor;
  final Widget child;

  @override
  State<_OvertimePulse> createState() => _OvertimePulseState();
}

class _OvertimePulseState extends State<_OvertimePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          color: Color.lerp(
            widget.from,
            widget.to,
            Curves.easeInOut.transform(_controller.value),
          ),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: widget.borderColor, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
      child: widget.child,
    );
  }
}
