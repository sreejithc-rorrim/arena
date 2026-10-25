import { formatRupees } from '../../../shared/money/rupees.pipe';
import { BillingPolicy } from './billing-policy';

export type DurationModel = 'hourly' | 'unit' | 'flat_hourly';

/** A station type (server: activities) — what can be played and how it is billed. */
export interface StationType {
  readonly id: string;
  /** Stable business code (PS5, VR…), fixed once created. */
  readonly code: string;
  readonly name: string;
  /** Pads are tracked, and the price depends on how many are in use. */
  readonly usesControllers: boolean;
  readonly usesGames: boolean;
  readonly durationModel: DurationModel;
  readonly sortOrder: number;
  readonly active: boolean;
  /**
   * Overtime allowed free past a session's booked end when it ends on this type: within it only
   * the booked time is billed, past it the whole actual time. 0 = every overtime minute.
   */
  readonly overtimeGraceMinutes: number;
  /** Stations offering it (not disabled). */
  readonly stations: number;
}

/**
 * One price on the active rate card (the standard band: day/time changes are pricing rules).
 * `controllerCount` null = any number of players.
 */
export interface Rate {
  readonly activityCode: string;
  readonly controllerCount: number | null;
  readonly unitMinutes: number;
  readonly pricePaise: number;
}

/** A window in minutes from IST midnight. */
export interface DayWindow {
  readonly start: number;
  readonly end: number;
}

/** ISO weekday '1' (Mon) … '7' (Sun) → window, or null (closed). */
export type WeekWindows = Readonly<Record<string, DayWindow | null>>;

/** Opening hours per weekday (settings key business_hours). */
export interface BusinessHours {
  readonly open: WeekWindows;
}

/**
 * A day off the regular calendar (server: holidays). Pricing rules set to skip holidays don't
 * apply on it (and rules set to holidays only apply only on it); `closed` marks the arena shut
 * all day. Part of the price list, like the hours.
 */
export interface Holiday {
  /** The IST calendar date, "2026-11-08" (one holiday per day). */
  readonly day: string;
  readonly name: string;
  readonly closed: boolean;
}

export interface PricingData {
  readonly types: readonly StationType[];
  readonly rates: readonly Rate[];
  readonly hours: BusinessHours;
  /** Ordered by day. */
  readonly holidays: readonly Holiday[];
  /** The arena's billing rules (the server's defaults until it saves its own). */
  readonly policy: BillingPolicy;
  /** Day/time price rules, by priority. */
  readonly rules: readonly PricingRule[];
  /** Preset discounts and coupons. */
  readonly discounts: readonly Discount[];
  readonly discountOptions: DiscountOptions;
}

/** What the type dialog sends (activity.upsert). */
export interface TypeInput {
  readonly id: string;
  readonly code: string;
  readonly name: string;
  readonly usesControllers: boolean;
  readonly usesGames: boolean;
  readonly durationModel: DurationModel;
  readonly sortOrder: number;
  readonly active: boolean;
  /** Absent: the server keeps the saved grace (0 for a new type). */
  readonly overtimeGraceMinutes?: number;
}

/** A price to set (`pricePaise`) or remove (null) on the active card. */
export interface RateChange {
  readonly activityCode: string;
  readonly controllerCount: number | null;
  readonly unitMinutes: number;
  readonly pricePaise: number | null;
}

/** Physical pads per station: the engine prices 1–4 controllers. */
export const MAX_PADS = 4;

export const WEEKDAYS: readonly { readonly key: string; readonly short: string }[] = [
  { key: '1', short: 'Mon' },
  { key: '2', short: 'Tue' },
  { key: '3', short: 'Wed' },
  { key: '4', short: 'Thu' },
  { key: '5', short: 'Fri' },
  { key: '6', short: 'Sat' },
  { key: '7', short: 'Sun' },
];

export const BILLING_STYLES: readonly { readonly key: DurationModel; readonly label: string }[] = [
  { key: 'hourly', label: 'By the minute, hourly rate' },
  { key: 'unit', label: 'In fixed blocks (e.g. VR, a turf hour)' },
  { key: 'flat_hourly', label: 'Flat hourly, any group size' },
];

export function billingLabel(model: DurationModel): string {
  return BILLING_STYLES.find((b) => b.key === model)?.label ?? model;
}

