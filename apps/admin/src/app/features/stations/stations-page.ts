import { Component, computed, effect, inject, input } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatChipListbox, MatChipListboxChange, MatChipOption } from '@angular/material/chips';
import { MatDialog } from '@angular/material/dialog';
import { MatIcon } from '@angular/material/icon';
import { MatProgressBar } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Router } from '@angular/router';
import { ArenaContext } from '../../core/arena/arena-context';
import { FloorRead, FloorStore } from '../../core/floor/floor-store';
import { FLOOR_STATE_LABEL, LiveStation, liveStations } from '../../core/floor/floor.models';
import { Layout } from '../../core/layout/layout';
import { injectNow } from '../../core/time/ticker';
import { ListDetail } from '../../shared/list-detail/list-detail';
import { ListPaneHeader } from '../../shared/list-detail/list-pane-header';
import { ListRow } from '../../shared/list-detail/list-row';
import { StatusPill } from '../../shared/status-pill/status-pill';
import { PricingStore } from '../pricing/data/pricing-store';
import { StationDetail } from './components/station-detail';
import { STATE_TONE, stationIcon, stationSubtitle } from './data/station-view';
import { StationDialog, StationDialogData, StationDialogResult } from './dialogs/station-dialog';

/**
 * Stations: every station with what is on it now and its accessories, filtered by type. Type
 * filter and selection are in the URL (`?type=PS5&id=…`); on a wide screen the first station is
 * shown when none is chosen. Removed stations are not listed (Sales and reports still name them).
 */
