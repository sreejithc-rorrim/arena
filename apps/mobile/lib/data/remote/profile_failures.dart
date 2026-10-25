/// The words staff see when their details or the staff terms do not load or
/// save, keyed by the server's codes (op_staff_details_save, op_terms_accept)
/// and the field checks the app makes first.
library;

import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/data/remote/online_failures.dart';
import 'package:arena_ops/domain/profile/staff_details.dart';

abstract final class ProfileFailures {
  static const Failure cloudOnly = Failure(
    message: 'Your profile works only when the app is connected to your arena '
        'online.',
    fix: 'Sign in to your arena to fill in your details.',
    code: 'profile_needs_cloud',
  );

  static const Failure offline = Failure(
    message: "You're offline. Your details and the staff terms need the "
        'internet.',
    fix: 'Connect to Wi-Fi or mobile data and try again.',
    code: 'offline',
  );

  static const Failure signedOut = Failure(
    message: 'Your sign-in has ended.',
    fix: 'Sign out, then sign in again.',
    code: 'not_signed_in',
  );

  static const Failure busy = Failure(
    message: 'The server was busy and did not record it.',
    fix: 'Try again.',
    code: 'retry',
  );

  static const Failure detailsLoadFailed = Failure(
    message: "Your details couldn't be loaded.",
    fix: 'Check the connection and try again.',
    code: 'load_failed',
  );

  static const Failure termsLoadFailed = Failure(
    message: "The staff terms couldn't be loaded.",
    fix: 'Check the connection and try again.',
    code: 'load_failed',
  );

  /// The form was not sent: some fields hold values the server would refuse.
  static const Failure fieldsToFix = Failure(
    message: 'Some details need correcting.',
    fix: 'Fix the fields marked in red, then save again.',
    code: 'invalid_fields',
  );

  /// The shared online plumbing words network states generically; these
  /// screens say it for themselves.
  static Failure reword(Failure f) => switch (f.code) {
        'offline' => offline,
        'not_signed_in' => signedOut,
        'retry' => busy,
        _ => f,
      };

  /// A value the server would refuse (checked before sending).
  static Failure invalidField(StaffDetailsField f) => switch (f) {
        StaffDetailsField.phone || StaffDetailsField.emergencyPhone => const Failure(
            message: 'Enter a phone number of 7 to 20 digits.',
            fix: 'Digits, spaces or dashes, with an optional + in front.',
            code: 'invalid_phone'),
        StaffDetailsField.email => const Failure(
            message: 'That e-mail address does not look right.',
            fix: 'Check it, e.g. name@example.com.',
            code: 'invalid_email'),
        StaffDetailsField.birthDate => const Failure(
            message: 'Pick a date of birth from 1900 to today.',
            code: 'invalid_birth_date'),
        StaffDetailsField.bloodGroup => const Failure(
            message: 'Pick a blood group from the list.',
            code: 'invalid_blood_group'),
        StaffDetailsField.pinCode => const Failure(
            message: 'A PIN code is six digits and does not start with 0.',
            code: 'invalid_pin_code'),
        _ => Failure(
            message: 'Keep this to ${f.maxLength} characters.',
            code: 'too_long'),
      };

  /// A refusal of `staff_details.save` with [code]; [detail] names the field.
  static Failure detailsRejected(String? code, String? detail) => switch (code) {
        'invalid_payload' => Failure(
            message: 'Some details were not accepted'
                '${detail == null ? '' : ' ($detail)'}.',
            fix: 'Correct that field and save again.',
            code: code),
        'not_found' => const Failure(
            message: "Your staff profile isn't in this arena.",
            fix: 'Ask the owner to check your access.',
            code: 'not_found'),
        'forbidden' => OnlineFailures.accessOff,
        _ => Failure(
            message: "Your details weren't saved"
                '${code == null ? '' : ' ($code)'}.',
            fix: 'Try again. If it keeps happening, tell the owner.',
            code: code ?? 'details_failed'),
      };

  /// A refusal of `terms.accept` with [code].
  static Failure termsRejected(String? code, String? detail) => switch (code) {
        'stale' => const Failure(
            message: 'A newer version of the terms was just published.',
            fix: 'Read the new version below, then accept it.',
            code: 'stale'),
        'not_found' when detail == 'terms' => const Failure(
            message: 'These terms are no longer in this arena.',
            fix: 'Try again to load the terms in force.',
            code: 'not_found'),
        'not_found' => const Failure(
            message: "Your staff profile isn't in this arena.",
            fix: 'Ask the owner to check your access.',
            code: 'not_found'),
        'invalid_payload' => Failure(
            message: 'The app sent an incomplete acceptance'
                '${detail == null ? '' : ' ($detail)'}.',
            fix: 'Update the app and try again.',
            code: code),
        'forbidden' => OnlineFailures.accessOff,
        _ => Failure(
            message: "Your acceptance didn't go through"
                '${code == null ? '' : ' ($code)'}.',
            fix: 'Try again. If it keeps happening, tell the owner.',
            code: code ?? 'terms_failed'),
      };
}