export function typeIcon(
  t: Pick<StationType, 'usesControllers' | 'usesGames' | 'durationModel'>,
): string {
  if (t.usesControllers) return 'sports_esports';
  if (t.durationModel === 'unit') return t.usesGames ? 'view_in_ar' : 'stadium';
  if (t.durationModel === 'flat_hourly') return 'weekend';
  if (t.usesGames) return 'computer';
  return 'table_restaurant';
}

export function ratesFor(type: StationType, rates: readonly Rate[]): Rate[] {
  return rates.filter((r) => r.activityCode === type.code);
}

/** The rows a type is priced by: 1…4 controllers, or one "any number" row. */
export function rateRows(type: Pick<StationType, 'usesControllers'>): (number | null)[] {
  return type.usesControllers ? Array.from({ length: MAX_PADS }, (_, i) => i + 1) : [null];
}

export function findRate(
  rates: readonly Rate[],
  code: string,
  controllers: number | null,
): Rate | undefined {
  return rates.find((r) => r.activityCode === code && r.controllerCount === controllers);
}

/** Block length used by a type's rates (60 for hourly types). */
export function unitMinutesOf(type: StationType, rates: readonly Rate[]): number {
  return ratesFor(type, rates)[0]?.unitMinutes ?? (type.durationModel === 'unit' ? 30 : 60);
}

/** Most controllers with a price (players a station of this type takes). */
export function maxPlayers(type: StationType, rates: readonly Rate[]): number {
  if (!type.usesControllers) return 0;
  return Math.max(
    0,
    ...ratesFor(type, rates)
      .filter((r) => r.controllerCount != null)
      .map((r) => r.controllerCount as number),
  );
}

/** A type's cheapest rate (its headline price), or null when it has none. */
export function cheapestRate(type: StationType, rates: readonly Rate[]): Rate | null {
  const own = ratesFor(type, rates);
  return own.length ? own.reduce((a, b) => (b.pricePaise < a.pricePaise ? b : a)) : null;
}

/** The time a price is charged per is entered as hours and minutes (24 h = a day). */
/** Longest unit a price can be per: a week. */
export const MAX_UNIT_MINUTES = 7 * 1440;

/**
 * The way an owner would say a unit: 1440 → 1 day, 2160 → 1.5 days, 120 → 2 hours,
 * 90 → 1.5 hours, 45 → 45 minutes. Halves are used only above one (30 stays 30 minutes).
 */
export function splitUnit(minutes: number): {
  count: number;
  unit: 'minutes' | 'hours' | 'days';
} {
  if (minutes > 0 && (minutes % 1440 === 0 || (minutes > 1440 && minutes % 720 === 0))) {
    return { count: minutes / 1440, unit: 'days' };
  }
  if (minutes > 0 && (minutes % 60 === 0 || (minutes > 60 && minutes % 30 === 0))) {
    return { count: minutes / 60, unit: 'hours' };
  }
  return { count: minutes, unit: 'minutes' };
}

/**
 * Minutes for typed hours and minutes ("1" h "30" min → 90), or null unless both are whole
 * numbers from 0 (blank = 0) and the total is at least a minute.
 */
export function unitFromParts(hours: string, minutes: string): number | null {
  const part = (v: string) => (v.trim() === '' ? 0 : Number(v));
  const h = part(hours);
  const m = part(minutes);
  if (!Number.isInteger(h) || !Number.isInteger(m) || h < 0 || m < 0) return null;
  const total = h * 60 + m;
  return total >= 1 ? total : null;
}

/** "per hour", "per 30 min", "per 1.5 hours", "per day", "per 1.5 days". */
export function perLabel(unitMinutes: number): string {
  const { count, unit } = splitUnit(unitMinutes);
  if (unit === 'minutes') return `per ${count} min`;
  const one = unit === 'days' ? 'day' : 'hour';
  return count === 1 ? `per ${one}` : `per ${count} ${one}s`;
}

/** The list's headline price: the cheapest rate, per its block. */
export function headlinePrice(
  type: StationType,
  rates: readonly Rate[],
): { price: string; per: string } | null {
  const cheapest = cheapestRate(type, rates);
  return cheapest
    ? { price: formatRupees(cheapest.pricePaise), per: perLabel(cheapest.unitMinutes) }
    : null;
}

