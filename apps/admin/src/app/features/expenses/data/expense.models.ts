import { formatPaise, formatRupees } from '../../../shared/money/rupees.pipe';
import {
  formatDay,
  formatDayYear,
  formatRange,
  isoWeekday,
  rangesOverlap,
} from '../../../shared/staff/staff-format';
import { PillTone } from '../../../shared/status-pill/status-pill';
import { addDays, daysBetween, istDayStartOf } from '../../../shared/time/ist';

/** A running cost (`general`, in a category) or a staff member's pay for a period (`salary`). */
export type ExpenseKind = 'general' | 'salary';
export type ExpenseMethod = 'cash' | 'upi' | 'bank' | 'card' | 'other';
/** Whose money paid: the arena's account, or an owner's own (an owner contribution). */
export type PaidFrom = 'company' | 'personal';
export type ExpensePaymentStatus = 'unpaid' | 'partial' | 'paid';
export type SalaryPeriod = 'monthly' | 'weekly';

export const EXPENSE_METHODS: readonly ExpenseMethod[] = ['cash', 'upi', 'bank', 'card', 'other'];

const METHOD_LABELS: Readonly<Record<ExpenseMethod, string>> = {
  cash: 'Cash',
  upi: 'UPI',
  bank: 'Bank transfer',
  card: 'Card',
  other: 'Other',
};

export function expenseMethodName(method: string): string {
  return METHOD_LABELS[method as ExpenseMethod] ?? method;
}

/** "₹2,300", "₹2,345.50", "−₹15,000": rupees, with paise only when there are some. */
export function formatAmount(paise: number): string {
  const p = Math.round(paise);
  if (p % 100 !== 0) return formatPaise(p);
  return `${p < 0 ? '−' : ''}${formatRupees(Math.abs(p))}`;
}

/** The server's limits (op_expense_*), checked in the forms before sending. */
export const MAX_TITLE = 80;
export const MAX_NOTES = 1000;
export const MAX_PAYMENT_NOTE = 200;
export const MAX_REASON = 500;
export const MAX_CATEGORY_NAME = 40;
export const MAX_SALARY_NOTE = 200;
/** A salary period covers at most this many days (62). */
export const MAX_SALARY_SPAN = 61;

/** One row of an expense's payments (append-only; a reversal is a negative row). */
export interface ExpensePayment {
  readonly id: string;
  readonly kind: 'payment' | 'reversal';
  /** A reversal is negative. */
  readonly amountPaise: number;
  readonly method: ExpenseMethod;
  /** IST day the money went out; a reversal keeps the day of the payment it undoes. */
  readonly paidOn: string;
  readonly paidFrom: PaidFrom;
  /** The owner whose own money it was (personal only). */
  readonly payerStaffId: string | null;
  readonly payerName: string | null;
  /** The reason, on a reversal. */
  readonly note: string | null;
  /** The payment a reversal undoes. */
  readonly reversesId: string | null;
  /** A payment that was reversed. */
  readonly reversed: boolean;
  readonly by: string | null;
  /** When the server recorded it. */
  readonly at: string;
}

/** What the arena owes for something (arena_expenses / arena_expense). */
export interface Expense {
  readonly id: string;
  readonly kind: ExpenseKind;
  readonly title: string;
  readonly categoryId: string | null;
  readonly categoryName: string | null;
  /** The person paid (a salary), or the one a cost was for. */
  readonly staffId: string | null;
  readonly staffName: string | null;
  /** A salary's first and last day (IST); null on a cost. */
  readonly periodStart: string | null;
  readonly periodEnd: string | null;
  readonly amountPaise: number;
  /** Net paid (payments minus reversals), whatever the source. */
  readonly paidPaise: number;
  readonly paidCompanyPaise: number;
  readonly paidPersonalPaise: number;
  /** Still owed (0 once paid, and on a voided expense). */
  readonly balancePaise: number;
  readonly paymentStatus: ExpensePaymentStatus;
  readonly voided: boolean;
  readonly voidReason: string | null;
  /** The day it belongs to (a salary: its period's last day). */
  readonly expenseDate: string;
  readonly notes: string | null;
  readonly createdByName: string | null;
  readonly createdAt: string;
  /** In the order they were recorded. */
  readonly payments: readonly ExpensePayment[];
}

