import { Component, computed, inject, input, linkedSignal, output, signal } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatChipListbox, MatChipListboxChange, MatChipOption } from '@angular/material/chips';
import { MatDialog } from '@angular/material/dialog';
import { MatFormField, MatHint, MatLabel, MatPrefix, MatSuffix } from '@angular/material/form-field';
import { MatIcon } from '@angular/material/icon';
import { MatInput } from '@angular/material/input';
import { MatOption, MatSelect } from '@angular/material/select';
import { MatSlideToggleChange } from '@angular/material/slide-toggle';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { ConfirmDialog, ConfirmDialogData } from '../../../shared/confirm/confirm-dialog';
import { DetailPane } from '../../../shared/list-detail/detail-pane';
import { DetailRow } from '../../../shared/list-detail/detail-row';
import { DetailSection } from '../../../shared/list-detail/detail-section';
import { ToggleRow } from '../../../shared/list-detail/toggle-row';
import { UnsavedBar } from '../../../shared/list-detail/unsaved-bar';
import { formatRupees } from '../../../shared/money/rupees.pipe';
import { StatusPill } from '../../../shared/status-pill/status-pill';
import { PricingStore } from '../data/pricing-store';
import {
  ADJUST_KINDS,
  PricingRule,
  WEEKDAYS,
  adjustLabel,
  cheapestRate,
  isCalendarDay,
  perLabel,
  rulePrice,
  ruleWhen,
  toTimeInput,
} from '../data/pricing.models';

interface Draft {
  readonly name: string;
  readonly active: boolean;
  readonly days: readonly number[];
  readonly from: string;
  readonly to: string;
  readonly holidayMode: PricingRule['holidayMode'];
  readonly validFrom: string;
  readonly validUntil: string;
  readonly types: readonly string[];
  readonly direction: 'up' | 'down';
  readonly kind: PricingRule['adjustKind'];
  readonly amount: string;
}

const NEW_RULE: Draft = {
  name: '',
  active: true,
  days: [6, 7],
  from: '18:00',
  to: '23:00',
  holidayMode: 'any',
  validFrom: '',
  validUntil: '',
  types: [],
  direction: 'up',
  kind: 'percent',
  amount: '10',
};

function draftOf(r: PricingRule): Draft {
  const amount = Math.abs(r.adjustValue);
  return {
    name: r.name,
    active: r.active,
    days: [...r.days].sort(),
    from: toTimeInput(r.startMin),
    to: toTimeInput(r.endMin),
    holidayMode: r.holidayMode,
    validFrom: r.validFrom ?? '',
    validUntil: r.validUntil ?? '',
    types: [...r.activityCodes].sort(),
    direction: r.adjustValue < 0 ? 'down' : 'up',
    kind: r.adjustKind,
    amount: String(r.adjustKind === 'percent' ? amount : amount / 100),
  };
}

/** "18:30" → 1110; "00:00" as an end is midnight (1440). */
function minutes(value: string, end: boolean): number | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(value);
  if (!m) return null;
  const v = Number(m[1]) * 60 + Number(m[2]);
  if (v < 0 || v >= 1440) return null;
  return end && v === 0 ? 1440 : v;
}

const HOLIDAY_MODES: readonly { key: PricingRule['holidayMode']; label: string }[] = [
  { key: 'any', label: 'Holidays like any other day' },
  { key: 'skip', label: 'Not on holidays' },
  { key: 'only', label: 'Only on holidays' },
];

/** Whether the rule raises or lowers the price (a discount, e.g. happy hours, lowers it). */
const DIRECTIONS: readonly { key: Draft['direction']; label: string }[] = [
  { key: 'down', label: 'Lower by' },
  { key: 'up', label: 'Raise by' },
];

/**
 * A day/time price rule (rule.upsert): when it applies (days, IST window, holidays, dates, types)
 * and how it changes the price (lower or raise it, by a percent or a flat ₹ per hour; happy hours
 * are a rule that lowers it). A session is priced
 * by the rule in force when it starts, for its whole length; when several match, the one higher
 * in the list wins. A live example shows the effect on a real price. `rule` null adds one.
 */
