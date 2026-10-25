import 'package:arena_ops/domain/entities/activity.dart';
import 'package:meta/meta.dart';

/// Which optional parts of the app this venue uses, worked out from its active station types —
/// never from a business category. A pool hall has no console types, so it sees no games or
/// controller screens; the day it adds a PlayStation they appear.
///
/// Visibility only: the server keeps enforcing permissions and ops whatever is shown, and
/// nothing is deleted when a capability goes away (the records stay, the screens hide).
/// The admin dashboard applies the same rule (`apps/admin/src/app/core/venue/`).
@immutable
class VenueCapabilities {
  const VenueCapabilities({
    required this.games,
    required this.equipment,
  });

  /// Everything on: what the floor shows while the catalog is still loading, so a console
  /// venue never sees its screens flicker away.
  static const all = VenueCapabilities(games: true, equipment: true);

  factory VenueCapabilities.of(List<Activity> activities) {
    final active = activities.where((a) => a.active);
    return VenueCapabilities(
      games: active.any((a) => a.usesGames),
      equipment: active.any((a) => a.usesControllers),
    );
  }

  /// A type picks a game when it starts: the game library, game controls, "games on this station".
  final bool games;

  /// A type uses controllers: the controller board, pads per station, controller counts.
  final bool equipment;

  @override
  bool operator ==(Object other) =>
      other is VenueCapabilities &&
      other.games == games &&
      other.equipment == equipment;

  @override
  int get hashCode => Object.hash(games, equipment);
}