/** One audit entry of an expense: add, update, payment_reverse or void. */
export interface ExpenseHistoryEntry {
  readonly at: string;
  readonly action: string;
  readonly by: string | null;
  readonly reason: string | null;
  readonly before: Readonly<Record<string, unknown>> | null;
  readonly after: Readonly<Record<string, unknown>> | null;
}

export interface ExpenseDetail extends Expense {
  readonly history: readonly ExpenseHistoryEntry[];
}

/** A payment or reversal dated in a period, with its expense (arena_expenses `payments`). */
export interface PaymentLine {
  readonly id: string;
  readonly expenseId: string;
  readonly expenseTitle: string;
  readonly expenseKind: ExpenseKind;
  readonly expenseVoided: boolean;
  readonly categoryName: string | null;
  readonly staffId: string | null;
  readonly staffName: string | null;
  readonly kind: 'payment' | 'reversal';
  readonly amountPaise: number;
  readonly method: ExpenseMethod;
  readonly paidOn: string;
  readonly paidFrom: PaidFrom;
  readonly payerStaffId: string | null;
  readonly payerName: string | null;
  readonly note: string | null;
  readonly reversesId: string | null;
}

/** A period's expenses (by expense date) and money paid out (by payment date). */
export interface ExpensesData {
  readonly expenses: readonly Expense[];
  readonly payments: readonly PaymentLine[];
  /** Still owed on every active expense, whatever its date. */
  readonly owedTotalPaise: number;
  readonly owedCount: number;
}

export interface ExpenseCategory {
  readonly id: string;
  readonly name: string;
  readonly sortOrder: number;
  /** Off: kept for the expenses already in it, offered for no new one. */
  readonly active: boolean;
}

/** An agreed salary from a day on (a raise is a new row). */
export interface StaffSalary {
  readonly id: string;
  readonly staffId: string;
  readonly effectiveFrom: string;
  readonly period: SalaryPeriod;
  readonly amountPaise: number;
  readonly note: string | null;
}

/** One person's agreed salaries (newest first) and salary periods (arena_staff_salary). */
export interface StaffSalaryRecord {
  readonly staffId: string;
  readonly name: string;
  readonly removed: boolean;
  readonly salaries: readonly StaffSalary[];
  readonly periods: readonly Expense[];
}

// ---------------------------------------------------------------------------------- periods

export type ExpenseRange = 'today' | 'week' | 'month' | 'prev_month' | 'year' | 'custom';

export const EXPENSE_RANGES: readonly { readonly key: ExpenseRange; readonly label: string }[] = [
  { key: 'today', label: 'Today' },
  { key: 'week', label: 'This week' },
  { key: 'month', label: 'This month' },
  { key: 'prev_month', label: 'Previous month' },
  { key: 'year', label: 'This year' },
  { key: 'custom', label: 'Dates…' },
];

/** Without `?range=`: this month, so a salary dated the month's last day is in it. */
export const DEFAULT_RANGE: ExpenseRange = 'month';

/** The server lists at most 400 days at once (arena_expenses). */
export const MAX_RANGE_DAYS = 400;

/** IST calendar days `first`…`last`, inclusive ("2026-10-01"). */
export interface ExpensePeriod {
  readonly range: ExpenseRange;
  readonly first: string;
  readonly last: string;
}

export function asExpenseRange(value: string | undefined): ExpenseRange {
  return EXPENSE_RANGES.some((r) => r.key === value) ? (value as ExpenseRange) : DEFAULT_RANGE;
}

/** Why `first`…`last` cannot be a report period, or null when it can. */
export function rangeProblem(first: string, last: string): string | null {
  const span = daysBetween(first, last);
  if (Number.isNaN(span)) return 'Pick both dates';
  if (span < 0) return 'The first day is after the last';
  if (span + 1 > MAX_RANGE_DAYS) return `Pick at most ${MAX_RANGE_DAYS} days`;
  return null;
}