/** "2:00 pm" from minutes after IST midnight (1440 = midnight). */
export function formatMinuteOfDay(minutes: number): string {
  const m = minutes % 1440;
  const h = Math.floor(m / 60);
  const mm = m % 60;
  const h12 = h % 12 || 12;
  return `${h12}:${String(mm).padStart(2, '0')} ${h < 12 ? 'am' : 'pm'}`;
}

/** "14:00" for <input type="time">. */
export function toTimeInput(minutes: number): string {
  const m = minutes % 1440;
  return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
}

export function fromTimeInput(value: string): number | null {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value);
  if (!match) return null;
  const minutes = Number(match[1]) * 60 + Number(match[2]);
  return minutes >= 0 && minutes < 1440 ? minutes : null;
}

/** "Tue–Fri · 2:00–5:00 pm", grouping consecutive days with the same window. */
export function summarizeWindows(windows: WeekWindows): string {
  const parts: string[] = [];
  let i = 0;
  while (i < WEEKDAYS.length) {
    const w = windows[WEEKDAYS[i].key];
    if (!w) {
      i++;
      continue;
    }
    let j = i;
    while (j + 1 < WEEKDAYS.length) {
      const next = windows[WEEKDAYS[j + 1].key];
      if (!next || next.start !== w.start || next.end !== w.end) break;
      j++;
    }
    const days = i === j ? WEEKDAYS[i].short : `${WEEKDAYS[i].short}–${WEEKDAYS[j].short}`;
    parts.push(`${days} · ${formatMinuteOfDay(w.start)}–${formatMinuteOfDay(w.end)}`);
    i = j + 1;
  }
  return parts.join(', ');
}

const holidayDay = new Intl.DateTimeFormat('en-IN', {
  weekday: 'short',
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  timeZone: 'UTC',
});

/** "Sun, 8 Nov 2026" for a holiday's calendar date (already an IST date: no zone shift). */
export function formatHolidayDay(day: string): string {
  const parts = holidayDay.formatToParts(new Date(`${day}T00:00:00Z`));
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((p) => p.type === type)?.value ?? '';
  return `${part('weekday')}, ${part('day')} ${part('month')} ${part('year')}`;
}

/** A real calendar date written "YYYY-MM-DD". */
export function isCalendarDay(day: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) return false;
  const at = new Date(`${day}T00:00:00Z`);
  return !Number.isNaN(at.getTime()) && at.toISOString().slice(0, 10) === day;
}

/** A code suggestion from a name: "PlayStation 5" → "PLAYSTATION5" (12 max). */
export function suggestCode(name: string): string {
  return name
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '')
    .slice(0, 12);
}

/**
 * A day/time price rule (server: pricing_rules). Judged at a session's start (IST): the first
 * enabled rule by priority whose days, time window, holiday setting, dates and types match
 * changes every price of that session, for the whole session.
 */
export interface PricingRule {
  readonly id: string;
  readonly name: string;
  /** Lower comes first. */
  readonly priority: number;
  readonly active: boolean;
  /** ISO weekdays 1 (Mon) … 7 (Sun). */
  readonly days: readonly number[];
  /** Minutes after IST midnight; the window is [startMin, endMin). */
  readonly startMin: number;
  readonly endMin: number;
  readonly holidayMode: 'any' | 'only' | 'skip';
  /** IST dates "2026-11-01"; null = open-ended. */
  readonly validFrom: string | null;
  readonly validUntil: string | null;
  /** Station type codes; empty = every type. */
  readonly activityCodes: readonly string[];
  readonly adjustKind: 'percent' | 'per_hour';
  /** Signed: positive raises the price. Percent, or paise per hour. */
  readonly adjustValue: number;
}

/** A preset discount or a coupon (server: discounts). */
export interface Discount {
  readonly id: string;
  readonly kind: 'preset' | 'coupon';
  readonly name: string;
  readonly code: string | null;
  readonly valueKind: 'percent' | 'flat';
  /** Percent (1–100) or paise. */
  readonly value: number;
  readonly maxDiscountPaise: number | null;
  readonly minBillPaise: number | null;
  readonly activityCodes: readonly string[];
  /** Instants (UTC ISO); validUntil is a coupon's expiry. */
  readonly validFrom: string | null;
  readonly validUntil: string | null;
  readonly maxUses: number | null;
  readonly active: boolean;
}

