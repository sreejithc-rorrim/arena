/// Turns "is this person allowed to do that?" into a [Failure] the UI already
/// knows how to show.
///
/// Hiding a button is a courtesy, not a control: the sheets and screens are
/// reachable from several places and a stale route can outlive a sign-out. So
/// the actions that take money or change the floor check the signed-in user
/// here, underneath the UI, where every caller has to pass.
library;

import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/auth/permission.dart';

class PermissionGuard {
  const PermissionGuard(this.actor);

  /// Who is signed in, or null when the session is locked.
  final AppUser? actor;

  /// Null when someone active is signed in, otherwise the refusal to return —
  /// for actions every member may take on their own behalf (their own profile,
  /// accepting the staff terms).
  Failure? checkSignedIn() {
    final user = actor;
    if (user == null) {
      return const Failure(
        message: 'No one is signed in.',
        fix: 'Sign in with your PIN and try again.',
        code: 'not_signed_in',
      );
    }
    if (!user.active) {
      return const Failure(
        message: 'This account has been turned off.',
        fix: 'Ask an owner to turn it back on.',
        code: 'account_inactive',
      );
    }
    return null;
  }

  /// Null when [permission] is held, otherwise the refusal to return.
  Failure? check(Permission permission) {
    final signedOut = checkSignedIn();
    if (signedOut != null) return signedOut;
    final user = actor!;
    if (!user.can(permission)) {
      return Failure(
        message: '${user.name} is not allowed to '
            '${_phrase(permission)}.',
        fix: 'Ask an owner to do this, or to change the permissions.',
        code: 'not_permitted',
      );
    }
    return null;
  }

  /// True when the action is allowed — for deciding what to *show*.
  bool allows(Permission permission) => check(permission) == null;

  /// Null when ANY of [permissions] is held — for actions more than one role
  /// may take (a customer can be added by whoever starts sessions or manages
  /// members) — otherwise one refusal naming all of them.
  Failure? checkAny(List<Permission> permissions) {
    assert(permissions.isNotEmpty, 'checkAny needs at least one permission');
    Failure? refused;
    for (final p in permissions) {
      final f = check(p);
      if (f == null) return null;
      refused ??= f;
    }
    // Not signed in / turned off read the same for every permission.
    if (refused!.code != 'not_permitted' || permissions.length == 1) {
      return refused;
    }
    return Failure(
      message: '${actor!.name} is not allowed to '
          '${permissions.map(_phrase).join(' or ')}.',
      fix: 'Ask an owner to do this, or to change the permissions.',
      code: 'not_permitted',
    );
  }

  /// [checkAny] as a yes/no — for deciding what to *show*.
  bool allowsAny(List<Permission> permissions) =>
      checkAny(permissions) == null;

  static String _phrase(Permission p) => switch (p) {
        Permission.start => 'start or change sessions',
        Permission.bill => 'bill or take payment',
        Permission.discount => 'give discounts, waive a bill or refund',
        Permission.members => 'manage members',
        Permission.stations => 'manage stations',
        Permission.money => 'see the money screen',
        Permission.reports => 'see reports',
        Permission.settings => 'change settings',
        Permission.billEdit => 'edit your bills',
        Permission.billRecord => 'add missed bills',
      };
}