@Component({
  selector: 'app-rule-detail',
  imports: [
    DetailPane,
    DetailSection,
    DetailRow,
    ToggleRow,
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
      [crumb]="'Pricing / ' + (rule()?.name || 'New rule')"
      icon="schedule"
      [heading]="rule()?.name || 'New rule'"
      [subtitle]="summary()"
      (closed)="closed.emit()"
    >
      @if (rule()) {
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
      <app-status-pill chip [tone]="d.active ? 'primary' : 'info'">{{
        d.active ? 'On' : 'Off'
      }}</app-status-pill>

      <app-detail-section heading="Rule">
        <mat-form-field>
          <mat-label>Name</mat-label>
          <input
            matInput
            autocomplete="off"
            maxlength="40"
            placeholder="e.g. Weekend evening"
            [value]="d.name"
            (input)="set({ name: $any($event.target).value })"
          />
        </mat-form-field>
        <app-toggle-row
          label="On"
          sub="Applies to sessions started after you save"
          [checked]="d.active"
          [disabled]="busy() || !canEdit()"
          (changed)="setActive($event)"
        />
      </app-detail-section>

      <app-detail-section
        heading="When"
        subtitle="Judged when a session starts (IST). The whole session is priced by it."
      >
        <mat-chip-listbox
          multiple
          aria-label="Days"
          [value]="d.days"
          (change)="setDays($event)"
        >
          @for (w of weekdays; track w.key) {
            <mat-chip-option [value]="+w.key">{{ w.short }}</mat-chip-option>
          }
        </mat-chip-listbox>
        <!-- items-start: a hint under one field must not stretch the other one's box. -->
        <div class="flex flex-wrap items-start gap-3">
          <mat-form-field class="w-44">
            <mat-label>From</mat-label>
            <input
              matInput
              type="time"
              [value]="d.from"
              (input)="set({ from: $any($event.target).value })"
            />
          </mat-form-field>
          <mat-form-field class="w-44">
            <mat-label>To</mat-label>
            <input
              matInput
              type="time"
              [value]="d.to"
              (input)="set({ to: $any($event.target).value })"
            />
            <mat-hint>00:00 is midnight</mat-hint>
          </mat-form-field>
        </div>
        <mat-form-field>
          <mat-label>Holidays</mat-label>
          <mat-select [value]="d.holidayMode" (selectionChange)="set({ holidayMode: $event.value })">
            @for (h of holidayModes; track h.key) {
              <mat-option [value]="h.key">{{ h.label }}</mat-option>
            }
          </mat-select>
        </mat-form-field>
        <div class="flex flex-wrap items-start gap-3">
          <mat-form-field class="w-44">
            <mat-label>Starts</mat-label>
            <input
              matInput
              type="date"
              [value]="d.validFrom"
              (input)="set({ validFrom: $any($event.target).value })"
            />
            <mat-hint>Blank: already on</mat-hint>
          </mat-form-field>
          <mat-form-field class="w-44">
            <mat-label>Ends</mat-label>
            <input
              matInput
              type="date"
              [value]="d.validUntil"
              (input)="set({ validUntil: $any($event.target).value })"
            />
            <mat-hint>Blank: no end</mat-hint>
          </mat-form-field>
        </div>
      </app-detail-section>

      <app-detail-section heading="Station types" subtitle="None picked: every type.">
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

      <app-detail-section
        heading="Price change"
        subtitle="Lower the price for a discount (e.g. happy hours), or raise it for busy times."
      >
        <div class="flex flex-wrap gap-3">
          <mat-form-field class="w-40">
            <mat-label>Price</mat-label>
            <mat-select [value]="d.direction" (selectionChange)="set({ direction: $event.value })">
              @for (o of directions; track o.key) {
                <mat-option [value]="o.key">{{ o.label }}</mat-option>
              }
            </mat-select>
          </mat-form-field>
          <mat-form-field class="w-44">
            <mat-label>Change by</mat-label>
            <mat-select [value]="d.kind" (selectionChange)="set({ kind: $event.value })">
              @for (k of adjustKinds; track k.key) {
                <mat-option [value]="k.key">{{ k.label }}</mat-option>
              }
            </mat-select>
          </mat-form-field>
          <mat-form-field class="w-36">
            <mat-label>Amount</mat-label>
            @if (d.kind === 'per_hour') {
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
            @if (d.kind === 'percent') {
              <span matTextSuffix>%</span>
            } @else {
              <span matTextSuffix>/hr</span>
            }
          </mat-form-field>
        </div>
        @for (e of examples(); track e.label) {
          <app-detail-row [label]="e.label" [value]="e.value" />
        } @empty {
          <p class="text-[13px] leading-[1.45] text-muted">
            Set a price for a station type to see an example.
          </p>
        }
        @if (error()) {
          <p role="alert" class="text-sm font-medium text-danger">{{ error() }}</p>
        }
      </app-detail-section>

      @if (rule(); as r) {
        <app-detail-section
          heading="Order"
          subtitle="When several rules match a session's start, the one higher in the list wins."
        >
          <div class="flex flex-wrap items-center gap-3">
            <span class="text-sm">{{ position() + 1 }} of {{ store.rules().length }}</span>
            <button
              mat-stroked-button
              type="button"
              [disabled]="busy() || !canEdit() || position() === 0"
              (click)="move(-1)"
            >
              <mat-icon aria-hidden="true">arrow_upward</mat-icon>Move up
            </button>
            <button
              mat-stroked-button
              type="button"
              [disabled]="busy() || !canEdit() || position() === store.rules().length - 1"
              (click)="move(1)"
            >
              <mat-icon aria-hidden="true">arrow_downward</mat-icon>Move down
            </button>
          </div>
        </app-detail-section>
      }

      @if (dirty() || !rule()) {
        <app-unsaved-bar footer [busy]="busy()" (discard)="discard()" (save)="save()" />
      }
    </app-detail-pane>
  `,
})
export class RuleDetail {
  protected readonly canEdit = inject(ArenaContext).canEdit;
  protected readonly store = inject(PricingStore);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);

  /** null: a new rule. */
  readonly rule = input.required<PricingRule | null>();
  readonly closed = output<void>();
  /** A new rule was saved (the page selects it). */
  readonly created = output<string>();

  protected readonly weekdays = WEEKDAYS;
  protected readonly holidayModes = HOLIDAY_MODES;
  protected readonly directions = DIRECTIONS;
  protected readonly adjustKinds = ADJUST_KINDS;
  protected readonly types = computed(() => this.store.types().filter((t) => t.active));

  private readonly saved = computed(() => {
    const r = this.rule();
    return r ? draftOf(r) : NEW_RULE;
  });
  protected readonly draft = linkedSignal<Draft>(() => this.saved());
  protected readonly dirty = computed(
    () => JSON.stringify(this.draft()) !== JSON.stringify(this.saved()),
  );
  protected readonly busy = signal(false);
  protected readonly error = signal('');
  protected readonly position = computed(() =>
    this.store.rules().findIndex((r) => r.id === this.rule()?.id),
  );

  /** The draft as a rule, or why it can't be one. */
  private readonly built = computed<PricingRule | string>(() => {
    const d = this.draft();
    const name = d.name.trim();
    if (!name || name.length > 40) return 'Give the rule a name of up to 40 characters';
    if (!d.days.length) return 'Pick at least one day';
    const start = minutes(d.from, false);
    const end = minutes(d.to, true);
    if (start == null || end == null || end <= start) return 'Pick an end time after the start';
    if (d.validFrom && !isCalendarDay(d.validFrom)) return 'Check the start date';
    if (d.validUntil && !isCalendarDay(d.validUntil)) return 'Check the end date';
    if (d.validFrom && d.validUntil && d.validUntil < d.validFrom) {
      return 'The end date is before the start date';
    }
    const amount = Number(d.amount);
    const sign = d.direction === 'down' ? -1 : 1;
    let value: number;
    if (d.kind === 'percent') {
      if (!Number.isInteger(amount) || amount < 1 || amount > (sign < 0 ? 100 : 500)) {
        return sign < 0 ? 'Lower by 1 to 100%' : 'Raise by 1 to 500%';
      }
      value = sign * amount;
    } else {
      const paise = Math.round(amount * 100);
      if (!(paise >= 1) || paise > 10_000_000 || Math.abs(amount * 100 - paise) > 1e-6) {
        return 'Enter a flat ₹ per hour, e.g. 30 or 12.50';
      }
      value = sign * paise;
    }
    const r = this.rule();
    return {
      id: r?.id ?? '',
      name,
      priority: r?.priority ?? Math.max(0, ...this.store.rules().map((x) => x.priority)) + 1,
      active: d.active,
      days: [...d.days].sort(),
      startMin: start,
      endMin: end,
      holidayMode: d.holidayMode,
      validFrom: d.validFrom || null,
      validUntil: d.validUntil || null,
      activityCodes: [...d.types],
      adjustKind: d.kind,
      adjustValue: value,
    };
  });

  protected readonly summary = computed(() => {
    const b = this.built();
    return typeof b === 'string' ? 'Not saved yet' : `${ruleWhen(b)} · ${adjustLabel(b)}`;
  });

  /** "PlayStation 5 · ₹150 → ₹180 per hour" for each type it covers (the cheapest price). */
  protected readonly examples = computed(() => {
    const b = this.built();
    if (typeof b === 'string') return [];
    const covered = this.types().filter(
      (t) => !b.activityCodes.length || b.activityCodes.includes(t.code),
    );
    return covered.flatMap((t) => {
      const base = cheapestRate(t, this.store.rates());
      if (!base) return [];
      const per = perLabel(base.unitMinutes);
      const after = rulePrice(base.pricePaise, base.unitMinutes, b);
      return [
        {
          label: t.name,
          value: `${formatRupees(base.pricePaise)} → ${formatRupees(after)} ${per}`,
        },
      ];
    });
  });

  protected set(change: Partial<Draft>): void {
    this.draft.update((d) => ({ ...d, ...change }));
  }

  protected setDays(event: MatChipListboxChange): void {
    this.set({ days: ((event.value as number[] | null) ?? []).map(Number).sort() });
  }

  /** On / off saves straight away for a saved rule; a new one keeps it in the draft. */
  protected async setActive(event: MatSlideToggleChange): Promise<void> {
    const r = this.rule();
    if (!r) {
      this.set({ active: event.checked });
      return;
    }
    this.busy.set(true);
    try {
      await this.store.saveRule({ ...r, active: event.checked });
      this.say(event.checked ? `${r.name} is on` : `${r.name} is off`);
    } catch (e) {
      event.source.checked = !event.checked;
      this.say(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected discard(): void {
    if (!this.rule()) {
      this.closed.emit();
      return;
    }
    this.draft.set(this.saved());
    this.error.set('');
  }

  protected async save(): Promise<void> {
    const b = this.built();
    if (typeof b === 'string') {
      this.error.set(b);
      return;
    }
    const rule = { ...b, id: b.id || crypto.randomUUID() };
    this.busy.set(true);
    this.error.set('');
    try {
      await this.store.saveRule(rule);
      this.say(`${rule.name} saved · new sessions use it`);
      if (!this.rule()) this.created.emit(rule.id);
    } catch (e) {
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async move(step: -1 | 1): Promise<void> {
    const ids = this.store.rules().map((r) => r.id);
    const i = this.position();
    const j = i + step;
    if (this.busy() || i < 0 || j < 0 || j >= ids.length) return;
    [ids[i], ids[j]] = [ids[j], ids[i]];
    this.busy.set(true);
    try {
      await this.store.reorderRules(ids);
      this.say('Order saved · new sessions use it');
    } catch (e) {
      this.say(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected remove(): void {
    const r = this.rule();
    if (!r) return;
    this.dialog
      .open<ConfirmDialog, ConfirmDialogData, boolean>(ConfirmDialog, {
        data: {
          title: `Delete ${r.name}?`,
          message:
            'New sessions stop using it. Sessions already started keep the price they started with.',
          confirm: 'Delete',
          danger: true,
        },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe(async (yes) => {
        if (!yes) return;
        this.busy.set(true);
        try {
          await this.store.deleteRule(r.id);
          this.say(`${r.name} deleted`);
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
