import 'package:arena_ops/app/controllers/booking_actions.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/time/duration_format.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/core/widgets/app_toast.dart';
import 'package:arena_ops/core/widgets/custom_duration_sheet.dart';
import 'package:arena_ops/domain/entities/activity.dart';
import 'package:arena_ops/domain/entities/booking.dart';
import 'package:arena_ops/domain/entities/customer.dart';
import 'package:arena_ops/domain/entities/game.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/features/new_session/presentation/customer_picker_sheet.dart';
import 'package:arena_ops/features/new_session/presentation/game_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Game-first booking (spec §18–§21). Pick a game + time, then book any
/// compatible system or a specific one.
///
/// Pass [existing] to amend a reservation: the same availability checks run,
/// minus the booking's own slot, so a booking never conflicts with itself.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, this.existing});

  final Booking? existing;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  Customer? _customer;
  String? _activityCode;
  Game? _game;
  DateTime? _date;
  TimeOfDay? _time;
  int _duration = 60;
  int? _players;
  String? _resourceId; // null = any compatible
  List<Resource> _candidates = const [];
  final _notes = TextEditingController();
  bool _checking = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    if (b == null) return;
    // Prefill from the planned record so staff change one field, not all of
    // them. The planned times stay in IST, as they were entered.
    final startIst = IstTime.fromUtc(b.scheduledStart);
    _activityCode = b.activityCode;
    _date = DateTime(startIst.year, startIst.month, startIst.day);
    _time = TimeOfDay(hour: startIst.hour, minute: startIst.minute);
    _duration = b.plannedDuration.inMinutes;
    _players = b.playersRequired;
    _resourceId = b.resourceId;
    _notes.text = b.notes ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (b.customerId != null) {
        final c = await ref.read(customerRepositoryProvider).getById(b.customerId!);
        if (mounted) setState(() => _customer = c);
      }
      if (b.gameId != null) {
        final g = await ref.read(catalogRepositoryProvider).gameById(b.gameId!);
        if (mounted) setState(() => _game = g);
      }
      await _refreshCandidates();
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  int? get _startMinute => _time == null ? null : _time!.hour * 60 + _time!.minute;
  IstDate? get _istDate =>
      _date == null ? null : IstDate(_date!.year, _date!.month, _date!.day);

  bool get _ready =>
      _customer != null && _activityCode != null && _istDate != null && _time != null;

  BookingDraft? _draft() {
    if (!_ready) return null;
    return BookingDraft(
      customerId: _customer!.id,
      activityCode: _activityCode!,
      date: _istDate!,
      startMinuteOfDay: _startMinute!,
      durationMinutes: _duration,
      gameId: _game?.id,
      resourceId: _resourceId,
      playersRequired: _players,
      controllerRequirement: _players,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      editingId: widget.existing?.id,
    );
  }

  Future<void> _refreshCandidates() async {
    final d = _draft();
    if (d == null) {
      setState(() => _candidates = const []);
      return;
    }
    setState(() => _checking = true);
    final c = await ref.read(bookingActionsProvider).candidateSystems(
          BookingDraft(
            customerId: d.customerId,
            activityCode: d.activityCode,
            date: d.date,
            startMinuteOfDay: d.startMinuteOfDay,
            durationMinutes: d.durationMinutes,
            gameId: d.gameId,
            playersRequired: d.playersRequired,
          ),
        );
    if (mounted) {
      setState(() {
        _candidates = c;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activities = ref.watch(activitiesProvider).value ?? const [];
    final resources = ref.watch(resourcesProvider).value ?? const [];
    Activity? activity;
    for (final a in activities) {
      if (a.code == _activityCode) activity = a;
    }
    // A removed (disabled) station is never offered.
    final specificOptions = resources
        .where((r) =>
            r.status != ResourceStatus.disabled &&
            _activityCode != null &&
            r.activityCodes.contains(_activityCode))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit booking' : 'New booking'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _section('Customer', OutlinedButton.icon(
            onPressed: () async {
              final c = await showCustomerPicker(context);
              if (c != null) setState(() => _customer = c);
            },
            icon: const Icon(Icons.person_outline),
            label: Text(_customer?.displayName ?? 'Select customer'),
          )),
          _section('Activity', Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final a in activities)
                ChoiceChip(
                  label: Text(a.name),
                  selected: _activityCode == a.code,
                  onSelected: (_) {
                    setState(() {
                      _activityCode = a.code;
                      _game = null;
                      _resourceId = null;
                    });
                    _refreshCandidates();
                  },
                ),
            ],
          )),
          if (activity != null && activity.usesGames)
            _section('Game', OutlinedButton.icon(
              onPressed: () async {
                final g = await _pickGame(activity!);
                if (g != null) {
                  setState(() => _game = g);
                  _refreshCandidates();
                }
              },
              icon: const Icon(Icons.videogame_asset_outlined),
              label: Text(_game?.name ?? 'Select game (optional)'),
            )),
          _section('When', Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Today is the arena's (IST) business day from the app
                    // clock, never the device's wall clock.
                    final today =
                        IstDate.fromUtc(ref.read(clockProvider).now());
                    final now = DateTime(today.year, today.month, today.day);
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date ?? now,
                      currentDate: now,
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 60)),
                    );
                    if (d != null) {
                      setState(() => _date = d);
                      _refreshCandidates();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_date == null
                      ? 'Date'
                      : '${_date!.day}/${_date!.month}'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _time ?? const TimeOfDay(hour: 19, minute: 0),
                    );
                    if (t != null) {
                      setState(() => _time = t);
                      _refreshCandidates();
                    }
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(_time == null ? 'Time' : _time!.format(context)),
                ),
              ),
            ],
          )),
          _section('Duration', Builder(builder: (context) {
            final presets = ref.watch(startPresetsProvider);
            final isCustom = !presets.contains(_duration);
            return Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final m in presets)
                  ChoiceChip(
                    label: Text('$m min'),
                    selected: _duration == m,
                    onSelected: (_) {
                      setState(() => _duration = m);
                      _refreshCandidates();
                    },
                  ),
                ChoiceChip(
                  label: Text(isCustom
                      ? 'Custom · ${formatMinutesLabel(Duration(minutes: _duration))}'
                      : 'Custom'),
                  selected: isCustom,
                  onSelected: (_) async {
                    final mins =
                        await showCustomMinutesSheet(context, initial: _duration);
                    if (mins != null) {
                      setState(() => _duration = mins);
                      _refreshCandidates();
                    }
                  },
                ),
              ],
            );
          })),
          if (activity != null && activity.usesControllers)
            _section('Players', Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final n in [1, 2, 3, 4])
                  ChoiceChip(
                    label: Text('$n'),
                    selected: _players == n,
                    onSelected: (_) {
                      setState(() => _players = n);
                      _refreshCandidates();
                    },
                  ),
              ],
            )),
          _section('System', Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('Any compatible'),
                    selected: _resourceId == null,
                    onSelected: (_) => setState(() => _resourceId = null),
                  ),
                  for (final r in specificOptions)
                    ChoiceChip(
                      label: Text(r.name),
                      selected: _resourceId == r.id,
                      onSelected: (_) => setState(() => _resourceId = r.id),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_checking)
                const Text('Checking availability…')
              else if (_ready && _resourceId == null)
                Text(_candidates.isEmpty
                    ? 'No compatible system available for that time.'
                    : 'Available: ${_candidates.map((r) => r.name).join(', ')}'),
            ],
          )),
          _section(
            'Notes',
            TextField(
              controller: _notes,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Birthday party · wants the corner station',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _ready && !_saving ? _confirm : null,
            icon: Icon(_isEditing ? Icons.save_outlined : Icons.event_available),
            label: Text(_saving
                ? 'Saving…'
                : _isEditing
                    ? 'Save changes'
                    : 'Confirm booking'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      );

  Future<Game?> _pickGame(Activity activity) {
    return showGamePickerForActivity(
      context,
      activityCode: activity.code,
      activityLabel: activity.name,
    );
  }

  Future<void> _confirm() async {
    final d = _draft();
    if (d == null) return;
    setState(() => _saving = true);
    final actions = ref.read(bookingActionsProvider);
    final r = _isEditing
        ? await actions.updateBooking(d)
        : await actions.createBooking(d);
    if (!mounted) return;
    setState(() => _saving = false);
    r.fold(
      (_) {
        Navigator.of(context).pop();
        showToast(context, _isEditing ? 'Booking updated' : 'Booking confirmed');
      },
      (f) => showFailure(context, f),
    );
  }
}
