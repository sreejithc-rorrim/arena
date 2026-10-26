import { Component, computed, effect, inject, resource, signal } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatCard } from '@angular/material/card';
import { MatCheckbox } from '@angular/material/checkbox';
import { MatFormField, MatLabel } from '@angular/material/form-field';
import { MatInput } from '@angular/material/input';
import { MatProgressBar } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Router } from '@angular/router';
import { ArenaContext } from '../../core/arena/arena-context';
import { toAppError } from '../../core/auth/auth-api';
import { FloorStore } from '../../core/floor/floor-store';
import { Station } from '../../core/floor/floor.models';
import { PageHeader } from '../../core/layout/page-header';
import {
  CatalogType,
  NOUN_WORDS,
  ResourceNoun,
  VenueApi,
  VenueStore,
  nounFor,
} from '../../core/venue/venue';
import { PricingStore } from '../pricing/data/pricing-store';
import {
  MAX_UNIT_MINUTES,
  RateChange,
  StationType,
  WEEKDAYS,
  findRate,
  fromTimeInput,
  perLabel,
  rateRows,
  unitFromParts,
  typeIcon,
} from '../pricing/data/pricing.models';

type Step = 'types' | 'hours' | 'prices' | 'places' | 'done';

const STEPS: readonly { key: Exclude<Step, 'done'>; title: string }[] = [
  { key: 'types', title: 'What you run' },
  { key: 'hours', title: 'Opening hours' },
  { key: 'prices', title: 'Prices' },
  { key: 'places', title: 'Your floor' },
];

/** "What business do you run?": each choice only pre-ticks catalog types; nothing is stored. */
const CATEGORIES: readonly {
  key: string;
  label: string;
  icon: string;
  picks: readonly string[];
}[] = [
  { key: 'gaming', label: 'Gaming centre', icon: 'sports_esports', picks: ['PS5', 'PC', 'VR'] },
  {
    key: 'cue',
    label: 'Pool or snooker hall',
    icon: 'table_restaurant',
    picks: ['POOL', 'SNOOKER'],
  },
  { key: 'sports', label: 'Turf or courts', icon: 'stadium', picks: ['TURF', 'CRICKET'] },
  { key: 'arcade', label: 'Arcade', icon: 'videogame_asset', picks: ['ARCADE'] },
  { key: 'mixed', label: 'Something else', icon: 'category', picks: [] },
];

const GROUP_LABELS: Readonly<Record<CatalogType['group'], string>> = {
  gaming: 'Gaming',
  cue: 'Cue sports',
  sports: 'Sports',
  arcade: 'Arcade',
  other: 'Other',
};

const LONG = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const MAX_RUPEES = 100_000;
const MAX_PLACES = 30;

/** Tables and rooms get their own floor zone in the app; everything else is a station. */
function stationKind(noun: ResourceNoun): Station['kind'] {
  return noun === 'table' || noun === 'room' ? noun : 'station';
}

/**
 * Self-service setup for a new venue, four short steps: what it runs (picked from the global
 * station type catalog), when it is open, what it charges, and how many of each it has. Each
 * step saves through the ordinary ops as it is completed, so leaving half-way resumes at the
 * first unfinished step; everything stays editable in Settings and Pricing afterwards.
 */
