import { PillTone } from '../../../shared/status-pill/status-pill';
import { formatRupees } from '../../../shared/money/rupees.pipe';
import {
  addDays,
  daysBetween,
  formatIsoDate,
  istDayStart,
  istDayStartOf,
} from '../../../shared/time/ist';

export type PayMethod = 'cash' | 'upi' | 'card' | 'other';
export type PaymentStatus = 'unpaid' | 'partial' | 'paid' | 'waived';

export const PAY_METHODS: readonly PayMethod[] = ['cash', 'upi', 'card', 'other'];

/** One row of a bill's payments ledger (append-only; a refund is a negative row). */
export interface BillPayment {
  readonly id: string;
  /** When the server recorded it (a payment taken offline carries the time it synced). */
  readonly at: string;
  /** Refunds are negative. */
  readonly amountPaise: number;
  readonly method: PayMethod;
  readonly refund: boolean;
  /**
   * One of the two rows a method correction wrote (a refund on the wrong method, a payment on
   * the right one): not money in or out, and not counted as a refund.
   */
  readonly correction: boolean;
  readonly reason: string | null;
  readonly note: string | null;
  readonly by: string | null;
}

/** A closed bill (arena_sales): one session, completed or voided. */
export interface Bill {
  readonly id: string;
  /** Short display reference (`S-3F9A2C`); bills have no invoice number yet. */
  readonly ref: string;
  /** When it closed (ended, or voided while it ran). UTC ISO. */
  readonly at: string;
  readonly startedAt: string;
  readonly endedAt: string | null;
  /** When the server received the start (the device stamps `startedAt`). */
  readonly recordedAt: string | null;
  /** When the server received the end (the device stamps `endedAt`); null before it was kept. */
  readonly endRecordedAt: string | null;
  readonly voided: boolean;
  readonly paymentStatus: PaymentStatus;
  readonly customer: string;
  readonly guest: boolean;
  /** The customer (never a walk-in) has an earlier completed bill in this arena. */
  readonly returning: boolean;
  readonly stations: readonly string[];
  readonly activities: readonly string[];
  readonly games: readonly string[];
  /** Its largest controller count (1 without controllers). */
  readonly players: number;
  /** Time played × the players on it. */
  readonly playerMinutes: number;
  /** The final bill after cash rounding; null for a bill voided before it ended. */
  readonly billedPaise: number | null;
  /** Net collected (payments minus refunds). */
  readonly paidPaise: number;
  /** Money given back (refunds; a method correction's rows are not refunds). */
  readonly refundedPaise: number;
  /** Net collected per payment method. */
  readonly methods: Readonly<Partial<Record<PayMethod, number>>>;
  /** The payments ledger in time order (a correction's refund before its payment). */
  readonly payments: readonly BillPayment[];
  readonly startedBy: string | null;
  readonly voidReason: string | null;
  readonly voidedAt: string | null;
  readonly voidedBy: string | null;
  /** Taken off the subtotal before cash rounding (0 without a discount). */
  readonly discountPaise: number;
  /** The preset, coupon or manual discount applied, as it was then; null without one. */
  readonly discount: BillDiscount | null;
}

/** A discount on a bill (bill_discounts): a copy of what was applied, who and why. */
export interface BillDiscount {
  readonly source: 'preset' | 'coupon' | 'manual';
  readonly name: string;
  readonly code: string | null;
  readonly discountId: string | null;
  readonly valueKind: 'percent' | 'flat';
  readonly value: number;
  readonly amountPaise: number;
  readonly reason: string | null;
  readonly by: string | null;
}

/** "Coupon DIWALI20 · 20%", "Student · ₹50 off", "Manual · 10%". */
export function discountLabel(d: BillDiscount): string {
  const value = d.valueKind === 'percent' ? `${d.value}%` : `${formatRupees(d.value)} off`;
  const what =
    d.source === 'coupon'
      ? `Coupon ${d.code ?? d.name}`
      : d.source === 'manual'
        ? 'Manual'
        : d.name;
  return `${what} · ${value}`;
}

export interface BillLine {
  readonly station: string;
  readonly activity: string;
  readonly controllers: number | null;
  readonly start: string | null;
  readonly end: string | null;
  readonly playedMinutes: number;
  readonly billedMinutes: number;
  readonly amountPaise: number;
}

export interface BillExtension {
  readonly at: string;
  readonly addedMinutes: number;
  readonly addedPaise: number;
  readonly reason: string | null;
  readonly by: string | null;
}

