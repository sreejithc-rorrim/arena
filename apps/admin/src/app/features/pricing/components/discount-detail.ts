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
import { MatChipListbox, MatChipOption } from '@angular/material/chips';
import { MatDialog } from '@angular/material/dialog';
import {
  MatFormField,
  MatHint,
  MatLabel,
  MatPrefix,
  MatSuffix,
} from '@angular/material/form-field';
import { MatIcon } from '@angular/material/icon';
import { MatInput } from '@angular/material/input';
import { MatOption, MatSelect } from '@angular/material/select';
import { MatSlideToggleChange } from '@angular/material/slide-toggle';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { Clock } from '../../../core/time/clock';
import { ConfirmDialog, ConfirmDialogData } from '../../../shared/confirm/confirm-dialog';
import { DetailPane } from '../../../shared/list-detail/detail-pane';
import { DetailSection } from '../../../shared/list-detail/detail-section';
import { LineRow } from '../../../shared/list-detail/line-row';
import { ToggleRow } from '../../../shared/list-detail/toggle-row';
import { UnsavedBar } from '../../../shared/list-detail/unsaved-bar';
import { formatRupees } from '../../../shared/money/rupees.pipe';
import { StatTile } from '../../../shared/stat-tile/stat-tile';
import { StatusPill } from '../../../shared/status-pill/status-pill';
import { formatDate, formatIsoDate, formatTime } from '../../../shared/time/ist';
import { billRef } from '../../sales/data/sale.models';
import { PricingStore } from '../data/pricing-store';
import {
  Discount,
  DiscountUse,
  discountState,
  discountValueLabel,
  isCalendarDay,
} from '../data/pricing.models';
import { COUPON_STATE } from './discount-state';

interface Draft {
  readonly name: string;
  readonly code: string;
  readonly valueKind: Discount['valueKind'];
  readonly amount: string;
  readonly cap: string;
  readonly minBill: string;
  readonly types: readonly string[];
  readonly validFrom: string;
  readonly validUntil: string;
  readonly maxUses: string;
  readonly active: boolean;
}

const rupees = (paise: number | null) => (paise == null ? '' : String(paise / 100));

function draftOf(d: Discount): Draft {
  return {
    name: d.name,
    code: d.code ?? '',
    valueKind: d.valueKind,
    amount: d.valueKind === 'percent' ? String(d.value) : rupees(d.value),
    cap: rupees(d.maxDiscountPaise),
    minBill: rupees(d.minBillPaise),
    types: [...d.activityCodes].sort(),
    validFrom: d.validFrom ? formatIsoDate(d.validFrom) : '',
    validUntil: d.validUntil ? formatIsoDate(d.validUntil) : '',
    maxUses: d.maxUses == null ? '' : String(d.maxUses),
    active: d.active,
  };
}

const blank = (kind: Discount['kind']): Draft => ({
  name: '',
  code: '',
  valueKind: 'percent',
  amount: '10',
  cap: '',
  minBill: '',
  types: [],
  validFrom: '',
  validUntil: '',
  maxUses: kind === 'coupon' ? '100' : '',
  active: true,
});

/** Whole or 2-decimal rupees → paise; '' → null; anything else → NaN. */
function paise(value: string): number | null {
  if (!value.trim()) return null;
  const n = Number(value);
  const p = Math.round(n * 100);
  return Number.isFinite(n) && n >= 0 && Math.abs(n * 100 - p) < 1e-6 ? p : NaN;
}

/** Usage rows per page. */
const USES_PAGE = 20;

/**
 * A preset discount (staff pick it at checkout) or a coupon (staff type its code): its value,
 * cap, minimum bill, station types, dates (a coupon's expiry) and use limit, and — read when it is
 * opened — which bills used it. A used one can be turned off but not deleted, so its bills keep
 * their record. `discount` null adds one of `kind`.
 */