@Component({
  selector: 'app-setup-page',
  imports: [
    PageHeader,
    MatButton,
    MatCard,
    MatCheckbox,
    MatFormField,
    MatLabel,
    MatInput,
    MatProgressBar,
  ],
  host: { class: 'flex min-h-full flex-col' },
  template: `
    <app-page-header title="Set up your venue" />
    @if (!ready()) {
      <mat-progress-bar mode="indeterminate" aria-label="Loading" />
    }
    <div class="mx-auto flex w-full max-w-3xl flex-col gap-5 p-5">
      <ol class="flex flex-wrap gap-2" aria-label="Setup steps">
        @for (s of steps; track s.key; let i = $index) {
          <li
            class="flex items-center gap-2 rounded-chip px-3 py-1.5 text-sm"
            [class.bg-info-soft]="s.key === step()"
            [class.font-semibold]="s.key === step()"
            [class.text-muted]="s.key !== step()"
            [attr.aria-current]="s.key === step() ? 'step' : null"
          >
            <span class="font-mono text-xs">{{ i + 1 }}</span
            >{{ s.title }}
          </li>
        }
      </ol>

      @if (loadError(); as e) {
        <p role="alert" class="text-sm text-danger">{{ e }}</p>
      } @else if (ready()) {
        <mat-card appearance="outlined">
          <div class="flex flex-col gap-5 p-5">
            @switch (step()) {
              @case ('types') {
                <h2 class="text-lg leading-[1.2] font-semibold">What do you run?</h2>
                <div class="grid grid-cols-[repeat(auto-fit,minmax(150px,1fr))] gap-2">
                  @for (c of categories; track c.key) {
                    <button
                      mat-stroked-button
                      type="button"
                      class="!h-auto !py-3"
                      [attr.aria-pressed]="category() === c.key"
                      [class.!border-primary]="category() === c.key"
                      (click)="pickCategory(c.key)"
                    >
                      <span class="flex flex-col items-center gap-1">
                        <span class="icon text-2xl" aria-hidden="true">{{ c.icon }}</span>
                        {{ c.label }}
                      </span>
                    </button>
                  }
                </div>
                <p class="text-sm text-muted">
                  Tick everything customers can use. You can add more later in Settings.
                </p>
                @for (g of catalogGroups(); track g.group) {
                  <fieldset class="flex flex-col gap-1">
                    <legend class="pb-1 text-xs font-semibold tracking-wide text-muted uppercase">
                      {{ g.label }}
                    </legend>
                    @for (t of g.types; track t.code) {
                      <mat-checkbox
                        [checked]="picked().has(t.code)"
                        [disabled]="existing().has(t.code)"
                        (change)="toggle(t.code, $event.checked)"
                      >
                        {{ t.name }}
                        @if (existing().has(t.code)) {
                          <span class="text-muted"> · added</span>
                        }
                      </mat-checkbox>
                    }
                  </fieldset>
                }
              }
              @case ('hours') {
                <h2 class="text-lg leading-[1.2] font-semibold">When are you open?</h2>
                <div class="flex flex-wrap gap-3">
                  <mat-form-field class="w-40">
                    <mat-label>Opens at</mat-label>
                    <input
                      matInput
                      type="time"
                      [value]="opens()"
                      (input)="opens.set($any($event.target).value)"
                    />
                  </mat-form-field>
                  <mat-form-field class="w-40">
                    <mat-label>Closes at</mat-label>
                    <input
                      matInput
                      type="time"
                      [value]="closes()"
                      (input)="closes.set($any($event.target).value)"
                    />
                  </mat-form-field>
                </div>
                <fieldset class="flex flex-col gap-1">
                  <legend class="pb-1 text-sm text-muted">
                    Open on (times in IST; 00:00 closing is midnight)
                  </legend>
                  <div class="flex flex-wrap gap-x-4">
                    @for (d of days; track d.key) {
                      <mat-checkbox
                        [checked]="!closed().has(d.key)"
                        [attr.aria-label]="d.long + ' open'"
                        (change)="toggleDay(d.key, $event.checked)"
                        >{{ d.short }}</mat-checkbox
                      >
                    }
                  </div>
                </fieldset>
              }
              @case ('prices') {
                <h2 class="text-lg leading-[1.2] font-semibold">How much do you charge?</h2>
                <p class="text-sm text-muted">
                  Whole rupees, per the time you choose (minutes, hours or days). Happy hours and
                  discounts can be added later in Pricing.
                </p>
                @for (t of activeTypes(); track t.id) {
                  <fieldset class="flex flex-col gap-2">
                    <legend class="flex items-center gap-2 pb-1 text-sm font-semibold">
                      <span class="icon text-lg text-muted" aria-hidden="true">{{ icon(t) }}</span>
                      {{ t.name }} · {{ per(t) }}
                    </legend>
                    <div class="flex flex-wrap items-center gap-3">
                      <span class="text-sm">Charged per</span>
                      <mat-form-field class="arena-dense w-28">
                        <mat-label>Hours</mat-label>
                        <input
                          matInput
                          type="number"
                          inputmode="numeric"
                          min="0"
                          [value]="units()[t.code]?.hours ?? ''"
                          (input)="setUnit(t.code, { hours: $any($event.target).value })"
                        />
                        <span matTextSuffix>h</span>
                      </mat-form-field>
                      <mat-form-field class="arena-dense w-28">
                        <mat-label>Minutes</mat-label>
                        <input
                          matInput
                          type="number"
                          inputmode="numeric"
                          min="0"
                          [value]="units()[t.code]?.minutes ?? ''"
                          (input)="setUnit(t.code, { minutes: $any($event.target).value })"
                        />
                        <span matTextSuffix>min</span>
                      </mat-form-field>
                    </div>
                    <div
                      class="grid grid-cols-[minmax(0,1fr)_minmax(0,9rem)] items-center gap-x-3 gap-y-2"
                    >
                      @for (row of rows(t); track row) {
                        <span class="text-sm">{{ rowLabel(row) }}</span>
                        <mat-form-field class="arena-dense">
                          <span matTextPrefix>₹&nbsp;</span>
                          <input
                            matInput
                            type="number"
                            inputmode="numeric"
                            min="0"
                            [attr.aria-label]="t.name + ' price, ' + rowLabel(row)"
                            [value]="prices()[priceKey(t, row)] ?? ''"
                            (input)="setPrice(t, row, $any($event.target).value)"
                          />
                        </mat-form-field>
                      }
                    </div>
                  </fieldset>
                }
              }
              @case ('places') {
                <h2 class="text-lg leading-[1.2] font-semibold">
                  Add your {{ words().many.toLowerCase() }}
                </h2>
                <p class="text-sm text-muted">
                  How many of each? They are named for you; rename them any time.
                </p>
                <div
                  class="grid grid-cols-[minmax(0,1fr)_minmax(0,7rem)] items-center gap-x-3 gap-y-2"
                >
                  @for (t of activeTypes(); track t.id) {
                    <span class="text-sm">{{ t.name }}</span>
                    <mat-form-field class="arena-dense">
                      <input
                        matInput
                        type="number"
                        inputmode="numeric"
                        min="0"
                        [attr.max]="maxPlaces"
                        [attr.aria-label]="'How many ' + t.name"
                        [value]="counts()[t.code] ?? 0"
                        (input)="setCount(t.code, $any($event.target).value)"
                      />
                    </mat-form-field>
                  }
                </div>
              }
              @case ('done') {
                <h2 class="text-lg leading-[1.2] font-semibold">You're set up</h2>
                <p class="text-sm text-muted">
                  Staff can start sessions on the floor app now. Optional next steps: invite staff
                  in Users, and fine-tune billing rules and holidays in Settings and Pricing.
                </p>
              }
            }
            @if (error()) {
              <p role="alert" class="text-sm font-medium text-danger">{{ error() }}</p>
            }
            <div class="flex flex-wrap justify-end gap-2">
              @if (step() === 'done') {
                <button mat-stroked-button type="button" (click)="go('/users')">
                  Invite staff
                </button>
                <button mat-flat-button type="button" (click)="go('/overview')">
                  Go to overview
                </button>
              } @else {
                @if (step() !== 'types') {
                  <button mat-button type="button" [disabled]="busy()" (click)="back()">
                    Back
                  </button>
                }
                <button
                  mat-flat-button
                  type="button"
                  [disabled]="busy() || !arena.canEdit()"
                  (click)="next()"
                >
                  {{ step() === 'places' ? 'Finish' : 'Continue' }}
                </button>
              }
            </div>
          </div>
        </mat-card>
      }
    </div>
  `,
})
export class SetupPage {
  protected readonly arena = inject(ArenaContext);
  private readonly pricing = inject(PricingStore);
  private readonly floor = inject(FloorStore);
  private readonly venue = inject(VenueStore);
  private readonly venueApi = inject(VenueApi);
  private readonly router = inject(Router);
  private readonly snack = inject(MatSnackBar);

