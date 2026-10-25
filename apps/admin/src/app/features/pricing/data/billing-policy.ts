import { formatRupees } from '../../../shared/money/rupees.pipe';

export type BillingUnit = 'per_minute' | 'block_15' | 'block_30' | 'block_60';
export type BlockRounding = 'up' | 'nearest';
export type EarlyExit = 'actual' | 'planned';
export type RoundingScope = 'session' | 'segment';
export type LateArrival = 'actual' | 'planned';
export type VrUnitRounding = 'up' | 'nearest' | 'prorate';
export type MoneyRoundingDir = 'nearest' | 'up';
export type PaymentTiming = 'either' | 'start' | 'end';

/**
 * The arena's billing rules (server: billing_policies, the oldest active row), the knobs the
 * price list does not state (docs/OWNER_CONFIRMATION.md). Captured into each session's pricing
 * snapshot when it starts, so a change only affects sessions started after it.
 */
export interface BillingPolicy {
  readonly billingUnit: BillingUnit;
  readonly blockRounding: BlockRounding;
  readonly graceMinutes: number;
  readonly minimumChargeMinutes: number;
  readonly earlyExit: EarlyExit;
  readonly roundingScope: RoundingScope;
  readonly lateArrival: LateArrival;
  readonly vrUnitRounding: VrUnitRounding;
  /** The final cash total is rounded to a multiple of this (100 = ₹1). */
  readonly moneyRoundingPaise: number;
  readonly moneyRoundingDir: MoneyRoundingDir;
  readonly paymentTiming: PaymentTiming;
  readonly allowExtendPastClose: boolean;
  readonly cleaningGapMinutes: number;
}

/** The server's defaults (_pr_policy), the floor app's BillingPolicy.defaults. */
export const DEFAULT_POLICY: BillingPolicy = {
  billingUnit: 'per_minute',
  blockRounding: 'up',
  graceMinutes: 0,
  minimumChargeMinutes: 0,
  earlyExit: 'actual',
  roundingScope: 'session',
  lateArrival: 'actual',
  vrUnitRounding: 'up',
  moneyRoundingPaise: 100,
  moneyRoundingDir: 'nearest',
  paymentTiming: 'either',
  allowExtendPastClose: false,
  cleaningGapMinutes: 0,
};

/** The billing_policies columns the dashboard reads. */
export const POLICY_COLUMNS =
  'billing_unit, block_rounding, grace_minutes, minimum_charge_minutes, early_exit, rounding_scope, late_arrival, vr_unit_rounding, money_rounding_paise, money_rounding_dir, payment_timing, allow_extend_past_close, cleaning_gap_minutes';

export interface Choice<T> {
  readonly value: T;
  readonly label: string;
}

/** The floor app's choices (billing_rules_screen.dart), with the same wording. */
export const BILLING_UNITS: readonly Choice<BillingUnit>[] = [
  { value: 'per_minute', label: 'Per minute (exact)' },
  { value: 'block_15', label: 'In 15-minute blocks' },
  { value: 'block_30', label: 'In 30-minute blocks' },
  { value: 'block_60', label: 'In whole hours' },
];
export const BLOCK_ROUNDINGS: readonly Choice<BlockRounding>[] = [
  { value: 'up', label: 'Always round up' },
  { value: 'nearest', label: 'Round to nearest' },
];
export const EARLY_EXITS: readonly Choice<EarlyExit>[] = [
  { value: 'actual', label: 'Bill the time actually played' },
  { value: 'planned', label: 'Bill the full booked duration' },
];
export const MONEY_DIRS: readonly Choice<MoneyRoundingDir>[] = [
  { value: 'nearest', label: 'To the nearest' },
  { value: 'up', label: 'Always up' },
];
export const ROUNDING_SCOPES: readonly Choice<RoundingScope>[] = [
  { value: 'session', label: 'Once, on the session total' },
  { value: 'segment', label: 'Separately for each segment' },
];
export const VR_ROUNDINGS: readonly Choice<VrUnitRounding>[] = [
  { value: 'up', label: 'Charge the whole block' },
  { value: 'nearest', label: 'Round to the nearest block' },
  { value: 'prorate', label: 'Charge the exact time used' },
];

/** Minutes offered for grace, minimum charge and the cleaning gap. */
export const MINUTE_CHOICES: readonly number[] = [0, 5, 10, 15, 30, 60];
/** What the final bill can be rounded to, in paise. */
export const MONEY_ROUNDING_CHOICES: readonly number[] = [100, 500, 1000];

