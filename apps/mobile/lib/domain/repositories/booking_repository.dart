import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/domain/entities/booking.dart';
import 'package:arena_ops/domain/value/enums.dart';

/// Thrown by [BookingRepository.create] / [BookingRepository.update] when the
/// station turns out to be taken for that time *inside* the write — another
/// booking or a session got there between the caller's availability check and
/// the save. Nothing is written; [failure] is what to show.
class BookingConflict implements Exception {
  const BookingConflict(this.failure);
  final Failure failure;

  @override
  String toString() => 'BookingConflict($failure)';
}

abstract interface class BookingRepository {
  /// Open/checked-in bookings, soonest first (spec §22 upcoming area).
  Stream<List<Booking>> watchUpcoming();
  Future<List<Booking>> upcoming();

  Future<Booking?> getById(String id);

  /// Save a new booking. A `booked` booking on a specific station is
  /// re-checked against that station's other bookings and open sessions in
  /// the same transaction; throws [BookingConflict] (writing nothing) if the
  /// slot is no longer free.
  Future<Booking> create(Booking booking);

  /// Edit an existing booking (spec §18 — staff can amend a reservation).
  /// Re-checked like [create], ignoring the booking's own slot.
  Future<Booking> update(Booking booking);

  Future<void> setReminderStatus(String id, ReminderStatus status);
  Future<void> setStatus(String id, BookingStatus status);

  /// Open bookings overlapping [fromUtc, toUtc) — used for conflict checks.
  Future<List<Booking>> overlapping(DateTime fromUtc, DateTime toUtc);
}