/** One audit_log entry of the bill: a void, a waive or a payment-method correction. */
export interface BillHistoryEntry {
  readonly at: string;
  readonly action: string;
  readonly by: string | null;
  readonly reason: string | null;
  readonly before: Readonly<Record<string, unknown>> | null;
  readonly after: Readonly<Record<string, unknown>> | null;
}

/** A bill in full (arena_sale). */
export interface BillDetail extends Bill {
  readonly lines: readonly BillLine[];
  readonly extensions: readonly BillExtension[];
  readonly history: readonly BillHistoryEntry[];
  readonly voidRecord: { readonly at: string; readonly by: string | null } | null;
  /** The time rule the bill was priced with (judged at its start); null without one. */
  readonly rule: {
    readonly name: string;
    readonly adjustKind: 'percent' | 'per_hour';
    readonly adjustValue: number;
  } | null;
}

export type SalesPreset = 'today' | 'yesterday' | '7d' | '30d';
export type SalesRange = SalesPreset | 'custom';

export const SALES_RANGES: readonly { readonly key: SalesRange; readonly label: string }[] = [
  { key: 'today', label: 'Today' },
  { key: 'yesterday', label: 'Yesterday' },
  { key: '7d', label: '7 days' },
  { key: '30d', label: '30 days' },
  { key: 'custom', label: 'Dates…' },
];

/** The server lists at most 93 days at once (arena_sales). */
export const MAX_PERIOD_DAYS = 93;

/**
 * The days a report covers: IST calendar days `first`…`last`, inclusive ("2026-10-01"). A bill
 * belongs to the day it closed.
 */
export interface SalesPeriod {
  readonly range: SalesRange;
  readonly first: string;
  readonly last: string;
}

/** The design's method chips (Card and Other bills are still listed and totalled). */
export const METHOD_FILTERS: readonly { readonly key: PayMethod; readonly label: string }[] = [
  { key: 'upi', label: 'UPI' },
  { key: 'cash', label: 'Cash' },
];

export const VOID_REASONS = [
  'Wrong amount',
  'Wrong station',
  'Duplicate bill',
  'Refund to customer',
] as const;

const METHOD_LABELS: Readonly<Record<PayMethod, string>> = {
  upi: 'UPI',
  cash: 'Cash',
  card: 'Card',
  other: 'Other',
};

export function methodName(method: PayMethod | string): string {
  return METHOD_LABELS[method as PayMethod] ?? method;
}

export function asRange(value: string | undefined): SalesRange {
  return SALES_RANGES.some((r) => r.key === value) ? (value as SalesRange) : 'today';
}

export function asMethod(value: string | undefined): PayMethod | null {
  return METHOD_FILTERS.some((m) => m.key === value) ? (value as PayMethod) : null;
}

/** Why `first`…`last` cannot be a report period, or null when it can. */
export function periodProblem(first: string, last: string): string | null {
  const span = daysBetween(first, last);
  if (Number.isNaN(span)) return 'Pick both dates';
  if (span < 0) return 'The first day is after the last';
  if (span + 1 > MAX_PERIOD_DAYS) return `Pick at most ${MAX_PERIOD_DAYS} days`;
  return null;
}

/**
 * The period a URL asks for: a preset relative to `now`, or `?range=custom&from=…&to=…` (any
 * IST days, at most 93). A custom period that is not valid falls back to today.
 */
export function periodFor(
  range: string | undefined,
  from: string | undefined,
  to: string | undefined,
  now: Date,
): SalesPeriod {
  const today = formatIsoDate(istDayStart(now));
  const key = asRange(range);
  switch (key) {
    case 'yesterday': {
      const day = addDays(today, -1);
      return { range: key, first: day, last: day };
    }
    case '7d':
      return { range: key, first: addDays(today, -6), last: today };
    case '30d':
      return { range: key, first: addDays(today, -29), last: today };
    case 'custom':
      if (from && to && !periodProblem(from, to)) return { range: key, first: from, last: to };
      return { range: 'today', first: today, last: today };
    default:
      return { range: 'today', first: today, last: today };
  }
}

/** [from, to) instants of a period: IST midnight of its first day to the midnight after its last. */
export function periodBounds(period: SalesPeriod): { from: Date; to: Date } {
  return {
    from: istDayStartOf(period.first) as Date,
    to: istDayStartOf(addDays(period.last, 1)) as Date,
  };
}

/** [from, to) of a preset range in IST calendar days. */
export function rangeBounds(range: SalesPreset, now: Date): { from: Date; to: Date } {
  return periodBounds(periodFor(range, undefined, undefined, now));
}

export function billRef(id: string): string {
  return 'S-' + id.replace(/-/g, '').slice(0, 6).toUpperCase();
}