  protected readonly steps = STEPS;
  protected readonly categories = CATEGORIES;
  protected readonly days = WEEKDAYS.map((d) => ({ ...d, long: LONG[Number(d.key) - 1] }));
  protected readonly maxPlaces = MAX_PLACES;
  protected readonly icon = typeIcon;
  protected readonly words = this.venue.words;

  private readonly catalog = resource({ loader: () => this.venueApi.catalog() });
  protected readonly ready = computed(
    () =>
      this.catalog.hasValue() &&
      !!this.pricing.data() &&
      this.floor.stationsReady() &&
      this.venue.types() !== null,
  );
  protected readonly loadError = computed(() => {
    if (this.catalog.error())
      return `The station type list couldn't load: ${toAppError(this.catalog.error()).message}`;
    return this.pricing.loadError();
  });

  protected readonly step = signal<Step>('types');
  protected readonly busy = signal(false);
  protected readonly error = signal('');

  // --- step 1: types
  protected readonly category = signal('');
  protected readonly picked = signal<ReadonlySet<string>>(new Set());
  /** Codes the venue already has (any state), so the catalog never adds them twice. */
  protected readonly existing = computed(() => new Set(this.pricing.types().map((t) => t.code)));
  protected readonly catalogGroups = computed(() => {
    const all = this.catalog.hasValue() ? this.catalog.value() : [];
    return (Object.keys(GROUP_LABELS) as CatalogType['group'][])
      .map((group) => ({
        group,
        label: GROUP_LABELS[group],
        types: all.filter((t) => t.group === group),
      }))
      .filter((g) => g.types.length);
  });

