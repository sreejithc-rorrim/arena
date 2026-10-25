import 'package:arena_ops/app/auth/auth_controller.dart';
import 'package:arena_ops/core/monitoring/replay_privacy.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/repositories/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// PIN login (design): pick who's on shift, then enter a 4-digit PIN. Staff land
/// on the Floor, owners too — handled by the router once signed in.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const String path = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  AppUser? _picked;
  String _pin = '';
  bool _checking = false;
  String? _error;

  void _pick(AppUser u) => setState(() {
    _picked = u;
    _pin = '';
    _error = null;
  });

  void _back() => setState(() {
    _picked = null;
    _pin = '';
    _error = null;
  });

  Future<void> _press(String d) async {
    if (_checking || _pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) await _submit();
  }

  void _delete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    final attempt = await ref
        .read(authControllerProvider.notifier)
        .signIn(_picked!.id, _pin);
    if (!mounted) return;
    if (attempt is PinAccepted) return; // router redirect takes over
    HapticFeedback.heavyImpact();
    setState(() {
      _checking = false;
      _pin = '';
      _error = switch (attempt) {
        PinRejected(:final attemptsLeft) =>
          attemptsLeft <= 2
              ? 'Wrong PIN. $attemptsLeft ${attemptsLeft == 1 ? 'try' : 'tries'} '
                    'left before this account locks.'
              : 'Wrong PIN. Try again.',
        PinLockedOut(:final retryIn) =>
          'Too many wrong PINs. Try again in ${_wait(retryIn)}.',
        PinUnavailable(:final reason) => reason,
        PinAccepted() => null,
      };
    });
  }

  /// A lockout is read off a tablet mid-shift, so it is phrased as a wait, not
  /// a timestamp.
  static String _wait(Duration d) {
    final seconds = d.inSeconds < 1 ? 1 : d.inSeconds;
    if (seconds < 60) return '$seconds seconds';
    final minutes = (seconds / 60).ceil();
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }

  // Credentials are entered here: Session Replay pauses while it is open.
  @override
  Widget build(BuildContext context) => ReplayPause(child: _screen(context));

  Widget _screen(BuildContext context) {
    final arena = context.arena;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: arena.border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: arena.primary.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ARQ',
                        style: ArenaType.overline.copyWith(
                          color: arena.primary,
                        ),
                      ),
                      Text(
                        'Gaming Operations',
                        style: ArenaType.caption.copyWith(
                          color: arena.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                _picked == null ? "Who's on shift?" : 'Enter PIN',
                style: ArenaType.h1.copyWith(color: arena.text, fontSize: 30),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: _picked == null
                    ? _UserList(onPick: _pick)
                    : _PinPad(
                        user: _picked!,
                        pin: _pin,
                        error: _error,
                        checking: _checking,
                        onPress: _press,
                        onDelete: _delete,
                        onBack: _back,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserList extends ConsumerWidget {
  const _UserList({required this.onPick});
  final ValueChanged<AppUser> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arena = context.arena;
    final users = ref.watch(usersProvider);
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          'Could not load accounts.',
          style: ArenaType.body.copyWith(color: arena.textMuted),
        ),
      ),
      data: (list) => ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) {
          final u = list[i];
          return Material(
            color: arena.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: InkWell(
              onTap: () => onPick(u),
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minTarget,
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: arena.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: arena.primarySoft,
                      child: Text(
                        u.name.characters.first.toUpperCase(),
                        style: ArenaType.label.copyWith(
                          color: arena.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.name,
                            style: ArenaType.h3.copyWith(
                              color: arena.text,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            '${u.roleLabel} · PIN ••••',
                            style: ArenaType.caption.copyWith(
                              color: arena.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: arena.textSubtle),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.user,
    required this.pin,
    required this.error,
    required this.checking,
    required this.onPress,
    required this.onDelete,
    required this.onBack,
  });

  final AppUser user;
  final String pin;
  final String? error;
  final bool checking;
  final ValueChanged<String> onPress;
  final VoidCallback onDelete;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(user.name, style: ArenaType.h3.copyWith(color: arena.text)),
          TextButton(onPressed: onBack, child: const Text('Not you?')),
          const SizedBox(height: AppSpacing.lg),
          // 4 dots.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < pin.length ? arena.primary : Colors.transparent,
                    border: Border.all(
                      color: error != null
                          ? arena.stOvertime
                          : (i < pin.length
                                ? arena.primary
                                : arena.borderStrong),
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 24,
            child: checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    error ?? '',
                    style: ArenaType.caption.copyWith(color: arena.stOvertime),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Keypad(onPress: onPress, onDelete: onDelete),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onPress, required this.onDelete});
  final ValueChanged<String> onPress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;

    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Material(
          color: arena.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            side: BorderSide(color: arena.border),
          ),
          child: InkWell(
            onTap: onTap ?? () => onPress(label),
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: SizedBox(
              height: 64,
              child: Center(
                child:
                    child ??
                    Text(
                      label,
                      style: ArenaType.h2.copyWith(
                        color: arena.text,
                        fontSize: 24,
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );

    Widget row(List<Widget> children) => Row(children: children);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([key('1'), key('2'), key('3')]),
        row([key('4'), key('5'), key('6')]),
        row([key('7'), key('8'), key('9')]),
        row([
          const Spacer(),
          key('0'),
          key(
            '⌫',
            onTap: onDelete,
            child: Icon(Icons.backspace_outlined, color: arena.text),
          ),
        ]),
      ],
    );
  }
}
