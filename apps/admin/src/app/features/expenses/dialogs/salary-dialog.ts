import { Component, computed, effect, inject, resource, signal, untracked } from '@angular/core';
import { FormField, form, validate } from '@angular/forms/signals';
import { MatButton } from '@angular/material/button';
import { MatCheckbox } from '@angular/material/checkbox';
import {
  MAT_DIALOG_DATA,
  MatDialogActions,
  MatDialogContent,
  MatDialogRef,
  MatDialogTitle,
} from '@angular/material/dialog';
import { MatFormField, MatHint, MatLabel } from '@angular/material/form-field';
import { MatInput } from '@angular/material/input';
import { MatProgressBar } from '@angular/material/progress-bar';
import { MatOption, MatSelect } from '@angular/material/select';
import { toAppError } from '../../../core/auth/auth-api';
import { Session } from '../../../core/auth/session';
import { Attempt, partlyApplied } from '../../../core/sync/push-ops';
import { Clock } from '../../../core/time/clock';
import { MATERIAL_DEFAULTS } from '../../../shared/material/material-defaults';
import { formatDayYear } from '../../../shared/staff/staff-format';
import { daysBetween, formatIsoDate } from '../../../shared/time/ist';
import { parseRupees, rupeesText } from '../../sales/data/sale.models';
import { isEmployee } from '../../team/data/team.models';
import { ExpensesStore } from '../data/expenses-store';
import {
  MAX_NOTES,
  MAX_SALARY_SPAN,
  PeriodOption,
  SalaryPeriod,
  agreedLabel,
  agreedOn,
  formatAmount,
  monthOf,
  overlapping,
  salaryPeriodName,
  salaryPeriodOptions,
  salaryTitle,
  weekOf,
} from '../data/expense.models';
import {
  PaymentFields,
  PaymentModel,
  injectPayers,
  paymentInput,
  paymentRules,
} from './payment-fields';

export interface SalaryDialogData {
  /** The person (a Salaries row); absent: picked here. */
  readonly staffId?: string;
  /** The month the Salaries tab shows (its first day): preselected for a monthly salary. */
  readonly month?: string;
}

/** Closes with the salary period's id and the snackbar text; undefined when cancelled. */
export interface SalaryDialogResult {
  readonly id: string;
  readonly snack: string;
}

const OTHER = 'other';
const keyOf = (p: { first: string; last: string }) => `${p.first}|${p.last}`;

/**
 * Quick salary entry: pick the staff member and the month (or week, for weekly pay) and the
 * agreed salary in force then fills in the amount owed (editable: a joiner's part month, a
 * deduction, a bonus). With no agreed salary yet, the amount typed can be saved as theirs in the
 * same push (staff_salary.set, then expense.add). A period already recorded is never recorded
 * twice: the dialog says what is owed and paid on it and records a payment of what is left. Pay
 * now records the first payment with it — from the company or an owner's own money; paid before
 * the period ends, it is an advance.
 */
