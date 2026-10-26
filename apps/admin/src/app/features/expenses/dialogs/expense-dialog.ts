import { Component, computed, inject, signal } from '@angular/core';
import { FormField, form, validate } from '@angular/forms/signals';
import { MatButton } from '@angular/material/button';
import { MatButtonToggle, MatButtonToggleGroup } from '@angular/material/button-toggle';
import {
  MAT_DIALOG_DATA,
  MatDialogActions,
  MatDialogContent,
  MatDialogRef,
  MatDialogTitle,
} from '@angular/material/dialog';
import { MatFormField, MatHint, MatLabel } from '@angular/material/form-field';
import { MatInput } from '@angular/material/input';
import { MatOption, MatSelect } from '@angular/material/select';
import { toAppError } from '../../../core/auth/auth-api';
import { Attempt } from '../../../core/sync/push-ops';
import { Clock } from '../../../core/time/clock';
import { MATERIAL_DEFAULTS } from '../../../shared/material/material-defaults';
import { addDays, daysBetween, formatIsoDate, istDayStartOf } from '../../../shared/time/ist';
import { parseRupees, rupeesText } from '../../sales/data/sale.models';
import { ExpenseInput } from '../data/expenses-api';
import { ExpensesStore } from '../data/expenses-store';
import {
  Expense,
  MAX_NOTES,
  MAX_SALARY_SPAN,
  MAX_TITLE,
  formatAmount,
  missingStandard,
  nextSortOrder,
} from '../data/expense.models';
import {
  PaymentFields,
  PaymentModel,
  injectPayers,
  paymentInput,
  paymentRules,
} from './payment-fields';

export interface ExpenseDialogData {
  /** Absent: add a running cost. Present: edit it (a cost or a salary period). */
  readonly expense?: Expense;
}

/** Closes with the expense's id and the snackbar text; undefined when cancelled. */
export interface ExpenseDialogResult {
  readonly id: string;
  readonly snack: string;
}

type Paid = 'no' | 'full' | 'part';

/**
 * Add a running cost (category, title, amount, day, optional staff member and notes), paid or
 * not, in one push (expense.add with its payment); or edit an expense's details
 * (expense.update, audited with the fields that changed). An edit never touches payments and
 * never takes the amount below what is already paid: payments are corrected by reversing them.
 */
