import {
  Component,
  computed,
  inject,
  input,
  linkedSignal,
  output,
  resource,
  signal,
} from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatFormField, MatLabel } from '@angular/material/form-field';
import { MatIcon } from '@angular/material/icon';
import { MatInput } from '@angular/material/input';
import { MatOption, MatSelect } from '@angular/material/select';
import { MatSlideToggleChange } from '@angular/material/slide-toggle';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { FloorStore } from '../../../core/floor/floor-store';
import { FLOOR_STATE_LABEL, LiveStation, minutesLeft } from '../../../core/floor/floor.models';
import { VenueStore } from '../../../core/venue/venue';
import { ConfirmDialog, ConfirmDialogData } from '../../../shared/confirm/confirm-dialog';
import { DetailPane } from '../../../shared/list-detail/detail-pane';
import { DetailRow } from '../../../shared/list-detail/detail-row';
import { DetailSection } from '../../../shared/list-detail/detail-section';
import { LineRow } from '../../../shared/list-detail/line-row';
import { ToggleRow } from '../../../shared/list-detail/toggle-row';
import { UnsavedBar } from '../../../shared/list-detail/unsaved-bar';
import { formatRupees } from '../../../shared/money/rupees.pipe';
import { StatTile } from '../../../shared/stat-tile/stat-tile';
import { StatusPill } from '../../../shared/status-pill/status-pill';
import { StationAccessories } from '../../accessories/components/station-accessories';
import { PricingStore } from '../../pricing/data/pricing-store';
import { STATE_TONE, activityLines, rateLine, stationIcon } from '../data/station-view';

/**
 * One station: what is on now, figures for today and 30 days (aggregated on the server), name and
 * type (saved together from the unsaved-changes bar), in service, its accessories, and recent
 * bills (read when the station is opened). Remove is a safe delete: the station leaves the floor
 * for good and its name is free again, while past bills and reports keep it.
 */