@Component({
  selector: 'app-salary-dialog',
  providers: [MATERIAL_DEFAULTS],
  imports: [
    FormField,
    PaymentFields,
    MatButton,
    MatCheckbox,
    MatDialogTitle,
    MatDialogContent,
    MatDialogActions,
    MatFormField,
    MatHint,
    MatLabel,
    MatInput,
    MatProgressBar,
    MatSelect,
    MatOption,
  ],
  template: `
    <h2 mat-dialog-title>Record salary</h2>
    <form novalidate (submit)="save($event)">
      <mat-dialog-content>
        <div class="flex flex-col gap-5 pt-1">
          <p class="text-sm leading-[1.4] text-muted">
            What a staff member is owed for a month or a week. Pay it now or later, in one payment
            or several; nothing is paid automatically.
          </p>
          <mat-form-field>
            <mat-label>Staff member</mat-label>
            <mat-select [formField]="f.staffId">
              @for (s of staffOptions(); track s.id) {
                <mat-option [value]="s.id"
                  >{{ s.name }}{{ s.active ? '' : ' (inactive)' }}</mat-option
                >
              }
            </mat-select>
            @if (!staffOptions().length) {
              <mat-hint>No staff on the team yet</mat-hint>
            }
          </mat-form-field>
          @if (record.isLoading()) {
            <mat-progress-bar mode="indeterminate" aria-label="Loading their salary records" />
          }
          @if (model().staffId && !latestAgreed()) {
            <mat-form-field>
              <mat-label>Paid</mat-label>
              <mat-select [formField]="f.agreedPeriod">
                <mat-option value="monthly">Monthly</mat-option>
                <mat-option value="weekly">Weekly (Monday to Sunday)</mat-option>
              </mat-select>
              <mat-hint>No agreed salary yet: how often they are paid</mat-hint>
            </mat-form-field>
          }
          <mat-form-field>
            <mat-label>{{ kind() === 'weekly' ? 'Week' : 'Month' }}</mat-label>
            <mat-select [formField]="f.periodKey">
              @for (o of options(); track o.first) {
                <mat-option [value]="key(o)">{{ o.label }}</mat-option>
              }
              <mat-option [value]="other">Other dates…</mat-option>
            </mat-select>
          </mat-form-field>
          @if (model().periodKey === other) {
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <mat-form-field>
                <mat-label>From</mat-label>
                <input matInput type="date" [formField]="f.periodStart" />
              </mat-form-field>
              <mat-form-field>
                <mat-label>To</mat-label>
                <input matInput type="date" [formField]="f.periodEnd" />
              </mat-form-field>
            </div>
          }
          @if (exact(); as e) {
            <div
              role="note"
              class="flex items-start gap-3 rounded-card bg-info-soft px-4 py-3 text-sm leading-[1.45]"
            >
              <span class="icon flex-none text-muted" aria-hidden="true">info</span>
              <span>
                {{ periodName() }} is already recorded: {{ amount(e.amountPaise) }} owed,
                {{ amount(e.paidPaise) }} paid.
                @if (e.balancePaise > 0) {
                  Record a payment of what is left below.
                } @else {
                  It is paid in full.
                }
              </span>
            </div>
          } @else {
            <mat-form-field>
              <mat-label>Salary owed (₹)</mat-label>
              <input matInput inputmode="decimal" autocomplete="off" [formField]="f.amount" />
              <mat-hint>{{ agreedHint() }}</mat-hint>
            </mat-form-field>
            @if (model().staffId && !agreedForSpan() && !record.isLoading()) {
              <mat-checkbox [formField]="f.saveAgreed">
                Save as {{ staffName() }}'s agreed
                {{ kind() === 'weekly' ? 'weekly' : 'monthly' }} salary from {{ day(span().first) }}
              </mat-checkbox>
            }
            <mat-form-field>
              <mat-label>Notes (optional)</mat-label>
              <input matInput autocomplete="off" [formField]="f.notes" />
            </mat-form-field>
            <mat-checkbox [formField]="f.payNow" (change)="payNowChanged($event.checked)">
              Pay now
            </mat-checkbox>
          }
          @if (paying()) {
            <app-payment-fields
              [f]="f.payment"
              [owners]="payers.owners()"
              [defaultPayer]="payers.me()"
              [hint]="dueHint()"
            />
            @if (advance()) {
              <p class="-mt-2 text-[13px] leading-[1.4] text-muted">
                Paid before {{ day(span().last) }}: shown as an advance on this salary.
              </p>
            }
          }
          @if (error()) {
            <p role="alert" class="text-sm leading-[1.3] font-medium text-danger">{{ error() }}</p>
          }
        </div>
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" [disabled]="busy()" (click)="ref.close()">Cancel</button>
        <button mat-flat-button type="submit" [disabled]="busy() || paidInFull()">
          {{ exact() ? 'Record payment' : 'Record salary' }}
        </button>
      </mat-dialog-actions>
    </form>
  `,
})
export class SalaryDialog {
  private readonly data = inject<SalaryDialogData>(MAT_DIALOG_DATA);
  protected readonly ref = inject<MatDialogRef<SalaryDialog, SalaryDialogResult>>(MatDialogRef);
  private readonly store = inject(ExpensesStore);
  private readonly session = inject(Session);
  protected readonly payers = injectPayers();
  private readonly today = formatIsoDate(inject(Clock).now());

  protected readonly other = OTHER;
  protected readonly key = keyOf;
  protected readonly amount = formatAmount;
  protected readonly day = formatDayYear;

  protected readonly model = signal({
    staffId: this.data.staffId ?? '',
    periodKey: '',
    periodStart: '',
    periodEnd: '',
    amount: '',
    saveAgreed: true,
    agreedPeriod: 'monthly' as SalaryPeriod,
    notes: '',
    payNow: false,
    payment: {
      amount: '',
      paidOn: this.today,
      method: 'upi',
      paidFrom: 'company',
      payerId: '',
      note: '',
    } as PaymentModel,
  });

  private readonly staffId = computed(() => this.model().staffId);
  /** Employees not removed (an inactive one may still be owed). */
  protected readonly staffOptions = computed(() =>
    (this.payers.team.staff() ?? [])
      .filter((s) => isEmployee(s) && !s.removed)
      .sort((a, b) => a.name.localeCompare(b.name)),
  );
  protected readonly staffName = computed(
    () => this.staffOptions().find((s) => s.id === this.staffId())?.name ?? '',
  );

