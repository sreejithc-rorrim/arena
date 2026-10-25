import { Component, computed, inject, signal } from '@angular/core';
import { MatButton } from '@angular/material/button';
import {
  MatDialogActions,
  MatDialogContent,
  MatDialogRef,
  MatDialogTitle,
} from '@angular/material/dialog';
import { MatFormField, MatHint, MatLabel } from '@angular/material/form-field';
import { MatInput } from '@angular/material/input';
import { MatOption, MatSelect } from '@angular/material/select';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { MemberRow } from '../../../core/floor/floor.models';
import { FloorStore } from '../../../core/floor/floor-store';
import { Attempt } from '../../../core/sync/push-ops';
import { Clock } from '../../../core/time/clock';
import { VenueStore } from '../../../core/venue/venue';
import { MATERIAL_DEFAULTS } from '../../../shared/material/material-defaults';
import { formatRupees } from '../../../shared/money/rupees.pipe';
import { formatIsoDate, istDayStartOf } from '../../../shared/time/ist';
import { MissedBillApi } from '../data/missed-bill-api';
import { PAY_METHODS, PayMethod, methodName, parseRupees, rupeesText } from '../data/sale.models';

/**
 * Add missed bill: a single session that was played but never started on the floor. Pick the
 * customer (or walk-in), station, type, game, controllers, date and times; the price comes from
 * the server on the current price list (session_quote) and fills in the amount paid, which staff
 * change to what the customer actually paid. Saving adds it already ended, billed and paid at that
 * amount by the method picked, with the required reason (session.record; audited).
 */
@Component({
  selector: 'app-missed-bill-dialog',
  providers: [MATERIAL_DEFAULTS],
  imports: [
    MatDialogTitle,
    MatDialogContent,
    MatDialogActions,
    MatFormField,
    MatLabel,
    MatHint,
    MatInput,
    MatSelect,
    MatOption,
    MatButton,
  ],
  template: `
    <h2 mat-dialog-title>Add missed bill</h2>
    <form novalidate (submit)="save($event)">
      <mat-dialog-content>
        <div class="flex flex-col gap-4 pt-1">
          <p class="text-sm leading-[1.4] text-muted">
            For play that was never started on the floor. It is priced on today's price list and
            recorded at the amount the customer actually paid.
          </p>
          <mat-form-field>
            <mat-label>Find member</mat-label>
            <input
              matInput
              type="search"
              autocomplete="off"
              [value]="search()"
              (input)="find($any($event.target).value)"
            />
            <mat-hint>Name or phone; leave empty for a walk-in</mat-hint>
          </mat-form-field>
          <mat-form-field>
            <mat-label>Customer</mat-label>
            <mat-select [value]="customerId()" (selectionChange)="customerId.set($event.value)">
              <mat-option [value]="null">Walk-in</mat-option>
              @for (m of members(); track m.id) {
                <mat-option [value]="m.id"
                  >{{ m.name }}{{ m.phone ? ' · ' + m.phone : '' }}</mat-option
                >
              }
            </mat-select>
          </mat-form-field>
          <mat-form-field>
            <mat-label>Station</mat-label>
            <mat-select [value]="stationId()" (selectionChange)="pickStation($event.value)">
              @for (s of floor.stations(); track s.id) {
                <mat-option [value]="s.id">{{ s.name }}</mat-option>
              }
            </mat-select>
          </mat-form-field>
          @if (types().length > 1) {
            <mat-form-field>
              <mat-label>Type</mat-label>
              <mat-select [value]="activity()" (selectionChange)="pickType($event.value)">
                @for (t of types(); track t.code) {
                  <mat-option [value]="t.code">{{ t.code }}</mat-option>
                }
              </mat-select>
            </mat-form-field>
          }
          @if (type()?.usesGames) {
            <mat-form-field>
              <mat-label>Game (optional)</mat-label>
              <mat-select [value]="gameId()" (selectionChange)="gameId.set($event.value)">
                <mat-option [value]="null">No game</mat-option>
                @for (g of games(); track g.id) {
                  <mat-option [value]="g.id">{{ g.name }}</mat-option>
                }
              </mat-select>
            </mat-form-field>
          }
          @if (type()?.usesControllers) {
            <mat-form-field>
              <mat-label>Controllers</mat-label>
              <mat-select [value]="controllers()" (selectionChange)="pickControllers($event.value)">
                @for (n of [1, 2, 3, 4]; track n) {
                  <mat-option [value]="n">{{ n }}</mat-option>
                }
              </mat-select>
            </mat-form-field>
          }
          <div class="grid grid-cols-3 gap-x-3">
            <mat-form-field>
              <mat-label>Date</mat-label>
              <input
                matInput
                type="date"
                [max]="today"
                [value]="day()"
                (change)="setDay($any($event.target).value)"
              />
            </mat-form-field>
            <mat-form-field>
              <mat-label>Start</mat-label>
              <input
                matInput
                type="time"
                [value]="start()"
                (change)="setStart($any($event.target).value)"
              />
            </mat-form-field>
            <mat-form-field>
              <mat-label>End</mat-label>
              <input
                matInput
                type="time"
                [value]="end()"
                (change)="setEnd($any($event.target).value)"
              />
              @if (overnight()) {
                <mat-hint>Next day</mat-hint>
              }
            </mat-form-field>
          </div>
          <p class="-mt-2 text-sm leading-[1.4]" aria-live="polite">
            @if (quoting()) {
              Working out the price…
            } @else if (quoteError()) {
              <span class="text-danger">{{ quoteError() }}</span>
            } @else if (price() !== null) {
              Price: <span class="font-medium tabular-nums">{{ rupees(price()!) }}</span>
            } @else {
              Pick the station and details to see the price.
            }
          </p>
          <mat-form-field>
            <mat-label>Amount paid (₹)</mat-label>
            <input
              matInput
              inputmode="decimal"
              autocomplete="off"
              required
              [value]="amount()"
              (input)="setAmount($any($event.target).value)"
            />
            <mat-hint [class.text-danger]="amountInvalid()">{{ amountHint() }}</mat-hint>
          </mat-form-field>
          <mat-form-field>
            <mat-label>Paid by</mat-label>
            <mat-select [value]="method()" (selectionChange)="method.set($event.value)">
              @for (m of methods; track m) {
                <mat-option [value]="m">{{ methodName(m) }}</mat-option>
              }
            </mat-select>
          </mat-form-field>
          <mat-form-field>
            <mat-label>Reason (required)</mat-label>
            <input
              matInput
              autocomplete="off"
              maxlength="500"
              required
              [value]="reason()"
              (input)="reason.set($any($event.target).value)"
            />
            <mat-hint>Why it was not started on the floor</mat-hint>
          </mat-form-field>
          @if (error()) {
            <p role="alert" class="text-sm leading-[1.3] font-medium text-danger">{{ error() }}</p>
          }
        </div>
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" [disabled]="busy()" (click)="ref.close()">Cancel</button>
        <button mat-flat-button type="submit" [disabled]="busy() || !canSave()">Add bill</button>
      </mat-dialog-actions>
    </form>
  `,
})
export class MissedBillDialog {
  protected readonly ref = inject<MatDialogRef<MissedBillDialog, boolean>>(MatDialogRef);
  protected readonly floor = inject(FloorStore);
  private readonly venue = inject(VenueStore);
  private readonly arena = inject(ArenaContext);
  private readonly api = inject(MissedBillApi);