@Component({
  selector: 'app-expense-dialog',
  providers: [MATERIAL_DEFAULTS],
  imports: [
    FormField,
    PaymentFields,
    MatButton,
    MatButtonToggleGroup,
    MatButtonToggle,
    MatDialogTitle,
    MatDialogContent,
    MatDialogActions,
    MatFormField,
    MatHint,
    MatLabel,
    MatInput,
    MatSelect,
    MatOption,
  ],
  template: `
    <h2 mat-dialog-title>{{ editing ? 'Edit expense' : 'Add expense' }}</h2>
    <form novalidate (submit)="save($event)">
      <mat-dialog-content>
        <div class="flex flex-col gap-5 pt-1">
          @if (salary) {
            <p class="text-sm leading-[1.4] text-muted">
              {{ original?.staffName }}'s salary. Payments stay as recorded: reverse one to correct
              it.
            </p>
          } @else {
            <mat-form-field>
              <mat-label>Category</mat-label>
              <mat-select
                [formField]="f.categoryId"
                (selectionChange)="categoryPicked($event.value)"
              >
                @for (c of categoryOptions(); track c.id) {
                  <mat-option [value]="c.id"
                    >{{ c.name }}{{ c.active ? '' : ' (turned off)' }}</mat-option
                  >
                }
              </mat-select>
            </mat-form-field>
            @if (store.categories()?.length === 0) {
              <div
                class="-mt-2 flex flex-wrap items-center gap-2 text-[13px] leading-[1.35] text-muted"
              >
                <span>No categories yet.</span>
                <button mat-button type="button" [disabled]="busy()" (click)="addStandard()">
                  Add the standard ones
                </button>
              </div>
            }
          }
          <mat-form-field>
            <mat-label>Title</mat-label>
            <input
              matInput
              autocomplete="off"
              placeholder="e.g. Electricity bill, October"
              [formField]="f.title"
            />
          </mat-form-field>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <mat-form-field>
              <mat-label>Amount (₹)</mat-label>
              <input matInput inputmode="decimal" autocomplete="off" [formField]="f.amount" />
              @if (paidHint()) {
                <mat-hint>{{ paidHint() }}</mat-hint>
              }
            </mat-form-field>
            @if (!salary) {
              <mat-form-field>
                <mat-label>Date</mat-label>
                <input matInput type="date" [formField]="f.expenseDate" />
                <mat-hint>The day it belongs to (IST)</mat-hint>
              </mat-form-field>
            }
          </div>
          @if (salary) {
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <mat-form-field>
                <mat-label>Period from</mat-label>
                <input matInput type="date" [formField]="f.periodStart" />
              </mat-form-field>
              <mat-form-field>
                <mat-label>Period to</mat-label>
                <input matInput type="date" [formField]="f.periodEnd" />
              </mat-form-field>
            </div>
          } @else {
            <mat-form-field>
              <mat-label>Staff member (optional)</mat-label>
              <mat-select [formField]="f.staffId">
                <mat-option value="">None</mat-option>
                @for (s of staffOptions(); track s.id) {
                  <mat-option [value]="s.id">{{ s.name }}</mat-option>
                }
              </mat-select>
              <mat-hint>Who the cost was for, if anyone (a uniform, a training)</mat-hint>
            </mat-form-field>
          }
          <mat-form-field>
            <mat-label>Notes (optional)</mat-label>
            <textarea matInput rows="2" [formField]="f.notes"></textarea>
          </mat-form-field>
          @if (!editing) {
            <div class="flex flex-col gap-2">
              <span id="expense-paid" class="text-[13px] leading-none font-medium text-muted"
                >Paid?</span
              >
              <mat-button-toggle-group
                class="arena-seg self-start"
                hideSingleSelectionIndicator
                aria-labelledby="expense-paid"
                [formField]="f.paid"
              >
                <mat-button-toggle value="no">Not yet</mat-button-toggle>
                <mat-button-toggle value="full">In full</mat-button-toggle>
                <mat-button-toggle value="part">Part paid</mat-button-toggle>
              </mat-button-toggle-group>
            </div>
            @if (model().paid !== 'no') {
              <app-payment-fields
                [f]="f.payment"
                [owners]="payers.owners()"
                [defaultPayer]="payers.me()"
                [showAmount]="model().paid === 'part'"
              />
            }
          }
          @if (error()) {
            <p role="alert" class="text-sm leading-[1.3] font-medium text-danger">{{ error() }}</p>
          }
        </div>
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" [disabled]="busy()" (click)="ref.close()">Cancel</button>
        <button mat-flat-button type="submit" [disabled]="busy()">
          {{ editing ? 'Save' : 'Add expense' }}
        </button>
      </mat-dialog-actions>
    </form>
  `,
})
export class ExpenseDialog {
  private readonly data = inject<ExpenseDialogData>(MAT_DIALOG_DATA);
  protected readonly ref = inject<MatDialogRef<ExpenseDialog, ExpenseDialogResult>>(MatDialogRef);
  protected readonly store = inject(ExpensesStore);
  protected readonly payers = injectPayers();

  protected readonly original = this.data.expense;
  protected readonly editing = !!this.original;
  protected readonly salary = this.original?.kind === 'salary';
  private readonly today = formatIsoDate(inject(Clock).now());

  protected readonly model = signal({
    title: this.original?.title ?? '',
    categoryId: this.original?.categoryId ?? '',
    amount: this.original ? rupeesText(this.original.amountPaise) : '',
    expenseDate: this.original?.expenseDate ?? this.today,
    periodStart: this.original?.periodStart ?? '',
    periodEnd: this.original?.periodEnd ?? '',
    staffId: this.original?.staffId ?? '',
    notes: this.original?.notes ?? '',
    paid: 'no' as Paid,
    payment: {
      amount: '',
      paidOn: this.today,
      method: 'upi',
      paidFrom: 'company',
      payerId: '',
      note: '',
    } as PaymentModel,
  });
  protected readonly f = form(this.model, (p) => {
    validate(p.title, ({ value }) => {
      const title = value().trim();
      if (!title) return { kind: 'title', message: 'Give the expense a title' };
      return title.length > MAX_TITLE
        ? { kind: 'title', message: `Keep the title to ${MAX_TITLE} characters` }
        : null;
    });
    validate(p.categoryId, ({ value }) =>
      !this.salary && !value() ? { kind: 'category', message: 'Pick a category' } : null,
    );
    validate(p.amount, ({ value }) => {
      const paise = parseRupees(value());
      if (paise === null) {
        return { kind: 'amount', message: 'Enter the amount in rupees, like 2300 or 2300.50' };
      }
      const paid = this.original?.paidPaise ?? 0;
      return paise < paid
        ? {
            kind: 'below_paid',
            message: `${formatAmount(paid)} is already paid: the amount cannot be less. Reverse a payment first`,
          }
        : null;
    });
    validate(p.expenseDate, ({ value }) => {
      if (this.salary) return null;
      const day = value();
      if (!istDayStartOf(day)) return { kind: 'day', message: 'Pick the day it belongs to' };
      return day < '2000-01-01' || day > addDays(this.today, 366)
        ? { kind: 'day', message: 'Pick a day from 2000 to a year from today' }
        : null;
    });
    validate(p.periodEnd, ({ value, valueOf }) => {
      if (!this.salary) return null;
      const span = daysBetween(valueOf(p.periodStart), value());
      if (Number.isNaN(span))
        return { kind: 'period', message: 'Pick the period’s first and last day' };
      if (span < 0) return { kind: 'period', message: 'The period ends before it starts' };
      return span > MAX_SALARY_SPAN
        ? { kind: 'period', message: 'A salary period covers at most 62 days' }
        : null;
    });
    validate(p.notes, ({ value }) =>
      value().trim().length > MAX_NOTES
        ? {
            kind: 'notes',
            message: `Keep the notes to ${MAX_NOTES.toLocaleString('en-IN')} characters`,
          }
        : null,
    );
    paymentRules(p.payment, {
      active: () => !this.editing && this.model().paid !== 'no',
      fixedAmount: () => this.model().paid === 'full',
      limit: () => parseRupees(this.model().amount) ?? 0,
      today: () => this.today,
    });
  });