export function playedMinutes(bill: Bill): number {
  const end = bill.endedAt ?? bill.at;
  return Math.max(0, Math.round((Date.parse(end) - Date.parse(bill.startedAt)) / 60_000));
}

/** Methods money was collected by (net above zero), largest first. */
export function paidMethods(bill: Bill): PayMethod[] {
  return (Object.entries(bill.methods) as [PayMethod, number][])
    .filter(([, net]) => net > 0)
    .sort((a, b) => b[1] - a[1])
    .map(([m]) => m);
}

/** Still owed on a live bill (0 when paid, waived or voided). */
export function duePaise(bill: Bill): number {
  if (bill.voided || bill.paymentStatus === 'waived') return 0;
  return Math.max(0, (bill.billedPaise ?? 0) - bill.paidPaise);
}

/** What a waive wrote off: the bill minus what was collected on it (0 unless waived). */
export function writtenOffPaise(bill: Bill): number {
  if (bill.voided || bill.paymentStatus !== 'waived') return 0;
  return Math.max(0, (bill.billedPaise ?? 0) - bill.paidPaise);
}

/** Customer type as the spreadsheet records it: walk-in, new or returning. */
export function customerType(bill: Bill): 'Walk-in' | 'Returning' | 'New' {
  if (bill.guest) return 'Walk-in';
  return bill.returning ? 'Returning' : 'New';
}

/** The bill's state in a list row / detail chip: void, waived, unpaid, part paid, or how it was paid. */
export function billState(bill: Bill): { label: string; tone: PillTone | null } {
  if (bill.voided) return { label: 'Void', tone: 'danger' };
  if (bill.paymentStatus === 'waived') return { label: 'Waived', tone: 'info' };
  if (bill.paymentStatus === 'unpaid') return { label: 'Unpaid', tone: 'warning' };
  if (bill.paymentStatus === 'partial') return { label: 'Part paid', tone: 'warning' };
  const methods = paidMethods(bill);
  return { label: methods.length === 1 ? methodName(methods[0]) : 'Split', tone: null };
}

/** Payment-ledger notes the server writes for these changes (op_session_record, op_bill_adjust). */
export const ADDED_LATER_NOTE = 'Added later';
export const BILL_EDITED_NOTE = 'Bill edited';

export interface BillFlag {
  readonly label: string;
  readonly tone: PillTone;
}

/**
 * What happened to a bill beyond its state, for tags in the list and the detail: added later as
 * a missed bill, total edited, end set earlier by staff, discounted, money refunded. `history` (the full bill) also catches
 * an edit that moved no money.
 */
export function billFlags(bill: Bill, history: readonly BillHistoryEntry[] = []): BillFlag[] {
  const notes = new Set(bill.payments.map((p) => p.note));
  const out: BillFlag[] = [];
  if (notes.has(ADDED_LATER_NOTE)) out.push({ label: 'Added later', tone: 'info' });
  if (notes.has(BILL_EDITED_NOTE) || history.some((h) => h.action === 'bill_adjust')) {
    out.push({ label: 'Edited', tone: 'warning' });
  }
  if (history.some((h) => h.action === 'end_moved'))
    out.push({ label: 'End moved', tone: 'warning' });
  if (bill.discountPaise > 0) out.push({ label: 'Discount', tone: 'success' });
  if (bill.refundedPaise > 0) out.push({ label: 'Refunded', tone: 'danger' });
  return out;
}

export interface SalesSummary {
  /** Bills that count: not voided. */
  readonly count: number;
  /** Σ final bill of the bills that count (waived ones included). */
  readonly expectedPaise: number;
  /** Net collected (payments − refunds) on the bills that count, whenever it was received. */
  readonly takingsPaise: number;
  /** Net per method on the bills that count; adds up to the takings. */
  readonly byMethod: Readonly<Record<PayMethod, number>>;
  /** Outstanding: still owed on bills not waived and not voided. */
  readonly duePaise: number;
  /** What waives wrote off. */
  readonly writtenOffPaise: number;
  /** Collected beyond the bill (refund it, or it stays as credit). */
  readonly overpaidPaise: number;
  /** Refunds on the bills that count (already taken out of the takings). */
  readonly refundedPaise: number;
  readonly voidedCount: number;
  /**
   * Net collected on voided bills: left out of the takings (a voided bill does not count) but
   * in the till until refunded, since voiding never refunds. Shown apart so the day reconciles.
   */
  readonly voidedPaidPaise: number;
}

/**
 * Voided bills drop out; everything else counts. For the bills that count:
 * expected + overpaid = collected + outstanding + written off.
 */