  protected readonly rupees = formatRupees;
  protected readonly methodName = methodName;
  protected readonly methods = PAY_METHODS;
  protected readonly today = formatIsoDate(inject(Clock).now());

  protected readonly search = signal('');
  protected readonly members = signal<readonly MemberRow[]>([]);
  protected readonly customerId = signal<string | null>(null);
  protected readonly stationId = signal<string | null>(null);
  protected readonly activity = signal<string | null>(null);
  protected readonly gameId = signal<string | null>(null);
  protected readonly controllers = signal<number | null>(null);
  protected readonly day = signal(this.today);
  protected readonly start = signal('18:00');
  protected readonly end = signal('19:00');
  protected readonly method = signal<PayMethod>('cash');
  /** The amount paid as typed; filled in with each new price until staff type in it. */
  protected readonly amount = signal('');
  protected readonly reason = signal('');
  protected readonly price = signal<number | null>(null);
  protected readonly quoting = signal(false);
  protected readonly quoteError = signal('');
  protected readonly error = signal('');
  protected readonly busy = signal(false);

  /** The types the chosen station offers (any active type when it lists none). */
  protected readonly types = computed(() => {
    const active = (this.venue.types() ?? []).filter((t) => t.active);
    const s = this.stationId() ? this.floor.stationById().get(this.stationId()!) : null;
    if (!s) return [];
    return s.activityCodes.length ? active.filter((t) => s.activityCodes.includes(t.code)) : active;
  });
  protected readonly type = computed(
    () => this.types().find((t) => t.code === this.activity()) ?? null,
  );
  protected readonly games = computed(() => this.floor.games().filter((g) => g.active));
  /** Start and end as instants; an end at or before the start is the next day. */
  private readonly window = computed(() => {
    const midnight = istDayStartOf(this.day());
    const at = (hm: string) => {
      const [h, m] = hm.split(':').map(Number);
      return midnight && Number.isFinite(h) && Number.isFinite(m)
        ? new Date(midnight.getTime() + (h * 60 + m) * 60_000)
        : null;
    };
    const s = at(this.start());
    let e = at(this.end());
    if (s && e && e.getTime() <= s.getTime()) e = new Date(e.getTime() + 86_400_000);
    return s && e ? { start: s, end: e } : null;
  });
  protected readonly overnight = computed(() => {
    const w = this.window();
    return !!w && formatIsoDate(w.end) !== formatIsoDate(w.start);
  });
  /** The amount paid in paise (0 allowed), or null while it is not an amount. */
  private readonly paid = computed(() => {
    const t = this.amount().trim();
    return /^0+(\.0{1,2})?$/.test(t) ? 0 : parseRupees(t);
  });
  protected readonly amountInvalid = computed(
    () => this.amount().trim() !== '' && this.paid() === null,
  );
  /** Under the amount: what is wrong with it, else how it compares with today's price. */
  protected readonly amountHint = computed(() => {
    const paid = this.paid();
    const price = this.price();
    if (this.amountInvalid()) return 'Enter the amount paid in rupees, like 120 or 120.50';
    if (paid === null || price === null) return 'What the customer actually paid';
    const diff = paid - price;
    if (diff === 0) return "Same as today's price";
    return `${formatRupees(Math.abs(diff))} ${diff < 0 ? 'less' : 'more'} than today's price`;
  });
  /** Everything a save needs: the details priced, an amount paid and a reason. */
  protected readonly canSave = computed(() => {
    const t = this.type();
    return (
      !!this.stationId() &&
      !!t &&
      !!this.window() &&
      (!t.usesControllers || this.controllers() != null) &&
      !this.quoting() &&
      this.price() !== null &&
      this.paid() !== null &&
      this.reason().trim() !== ''
    );
  });

