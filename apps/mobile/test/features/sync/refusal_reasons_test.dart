import 'package:arena_ops/features/sync/presentation/sync_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every refusal the server can send for an op this app makes is worded for
/// staff on the Sync screen, never shown as a bare code.
void main() {
  // The codes the op_* functions behind the floor app's ops raise (sessions,
  // payments, pads, customers, bookings, settings), plus the codes
  // sync_push maps SQL errors to.
  const codes = [
    'resource_busy', 'controller_taken', 'controller_elsewhere',
    'controllers_unavailable', 'stale', 'not_active', 'booking_not_open',
    'booking_conflict', 'forbidden', 'voided', 'not_found', 'duplicate',
    'players_exceeded', 'not_playable', 'mode_locked', 'last_settings_holder',
    'price_mismatch', 'pricing_snapshot_mismatch', 'no_rate', 'overpayment',
    'refund_exceeds_paid', 'refund_reason_required', 'amount_zero',
    'amount_negative', 'invalid_method', 'invalid_time', 'no_open_segment',
    'resource_unavailable', 'resource_missing', 'missing_reference',
    'activity_missing', 'mode_switch_busy', 'controllers_exceeded',
    'controller_count_mismatch', 'controller_unusable', 'controller_missing',
    'controller_duplicate', 'controller_in_use', 'move_kind_invalid',
    'phone_taken', 'invalid_birth_year', 'booking_missing', 'invalid_status',
    'invalid_name', 'invalid', 'invalid_payload', 'invalid_permission',
    'setting_not_shared', 'unknown_op', 'server_error',
  ];

  for (final code in codes) {
    test('$code is worded', () {
      expect(reasonFor(code), isNot(startsWith('refused (')));
    });
  }

  test('money a refused payment took is called out', () {
    expect(reasonFor('overpayment'), contains('hand it back'));
  });

  test('an unknown code still says it was refused, with the code', () {
    expect(reasonFor('brand_new_rule'), 'refused (brand_new_rule)');
  });
}