/** The first day of the month `n` months after the month of `day` (`n` may be negative). */
export function addMonths(day: string, n: number): string {
  const months = Number(day.slice(0, 4)) * 12 + Number(day.slice(5, 7)) - 1 + n;
  const year = Math.floor(months / 12);
  return `${year}-${String((months % 12) + 1).padStart(2, '0')}-01`;
}

/** The calendar month of an IST day. */
export function monthOf(day: string): { first: string; last: string } {
  const first = `${day.slice(0, 7)}-01`;
  return { first, last: addDays(addMonths(first, 1), -1) };
}

/** The Monday–Sunday week of an IST day. */
export function weekOf(day: string): { first: string; last: string } {
  const first = addDays(day, 1 - isoWeekday(day));
  return { first, last: addDays(first, 6) };
}

/**
 * The period a URL asks for: a preset around `today` (an IST day), or
 * `?range=custom&from=…&to=…` (at most 400 days). Months, weeks and the year are whole, so
 * what falls due later in them (rent on the 30th, the month's salary) is counted too. A custom
 * period that is not valid falls back to this month.
 */
export function expensePeriodFor(
  range: string | undefined,
  from: string | undefined,
  to: string | undefined,
  today: string,
): ExpensePeriod {
  const key = asExpenseRange(range);
  switch (key) {
    case 'today':
      return { range: key, first: today, last: today };
    case 'week':
      return { range: key, ...weekOf(today) };
    case 'prev_month':
      return { range: key, ...monthOf(addMonths(today, -1)) };
    case 'year':
      return {
        range: key,
        first: `${today.slice(0, 4)}-01-01`,
        last: `${today.slice(0, 4)}-12-31`,
      };
    case 'custom':
      if (from && to && !rangeProblem(from, to)) return { range: key, first: from, last: to };
      return { range: DEFAULT_RANGE, ...monthOf(today) };
    default:
      return { range: 'month', ...monthOf(today) };
  }
}

const monthName = new Intl.DateTimeFormat('en-IN', {
  month: 'long',
  year: 'numeric',
  timeZone: 'Asia/Kolkata',
});
const monthShort = new Intl.DateTimeFormat('en-IN', {
  month: 'short',
  year: 'numeric',
  timeZone: 'Asia/Kolkata',
});
const monthOnly = new Intl.DateTimeFormat('en-IN', { month: 'short', timeZone: 'Asia/Kolkata' });

/** "October 2026" for any day of that month. */
export function formatMonth(day: string): string {
  const d = istDayStartOf(day);
  return d ? monthName.format(d) : day;
}

/** "Oct 2026". */
export function formatMonthShort(day: string): string {
  const d = istDayStartOf(day);
  return d ? monthShort.format(d) : day;
}

/** "Oct" (chart labels). */
export function formatMonthOnly(day: string): string {
  const d = istDayStartOf(day);
  return d ? monthOnly.format(d) : day;
}

/** The period in words: "October 2026", "2026", "26 Oct – 1 Nov 2026". */
export function periodLabel(p: ExpensePeriod): string {
  if (p.range === 'month' || p.range === 'prev_month') return formatMonth(p.first);
  if (p.range === 'year') return p.first.slice(0, 4);
  return formatRange(p.first, p.last);
}

/** "October 2026" for a calendar month, "Week 5–11 Oct 2026" for Mon–Sun, else the dates. */
export function salaryPeriodName(first: string, last: string): string {
  if (first.endsWith('-01') && monthOf(first).last === last) return formatMonth(first);
  if (isoWeekday(first) === 1 && daysBetween(first, last) === 6) {
    return `Week ${formatRange(first, last)}`;
  }
  return formatRange(first, last);
}

// ------------------------------------------------------------------------------- display

/** The expense's state in a list row and its detail: void, unpaid, part paid or paid. */
export function expenseState(e: Expense): { label: string; tone: PillTone } {
  if (e.voided) return { label: 'Void', tone: 'danger' };
  if (e.paymentStatus === 'paid') return { label: 'Paid', tone: 'success' };
  if (e.paymentStatus === 'partial') return { label: 'Part paid', tone: 'warning' };
  return { label: 'Unpaid', tone: 'warning' };
}