  // --- step 2: hours
  protected readonly opens = signal('10:00');
  protected readonly closes = signal('22:00');
  protected readonly closed = signal<ReadonlySet<string>>(new Set());

  // --- step 3: prices (whole rupees as typed, by type code and controller count)
  protected readonly activeTypes = computed(() => this.pricing.types().filter((t) => t.active));
  protected readonly prices = signal<Readonly<Record<string, string>>>({});
  /** "Charged per [hours] h [minutes] min" per type code, as typed. */
  protected readonly units = signal<
    Readonly<Record<string, { readonly hours: string; readonly minutes: string }>>
  >({});

  // --- step 4: how many of each
  protected readonly counts = signal<Readonly<Record<string, number>>>({});

  /** Where a returning owner picks up: the first step whose data is still missing. */
  private readonly firstIncomplete = computed<Step>(() => {
    const types = this.activeTypes();
    if (!types.length) return 'types';
    if (!this.venue.hoursSaved()) return 'hours';
    const rates = this.pricing.rates();
    if (types.some((t) => rateRows(t).some((row) => !findRate(rates, t.code, row))))
      return 'prices';
    if (!this.floor.stations().some((s) => s.status !== 'disabled')) return 'places';
    return 'done';
  });

  constructor() {
    void this.pricing.load(true);
    void this.floor.load(['stations'], true);
    void this.venue.load(true);
    let started = false;
    effect(() => {
      if (started || !this.ready()) return;
      started = true;
      this.step.set(this.firstIncomplete());
      this.seedDrafts();
    });
  }

  protected pickCategory(key: string): void {
    this.category.set(key);
    const picks = CATEGORIES.find((c) => c.key === key)?.picks ?? [];
    this.picked.set(new Set(picks.filter((code) => !this.existing().has(code))));
  }

  protected toggle(code: string, on: boolean): void {
    this.picked.update((s) => {
      const next = new Set(s);
      if (on) next.add(code);
      else next.delete(code);
      return next;
    });
  }

  protected toggleDay(day: string, open: boolean): void {
    this.closed.update((s) => {
      const next = new Set(s);
      if (open) next.delete(day);
      else next.add(day);
      return next;
    });
  }

  protected rows(t: StationType): (number | null)[] {
    return rateRows(t);
  }