  /** The person's salary periods (and agreed salaries), read again after a change. */
  protected readonly record = resource({
    params: () => {
      const staffId = this.staffId();
      return staffId ? { staffId, revision: this.store.revision() } : undefined;
    },
    loader: ({ params }) => this.store.staffRecord(params.staffId),
  });
  private readonly periods = computed(() => {
    const r = this.record.hasValue() ? this.record.value() : undefined;
    return r?.staffId === this.staffId() ? r.periods : null;
  });
  /** Their agreed salaries, newest first. */
  private readonly agreed = computed(() =>
    this.store
      .salaries()
      .filter((s) => s.staffId === this.staffId())
      .sort((a, b) => b.effectiveFrom.localeCompare(a.effectiveFrom)),
  );
  protected readonly latestAgreed = computed(() => this.agreed()[0] ?? null);
  /** Monthly or weekly: their agreed salary's, else the one picked here. */
  protected readonly kind = computed<SalaryPeriod>(
    () => this.latestAgreed()?.period ?? this.model().agreedPeriod,
  );
  protected readonly options = computed(() => salaryPeriodOptions(this.kind(), this.today));
  protected readonly span = computed(
    () => {
      const m = this.model();
      if (m.periodKey === OTHER) return { first: m.periodStart, last: m.periodEnd };
      const [first = '', last = ''] = m.periodKey.split('|');
      return { first, last };
    },
    { equal: (a, b) => a.first === b.first && a.last === b.last },
  );
  protected readonly periodName = computed(() => {
    const s = this.span();
    return s.first && s.last ? salaryPeriodName(s.first, s.last) : 'This period';
  });
  protected readonly agreedForSpan = computed(() =>
    this.span().first ? agreedOn(this.agreed(), this.staffId(), this.span().first) : null,
  );
  protected readonly agreedHint = computed(() => {
    const a = this.agreedForSpan();
    if (a) return `Agreed ${agreedLabel(a)}`;
    return this.latestAgreed() ? 'Their agreed salary starts later' : 'No agreed salary yet';
  });
  private readonly clashes = computed(() => {
    const s = this.span();
    const periods = this.periods();
    if (!periods || !s.first || !s.last) return [];
    return overlapping(periods, this.staffId(), s.first, s.last);
  });
  /** The same period already recorded: pay what is left on it instead. */
  protected readonly exact = computed(() => {
    const [only, ...more] = this.clashes();
    const s = this.span();
    return only && !more.length && only.periodStart === s.first && only.periodEnd === s.last
      ? only
      : null;
  });
  protected readonly paidInFull = computed(() => (this.exact()?.balancePaise ?? 1) <= 0);
  protected readonly paying = computed(
    () => (!!this.exact() && !this.paidInFull()) || (!this.exact() && this.model().payNow),
  );
  /** What a payment may be: the period's balance, or (new) the amount owed. */
  private readonly limit = computed(() => {
    const e = this.exact();
    return e ? e.balancePaise : (parseRupees(this.model().amount) ?? 0);
  });
  protected readonly dueHint = computed(() =>
    this.limit() > 0 ? `${formatAmount(this.limit())} due` : '',
  );
  protected readonly advance = computed(() => {
    const last = this.span().last;
    return !!last && this.model().payment.paidOn < last;
  });

  protected readonly f = form(this.model, (p) => {
    validate(p.staffId, ({ value }) => {
      if (!value()) return { kind: 'staff', message: 'Pick the staff member' };
      const me = this.session.user()?.id;
      const staff = this.staffOptions().find((s) => s.id === value());
      return me && staff?.userId === me
        ? { kind: 'own', message: 'You cannot record your own salary. Ask an owner' }
        : null;
    });
    validate(p.periodKey, ({ value }) => {
      if (!value()) return { kind: 'period', message: 'Pick the month or week' };
      const clash = this.clashes();
      return clash.length && !this.exact()
        ? {
            kind: 'taken',
            message: `That overlaps the salary already recorded for ${clash
              .map((e) => salaryPeriodName(e.periodStart ?? '', e.periodEnd ?? ''))
              .join(', ')}`,
          }
        : null;
    });
    validate(p.periodEnd, ({ value, valueOf }) => {
      if (valueOf(p.periodKey) !== OTHER) return null;
      const span = daysBetween(valueOf(p.periodStart), value());
      if (Number.isNaN(span)) return { kind: 'dates', message: 'Pick the first and last day' };
      if (span < 0) return { kind: 'dates', message: 'The period ends before it starts' };
      return span > MAX_SALARY_SPAN
        ? { kind: 'dates', message: 'A salary period covers at most 62 days' }
        : null;
    });
    validate(p.amount, ({ value }) =>
      !this.exact() && parseRupees(value()) === null
        ? { kind: 'amount', message: 'Enter the salary owed in rupees, like 18000' }
        : null,
    );
    validate(p.notes, ({ value }) =>
      value().trim().length > MAX_NOTES
        ? { kind: 'notes', message: 'Keep the notes to 1,000 characters' }
        : null,
    );
    paymentRules(p.payment, {
      active: () => this.paying(),
      limit: () => this.limit(),
      today: () => this.today,
    });
  });