/** The minute choices, plus a saved value outside them so it shows (and can be changed). */
export function minuteChoices(saved: number): Choice<number>[] {
  return [...new Set([...MINUTE_CHOICES, saved])]
    .sort((a, b) => a - b)
    .map((m) => ({ value: m, label: m === 0 ? 'None' : `${m} min` }));
}

/** "₹5", "50 paise", or "No rounding" (1 paisa or less). */
export function roundingLabel(paise: number): string {
  if (paise <= 1) return 'No rounding';
  return paise % 100 === 0 ? formatRupees(paise) : `${paise} paise`;
}

/** The rounding choices, plus a saved value outside them. */
export function moneyRoundingChoices(saved: number): Choice<number>[] {
  return [...new Set([...MONEY_ROUNDING_CHOICES, saved])]
    .sort((a, b) => a - b)
    .map((p) => ({ value: p, label: roundingLabel(p) }));
}

function pick<T extends string>(value: unknown, allowed: readonly Choice<T>[], fallback: T): T {
  return allowed.some((c) => c.value === value) ? (value as T) : fallback;
}

function int(value: unknown, fallback: number): number {
  const n = Number(value);
  return value != null && Number.isInteger(n) && n >= 0 ? n : fallback;
}

/** A billing_policies row (or none: the server prices on its defaults then). */
export function parsePolicy(row: Record<string, unknown> | null | undefined): BillingPolicy {
  if (!row) return DEFAULT_POLICY;
  const d = DEFAULT_POLICY;
  return {
    billingUnit: pick(row['billing_unit'], BILLING_UNITS, d.billingUnit),
    blockRounding: pick(row['block_rounding'], BLOCK_ROUNDINGS, d.blockRounding),
    graceMinutes: int(row['grace_minutes'], d.graceMinutes),
    minimumChargeMinutes: int(row['minimum_charge_minutes'], d.minimumChargeMinutes),
    earlyExit: pick(row['early_exit'], EARLY_EXITS, d.earlyExit),
    roundingScope: pick(row['rounding_scope'], ROUNDING_SCOPES, d.roundingScope),
    lateArrival: row['late_arrival'] === 'planned' ? 'planned' : 'actual',
    vrUnitRounding: pick(row['vr_unit_rounding'], VR_ROUNDINGS, d.vrUnitRounding),
    moneyRoundingPaise: int(row['money_rounding_paise'], d.moneyRoundingPaise),
    moneyRoundingDir: pick(row['money_rounding_dir'], MONEY_DIRS, d.moneyRoundingDir),
    paymentTiming:
      row['payment_timing'] === 'start' || row['payment_timing'] === 'end'
        ? row['payment_timing']
        : 'either',
    allowExtendPastClose: row['allow_extend_past_close'] === true,
    cleaningGapMinutes: int(row['cleaning_gap_minutes'], d.cleaningGapMinutes),
  };
}

/**
 * policy.save's `policy` object: every field, always. The server overwrites each column (a
 * missing one is refused).
 */
export function policyJson(p: BillingPolicy): Record<string, unknown> {
  return {
    billing_unit: p.billingUnit,
    block_rounding: p.blockRounding,
    grace_minutes: p.graceMinutes,
    minimum_charge_minutes: p.minimumChargeMinutes,
    early_exit: p.earlyExit,
    rounding_scope: p.roundingScope,
    late_arrival: p.lateArrival,
    vr_unit_rounding: p.vrUnitRounding,
    money_rounding_paise: p.moneyRoundingPaise,
    money_rounding_dir: p.moneyRoundingDir,
    payment_timing: p.paymentTiming,
    allow_extend_past_close: p.allowExtendPastClose,
    cleaning_gap_minutes: p.cleaningGapMinutes,
  };
}

/** Same rules (field by field). */
export function samePolicy(a: BillingPolicy, b: BillingPolicy): boolean {
  return (Object.keys(a) as (keyof BillingPolicy)[]).every((k) => a[k] === b[k]);
}

/** "Per minute (exact) · bills rounded to nearest ₹1" for the Settings list. */
export function policySummary(p: BillingPolicy): string {
  const unit = BILLING_UNITS.find((u) => u.value === p.billingUnit)?.label ?? p.billingUnit;
  const money =
    p.moneyRoundingPaise <= 1
      ? 'no bill rounding'
      : `bills rounded ${p.moneyRoundingDir === 'up' ? 'up' : 'to nearest'} ${roundingLabel(p.moneyRoundingPaise)}`;
  return `${unit} · ${money}`;
}
