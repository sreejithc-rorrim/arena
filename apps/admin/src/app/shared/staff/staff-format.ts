import { istDayStartOf } from '../time/ist';

/**
 * Display helpers shared by the staff screens (terms, personal details). Days are IST calendar
 * dates ("2026-10-05"); minutes are whole numbers.
 */

const TIME_ZONE = 'Asia/Kolkata';
const dayMonth = new Intl.DateTimeFormat('en-IN', {
  day: 'numeric',
  month: 'short',
  timeZone: TIME_ZONE,
});
const dayMonthYear = new Intl.DateTimeFormat('en-IN', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  timeZone: TIME_ZONE,
});
const weekday = new Intl.DateTimeFormat('en-IN', { weekday: 'short', timeZone: TIME_ZONE });

/** Minutes as hours and two-digit minutes: 485 → "8h 05m", 0 → "0h 00m", -30 → "−0h 30m". */
export function formatHMin(minutes: number): string {
  const m = Math.round(minutes);
  const abs = Math.abs(m);
  return `${m < 0 ? '−' : ''}${Math.floor(abs / 60)}h ${String(abs % 60).padStart(2, '0')}m`;
}

/** A day count without trailing zeros: 1 → "1", 1.5 → "1.5", 0.5 → "0.5". */
export function formatCount(n: number): string {
  return String(Math.round(n * 100) / 100);
}

/** 1 → "1 day", 2.5 → "2.5 days", 0.5 → "0.5 day". */
export function formatDays(n: number): string {
  return `${formatCount(n)} ${Math.abs(n) <= 1 ? 'day' : 'days'}`;
}

/** "5 Oct" for an IST date ("2026-10-05"); the text itself when it is not a date. */
export function formatDay(iso: string): string {
  const d = istDayStartOf(iso);
  return d ? dayMonth.format(d) : iso;
}

/** "5 Oct 2026". */
export function formatDayYear(iso: string): string {
  const d = istDayStartOf(iso);
  return d ? dayMonthYear.format(d) : iso;
}

/** "Mon" for an IST date. */
export function weekdayOf(iso: string): string {
  const d = istDayStartOf(iso);
  return d ? weekday.format(d) : '';
}

/** ISO weekday (1 = Monday … 7 = Sunday) of an IST date. */
export function isoWeekday(iso: string): number {
  const d = istDayStartOf(iso);
  if (!d) return Number.NaN;
  // The IST date's own weekday (its midnight IST is 18:30 UTC of the day before).
  const day = new Date(d.getTime() + 330 * 60_000).getUTCDay();
  return day === 0 ? 7 : day;
}

/**
 * An inclusive range of IST dates in words: "5 Oct 2026", "1–31 Oct 2026",
 * "28 Sep – 4 Oct 2026", "29 Dec 2026 – 4 Jan 2027".
 */
export function formatRange(first: string, last: string): string {
  if (first === last) return formatDayYear(first);
  const [fy, fm] = first.split('-');
  const [ly, lm] = last.split('-');
  if (fy === ly && fm === lm) return `${Number(first.slice(8, 10))}–${formatDayYear(last)}`;
  if (fy === ly) return `${formatDay(first)} – ${formatDayYear(last)}`;
  return `${formatDayYear(first)} – ${formatDayYear(last)}`;
}

/** Inclusive IST date ranges share at least one day. */
export function rangesOverlap(
  aFirst: string,
  aLast: string,
  bFirst: string,
  bLast: string,
): boolean {
  return aFirst <= bLast && bFirst <= aLast;
}
