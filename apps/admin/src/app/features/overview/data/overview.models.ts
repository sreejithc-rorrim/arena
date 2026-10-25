import { formatRupees } from '../../../shared/money/rupees.pipe';
import {
  addDays,
  formatDate,
  formatIsoDate,
  formatMinutes,
  istDayStart,
  istDayStartOf,
} from '../../../shared/time/ist';
import { WeekWindows } from '../../pricing/data/pricing.models';
import { Bill, PayMethod } from '../../sales/data/sale.models';

export type Period = 'today' | 'day' | '7d' | '30d' | '12m';

export const PERIODS: readonly { readonly key: Period; readonly label: string }[] = [
  { key: 'today', label: 'Today' },
  { key: 'day', label: 'Day' },
  { key: '7d', label: '7d' },
  { key: '30d', label: '30d' },
  { key: '12m', label: '12m' },
];

export function asPeriod(value: string | undefined): Period {
  return PERIODS.some((p) => p.key === value) ? (value as Period) : 'today';
}

/** The IST date of yesterday ("2026-10-23"): the newest day the Day period can show. */
export function yesterdayOf(now: Date): string {
  return formatIsoDate(istDayStart(now, 1));
}

/** `?day=` as a past IST date; `yesterday` when missing, malformed, today or later. */
export function asDay(value: string | undefined, yesterday: string): string {
  return value && istDayStartOf(value) && value <= yesterday ? value : yesterday;
}

const IST_OFFSET_MS = 330 * 60_000;

/** IST calendar parts of an instant. */
function ist(at: Date) {
  const d = new Date(at.getTime() + IST_OFFSET_MS);
  return { y: d.getUTCFullYear(), m: d.getUTCMonth(), day: d.getUTCDate(), h: d.getUTCHours() };
}

/** Midnight IST starting the given IST calendar month (month may be out of 0–11). */
function istMonthStart(y: number, m: number): Date {
  return new Date(Date.UTC(y, m, 1) - IST_OFFSET_MS);
}

export interface PeriodRange {
  readonly from: Date;
  readonly to: Date;
  readonly prevFrom: Date;
  readonly prevTo: Date;
  /** "Today so far", "Last 7 days"… */
  readonly label: string;
  /** "vs yesterday", "vs previous 7 days"… */
  readonly compare: string;
}

/**
 * The period and the one before it, as [from, to) instants on IST calendar boundaries. `day` is
 * the IST date the Day period shows (see asDay).
 */
export function periodRange(period: Period, now: Date, day = yesterdayOf(now)): PeriodRange {
  const tomorrow = istDayStart(now, -1);
  switch (period) {
    case 'day': {
      const from = istDayStartOf(day) ?? istDayStart(now, 1);
      const yesterday = day === yesterdayOf(now);
      return {
        from,
        to: istDayStartOf(addDays(day, 1)) ?? istDayStart(now),
        prevFrom: istDayStartOf(addDays(day, -1)) ?? istDayStart(now, 2),
        prevTo: from,
        label: yesterday ? 'Yesterday' : dayLabel.format(from),
        compare: 'vs the day before',
      };
    }
    case 'today':
      return {
        from: istDayStart(now),
        to: tomorrow,
        prevFrom: istDayStart(now, 1),
        prevTo: istDayStart(now),
        label: 'Today so far',
        compare: 'vs yesterday',
      };
    case '7d':
    case '30d': {
      const n = period === '7d' ? 7 : 30;
      return {
        from: istDayStart(now, n - 1),
        to: tomorrow,
        prevFrom: istDayStart(now, 2 * n - 1),
        prevTo: istDayStart(now, n - 1),
        label: `Last ${n} days`,
        compare: `vs previous ${n} days`,
      };
    }
    case '12m': {
      const { y, m } = ist(now);
      return {
        from: istMonthStart(y, m - 11),
        to: tomorrow,
        prevFrom: istMonthStart(y - 1, m - 11),
        prevTo: istMonthStart(y, m - 11),
        label: 'Last 12 months',
        compare: 'vs previous year',
      };
    }
  }
}

export interface Totals {
  readonly takingsPaise: number;
  readonly bills: number;
  readonly minutes: number;
  readonly averagePaise: number;
}

/** What arena_overview returns for a period (every figure aggregated on the server). */
export interface OverviewData {
  /** Bills that were not voided: collected, count, minutes played; discounts given. */
  readonly totals: Totals & { readonly discountPaise: number; readonly discounts: number };
  readonly previous: Totals;
  /** Collected per IST hour / day / month (empty buckets left out). */
  readonly buckets: readonly { readonly start: string; readonly paise: number }[];
  readonly methods: Readonly<Partial<Record<PayMethod, { paise: number; bills: number }>>>;
  /** Billed per station type code, from the bill lines. */
  readonly byType: ReadonlyMap<string, number>;
  readonly topGames: readonly { readonly name: string; readonly minutes: number }[];
  readonly byStaff: readonly {
    readonly name: string;
    readonly bills: number;
    readonly paise: number;
  }[];
  /** The newest bills closed today (any status). */
  readonly latest: readonly Bill[];
}

/** The bucket a period's chart is drawn in. */
export function bucketOf(period: Period): 'hour' | 'day' | 'month' {
  return period === 'today' || period === 'day' ? 'hour' : period === '12m' ? 'month' : 'day';
}

/** Totals with the average bill worked out. */
export function withAverage(t: Omit<Totals, 'averagePaise'>): Totals {
  return { ...t, averagePaise: t.bills ? t.takingsPaise / t.bills : 0 };
}