@Component({
  selector: 'app-station-detail',
  imports: [
    DetailPane,
    DetailSection,
    DetailRow,
    LineRow,
    ToggleRow,
    UnsavedBar,
    StatTile,
    StatusPill,
    StationAccessories,
    MatButton,
    MatIcon,
    MatFormField,
    MatLabel,
    MatInput,
    MatSelect,
    MatOption,
  ],
  template: `
    @let l = live();
    @let s = l.station;
    <app-detail-pane
      [crumb]="'Stations / ' + s.name"
      [icon]="icon()"
      [heading]="s.name"
      [subtitle]="rate()"
      (closed)="closed.emit()"
    >
      <div actions class="arena-compact flex gap-2">
        <button
          mat-button
          type="button"
          class="danger-action"
          [disabled]="busy() || !canEdit()"
          (click)="remove()"
        >
          <mat-icon aria-hidden="true">delete</mat-icon>Remove
        </button>
      </div>
      <app-status-pill chip [tone]="tone()">{{ stateLabel() }}</app-status-pill>

      <div stats class="grid grid-cols-[repeat(auto-fit,minmax(130px,1fr))] gap-3">
        <app-stat-tile label="Takings today" [value]="rupees(stats().billedToday)" />
        <app-stat-tile label="Sessions today" [value]="stats().sessionsToday.toString()" />
        <app-stat-tile label="Hours · 30 days" [value]="hours(stats().minutes30)" />
        <app-stat-tile label="Takings · 30 days" [value]="rupees(stats().billed30)" />
      </div>

      @if (l.state === 'playing') {
        <app-detail-section heading="In use">
          @if (venue.has('games')) {
            <app-detail-row label="Game" [value]="game() ?? '—'" />
          }
          @if (venue.has('equipment')) {
            <app-detail-row label="Players" [value]="l.players.toString()" />
          }
          @if (l.endsAt) {
            <app-detail-row label="Time left" [value]="timeLeft(l.endsAt)" />
          }
        </app-detail-section>
      }

      <app-detail-section heading="Settings">
        <mat-form-field>
          <mat-label>Name</mat-label>
          <input
            matInput
            autocomplete="off"
            maxlength="40"
            [value]="name()"
            (input)="name.set($any($event.target).value)"
          />
        </mat-form-field>
        <mat-form-field>
          <mat-label>Type</mat-label>
          <!-- One type, as designed; a station that offers several keeps them all. -->
          @if (s.activityCodes.length > 1) {
            <mat-select
              multiple
              [value]="codes()"
              [disabled]="l.state === 'playing'"
              (selectionChange)="codes.set($event.value)"
            >
              @for (o of typeOptions(); track o.code) {
                <mat-option [value]="o.code">{{ o.name }}</mat-option>
              }
            </mat-select>
          } @else {
            <mat-select
              [value]="codes()[0]"
              [disabled]="l.state === 'playing'"
              (selectionChange)="codes.set([$event.value])"
            >
              @for (o of typeOptions(); track o.code) {
                <mat-option [value]="o.code">{{ o.name }}</mat-option>
              }
            </mat-select>
          }
        </mat-form-field>
        @if (l.state === 'playing') {
          <p class="-mt-2 text-[13px] leading-[1.4] text-muted">
            Change type when the station is free.
          </p>
        }
        <app-toggle-row
          label="In service"
          [sub]="
            s.status === 'available'
              ? 'Staff can start sessions here'
              : 'Hidden from staff on the floor'
          "
          [checked]="s.status === 'available'"
          [disabled]="busy() || !canEdit()"
          (changed)="setInService($event)"
        />
        @if (error()) {
          <p role="alert" class="text-sm font-medium text-danger">{{ error() }}</p>
        }
      </app-detail-section>

      @if (venue.has('equipment')) {
        <app-station-accessories [station]="s" />
      }

      <app-detail-section heading="Recent bills">
        @if (activity.error()) {
          <p role="alert" class="text-[13px] leading-[1.45] text-danger">
            Recent bills couldn't load.
          </p>
        } @else if (activity.isLoading() && !bills().length) {
          <p class="text-[13px] leading-[1.45] text-muted">Loading…</p>
        }
        @for (b of bills(); track b.billId) {
          <app-line-row
            [title]="b.title"
            [subtitle]="b.subtitle"
            [value]="b.value"
            link="/sales"
            [queryParams]="{ id: b.billId }"
          />
        } @empty {
          @if (activity.hasValue()) {
            <p class="text-[13px] leading-[1.45] text-muted">No bills yet.</p>
          }
        }
      </app-detail-section>

      @if (dirty()) {
        <app-unsaved-bar footer [busy]="busy()" (discard)="discard()" (save)="save()" />
      }
    </app-detail-pane>
  `,
})
export class StationDetail {
  /** Without the Settings permission the server refuses every change here. */
  protected readonly canEdit = inject(ArenaContext).canEdit;
  private readonly floor = inject(FloorStore);
  protected readonly venue = inject(VenueStore);
  protected readonly pricing = inject(PricingStore);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);

  readonly live = input.required<LiveStation>();
  readonly now = input.required<Date>();
  readonly closed = output<void>();

  protected readonly rupees = formatRupees;
  protected readonly hours = (m: number) => `${Math.round(m / 60)}h`;
  /** Design: "18 min"; past the booked end, "6 min over". */
  protected readonly timeLeft = (endsAt: string) => {
    const m = minutesLeft(endsAt, this.now());
    return m >= 0 ? `${m} min` : `${-m} min over`;
  };

  private readonly station = computed(() => this.live().station);
  protected readonly icon = computed(() =>
    stationIcon(this.station().activityCodes, this.pricing.types()),
  );
  protected readonly rate = computed(() =>
    this.pricing.loadError()
      ? `${this.station().activityCodes.join(', ')} · price couldn't load`
      : rateLine(this.station().activityCodes, this.pricing.types(), this.pricing.rates()),
  );
  /** The price list's types, plus the station's own codes when the list hasn't loaded. */
  protected readonly typeOptions = computed(() => {
    const options = this.pricing.types().map((t) => ({ code: t.code, name: t.name }));
    for (const code of this.station().activityCodes) {
      if (!options.some((o) => o.code === code)) options.push({ code, name: code });
    }
    return options;
  });
  protected readonly stateLabel = computed(() => FLOOR_STATE_LABEL[this.live().state]);
  protected readonly tone = computed(() => STATE_TONE[this.live().state]);
  protected readonly stats = computed(
    () =>
      this.floor.stationFigures().get(this.station().id) ?? {
        billedToday: 0,
        sessionsToday: 0,
        minutes30: 0,
        billed30: 0,
        accessories: 0,
      },
  );
  protected readonly game = computed(() => {
    const id = this.live().gameId;
    return id ? (this.floor.gameById().get(id)?.name ?? null) : null;
  });
  /** The station's newest bills, read when it is opened (and again when its play changes). */
  protected readonly activity = resource({
    params: () => ({ id: this.station().id, revision: this.floor.revision() }),
    loader: ({ params }) => this.floor.activity({ stationId: params.id }),
  });
  protected readonly bills = computed(() =>
    activityLines(this.activity.hasValue() ? this.activity.value().bills : [], (b) => b.customer ?? 'Guest'),
  );

  protected readonly name = linkedSignal(() => this.station().name);
  protected readonly codes = linkedSignal<readonly string[]>(() => this.station().activityCodes);
  protected readonly dirty = computed(
    () =>
      this.name().trim() !== this.station().name ||
      [...this.codes()].sort().join() !== [...this.station().activityCodes].sort().join(),
  );
  protected readonly busy = signal(false);
  protected readonly error = signal('');

  protected discard(): void {
    this.name.set(this.station().name);
    this.codes.set(this.station().activityCodes);
    this.error.set('');
  }

  protected async save(): Promise<void> {
    const s = this.station();
    const name = this.name().trim();
    if (!name || name.length > 40) {
      this.error.set('Enter a name of up to 40 characters');
      return;
    }
    if (
      this.floor
        .stations()
        .some(
          (x) =>
            x.id !== s.id && x.status !== 'disabled' && x.name.toLowerCase() === name.toLowerCase(),
        )
    ) {
      this.error.set(`${name} already exists`);
      return;
    }
    if (!this.codes().length) {
      this.error.set('Pick at least one type');
      return;
    }
    await this.run(async () => {
      // No status: an edit never changes it (Out of service / Remove do, on their own).
      await this.floor.saveStation({
        id: s.id,
        name,
        kind: s.kind,
        sortOrder: s.sortOrder,
        activityCodes: [...this.codes()],
      });
      this.say('Station saved');
    });
  }

  protected async setInService(event: MatSlideToggleChange): Promise<void> {
    const s = this.station();
    if (!event.checked && this.live().state === 'playing') {
      event.source.checked = true;
      this.say(`${s.name} has a live session · end it on the floor first`);
      return;
    }
    const ok = await this.run(async () => {
      await this.floor.setStationStatus(s.id, event.checked ? 'available' : 'maintenance');
      this.say(`${s.name} ${event.checked ? 'back in service' : 'taken out of service'}`);
    });
    if (!ok) event.source.checked = !event.checked;
  }

  protected remove(): void {
    const s = this.station();
    if (this.live().state === 'playing') {
      this.say(`${s.name} has a live session · end it first`);
      return;
    }
    this.dialog
      .open<ConfirmDialog, ConfirmDialogData, boolean>(ConfirmDialog, {
        data: {
          title: `Remove ${s.name}?`,
          message:
            'It leaves the floor app and this list for good; it cannot be restored. Past bills and reports keep its name, and the name can be used for a new station.',
          confirm: 'Remove',
          danger: true,
        },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe(async (yes) => {
        if (!yes) return;
        const ok = await this.run(() => this.floor.setStationStatus(s.id, 'disabled'));
        if (ok) {
          this.say(`${s.name} removed`);
          this.closed.emit();
        }
      });
  }

  /** Runs a change; a refusal is shown in the section (and false returned). */
  private async run(change: () => Promise<void>): Promise<boolean> {
    this.busy.set(true);
    this.error.set('');
    try {
      await change();
      return true;
    } catch (e) {
      this.error.set(toAppError(e).message);
      return false;
    } finally {
      this.busy.set(false);
    }
  }

  private say(message: string): void {
    this.snack.open(message, undefined, { duration: 3200 });
  }
}