  protected rowLabel(row: number | null): string {
    return row == null ? 'Price' : `${row} controller${row === 1 ? '' : 's'}`;
  }

  protected per(t: StationType): string {
    return perLabel(this.draftUnit(t) ?? this.unitMinutes(t));
  }

  protected setUnit(code: string, change: { hours?: string; minutes?: string }): void {
    this.units.update((u) => {
      const was = u[code] ?? { hours: '1', minutes: '0' };
      return { ...u, [code]: { ...was, ...change } };
    });
  }

  /** The drafted unit in minutes; null while what is typed is not a whole count. */
  private draftUnit(t: StationType): number | null {
    const u = this.units()[t.code];
    return u ? unitFromParts(u.hours, u.minutes) : null;
  }

  protected priceKey(t: StationType, row: number | null): string {
    return `${t.code}:${row ?? 'any'}`;
  }

  protected setPrice(t: StationType, row: number | null, value: string): void {
    this.prices.update((p) => ({ ...p, [this.priceKey(t, row)]: value }));
  }

  protected setCount(code: string, value: string): void {
    const n = Number(value);
    this.counts.update((c) => ({ ...c, [code]: Number.isFinite(n) ? n : 0 }));
  }

  protected back(): void {
    const i = STEPS.findIndex((s) => s.key === this.step());
    if (i > 0) this.step.set(STEPS[i - 1].key);
    this.error.set('');
  }

  protected go(url: string): void {
    void this.router.navigateByUrl(url);
  }

