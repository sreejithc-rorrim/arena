/// The words staff see when My bills does not load or a bill edit does not go
/// through, keyed by the server's codes (my_bills, op_bill_adjust).
library;

import 'package:arena_ops/core/result/result.dart';

abstract final class BillFailures {
  static const Failure cloudOnly = Failure(
    message:
        'My bills works only when the app is connected to your arena online.',
    fix: 'Sign in to your arena to see and edit your bills.',
    code: 'bills_need_cloud',
  );

  /// Same code as the shared offline failure, worded for bills.
  static const Failure offline = Failure(
    message:
        "You're offline. My bills needs the internet, so the server can check "
        'and record the change.',
    fix: 'Connect to Wi-Fi or mobile data and try again.',
    code: 'offline',
  );

  static const Failure loadFailed = Failure(
    message: 'Your bills could not be loaded.',
    fix: 'Check you still have "Edit own bills" access, then pull to refresh.',
    code: 'bills_load_failed',
  );

  static Failure rejected(String? code, String? detail) => switch (code) {
    'reason_required' => const Failure(
      message: 'Say why the bill changes.',
      fix: 'Add a short comment.',
      code: 'reason_required',
    ),
    'reason_too_long' => const Failure(
      message: 'The comment is too long.',
      fix: 'Keep it under 500 characters.',
      code: 'reason_too_long',
    ),
    'invalid_total' => const Failure(
      message: 'That amount does not work.',
      fix: 'Enter the amount in rupees, 0 or more.',
      code: 'invalid_total',
    ),
    'invalid_method' => const Failure(
      message: 'Pick how the difference was paid or given back.',
      fix: 'Choose Cash, UPI, Card or Other.',
      code: 'invalid_method',
    ),
    'same_total' => const Failure(
      message: 'The bill is already that amount and paid.',
      fix: 'Enter a different amount.',
      code: 'same_total',
    ),
    'voided' => const Failure(
      message: 'This bill was voided.',
      fix: 'A voided bill cannot be edited.',
      code: 'voided',
    ),
    'waived' => const Failure(
      message: 'This bill was waived.',
      fix: 'A waived bill owes nothing and cannot be edited.',
      code: 'waived',
    ),
    'stale' => const Failure(
      message: 'This bill changed since you opened it.',
      fix: 'Open it again to see the new amounts, then make the change.',
      code: 'stale',
    ),
    'not_ended' => const Failure(
      message: 'This session is still running.',
      fix: 'End it on the floor first.',
      code: 'not_ended',
    ),
    'not_found' => Failure(
      message: detail == 'customer'
          ? 'That customer was not found.'
          : detail == 'station'
          ? 'That station was not found.'
          : detail == 'game'
          ? 'That game was not found.'
          : 'That bill was not found.',
      fix: 'Pull to refresh and pick again.',
      code: 'not_found',
    ),
    'time_in_future' => const Failure(
      message: 'The end time is in the future.',
      fix: 'A missed bill is for play that already happened.',
      code: 'time_in_future',
    ),
    'invalid_time' => const Failure(
      message: 'Those times do not work.',
      fix: 'The end must be after the start, at most 24 hours later.',
      code: 'invalid_time',
    ),
    'overlap' => const Failure(
      message: 'That station already has play recorded at that time.',
      fix: 'Check the times, or pick the station they actually used.',
      code: 'overlap',
    ),
    'no_rate' => const Failure(
      message: 'There is no price for that type and controller count.',
      fix: 'Pick another controller count, or ask the owner to add the rate.',
      code: 'no_rate',
    ),
    'activity_not_offered' => const Failure(
      message: 'That station does not offer this type.',
      fix: 'Pick the type the station offers.',
      code: 'activity_not_offered',
    ),
    'price_mismatch' => const Failure(
      message: 'The price changed before the bill was added.',
      fix: 'Check the new price and save again.',
      code: 'price_mismatch',
    ),
    'invalid_payload' => const Failure(
      message: 'Something is missing.',
      fix: 'Pick the customer, station, times and how it was paid.',
      code: 'invalid_payload',
    ),
    'forbidden' => const Failure(
      message: 'You cannot edit this bill.',
      fix:
          'You can edit only bills you started, with "Edit own bills" access. '
          'Ask the owner.',
      code: 'forbidden',
    ),
    _ => Failure(
      message:
          "The bill edit didn't go through"
          '${code == null ? '' : ' ($code)'}.',
      fix: 'Try again. If it keeps happening, tell the owner.',
      code: code ?? 'bill_edit_failed',
    ),
  };
}
