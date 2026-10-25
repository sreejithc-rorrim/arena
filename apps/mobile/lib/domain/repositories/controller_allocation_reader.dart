import 'package:arena_ops/domain/services/pad_selection.dart';

/// Read access to who is holding which physical pad right now. The app layer
/// uses it to carry a session's pads across a game change and to pre-check a
/// staff selection; writes happen inside the session repository.
abstract interface class ControllerAllocationReader {
  /// Every open (active) pad allocation.
  Future<List<OpenPadAllocation>> openPadAllocations();

  /// Live version of [openPadAllocations] for the pickers.
  Stream<List<OpenPadAllocation>> watchOpenPadAllocations();
}
