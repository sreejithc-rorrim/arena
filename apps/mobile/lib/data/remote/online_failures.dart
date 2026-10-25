/// The words staff see when an online-only feature (profile, terms, my bills)
/// can't reach the server. One place maps the network and session states to a
/// [Failure], so no screen invents its own copy.
library;

import 'package:arena_ops/core/result/result.dart';

abstract final class OnlineFailures {
  static const Failure offline = Failure(
    message: "You're offline. This needs the internet.",
    fix: 'Connect to Wi-Fi or mobile data and try again.',
    code: 'offline',
  );

  static const Failure signedOut = Failure(
    message: 'Your sign-in has ended.',
    fix: 'Sign in again, then try again.',
    code: 'not_signed_in',
  );

  static const Failure accessOff = Failure(
    message: 'Your access to this arena is turned off.',
    fix: 'Ask the owner to turn it back on.',
    code: 'forbidden',
  );

  static const Failure loadFailed = Failure(
    message: "This couldn't be loaded.",
    fix: 'Check the connection and pull to refresh.',
    code: 'load_failed',
  );

  /// The server asked for the op to be sent again (busy / lock timeout).
  static const Failure busy = Failure(
    message: 'The server was busy and did not record this.',
    fix: 'Try again.',
    code: 'retry',
  );
}