/** "+12%" / "−8%" with its tone, or "—" when there is nothing to compare with. */
export function delta(now: number, before: number): { label: string; up: boolean | null } {
  if (!before) return { label: '—', up: null };
  const p = Math.round(((now - before) / before) * 100);
  return { label: `${p >= 0 ? '+' : '−'}${Math.abs(p)}%`, up: p >= 0 };
}

export interface Bar {
  readonly paise: number;
  readonly label: string;
  readonly tip: string;
  /** Still to come today (drawn faint). */
  readonly future: boolean;
}

/**
 * Takings bars: by hour for today or one day (that weekday's opening hours, widened to any
 * takings), by day, or by month.
 */
export function takingsBars(
  period: Period,
  range: PeriodRange,
  buckets: OverviewData['buckets'],
  open: WeekWindows | null,
  now: Date,
): Bar[] {
  const live = buckets.map((b) => ({ at: b.start, paidPaise: b.paise }));
  if (period === 'today' || period === 'day') {
    const weekday = String(
      ((new Date(range.from.getTime() + IST_OFFSET_MS).getUTCDay() + 6) % 7) + 1,
    );
    const w = open?.[weekday];
    const hours = live.map((b) => ist(new Date(b.at)).h);
    const first = Math.min(w ? Math.floor(w.start / 60) : 10, ...hours);
    const last = Math.max(w ? Math.ceil(w.end / 60) - 1 : 23, ...hours);
    const nowHour = period === 'today' ? ist(now).h : 24;
    return Array.from({ length: last - first + 1 }, (_, k) => {
      const h = first + k;
      const paise = live
        .filter((b) => ist(new Date(b.at)).h === h)
        .reduce((n, b) => n + b.paidPaise, 0);
      const label = hourLabel(h);
      return {
        paise,
        label: k % 2 ? '' : label,
        tip: `${label} · ${formatRupees(paise)}`,
        future: h > nowHour,
      };
    });
  }
  if (period === '12m') {
    const { y, m } = ist(range.from);
    return Array.from({ length: 12 }, (_, k) => {
      const start = istMonthStart(y, m + k).getTime();
      const end = istMonthStart(y, m + k + 1).getTime();
      const paise = live
        .filter((b) => Date.parse(b.at) >= start && Date.parse(b.at) < end)
        .reduce((n, b) => n + b.paidPaise, 0);
      const label = new Intl.DateTimeFormat('en-IN', { month: 'short', timeZone: 'UTC' }).format(
        new Date(Date.UTC(y, m + k, 1)),
      );
      return { paise, label, tip: `${label} · ${formatRupees(paise)}`, future: false };
    });
  }
  const n = period === '7d' ? 7 : 30;
  return Array.from({ length: n }, (_, k) => {
    const daysAgo = n - 1 - k;
    const start = istDayStart(now, daysAgo);
    const end = istDayStart(now, daysAgo - 1).getTime();
    const paise = live
      .filter((b) => Date.parse(b.at) >= start.getTime() && Date.parse(b.at) < end)
      .reduce((n2, b) => n2 + b.paidPaise, 0);
    const label =
      n === 7
        ? daysAgo
          ? new Intl.DateTimeFormat('en-IN', { weekday: 'short', timeZone: 'Asia/Kolkata' }).format(
              start,
            )
          : 'Today'
        : daysAgo % 5 === 0
          ? String(ist(start).day)
          : '';
    return { paise, label, tip: `${formatDate(start)} · ${formatRupees(paise)}`, future: false };
  });
}

/** "Fri, 23 Oct" */
const dayLabel = new Intl.DateTimeFormat('en-IN', {
  weekday: 'short',
  day: 'numeric',
  month: 'short',
  timeZone: 'Asia/Kolkata',
});

function hourLabel(h: number): string {
  return `${h % 12 || 12}${h >= 12 && h < 24 ? 'pm' : 'am'}`;
}

/** The chart's top gridline (a round number above the tallest bar) and its labels. */
export function chartScale(bars: readonly Bar[]): { topPaise: number; top: string; mid: string } {
  const max = Math.max(100, ...bars.map((b) => b.paise));
  const unit = max > 2_000_000 ? 1_000_000 : 100_000;
  const top = Math.ceil(max / unit) * unit;
  return { topPaise: top, top: compact(top), mid: compact(top / 2) };
}

/** ₹48k, ₹1.2L */
function compact(paise: number): string {
  const r = paise / 100;
  return r >= 100_000 ? `₹${+(r / 100_000).toFixed(1)}L` : `₹${+(r / 1000).toFixed(1)}k`;
}

export interface MethodRow {
  readonly method: PayMethod;
  readonly label: string;
  readonly paise: number;
  readonly bills: number;
}

/** UPI and Cash always; Card and Other only when used. */
export function paymentRows(methods: OverviewData['methods']): MethodRow[] {
  const rows: MethodRow[] = (
    [
      ['upi', 'UPI'],
      ['cash', 'Cash'],
      ['card', 'Card'],
      ['other', 'Other'],
    ] as [PayMethod, string][]
  ).map(([method, label]) => ({
    method,
    label,
    paise: methods[method]?.paise ?? 0,
    bills: methods[method]?.bills ?? 0,
  }));
  return rows.filter((r) => r.method === 'upi' || r.method === 'cash' || r.paise);
}

/** "2h 30m" per game. */
export function topGames(games: OverviewData['topGames']): { name: string; time: string }[] {
  return games.map((g) => ({ name: g.name, time: formatMinutes(g.minutes) }));
}
