import { ActivityBill, Game, LiveStation, minutesLeft } from '../../../core/floor/floor.models';
import { formatRupees } from '../../../shared/money/rupees.pipe';
import { PillTone } from '../../../shared/status-pill/status-pill';
import { formatDate, formatTime } from '../../../shared/time/ist';
import { Rate, StationType, headlinePrice, typeIcon } from '../../pricing/data/pricing.models';
import { billRef } from '../../sales/data/sale.models';

export const STATE_TONE: Readonly<Record<LiveStation['state'], PillTone>> = {
  playing: 'primary',
  free: 'info',
  oos: 'danger',
};

/** The station types (activities) a station offers, in the price list's order. */
export function typesOf(codes: readonly string[], types: readonly StationType[]): StationType[] {
  return types.filter((t) => codes.includes(t.code));
}

export function typeLabel(codes: readonly string[], types: readonly StationType[]): string {
  const named = typesOf(codes, types).map((t) => t.name);
  return named.length ? named.join(', ') : codes.join(', ') || 'No type';
}

export function stationIcon(codes: readonly string[], types: readonly StationType[]): string {
  const t = typesOf(codes, types)[0];
  return t ? typeIcon(t) : 'grid_view';
}

/** "PlayStation 5 · ₹120 / hr" (the first type's cheapest standard price). */
export function rateLine(
  codes: readonly string[],
  types: readonly StationType[],
  rates: readonly Rate[],
): string {
  const t = typesOf(codes, types)[0];
  const price = t ? headlinePrice(t, rates) : null;
  const label = typeLabel(codes, types);
  if (!price) return `${label} · no price yet`;
  const per = price.per === 'per hour' ? '/ hr' : price.per.replace('per ', '/ ');
  return `${label} · ${price.price} ${per}`;
}

/** "18m left", "Ends now" or "6m over". */
export function leftLabel(endsAt: string, now: Date): string {
  const left = minutesLeft(endsAt, now);
  if (left > 0) return `${left}m left`;
  return left === 0 ? 'Ends now' : `${-left}m over`;
}

/** The list row's subtitle: what is on, or the type. */
export function stationSubtitle(
  live: LiveStation,
  games: ReadonlyMap<string, Game>,
  types: readonly StationType[],
  now: Date,
): string {
  if (live.state === 'playing') {
    const game = live.gameId ? games.get(live.gameId)?.name : null;
    return [game ?? 'Playing', live.endsAt ? leftLabel(live.endsAt, now) : '']
      .filter(Boolean)
      .join(' · ');
  }
  return typeLabel(live.station.activityCodes, types);
}

export interface BillLine {
  readonly billId: string;
  readonly title: string;
  readonly subtitle: string;
  readonly value: string;
}

/**
 * A station's or member's latest bills (arena_activity), newest first: who (or where),
 * "S-3F9A2C · 1 Oct, 6:40 pm · game", and the bill (or its state).
 */
export function activityLines(
  bills: readonly ActivityBill[],
  title: (b: ActivityBill) => string,
  { gameInSubtitle = true } = {},
): BillLine[] {
  return bills.map((b) => {
    const when = `${formatDate(b.startedAt)}, ${formatTime(b.startedAt)}`;
    const value =
      b.status === 'voided'
        ? 'Void'
        : b.status === 'active'
          ? 'Playing'
          : b.billedPaise != null
            ? formatRupees(b.billedPaise)
            : '—';
    return {
      billId: b.billId,
      title: title(b),
      subtitle: [billRef(b.billId), when, gameInSubtitle ? b.game : null]
        .filter(Boolean)
        .join(' · '),
      value,
    };
  });
}