/** "Company" or "Personal · Arjun Mehra". */
export function sourceLabel(p: { paidFrom: PaidFrom; payerName: string | null }): string {
  return p.paidFrom === 'company' ? 'Company' : `Personal · ${p.payerName ?? 'an owner'}`;
}

/** A salary paid before its period ended (shown as an advance; it is an ordinary payment). */
export function isAdvance(e: Expense, p: ExpensePayment): boolean {
  return e.kind === 'salary' && p.kind === 'payment' && !!e.periodEnd && p.paidOn < e.periodEnd;
}

/** A new salary period's title: "Ravi Kumar salary, October 2026" (at most 80 characters). */
export function salaryTitle(name: string, first: string, last: string): string {
  const period = salaryPeriodName(first, last);
  const title = `${name} salary, ${period}`;
  return title.length <= MAX_TITLE
    ? title
    : `${name.slice(0, MAX_TITLE - period.length - 10)}… salary, ${period}`;
}

/**
 * The list row's second line: "Electricity · 5 Oct", or "Salary" with whatever of the person and
 * period the title does not already say.
 */
export function expenseSubtitle(e: Expense): string {
  if (e.kind === 'salary') {
    const period = e.periodStart && e.periodEnd ? salaryPeriodName(e.periodStart, e.periodEnd) : '';
    const unsaid = (part: string | null) => (part && !e.title.includes(part) ? part : null);
    return ['Salary', unsaid(e.staffName), unsaid(period)].filter(Boolean).join(' · ');
  }
  return [e.categoryName, e.staffName, formatDay(e.expenseDate)].filter(Boolean).join(' · ');
}

/** When it belongs: "5 Oct 2026", or a salary's period. */
export function expenseWhen(e: Expense): string {
  if (e.kind === 'salary' && e.periodStart && e.periodEnd) {
    return salaryPeriodName(e.periodStart, e.periodEnd);
  }
  return formatDayYear(e.expenseDate);
}

const CATEGORY_ICONS: Readonly<Record<string, string>> = {
  rent: 'apartment',
  electricity: 'bolt',
  internet: 'wifi',
  water: 'water_drop',
  repairs: 'build',
  maintenance: 'handyman',
  equipment: 'sports_esports',
  cleaning: 'cleaning_services',
  supplies: 'inventory_2',
};

/** Material Symbols name for a category (by its standard name) or a salary. */
export function expenseIcon(e: { kind: ExpenseKind; categoryName: string | null }): string {
  if (e.kind === 'salary') return 'badge';
  return CATEGORY_ICONS[(e.categoryName ?? '').trim().toLowerCase()] ?? 'receipt';
}

export function categoryIcon(name: string): string {
  return CATEGORY_ICONS[name.trim().toLowerCase()] ?? 'receipt';
}

/** The standard names (expense_category_catalog) the arena has no category for yet. */
export function missingStandard(
  catalog: readonly string[],
  existing: readonly ExpenseCategory[],
): string[] {
  const have = new Set(existing.map((c) => c.name.trim().toLowerCase()));
  return catalog.filter((name) => !have.has(name.toLowerCase()));
}

/** Where a new category goes: after the last one. */
export function nextSortOrder(existing: readonly ExpenseCategory[]): number {
  return existing.reduce((n, c) => Math.max(n, c.sortOrder + 1), 0);
}

export const EXPENSE_VOID_REASONS: readonly string[] = [
  'Entered twice',
  'Wrong amount or details',
  'Not an expense of this arena',
];

// -------------------------------------------------------------------------------- filters

export type StatusFilter = 'unpaid' | 'partial' | 'paid' | 'voided';

export const STATUS_FILTERS: readonly { readonly key: StatusFilter; readonly label: string }[] = [
  { key: 'unpaid', label: 'Unpaid' },
  { key: 'partial', label: 'Part paid' },
  { key: 'paid', label: 'Paid' },
  { key: 'voided', label: 'Void' },
];