  protected readonly error = signal('');
  protected readonly busy = signal(false);

  /** One Save's ids: a resend after a lost answer replays instead of recording twice. */
  private attempt = new Attempt();
  /** The amount last filled in from an agreed salary. */
  private filled = '';

  constructor() {
    void this.store.loadMeta();
    // The default period: the Salaries tab's month (monthly), else the current month or week.
    effect(() => {
      const options = this.options();
      const key = untracked(() => this.model().periodKey);
      if (key === OTHER || options.some((o) => keyOf(o) === key)) return;
      untracked(() =>
        this.model.update((m) => ({ ...m, periodKey: keyOf(this.defaultPeriod(options)) })),
      );
    });
    // The agreed salary in force at the period's start fills in the amount owed; an amount typed
    // here (a part month, a deduction) is kept.
    effect(() => {
      const agreed = this.agreedForSpan();
      const text = agreed ? rupeesText(agreed.amountPaise) : '';
      untracked(() => {
        const amount = this.model().amount;
        if (!amount || amount === this.filled) this.model.update((m) => ({ ...m, amount: text }));
        this.filled = text;
      });
    });
    // A period already recorded: its balance is what the payment pays.
    effect(() => {
      const e = this.exact();
      if (!e) return;
      untracked(() => this.setPayment(e.balancePaise));
    });
  }

  protected payNowChanged(on: boolean): void {
    if (on) this.setPayment(parseRupees(this.model().amount) ?? 0);
  }

  protected async save(event: Event): Promise<void> {
    event.preventDefault();
    if (this.record.isLoading()) {
      this.error.set('Still reading their salary records. Try again in a moment');
      return;
    }
    const first = this.f().errorSummary()[0];
    if (first) {
      this.error.set(first.message ?? 'Check the form');
      return;
    }
    const m = this.model();
    const span = this.span();
    const name = this.staffName();
    const exact = this.exact();
    this.busy.set(true);
    this.error.set('');
    try {
      if (exact) {
        const payment = paymentInput(m.payment);
        await this.store.pay(exact, payment, this.attempt);
        this.ref.close({
          id: exact.id,
          snack: `${formatAmount(payment.amountPaise)} paid to ${name} for ${this.periodName()}`,
        });
        return;
      }
      const owed = parseRupees(m.amount) ?? 0;
      const agreed = !this.agreedForSpan() && m.saveAgreed;
      await this.store.add({
        kind: 'salary',
        title: salaryTitle(name, span.first, span.last),
        amountPaise: owed,
        notes: m.notes.trim() || null,
        staffId: m.staffId,
        categoryId: null,
        expenseDate: null,
        periodStart: span.first,
        periodEnd: span.last,
        payment: m.payNow ? paymentInput(m.payment) : null,
        agreed: agreed
          ? {
              staffId: m.staffId,
              effectiveFrom: span.first,
              period: this.kind(),
              amountPaise: owed,
              note: null,
            }
          : null,
        attempt: this.attempt,
      });
      this.ref.close({
        id: this.attempt.id('expense'),
        snack: `${name}'s salary for ${this.periodName()} recorded${m.payNow ? ' · payment recorded' : ''}`,
      });
    } catch (e) {
      // Part of the push applied (the agreed salary): the next Save is a new action.
      if (partlyApplied(e)) this.attempt = new Attempt();
      else this.attempt.settle(e);
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }

  /** The payment's amount and note for this period. */
  private setPayment(paise: number): void {
    const note = `${this.periodName()} salary`;
    this.model.update((m) => ({
      ...m,
      payment: { ...m.payment, amount: paise > 0 ? rupeesText(paise) : '', note },
    }));
  }

  private defaultPeriod(options: readonly PeriodOption[]): PeriodOption {
    const month = this.data.month;
    const current = options[1] ?? options[0];
    if (!month) return current;
    if (this.kind() === 'monthly') {
      return options.find((o) => o.first === monthOf(month).first) ?? current;
    }
    // Weekly: the current week in this month, else the first week that starts in the month.
    const { first, last } = monthOf(month);
    if (this.today >= first && this.today <= last) {
      return options.find((o) => o.first === weekOf(this.today).first) ?? current;
    }
    return [...options].reverse().find((o) => o.first >= first && o.first <= last) ?? current;
  }
}