/** How far staff may discount by hand (settings key discount_options). */
export interface DiscountOptions {
  /** Percent of the bill a staff member without Settings may take off; 0 = none. */
  readonly manualMaxPercent: number;
  readonly reasonRequired: boolean;
}

export const DEFAULT_DISCOUNT_OPTIONS: DiscountOptions = {
  manualMaxPercent: 0,
  reasonRequired: true,
};

/** One use of a discount on a bill (arena_discount_usage). */
export interface DiscountUse {
  readonly billId: string;
  readonly at: string;
  readonly customer: string | null;
  readonly billedPaise: number | null;
  readonly amountPaise: number;
  readonly status: string;
  readonly by: string | null;
}

export interface DiscountUsage {
  readonly uses: number;
  /** Uses on bills that were not voided (what counts toward the limit). */
  readonly activeUses: number;
  readonly rows: readonly DiscountUse[];
  /** Pass back for the next page; null at the end. */
  readonly next: string | null;
}

/** The pricing rule's effect on one price, as _pr_rule_price works it out (paise, ≥ 0). */
export function rulePrice(
  pricePaise: number,
  unitMinutes: number,
  rule: Pick<PricingRule, 'adjustKind' | 'adjustValue'>,
): number {
  if (rule.adjustKind === 'percent') {
    // Round half up (the server's _pr_div), never below 0.
    return Math.max(0, Math.floor((2 * pricePaise * (100 + rule.adjustValue) + 100) / 200));
  }
  return Math.max(0, pricePaise + Math.floor((2 * rule.adjustValue * unitMinutes + 60) / 120));
}

/** How a rule changes the price, in owner words: "Percent", "Flat ₹ per hour". */
export const ADJUST_KINDS: readonly {
  readonly key: PricingRule['adjustKind'];
  readonly label: string;
}[] = [
  { key: 'percent', label: 'Percent' },
  { key: 'per_hour', label: 'Flat ₹ per hour' },
];

export function adjustKindLabel(kind: PricingRule['adjustKind']): string {
  return ADJUST_KINDS.find((k) => k.key === kind)?.label ?? kind;
}

/** "20% higher", "20% lower", "₹30/hr lower", "No change". */
export function adjustLabel(rule: Pick<PricingRule, 'adjustKind' | 'adjustValue'>): string {
  if (rule.adjustValue === 0) return 'No change';
  const abs = Math.abs(rule.adjustValue);
  // A flat change may carry paise (₹12.50/hr): show them rather than round.
  const rupees =
    abs % 100 === 0
      ? formatRupees(abs)
      : `₹${(abs / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}`;
  const amount = rule.adjustKind === 'percent' ? `${abs}%` : `${rupees}/hr`;
  return `${amount} ${rule.adjustValue > 0 ? 'higher' : 'lower'}`;
}

/** "Sat–Sun · 6:00–11:00 pm" for a rule's days and window. */
export function ruleWhen(rule: Pick<PricingRule, 'days' | 'startMin' | 'endMin'>): string {
  const keys = new Set(rule.days.map(String));
  const windows: Record<string, DayWindow | null> = {};
  for (const d of WEEKDAYS) {
    windows[d.key] = keys.has(d.key) ? { start: rule.startMin, end: rule.endMin } : null;
  }
  return summarizeWindows(windows);
}

/** "20% off", "₹50 off". */
export function discountValueLabel(d: Pick<Discount, 'valueKind' | 'value'>): string {
  return d.valueKind === 'percent' ? `${d.value}% off` : `${formatRupees(d.value)} off`;
}

export type CouponState = 'active' | 'scheduled' | 'expired' | 'used_up' | 'off';

/** Where a preset or coupon stands at `now` (use counts come from its usage read). */
export function discountState(d: Discount, now: Date, activeUses?: number): CouponState {
  if (!d.active) return 'off';
  if (d.validUntil && Date.parse(d.validUntil) < now.getTime()) return 'expired';
  if (d.validFrom && Date.parse(d.validFrom) > now.getTime()) return 'scheduled';
  if (d.maxUses != null && activeUses != null && activeUses >= d.maxUses) return 'used_up';
  return 'active';
}