/** The category filter's value for salary periods (every other value is a category id). */
export const SALARIES = 'salaries';
/** Paid-from filter values: company, personal (any owner) or `owner:<staff id>`. */
export const OWNER_PREFIX = 'owner:';

export interface ExpenseFilters {
  readonly query: string;
  readonly category: string | null;
  readonly status: StatusFilter | null;
  readonly source: string | null;
}

export function matchesFilters(e: Expense, f: ExpenseFilters): boolean {
  if (f.category === SALARIES ? e.kind !== 'salary' : f.category && e.categoryId !== f.category) {
    return false;
  }
  if (f.status) {
    if (f.status === 'voided' ? !e.voided : e.voided || e.paymentStatus !== f.status) return false;
  }
  if (f.source) {
    const kept = e.payments.filter((p) => p.kind === 'payment' && !p.reversed);
    if (f.source === 'company' && e.paidCompanyPaise <= 0) return false;
    if (f.source === 'personal' && e.paidPersonalPaise <= 0) return false;
    if (
      f.source.startsWith(OWNER_PREFIX) &&
      !kept.some((p) => p.payerStaffId === f.source!.slice(OWNER_PREFIX.length))
    ) {
      return false;
    }
  }
  const q = f.query.trim().toLowerCase();
  if (!q) return true;
  return [
    e.title,
    e.notes ?? '',
    e.categoryName ?? '',
    e.staffName ?? '',
    ...e.payments.map((p) => p.payerName ?? ''),
  ].some((x) => x.toLowerCase().includes(q));
}

// --------------------------------------------------------------------------------- totals

/** A period's expenses, counted by the day they belong to (voided ones left out). */
export interface ExpenseTotals {
  readonly count: number;
  readonly incurredPaise: number;
  /** Paid on those expenses, whenever it was paid; company + personal. */
  readonly paidPaise: number;
  readonly paidCompanyPaise: number;
  readonly paidPersonalPaise: number;
  /** Still owed on them: incurred = paid + unpaid. */
  readonly unpaidPaise: number;
  readonly voidedCount: number;
}

export function expenseTotals(expenses: readonly Expense[]): ExpenseTotals {
  let count = 0;
  let incurred = 0;
  let company = 0;
  let personal = 0;
  let unpaid = 0;
  let voided = 0;
  for (const e of expenses) {
    if (e.voided) {
      voided++;
      continue;
    }
    count++;
    incurred += e.amountPaise;
    company += e.paidCompanyPaise;
    personal += e.paidPersonalPaise;
    unpaid += e.balancePaise;
  }
  return {
    count,
    incurredPaise: incurred,
    paidPaise: company + personal,
    paidCompanyPaise: company,
    paidPersonalPaise: personal,
    unpaidPaise: unpaid,
    voidedCount: voided,
  };
}

/** One owner's own money paid in a period (an owner contribution, not company cash). */
export interface OwnerContribution {
  readonly staffId: string;
  readonly name: string;
  readonly paidPaise: number;
  /** Taken back by reversals (dated the day of the payment each undoes). */
  readonly reversedPaise: number;
  readonly netPaise: number;
}

/** Money paid out in a period, counted by payment date (reversals net it). */
export interface CashTotals {
  /** Out of the company account. */
  readonly companyPaise: number;
  /** Owners' own money: never company cash out. */
  readonly personalPaise: number;
  readonly salariesPaise: number;
  readonly salariesCompanyPaise: number;
  readonly salariesPersonalPaise: number;
  /** Personal money by owner, largest net first. */
  readonly owners: readonly OwnerContribution[];
}