  protected async next(): Promise<void> {
    this.error.set('');
    this.busy.set(true);
    try {
      switch (this.step()) {
        case 'types':
          await this.saveTypes();
          break;
        case 'hours':
          await this.saveHours();
          break;
        case 'prices':
          await this.savePrices();
          break;
        case 'places':
          await this.savePlaces();
          break;
      }
    } catch (e) {
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }

  private async saveTypes(): Promise<void> {
    const catalog = this.catalog.hasValue() ? this.catalog.value() : [];
    const chosen = catalog.filter((t) => this.picked().has(t.code));
    if (!chosen.length && !this.activeTypes().length) {
      this.error.set('Tick at least one thing customers can use');
      return;
    }
    let order = this.pricing.types().length;
    for (const t of chosen) {
      await this.pricing.saveType({
        id: crypto.randomUUID(),
        code: t.code,
        name: t.name,
        usesControllers: t.usesControllers,
        usesGames: t.usesGames,
        durationModel: t.durationModel,
        sortOrder: order++,
        active: true,
      });
    }
    // The venue's word for its resources: from everything it now runs from the catalog.
    const codes = new Set(this.activeTypes().map((t) => t.code));
    const known = catalog.filter((t) => codes.has(t.code));
    if (known.length) await this.venue.saveNoun(nounFor(known));
    this.picked.set(new Set());
    this.seedDrafts();
    this.step.set(this.venue.hoursSaved() ? 'prices' : 'hours');
  }

  private async saveHours(): Promise<void> {
    const start = fromTimeInput(this.opens());
    const close = fromTimeInput(this.closes());
    // 00:00 as a closing time is midnight at the end of the day.
    const end = close === 0 ? 1440 : close;
    if (start == null || end == null || end <= start) {
      this.error.set('Closing time must be after opening time');
      return;
    }
    if (this.closed().size === WEEKDAYS.length) {
      this.error.set('Choose at least one day you are open');
      return;
    }
    const open: Record<string, { start: number; end: number } | null> = {};
    for (const d of WEEKDAYS) open[d.key] = this.closed().has(d.key) ? null : { start, end };
    await this.pricing.saveHours({ open });
    await this.venue.load(true);
    this.step.set('prices');
  }

  private async savePrices(): Promise<void> {
    const changes: RateChange[] = [];
    for (const t of this.activeTypes()) {
      const unit = this.draftUnit(t);
      if (unit == null || unit > MAX_UNIT_MINUTES) {
        this.error.set(
          `${t.name}: charged per whole hours and minutes, at least 1 minute, up to 168 hours`,
        );
        return;
      }
      for (const row of rateRows(t)) {
        const raw = (this.prices()[this.priceKey(t, row)] ?? '').trim();
        const rupees = Number(raw);
        if (raw === '' || !Number.isInteger(rupees) || rupees < 0 || rupees > MAX_RUPEES) {
          this.error.set(
            `${t.name}: enter a price in whole rupees (0 to ${MAX_RUPEES.toLocaleString('en-IN')})`,
          );
          return;
        }
        changes.push({
          activityCode: t.code,
          controllerCount: row,
          unitMinutes: unit,
          pricePaise: rupees * 100,
        });
      }
    }
    await this.pricing.saveRates(changes);
    this.step.set(this.floor.stations().some((s) => s.status !== 'disabled') ? 'done' : 'places');
  }

  private async savePlaces(): Promise<void> {
    const types = this.activeTypes();
    const counts = types.map((t) => Math.trunc(this.counts()[t.code] ?? 0));
    if (counts.some((n) => n < 0 || n > MAX_PLACES)) {
      this.error.set(`Up to ${MAX_PLACES} of each`);
      return;
    }
    if (!counts.some((n) => n > 0)) {
      this.error.set(`Add at least one ${this.words().one.toLowerCase()}`);
      return;
    }
    const catalog = this.catalog.hasValue() ? this.catalog.value() : [];
    const taken = new Set(
      this.floor
        .stations()
        .filter((s) => s.status !== 'disabled')
        .map((s) => s.name.toLowerCase()),
    );
    let order = Math.max(-1, ...this.floor.stations().map((s) => s.sortOrder)) + 1;
    for (const [i, t] of types.entries()) {
      const noun = catalog.find((c) => c.code === t.code)?.noun ?? this.venue.noun();
      // One type: "Table 1"; several: "Pool table 1", "Snooker table 1".
      const base = types.length === 1 ? NOUN_WORDS[noun].one : t.name;
      let n = 1;
      for (let k = 0; k < counts[i]; k++) {
        while (taken.has(`${base} ${n}`.toLowerCase())) n++;
        const name = `${base} ${n}`;
        taken.add(name.toLowerCase());
        await this.floor.saveStation({
          id: crypto.randomUUID(),
          name,
          kind: stationKind(noun),
          status: 'available',
          sortOrder: order++,
          activityCodes: [t.code],
        });
      }
    }
    await this.venue.load(true);
    this.step.set('done');
    this.snack.open('Your floor is ready', undefined, { duration: 3200 });
  }

  /** The block a type is priced per: its saved rate's, else the catalog's, else an hour. */
  private unitMinutes(t: StationType): number {
    const saved = this.pricing.rates().find((r) => r.activityCode === t.code);
    if (saved) return saved.unitMinutes;
    const catalog = this.catalog.hasValue() ? this.catalog.value() : [];
    return catalog.find((c) => c.code === t.code)?.unitMinutes ?? 60;
  }

  /** Starts the price and count drafts from what is saved (a resumed setup shows it). */
  private seedDrafts(): void {
    const rates = this.pricing.rates();
    const prices: Record<string, string> = { ...this.prices() };
    const counts: Record<string, number> = { ...this.counts() };
    const units: Record<string, { hours: string; minutes: string }> = { ...this.units() };
    for (const t of this.activeTypes()) {
      if (!units[t.code]) {
        const m = this.unitMinutes(t);
        units[t.code] = { hours: String(Math.floor(m / 60)), minutes: String(m % 60) };
      }
      for (const row of rateRows(t)) {
        const r = findRate(rates, t.code, row);
        if (r && prices[this.priceKey(t, row)] == null) {
          prices[this.priceKey(t, row)] = String(r.pricePaise / 100);
        }
      }
      counts[t.code] ??= this.floor.stations().some((s) => s.activityCodes.includes(t.code))
        ? 0
        : 1;
    }
    this.prices.set(prices);
    this.counts.set(counts);
    this.units.set(units);
  }
}
