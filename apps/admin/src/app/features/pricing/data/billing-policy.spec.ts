import {
  DEFAULT_POLICY,
  minuteChoices,
  moneyRoundingChoices,
  parsePolicy,
  policyJson,
  policySummary,
} from './billing-policy';

describe('billing policy', () => {
  it('no row: the server defaults', () => {
    expect(parsePolicy(null)).toEqual(DEFAULT_POLICY);
  });

  it('reads a row and writes back every field', () => {
    const row = {
      billing_unit: 'block_30',
      block_rounding: 'nearest',
      grace_minutes: 5,
      minimum_charge_minutes: 30,
      early_exit: 'planned',
      rounding_scope: 'segment',
      late_arrival: 'planned',
      vr_unit_rounding: 'prorate',
      money_rounding_paise: 500,
      money_rounding_dir: 'up',
      payment_timing: 'start',
      allow_extend_past_close: true,
      cleaning_gap_minutes: 10,
    };
    expect(policyJson(parsePolicy(row))).toEqual(row);
    expect(Object.keys(policyJson(DEFAULT_POLICY)).length).toBe(13);
  });

  it('an unknown value reads as the default', () => {
    const p = parsePolicy({
      billing_unit: 'block_7',
      grace_minutes: -3,
      money_rounding_paise: 'x',
    });
    expect(p.billingUnit).toBe('per_minute');
    expect(p.graceMinutes).toBe(0);
    expect(p.moneyRoundingPaise).toBe(100);
  });

  it('offers the floor app’s choices plus a saved value outside them', () => {
    expect(minuteChoices(0).map((c) => c.label)).toEqual([
      'None',
      '5 min',
      '10 min',
      '15 min',
      '30 min',
      '60 min',
    ]);
    expect(minuteChoices(7).map((c) => c.value)).toEqual([0, 5, 7, 10, 15, 30, 60]);
    expect(moneyRoundingChoices(1).map((c) => c.label)).toEqual(['No rounding', '₹1', '₹5', '₹10']);
    expect(moneyRoundingChoices(50).map((c) => c.label)[0]).toBe('50 paise');
  });

  it('summarises the unit and the bill rounding', () => {
    expect(policySummary(DEFAULT_POLICY)).toBe('Per minute (exact) · bills rounded to nearest ₹1');
  });
});
