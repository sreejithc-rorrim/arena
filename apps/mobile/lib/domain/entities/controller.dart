import 'package:freezed_annotation/freezed_annotation.dart';

part 'controller.freezed.dart';

/// A physical controller, tracked as a unit rather than a count.
///
/// Sessions still record a controller *count* — that is the billing tier, and
/// it does not change. This entity answers the questions a count cannot: which
/// pad is broken, where it is right now, and whether the station a customer is
/// standing at actually has enough working controllers to seat them.
enum ControllerStatus {
  /// Working and allocatable.
  usable,

  /// Present but broken — never allocated, never donated.
  faulty,

  /// Unaccounted for. Kept on the books so the shortfall is visible.
  missing,

  /// Written off. Excluded from every count.
  retired,

  /// Owner-marked temporarily out of service — distinct from a hardware fault.
  /// Never allocated while in this state; comes back with a status change.
  unavailable;

  String get code => name;

  String get label => switch (this) {
        ControllerStatus.usable => 'Usable',
        ControllerStatus.faulty => 'Faulty',
        ControllerStatus.missing => 'Missing',
        ControllerStatus.retired => 'Retired',
        ControllerStatus.unavailable => 'Unavailable',
      };

  /// True only when this pad may be handed to a customer.
  bool get isUsable => this == ControllerStatus.usable;

  static ControllerStatus fromCode(String c) =>
      ControllerStatus.values.firstWhere(
        (s) => s.code == c,
        orElse: () => ControllerStatus.usable,
      );
}

/// Why a controller is somewhere other than its home station.
enum ControllerMoveKind {
  /// Borrowed for one session; returns home at checkout.
  loan,

  /// Re-homed. The destination becomes its home station.
  permanent,

  /// Carried back to the station it belongs to. Owes no return.
  returnHome;

  String get code => name;

  String get label => switch (this) {
        ControllerMoveKind.loan => 'Just for this session',
        ControllerMoveKind.permanent => 'Permanently',
        ControllerMoveKind.returnHome => 'Back to its home station',
      };

  static ControllerMoveKind fromCode(String c) =>
      ControllerMoveKind.values.firstWhere(
        (k) => k.code == c,
        orElse: () => ControllerMoveKind.loan,
      );
}

@freezed
abstract class Controller with _$Controller {
  const Controller._();

  const factory Controller({
    required String id,
    /// What is written on the pad — "HEX-1". This is what staff are told to
    /// carry, so it must be the physical marking, not an id.
    required String label,

    /// The station it belongs to and returns to.
    required String homeResourceId,

    /// Where it physically is now. Equals [homeResourceId] unless it has been
    /// moved.
    required String currentResourceId,

    @Default(ControllerStatus.usable) ControllerStatus status,

    /// Why it is in this state — "left stick drift".
    String? notes,

    /// Set while on loan: the station to return it to.
    String? loanReturnTo,

    /// Which session owes the return, as `s:<sessionId>`.
    String? loanSessionRef,

    required DateTime updatedAt,
  }) = _Controller;

  /// Away from home, whether on loan or because it was re-homed.
  bool get isAwayFromHome => currentResourceId != homeResourceId;

  /// Borrowed for a session that has not ended yet.
  bool get isOnLoan => loanSessionRef != null;

  /// A loan reference for a single session.
  static String sessionRef(String sessionId) => 's:$sessionId';
}