@Component({
  selector: 'app-stations-page',
  imports: [
    ListDetail,
    ListPaneHeader,
    ListRow,
    StatusPill,
    StationDetail,
    MatButton,
    MatChipListbox,
    MatChipOption,
    MatIcon,
    MatProgressBar,
  ],
  template: `
    <app-list-detail
      listLabel="Stations"
      detailLabel="Station"
      [open]="!!selected()"
      (closed)="close()"
    >
      <ng-container list>
        <app-list-pane-header title="Stations">
          <button
            actions
            mat-flat-button
            type="button"
            [disabled]="!arena.canEdit()"
            (click)="add()"
          >
            <mat-icon aria-hidden="true">add</mat-icon>Add
          </button>
          @if (chips().length > 1) {
            <mat-chip-listbox
              aria-label="Station type"
              [value]="type()"
              (change)="pickType($event)"
            >
              @for (c of chips(); track c.key) {
                <mat-chip-option [value]="c.key" [selectable]="c.key !== type()">{{
                  c.label
                }}</mat-chip-option>
              }
            </mat-chip-listbox>
          }
        </app-list-pane-header>
        @if (loading()) {
          <mat-progress-bar mode="indeterminate" aria-label="Loading stations" />
        }
        <div class="flex min-h-0 flex-1 flex-col overflow-y-auto p-2">
          @if (pricing.loadError(); as error) {
            <!-- Stations still list without the price list; only names and prices are missing. -->
            <div class="flex flex-col items-start gap-2 px-3 pt-2 pb-3">
              <p role="alert" class="text-[13px] leading-[1.4] text-danger">
                Type names and prices couldn't load: {{ error }}
              </p>
              <button mat-stroked-button type="button" (click)="pricing.load(true)">
                Try again
              </button>
            </div>
          }
          @if (floor.errorOf(reads); as error) {
            <div class="flex flex-col items-center gap-3 px-4 py-12 text-center">
              <p role="alert" class="text-sm text-danger">{{ error }}</p>
              <button mat-stroked-button type="button" (click)="load(true)">Try again</button>
            </div>
          } @else if (!floor.loading() || live().length) {
            <ul class="flex flex-col gap-0.5" aria-label="Stations">
              @for (l of filtered(); track l.station.id) {
                <li>
                  <app-list-row
                    [title]="l.station.name"
                    [subtitle]="subtitle(l)"
                    [icon]="icon(l)"
                    [selected]="l.station.id === selected()?.station?.id"
                    [queryParams]="{ id: l.station.id }"
                    queryParamsHandling="merge"
                  >
                    <app-status-pill [tone]="tone(l)">{{ label(l) }}</app-status-pill>
                  </app-list-row>
                </li>
              }
            </ul>
            @if (!filtered().length) {
              <p class="px-4 py-12 text-center text-sm leading-[1.4] text-muted">
                {{
                  live().length
                    ? 'No stations of this type.'
                    : 'No stations yet. Add the first one.'
                }}
              </p>
            }
          }
        </div>
      </ng-container>
      <ng-container detail>
        @if (selected(); as l) {
          <app-station-detail [live]="l" [now]="now()" (closed)="close()" />
        }
      </ng-container>
    </app-list-detail>
  `,
})
export class StationsPage {
  protected readonly floor = inject(FloorStore);
  /**
   * What this screen reads (and reports errors for): the stations, what is open on them now and
   * their figures aggregated on the server. A station's recent bills are read when it is opened.
   */
  protected readonly reads: readonly FloorRead[] = ['stations', 'games', 'live', 'stationFigures'];
  protected readonly pricing = inject(PricingStore);
  protected readonly arena = inject(ArenaContext);
  private readonly layout = inject(Layout);
  private readonly router = inject(Router);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);

  /** `?type=` — an activity code, or all. */
  readonly typeParam = input<string>(undefined, { alias: 'type' });
  /** `?id=` — the selected station. */
  readonly id = input<string>();

  protected readonly now = injectNow();
  protected readonly loading = computed(() => this.floor.loading() || this.pricing.loading());

  protected readonly live = computed(() => liveStations(this.floor.stations(), this.floor.live()));
  protected readonly type = computed(() => {
    const t = this.typeParam();
    return t && this.live().some((l) => l.station.activityCodes.includes(t)) ? t : 'all';
  });
  protected readonly chips = computed(() => {
    const live = this.live();
    const types = this.pricing.types();
    const rank = (code: string) => {
      const i = types.findIndex((t) => t.code === code);
      return i < 0 ? Number.MAX_SAFE_INTEGER : i;
    };
    const codes = [...new Set(live.flatMap((l) => l.station.activityCodes))].sort(
      (x, y) => rank(x) - rank(y) || x.localeCompare(y),
    );
    return [
      { key: 'all', label: `All ${live.length}` },
      ...codes.map((code) => {
        const name = types.find((t) => t.code === code)?.name ?? code;
        const n = live.filter((l) => l.station.activityCodes.includes(code)).length;
        return { key: code, label: `${name} ${n}` };
      }),
    ];
  });
  protected readonly filtered = computed(() => {
    const t = this.type();
    return t === 'all'
      ? this.live()
      : this.live().filter((l) => l.station.activityCodes.includes(t));
  });
  protected readonly selected = computed<LiveStation | undefined>(() => {
    const id = this.id();
    if (id) return this.live().find((l) => l.station.id === id);
    return this.layout.wideDetail() ? this.filtered()[0] : undefined;
  });

  constructor() {
    // Load (and reload on an arena switch) what this screen shows.
    effect(() => {
      if (this.arena.current().id) void this.load();
    });
  }

  protected load(force = false): void {
    void this.floor.load(this.reads, force);
    void this.pricing.load(force);
  }

  protected subtitle(l: LiveStation): string {
    const line = stationSubtitle(l, this.floor.gameById(), this.pricing.types(), this.now());
    const n = this.floor.stationFigures().get(l.station.id)?.accessories ?? 0;
    return n ? `${line} · ${n} accessor${n === 1 ? 'y' : 'ies'}` : line;
  }

  protected icon(l: LiveStation): string {
    return stationIcon(l.station.activityCodes, this.pricing.types());
  }

  protected tone(l: LiveStation) {
    return STATE_TONE[l.state];
  }

  protected label(l: LiveStation): string {
    return FLOOR_STATE_LABEL[l.state];
  }

  protected pickType(event: MatChipListboxChange): void {
    if (!event.value) return;
    void this.router.navigate([], {
      queryParams: { type: event.value === 'all' ? null : event.value },
      queryParamsHandling: 'merge',
    });
  }

  protected close(): void {
    void this.router.navigate([], { queryParams: { id: null }, queryParamsHandling: 'merge' });
  }

  protected add(): void {
    const type = this.type();
    this.dialog
      .open<StationDialog, StationDialogData, StationDialogResult>(StationDialog, {
        data: { code: type === 'all' ? undefined : type },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((result) => {
        if (!result) return;
        this.snack.open(result.snack, undefined, { duration: 3200 });
        void this.router.navigate([], { queryParams: { type: null, id: result.id } });
      });
  }
}