export function summarize(bills: readonly Bill[]): SalesSummary {
  const byMethod: Record<PayMethod, number> = { upi: 0, cash: 0, card: 0, other: 0 };
  let count = 0;
  let expected = 0;
  let takings = 0;
  let due = 0;
  let writtenOff = 0;
  let overpaid = 0;
  let refunded = 0;
  let voidedCount = 0;
  let voidedPaid = 0;
  for (const b of bills) {
    if (b.voided) {
      voidedCount++;
      voidedPaid += b.paidPaise;
      continue;
    }
    count++;
    expected += b.billedPaise ?? 0;
    takings += b.paidPaise;
    refunded += b.refundedPaise;
    due += duePaise(b);
    writtenOff += writtenOffPaise(b);
    overpaid += Math.max(0, b.paidPaise - (b.billedPaise ?? 0));
    for (const [m, net] of Object.entries(b.methods) as [PayMethod, number][]) byMethod[m] += net;
  }
  return {
    count,
    expectedPaise: expected,
    takingsPaise: takings,
    byMethod,
    duePaise: due,
    writtenOffPaise: writtenOff,
    overpaidPaise: overpaid,
    refundedPaise: refunded,
    voidedCount,
    voidedPaidPaise: voidedPaid,
  };
}

/**
 * The line under the totals: "26 bills · UPI ₹30,800 · Cash ₹17,320" (+ Card / Other / Refunded /
 * Written off / Overpaid / voided when present). With a method chip on, it says the bills are the
 * ones paid that way and leads with that method's money.
 */
export function summaryLine(s: SalesSummary, method: PayMethod | null = null): string {
  const bills = `${s.count} bill${s.count === 1 ? '' : 's'}`;
  const parts = method
    ? [
        `${bills} paid by ${methodName(method)}`,
        `${methodName(method)} ${formatRupees(s.byMethod[method])}`,
      ]
    : [bills];
  for (const m of ['upi', 'cash', 'card', 'other'] as const) {
    if (m === method) continue;
    if (m === 'upi' || m === 'cash' || s.byMethod[m]) {
      parts.push(`${methodName(m)} ${formatRupees(s.byMethod[m])}`);
    }
  }
  if (s.refundedPaise) parts.push(`Refunded ${formatRupees(s.refundedPaise)}`);
  if (s.writtenOffPaise) parts.push(`Written off ${formatRupees(s.writtenOffPaise)}`);
  if (s.overpaidPaise) parts.push(`Overpaid ${formatRupees(s.overpaidPaise)}`);
  if (s.voidedPaidPaise) parts.push(`${formatRupees(s.voidedPaidPaise)} on voided bills`);
  return parts.join(' · ');
}

export function matchesSearch(bill: Bill, query: string): boolean {
  const q = query.trim().toLowerCase();
  if (!q) return true;
  return [bill.ref, bill.customer, bill.startedBy ?? '', ...bill.stations, ...bill.games].some(
    (x) => x.toLowerCase().includes(q),
  );
}

/**
 * Display numbers per business day ("No." in the export): each day's bills in start order,
 * 1, 2, 3… Bills keep their id as the stable reference; a bill synced late from an offline
 * device can move the numbers after it.
 */
export function dayNumbers(bills: readonly Bill[]): ReadonlyMap<string, number> {
  const byDay = new Map<string, Bill[]>();
  for (const b of bills) {
    const day = formatIsoDate(b.at);
    byDay.set(day, [...(byDay.get(day) ?? []), b]);
  }
  const out = new Map<string, number>();
  for (const day of byDay.values()) {
    day
      .sort((a, b) => Date.parse(a.startedAt) - Date.parse(b.startedAt) || a.id.localeCompare(b.id))
      .forEach((b, i) => out.set(b.id, i + 1));
  }
  return out;
}

/**
 * Rupees typed by a person → integer paise, exactly (no floating point): "120", "120.5",
 * "1,200.50". Null when it is not a positive amount with at most two decimals.
 */
export function parseRupees(text: string): number | null {
  const m = /^(\d{1,7})(?:\.(\d{1,2}))?$/.exec(text.trim().replace(/[,₹\s]/g, ''));
  if (!m) return null;
  const paise = Number(m[1]) * 100 + Number((m[2] ?? '').padEnd(2, '0'));
  return paise > 0 ? paise : null;
}

/** Paise as the shortest rupee text that parses back: 12000 → "120", 12050 → "120.50". */
export function rupeesText(paise: number): string {
  return paise % 100 === 0 ? String(paise / 100) : (paise / 100).toFixed(2);
}