@Component({
  selector: 'app-discount-detail',
  imports: [
    DetailPane,
    DetailSection,
    LineRow,
    ToggleRow,
    StatTile,
    StatusPill,
    UnsavedBar,
    MatButton,
    MatIcon,
    MatChipListbox,
    MatChipOption,
    MatFormField,
    MatLabel,
    MatHint,
    MatPrefix,
    MatSuffix,
    MatInput,
    MatSelect,
    MatOption,
  ],
  template: `
    @let d = draft();
    <app-detail-pane
      [crumb]="'Pricing / ' + (coupon() ? 'Coupons / ' : 'Discounts / ') + heading()"
      [icon]="coupon() ? 'confirmation_number' : 'percent'"
      [heading]="heading()"
      [subtitle]="subtitle()"
      (closed)="closed.emit()"
    >
      @if (discount()) {
        <div actions class="arena-compact flex gap-2">
          <button
            mat-button
            type="button"
            class="danger-action"
            [disabled]="busy() || !canEdit()"
            (click)="remove()"
          >
            <mat-icon aria-hidden="true">delete</mat-icon>Delete
          </button>
        </div>
      }
      <app-status-pill chip [tone]="state().tone">{{ state().label }}</app-status-pill>

      @if (discount()) {
        <div stats class="grid grid-cols-[repeat(auto-fit,minmax(130px,1fr))] gap-3">
          <app-stat-tile label="Used on bills" [value]="usedValue()" />
          <app-stat-tile label="Value" [value]="valueLabel()" />
          <app-stat-tile [label]="coupon() ? 'Expires' : 'Ends'" [value]="untilLabel()" />
        </div>
      }

      <app-detail-section [heading]="coupon() ? 'Coupon' : 'Discount'">
        <mat-form-field>
          <mat-label>Name</mat-label>
          <input
            matInput
            autocomplete="off"
            maxlength="40"
            [placeholder]="coupon() ? 'e.g. Diwali offer' : 'e.g. Student'"
            [value]="d.name"
            (input)="set({ name: $any($event.target).value })"
          />
          <mat-hint>{{
            coupon() ? 'For you; staff type the code' : 'What staff pick at checkout'
          }}</mat-hint>
        </mat-form-field>
        @if (coupon()) {
          <mat-form-field>
            <mat-label>Code</mat-label>
            <input
              matInput
              autocomplete="off"
              maxlength="20"
              class="uppercase"
              placeholder="e.g. DIWALI20"
              [value]="d.code"
              (input)="set({ code: $any($event.target).value })"
            />
            <mat-hint>3–20 letters, digits, - or _</mat-hint>
          </mat-form-field>
        }
        <app-toggle-row
          label="On"
          [sub]="coupon() ? 'Staff can use the code' : 'Staff can pick it'"
          [checked]="d.active"
          [disabled]="busy() || !canEdit()"
          (changed)="setActive($event)"
        />
      </app-detail-section>

      <app-detail-section heading="Value" subtitle="Taken off the bill before cash rounding.">
        <div class="flex flex-wrap gap-3">
          <mat-form-field class="w-40">
            <mat-label>Off by</mat-label>
            <mat-select [value]="d.valueKind" (selectionChange)="set({ valueKind: $event.value })">
              <mat-option value="percent">Percent</mat-option>
              <mat-option value="flat">Rupees</mat-option>
            </mat-select>
          </mat-form-field>
          <mat-form-field class="w-36">
            <mat-label>Amount</mat-label>
            @if (d.valueKind === 'flat') {
              <span matTextPrefix>₹&nbsp;</span>
            }
            <input
              matInput
              type="number"
              inputmode="decimal"
              min="0"
              [value]="d.amount"
              (input)="set({ amount: $any($event.target).value })"
            />
            @if (d.valueKind === 'percent') {
              <span matTextSuffix>%</span>
            }
          </mat-form-field>
          @if (d.valueKind === 'percent') {
            <mat-form-field class="w-40">
              <mat-label>At most</mat-label>
              <span matTextPrefix>₹&nbsp;</span>
              <input
                matInput
                type="number"
                inputmode="decimal"
                min="0"
                [value]="d.cap"
                (input)="set({ cap: $any($event.target).value })"
              />
              <mat-hint>Blank: no limit</mat-hint>
            </mat-form-field>
          }
          <mat-form-field class="w-40">
            <mat-label>Bill of at least</mat-label>
            <span matTextPrefix>₹&nbsp;</span>
            <input
              matInput
              type="number"
              inputmode="decimal"
              min="0"
              [value]="d.minBill"
              (input)="set({ minBill: $any($event.target).value })"
            />
            <mat-hint>Blank: any bill</mat-hint>
          </mat-form-field>
        </div>
      </app-detail-section>

      <app-detail-section
        heading="Station types"
        subtitle="Taken off the part of the bill for these types. None picked: the whole bill."
      >
        <mat-chip-listbox
          multiple
          aria-label="Station types"
          [value]="d.types"
          (change)="set({ types: $event.value ?? [] })"
        >
          @for (t of types(); track t.code) {
            <mat-chip-option [value]="t.code">{{ t.name }}</mat-chip-option>
          }
        </mat-chip-listbox>
      </app-detail-section>

      <app-detail-section [heading]="coupon() ? 'Validity and limit' : 'Dates'">
        <div class="flex flex-wrap gap-3">
          <mat-form-field class="w-44">
            <mat-label>Starts</mat-label>
            <input
              matInput
              type="date"
              [value]="d.validFrom"
              (input)="set({ validFrom: $any($event.target).value })"
            />
            <mat-hint>Blank: already valid</mat-hint>
          </mat-form-field>
          <mat-form-field class="w-44">
            <mat-label>{{ coupon() ? 'Expires after' : 'Ends after' }}</mat-label>
            <input
              matInput
              type="date"
              [value]="d.validUntil"
              (input)="set({ validUntil: $any($event.target).value })"
            />
            <mat-hint>Blank: never</mat-hint>
          </mat-form-field>
          <mat-form-field class="w-44">
            <mat-label>Uses at most</mat-label>
            <input
              matInput
              type="number"
              inputmode="numeric"
              min="1"
              [value]="d.maxUses"
              (input)="set({ maxUses: $any($event.target).value })"
            />
            <mat-hint>Bills; blank: unlimited</mat-hint>
          </mat-form-field>
        </div>
        @if (error()) {
          <p role="alert" class="text-sm font-medium text-danger">{{ error() }}</p>
        }
      </app-detail-section>

      @if (discount()) {
        <app-detail-section
          heading="Used on"
          subtitle="Newest first; voided bills no longer count."
        >
          @if (usage.error()) {
            <p role="alert" class="text-[13px] leading-[1.45] text-danger">
              The bills couldn't load.
            </p>
          } @else if (!usage.hasValue()) {
            <p class="text-[13px] leading-[1.45] text-muted">Loading…</p>
          } @else {
            @for (u of uses(); track u.billId) {
              <app-line-row
                [title]="u.customer ?? 'Guest'"
                [subtitle]="useLine(u)"
                [value]="'−' + rupeesOf(u.amountPaise)"
                link="/sales"
                [queryParams]="{ id: u.billId }"
              />
            } @empty {
              <p class="text-[13px] leading-[1.45] text-muted">Not used yet.</p>
            }
            @if (next()) {
              <div>
                <button mat-stroked-button type="button" [disabled]="moreBusy()" (click)="more()">
                  Show more
                </button>
              </div>
            }
          }
        </app-detail-section>
      }

      @if (dirty() || !discount()) {
        <app-unsaved-bar footer [busy]="busy()" (discard)="discard()" (save)="save()" />
      }
    </app-detail-pane>
  `,
})
export class DiscountDetail {
  protected readonly canEdit = inject(ArenaContext).canEdit;
  private readonly store = inject(PricingStore);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);
  private readonly now = inject(Clock).now();

  /** null: a new one of `kind`. */
  readonly discount = input.required<Discount | null>();
  readonly kind = input<Discount['kind']>('preset');
  readonly closed = output<void>();
  readonly created = output<string>();

  protected readonly rupeesOf = formatRupees;
  protected readonly coupon = computed(() => (this.discount()?.kind ?? this.kind()) === 'coupon');
  protected readonly types = computed(() => this.store.types().filter((t) => t.active));

  private readonly saved = computed(() => {
    const d = this.discount();
    return d ? draftOf(d) : blank(this.kind());
  });
  protected readonly draft = linkedSignal<Draft>(() => this.saved());
  protected readonly dirty = computed(
    () => JSON.stringify(this.draft()) !== JSON.stringify(this.saved()),
  );
  protected readonly busy = signal(false);
  protected readonly error = signal('');

  protected readonly heading = computed(() => {
    const d = this.discount();
    if (!d) return this.coupon() ? 'New coupon' : 'New discount';
    return d.kind === 'coupon' ? (d.code ?? d.name) : d.name;
  });
  protected readonly subtitle = computed(() => {
    const d = this.discount();
    if (!d) return 'Not saved yet';
    return d.kind === 'coupon' ? `${d.name} · ${discountValueLabel(d)}` : discountValueLabel(d);
  });
  protected readonly valueLabel = computed(() => {
    const d = this.discount();
    return d ? discountValueLabel(d) : '—';
  });
  protected readonly untilLabel = computed(() => {
    const until = this.discount()?.validUntil;
    return until ? formatDate(until) : 'Never';
  });

  /** The first page of the bills that used it, read when it is opened. */
  protected readonly usage = resource({
    params: () => ({ id: this.discount()?.id ?? null }),
    loader: ({ params }) =>
      params.id
        ? this.store.discountUsage(params.id, USES_PAGE)
        : Promise.resolve({ uses: 0, activeUses: 0, rows: [], next: null }),
  });
  /** Pages read after the first ("Show more"). */
  private readonly extra = linkedSignal<{ rows: readonly DiscountUse[]; next: string | null }>(
    () => ({
      rows: [],
      next: this.usage.hasValue() ? this.usage.value().next : null,
    }),
  );
  protected readonly uses = computed(() => [
    ...(this.usage.hasValue() ? this.usage.value().rows : []),
    ...this.extra().rows,
  ]);
  protected readonly next = computed(() => this.extra().next);
  protected readonly moreBusy = signal(false);
  protected readonly usedValue = computed(() => {
    if (!this.usage.hasValue()) return '…';
    const u = this.usage.value();
    const max = this.discount()?.maxUses;
    return max != null ? `${u.activeUses} of ${max}` : String(u.activeUses);
  });
  protected readonly state = computed(() => {
    const d = this.discount();
    if (!d) return { label: 'New', tone: 'info' as const };
    const used = this.usage.hasValue() ? this.usage.value().activeUses : undefined;
    return COUPON_STATE[discountState(d, this.now, used)];
  });

  protected useLine(u: DiscountUse): string {
    const parts = [billRef(u.billId), `${formatDate(u.at)}, ${formatTime(u.at)}`];
    if (u.status === 'voided') parts.push('Void');
    else if (u.billedPaise != null) parts.push(`billed ${formatRupees(u.billedPaise)}`);
    return parts.join(' · ');
  }

  protected async more(): Promise<void> {
    const id = this.discount()?.id;
    const cursor = this.next();
    if (!id || !cursor) return;
    this.moreBusy.set(true);
    try {
      const page = await this.store.discountUsage(id, USES_PAGE, cursor);
      this.extra.update((x) => ({ rows: [...x.rows, ...page.rows], next: page.next }));
    } catch (e) {
      this.say(toAppError(e).message);
    } finally {
      this.moreBusy.set(false);
    }
  }

  protected set(change: Partial<Draft>): void {
    this.draft.update((d) => ({ ...d, ...change }));
  }

  /** On / off saves straight away for a saved one; a new one keeps it in the draft. */
  protected async setActive(event: MatSlideToggleChange): Promise<void> {
    const d = this.discount();
    if (!d) {
      this.set({ active: event.checked });
      return;
    }
    this.busy.set(true);
    try {
      await this.store.setDiscountActive(d.id, event.checked);
      this.say(`${this.heading()} is ${event.checked ? 'on' : 'off'}`);
    } catch (e) {
      event.source.checked = !event.checked;
      this.say(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected discard(): void {
    if (!this.discount()) {
      this.closed.emit();
      return;
    }
    this.draft.set(this.saved());
    this.error.set('');
  }

  /** The draft as a discount, or why it can't be one. */
  private build(): Discount | string {
    const d = this.draft();
    const kind = this.discount()?.kind ?? this.kind();
    const name = d.name.trim();
    if (!name || name.length > 40) return 'Give it a name of up to 40 characters';
    const code = d.code.trim().toUpperCase();
    if (kind === 'coupon' && !/^[A-Z0-9_-]{3,20}$/.test(code)) {
      return 'The code is 3–20 letters, digits, - or _';
    }
    let value: number;
    if (d.valueKind === 'percent') {
      value = Number(d.amount);
      if (!Number.isInteger(value) || value < 1 || value > 100) return 'A percent is 1 to 100';
    } else {
      const p = paise(d.amount);
      if (p == null || Number.isNaN(p) || p < 1) return 'Enter the rupees off, e.g. 50';
      value = p;
    }
    const cap = d.valueKind === 'percent' ? paise(d.cap) : null;
    const minBill = paise(d.minBill);
    if (Number.isNaN(cap) || Number.isNaN(minBill) || cap === 0) {
      return 'Check the rupee amounts';
    }
    const maxUses = d.maxUses.trim() ? Number(d.maxUses) : null;
    if (maxUses != null && (!Number.isInteger(maxUses) || maxUses < 1)) {
      return 'Uses is a whole number of 1 or more';
    }
    for (const day of [d.validFrom, d.validUntil]) {
      if (day && !isCalendarDay(day)) return 'Check the dates';
    }
    if (d.validFrom && d.validUntil && d.validUntil < d.validFrom) {
      return 'It ends before it starts';
    }
    return {
      id: this.discount()?.id ?? crypto.randomUUID(),
      kind,
      name,
      code: kind === 'coupon' ? code : null,
      valueKind: d.valueKind,
      value,
      maxDiscountPaise: cap,
      minBillPaise: minBill,
      activityCodes: [...d.types],
      // Whole IST days: from its first moment to its last.
      validFrom: d.validFrom ? new Date(`${d.validFrom}T00:00:00+05:30`).toISOString() : null,
      validUntil: d.validUntil ? new Date(`${d.validUntil}T23:59:59+05:30`).toISOString() : null,
      maxUses,
      active: d.active,
    };
  }

  protected async save(): Promise<void> {
    const built = this.build();
    if (typeof built === 'string') {
      this.error.set(built);
      return;
    }
    const isNew = !this.discount();
    this.busy.set(true);
    this.error.set('');
    try {
      await this.store.saveDiscount(built);
      this.say(`${built.code ?? built.name} saved`);
      if (isNew) this.created.emit(built.id);
    } catch (e) {
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected remove(): void {
    const d = this.discount();
    if (!d) return;
    const used = this.usage.hasValue() ? this.usage.value().uses : 0;
    const data: ConfirmDialogData = used
      ? {
          title: `${this.heading()} can't be deleted`,
          message: `${used} bill${used === 1 ? '' : 's'} used it and keep it on record. Turn it off instead: staff can no longer use it.`,
        }
      : {
          title: `Delete ${this.heading()}?`,
          message: 'No bill has used it yet, so it is deleted for good.',
          confirm: 'Delete',
          danger: true,
        };
    this.dialog
      .open<ConfirmDialog, ConfirmDialogData, boolean>(ConfirmDialog, {
        data,
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe(async (yes) => {
        if (!yes || used) return;
        this.busy.set(true);
        try {
          await this.store.deleteDiscount(d.id);
          this.say(`${this.heading()} deleted`);
          this.closed.emit();
        } catch (e) {
          this.error.set(toAppError(e).message);
        } finally {
          this.busy.set(false);
        }
      });
  }

  private say(message: string): void {
    this.snack.open(message, undefined, { duration: 3200 });
  }
}