export function cashTotals(payments: readonly PaymentLine[]): CashTotals {
  let company = 0;
  let personal = 0;
  let salaryCompany = 0;
  let salaryPersonal = 0;
  const owners = new Map<string, { name: string; paid: number; reversed: number }>();
  for (const p of payments) {
    const salary = p.expenseKind === 'salary';
    if (p.paidFrom === 'company') {
      company += p.amountPaise;
      if (salary) salaryCompany += p.amountPaise;
      continue;
    }
    personal += p.amountPaise;
    if (salary) salaryPersonal += p.amountPaise;
    const key = p.payerStaffId ?? '';
    const o = owners.get(key) ?? { name: p.payerName ?? 'Owner', paid: 0, reversed: 0 };
    if (p.amountPaise >= 0) o.paid += p.amountPaise;
    else o.reversed -= p.amountPaise;
    owners.set(key, o);
  }
  return {
    companyPaise: company,
    personalPaise: personal,
    salariesPaise: salaryCompany + salaryPersonal,
    salariesCompanyPaise: salaryCompany,
    salariesPersonalPaise: salaryPersonal,
    owners: [...owners]
      .map(([staffId, o]) => ({
        staffId,
        name: o.name,
        paidPaise: o.paid,
        reversedPaise: o.reversed,
        netPaise: o.paid - o.reversed,
      }))
      .sort((a, b) => b.netPaise - a.netPaise || a.name.localeCompare(b.name)),
  };
}

/** The list's line under the figures: "12 expenses · 2 void · 3 unpaid". */
export function summaryLine(expenses: readonly Expense[]): string {
  const t = expenseTotals(expenses);
  const open = expenses.filter((e) => !e.voided && e.balancePaise > 0).length;
  const parts = [`${t.count} expense${t.count === 1 ? '' : 's'}`];
  if (open) parts.push(`${open} not fully paid`);
  if (t.voidedCount) parts.push(`${t.voidedCount} void`);
  return parts.join(' · ');
}

// -------------------------------------------------------------------------------- reports

export interface CategoryRow {
  /** A category id, or SALARIES. */
  readonly key: string;
  readonly name: string;
  readonly paise: number;
  readonly count: number;
}

/** Incurred by category (salaries as one row), largest first; voided expenses left out. */
export function byCategory(expenses: readonly Expense[]): CategoryRow[] {
  const rows = new Map<string, { name: string; paise: number; count: number }>();
  for (const e of expenses) {
    if (e.voided) continue;
    const key = e.kind === 'salary' ? SALARIES : (e.categoryId ?? '');
    const name = e.kind === 'salary' ? 'Salaries' : (e.categoryName ?? 'No category');
    const row = rows.get(key) ?? { name, paise: 0, count: 0 };
    row.paise += e.amountPaise;
    row.count++;
    rows.set(key, row);
  }
  return [...rows]
    .map(([key, r]) => ({ key, ...r }))
    .sort((a, b) => b.paise - a.paise || a.name.localeCompare(b.name));
}

export interface StaffSalaryRow {
  readonly staffId: string;
  readonly name: string;
  readonly periods: number;
  readonly owedPaise: number;
  readonly paidCompanyPaise: number;
  readonly paidPersonalPaise: number;
  readonly balancePaise: number;
}

/** Salary periods dated in the period, by person, most owed first. */
export function salariesByStaff(expenses: readonly Expense[]): StaffSalaryRow[] {
  const rows = new Map<string, Omit<StaffSalaryRow, 'staffId'>>();
  for (const e of expenses) {
    if (e.voided || e.kind !== 'salary' || !e.staffId) continue;
    const r = rows.get(e.staffId) ?? {
      name: e.staffName ?? 'Staff member',
      periods: 0,
      owedPaise: 0,
      paidCompanyPaise: 0,
      paidPersonalPaise: 0,
      balancePaise: 0,
    };
    rows.set(e.staffId, {
      name: r.name,
      periods: r.periods + 1,
      owedPaise: r.owedPaise + e.amountPaise,
      paidCompanyPaise: r.paidCompanyPaise + e.paidCompanyPaise,
      paidPersonalPaise: r.paidPersonalPaise + e.paidPersonalPaise,
      balancePaise: r.balancePaise + e.balancePaise,
    });
  }
  return [...rows]
    .map(([staffId, r]) => ({ staffId, ...r }))
    .sort((a, b) => b.owedPaise - a.owedPaise || a.name.localeCompare(b.name));
}

export interface MonthRow {
  /** The month's first day. */
  readonly first: string;
  readonly label: string;
  /** By expense date. */
  readonly incurredPaise: number;
  readonly unpaidPaise: number;
  /** By payment date. */
  readonly companyPaise: number;
  readonly personalPaise: number;
}