  /** One Save's ids: a resend after a lost answer replays instead of adding twice. */
  private readonly attempt = new Attempt();
  private quoteSeq = 0;
  private findSeq = 0;
  /** Staff typed the amount: a new price no longer overwrites it. */
  private amountTyped = false;

  constructor() {
    void this.floor.load(['stations', 'games']);
  }

  protected async find(text: string): Promise<void> {
    this.search.set(text);
    const seq = ++this.findSeq;
    if (text.trim().length < 2) {
      this.members.set([]);
      return;
    }
    try {
      const page = await this.floor.members(text.trim(), 8, 0);
      if (seq === this.findSeq) this.members.set(page.rows);
    } catch (e) {
      if (seq === this.findSeq) this.error.set(toAppError(e).message);
    }
  }

  protected pickStation(id: string): void {
    this.stationId.set(id);
    const types = this.types();
    this.activity.set(
      types.some((t) => t.code === this.activity())
        ? this.activity()
        : types.length === 1
          ? types[0].code
          : null,
    );
    this.gameId.set(null);
    this.controllers.set(null);
    void this.requote();
  }

  protected pickType(code: string): void {
    this.activity.set(code);
    this.gameId.set(null);
    this.controllers.set(null);
    void this.requote();
  }

  protected pickControllers(n: number): void {
    this.controllers.set(n);
    void this.requote();
  }

  protected setDay(iso: string): void {
    this.day.set(iso);
    void this.requote();
  }

  protected setStart(hm: string): void {
    this.start.set(hm);
    void this.requote();
  }

  protected setEnd(hm: string): void {
    this.end.set(hm);
    void this.requote();
  }

  /** Clearing the field hands it back to the price. */
  protected setAmount(text: string): void {
    this.amount.set(text);
    this.amountTyped = text.trim() !== '';
  }

  private async requote(): Promise<void> {
    const seq = ++this.quoteSeq;
    const t = this.type();
    const w = this.window();
    this.price.set(null);
    this.quoteError.set('');
    if (!this.amountTyped) this.amount.set('');
    if (!this.stationId() || !t || !w || (t.usesControllers && this.controllers() == null)) {
      this.quoting.set(false);
      return;
    }
    this.quoting.set(true);
    try {
      const total = await this.api.quote(this.arena.current().id, {
        stationId: this.stationId()!,
        activityCode: t.code,
        gameId: null,
        controllers: t.usesControllers ? this.controllers() : null,
        startedAt: w.start,
        endedAt: w.end,
      });
      if (seq === this.quoteSeq) {
        this.price.set(total);
        if (!this.amountTyped) this.amount.set(rupeesText(total));
      }
    } catch (e) {
      if (seq === this.quoteSeq) this.quoteError.set(toAppError(e).message);
    } finally {
      if (seq === this.quoteSeq) this.quoting.set(false);
    }
  }

  protected async save(event: Event): Promise<void> {
    event.preventDefault();
    const t = this.type();
    const w = this.window();
    const price = this.price();
    const paid = this.paid();
    if (!this.stationId() || !t || !w || price === null) {
      this.error.set('Pick the station and details; the price shows once they are complete');
      return;
    }
    if (paid === null) {
      this.error.set('Enter the amount paid in rupees, like 120 or 120.50');
      return;
    }
    if (!this.reason().trim()) {
      this.error.set('Give a reason');
      return;
    }
    this.busy.set(true);
    this.error.set('');
    try {
      await this.api.record(this.arena.current().id, {
        customerId: this.customerId(),
        stationId: this.stationId()!,
        activityCode: t.code,
        gameId: t.usesGames ? this.gameId() : null,
        controllers: t.usesControllers ? this.controllers() : null,
        startedAt: w.start,
        endedAt: w.end,
        method: this.method(),
        billedPaise: price,
        paidPaise: paid,
        reason: this.reason().trim(),
        attempt: this.attempt,
      });
      this.ref.close(true);
    } catch (e) {
      this.attempt.settle(e);
      const err = toAppError(e);
      this.error.set(err.message);
      if (err.code === 'price_mismatch') void this.requote();
    } finally {
      this.busy.set(false);
    }
  }
}