  /** Active categories, and the edited expense's own even if it was turned off since. */
  protected readonly categoryOptions = computed(() =>
    (this.store.categories() ?? []).filter((c) => c.active || c.id === this.original?.categoryId),
  );
  protected readonly staffOptions = computed(() =>
    (this.payers.team.staff() ?? []).filter(
      (s) => (s.active && !s.removed) || s.id === this.original?.staffId,
    ),
  );
  protected readonly paidHint = computed(() => {
    const paid = this.original?.paidPaise ?? 0;
    return paid > 0 ? `${formatAmount(paid)} already paid` : '';
  });
  protected readonly error = signal('');
  protected readonly busy = signal(false);

  /** One Save's ids: a resend after a lost answer replays instead of recording twice. */
  private readonly attempt = new Attempt();
  /** The category picked before (the select has already moved the model on). */
  private lastCategory = this.original?.categoryId ?? '';

  constructor() {
    void this.store.loadMeta();
  }

  /** A title still empty, or still the previous category's name, follows the category. */
  protected categoryPicked(id: string): void {
    const names = new Map((this.store.categories() ?? []).map((c) => [c.id, c.name]));
    const previous = names.get(this.lastCategory) ?? '';
    this.lastCategory = id;
    this.model.update((m) => {
      const title = m.title.trim();
      return !title || title === previous ? { ...m, title: names.get(id) ?? m.title } : m;
    });
  }

  protected async addStandard(): Promise<void> {
    this.busy.set(true);
    this.error.set('');
    try {
      const existing = this.store.categories() ?? [];
      const names = missingStandard(await this.store.catalog(), existing);
      const start = nextSortOrder(existing);
      await this.store.saveCategories(
        names.map((name, i) => ({
          id: crypto.randomUUID(),
          name,
          sortOrder: start + i,
          active: true,
        })),
      );
    } catch (e) {
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async save(event: Event): Promise<void> {
    event.preventDefault();
    const first = this.f().errorSummary()[0];
    if (first) {
      this.error.set(first.message ?? 'Check the form');
      return;
    }
    const m = this.model();
    const amountPaise = parseRupees(m.amount) ?? 0;
    const details: ExpenseInput = {
      kind: this.salary ? 'salary' : 'general',
      title: m.title.trim(),
      amountPaise,
      notes: m.notes.trim() || null,
      staffId: m.staffId || null,
      categoryId: this.salary ? null : m.categoryId,
      expenseDate: this.salary ? null : m.expenseDate,
      periodStart: this.salary ? m.periodStart : null,
      periodEnd: this.salary ? m.periodEnd : null,
    };
    this.busy.set(true);
    this.error.set('');
    try {
      if (this.original) {
        await this.store.update(this.original, details, this.attempt);
        this.ref.close({ id: this.original.id, snack: `${details.title} saved` });
        return;
      }
      const payment =
        m.paid === 'no'
          ? null
          : {
              ...paymentInput(m.payment),
              amountPaise: m.paid === 'full' ? amountPaise : (parseRupees(m.payment.amount) ?? 0),
            };
      await this.store.add({ ...details, payment, agreed: null, attempt: this.attempt });
      this.ref.close({
        id: this.attempt.id('expense'),
        snack: `${details.title} added${payment ? (payment.amountPaise >= amountPaise ? ' · paid' : ' · part paid') : ''}`,
      });
    } catch (e) {
      this.attempt.settle(e);
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }
}