/** Each month from `firstMonth` to `lastMonth` (first days), oldest first. */
export function byMonth(data: ExpensesData, firstMonth: string, lastMonth: string): MonthRow[] {
  const rows: MonthRow[] = [];
  for (let m = firstMonth; m <= lastMonth; m = addMonths(m, 1)) {
    const { last } = monthOf(m);
    const within = (day: string) => day >= m && day <= last;
    const totals = expenseTotals(data.expenses.filter((e) => within(e.expenseDate)));
    const cash = cashTotals(data.payments.filter((p) => within(p.paidOn)));
    rows.push({
      first: m,
      label: formatMonthOnly(m),
      incurredPaise: totals.incurredPaise,
      unpaidPaise: totals.unpaidPaise,
      companyPaise: cash.companyPaise,
      personalPaise: cash.personalPaise,
    });
  }
  return rows;
}

/** "+12%" / "−5%" / "New" / "—": the change from `before` to `now`. */
export function changeLabel(now: number, before: number): string {
  if (!before) return now ? 'New' : '—';
  const pct = Math.round(((now - before) / before) * 100);
  return pct === 0 ? '0%' : `${pct > 0 ? '+' : '−'}${Math.abs(pct)}%`;
}

// -------------------------------------------------------------------------------- salaries

/** The agreed salary in force on `day`: the latest that starts on or before it. */
export function agreedOn(
  salaries: readonly StaffSalary[],
  staffId: string,
  day: string,
): StaffSalary | null {
  let best: StaffSalary | null = null;
  for (const s of salaries) {
    if (s.staffId !== staffId || s.effectiveFrom > day) continue;
    if (!best || s.effectiveFrom > best.effectiveFrom) best = s;
  }
  return best;
}

/** "₹15,000 a month from 1 Aug 2026". */
export function agreedLabel(s: StaffSalary): string {
  return `${formatAmount(s.amountPaise)} a ${s.period === 'weekly' ? 'week' : 'month'} from ${formatDayYear(s.effectiveFrom)}`;
}

export interface PeriodOption {
  readonly first: string;
  readonly last: string;
  readonly label: string;
}

/**
 * The quick salary form's periods: calendar months (or Monday–Sunday weeks) from one ahead to
 * twelve back, newest first.
 */
export function salaryPeriodOptions(kind: SalaryPeriod, today: string): PeriodOption[] {
  const out: PeriodOption[] = [];
  for (let n = 1; n >= -12; n--) {
    const span =
      kind === 'weekly'
        ? ((first: string) => ({ first, last: addDays(first, 6) }))(
            addDays(weekOf(today).first, 7 * n),
          )
        : monthOf(addMonths(today, n));
    out.push({ ...span, label: salaryPeriodName(span.first, span.last) });
  }
  return out;
}

/** Active salary periods of `staffId` that share a day with `first`…`last`. */
export function overlapping(
  periods: readonly Expense[],
  staffId: string,
  first: string,
  last: string,
  exceptId?: string,
): Expense[] {
  return periods.filter(
    (e) =>
      e.kind === 'salary' &&
      !e.voided &&
      e.staffId === staffId &&
      e.id !== exceptId &&
      !!e.periodStart &&
      !!e.periodEnd &&
      rangesOverlap(e.periodStart, e.periodEnd, first, last),
  );
}

/** One person's salary for a month on the Salaries list. */
export interface MonthSalary {
  /** Active periods that share a day with the month. */
  readonly periods: readonly Expense[];
  readonly owedPaise: number;
  readonly paidPaise: number;
  readonly balancePaise: number;
}

export function salaryInMonth(
  expenses: readonly Expense[],
  staffId: string,
  month: { first: string; last: string },
): MonthSalary {
  const periods = overlapping(expenses, staffId, month.first, month.last);
  return {
    periods,
    owedPaise: periods.reduce((n, e) => n + e.amountPaise, 0),
    paidPaise: periods.reduce((n, e) => n + e.paidPaise, 0),
    balancePaise: periods.reduce((n, e) => n + e.balancePaise, 0),
  };
}
