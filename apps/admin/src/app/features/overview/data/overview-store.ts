import { Service, inject, signal } from '@angular/core';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { LoginScope } from '../../../core/auth/login-scope';
import { Clock } from '../../../core/time/clock';
import { istDayStart } from '../../../shared/time/ist';
import { SalesApi } from '../../sales/data/sales-api';
import { OverviewData, Period, PeriodRange, bucketOf, periodRange } from './overview.models';

/**
 * The Overview's figures for one period, aggregated on the server in one read (arena_overview):
 * totals for the period and the one before it, takings per hour / day / month, payment split,
 * by type, top games, by staff, and today's latest bills.
 */
@Service()
export class OverviewStore {
  private readonly sales = inject(SalesApi);
  private readonly arena = inject(ArenaContext);
  private readonly clock = inject(Clock);

  readonly range = signal<PeriodRange | null>(null);
  readonly data = signal<OverviewData | null>(null);
  readonly loading = signal(false);
  readonly loadError = signal('');
  private loadedKey: string | null = null;
  private outOfDate = false;
  private currentPeriod: Period = 'today';
  private currentDay: string | undefined;
  private latest = 0;

  constructor() {
    // Sign-out or another login: the figures leave memory; a read in flight does not land.
    inject(LoginScope).onEnd(() => {
      this.latest++;
      this.loadedKey = null;
      this.range.set(null);
      this.data.set(null);
      this.loading.set(false);
      this.loadError.set('');
    });
  }

  /** `day` is the IST date the Day period shows (ignored by the others). */
  async load(period: Period, day?: string, force = false): Promise<void> {
    this.currentPeriod = period;
    this.currentDay = day;
    const arenaId = this.arena.current().id;
    if (!arenaId) return;
    const now = this.clock.now();
    const range = periodRange(period, now, day);
    // Another day is other figures: they are not shown while it loads.
    const series = period === 'day' ? `${arenaId}|${period}|${day}` : `${arenaId}|${period}`;
    const key = `${series}|${range.from.toISOString()}`;
    if (!force && !this.outOfDate && key === this.loadedKey) return;
    const call = ++this.latest;
    if (!this.loadedKey?.startsWith(`${series}|`)) this.data.set(null);
    this.loadedKey = key;
    this.outOfDate = false;
    this.range.set(range);
    this.loading.set(true);
    this.loadError.set('');
    try {
      const data = await this.sales.overview(arenaId, {
        from: range.from,
        to: range.to,
        prevFrom: range.prevFrom,
        prevTo: range.prevTo,
        bucket: bucketOf(period),
        today: istDayStart(now),
      });
      if (call !== this.latest) return;
      this.data.set(data);
    } catch (e) {
      if (call === this.latest) {
        this.loadError.set(toAppError(e).message);
        this.loadedKey = null;
      }
    } finally {
      if (call === this.latest) this.loading.set(false);
    }
  }

  async refresh(): Promise<void> {
    if (this.loadedKey) await this.load(this.currentPeriod, this.currentDay, true);
  }

  /** Marks the figures out of date (a live update while the Overview is not open). */
  stale(): void {
    if (this.loadedKey) this.outOfDate = true;
  }
}
