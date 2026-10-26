import { Component, computed, inject, signal } from '@angular/core';
import { form } from '@angular/forms/signals';
import { MatButton } from '@angular/material/button';
import {
  MAT_DIALOG_DATA,
  MatDialogActions,
  MatDialogContent,
  MatDialogRef,
  MatDialogTitle,
} from '@angular/material/dialog';
import { toAppError } from '../../../core/auth/auth-api';
import { Attempt } from '../../../core/sync/push-ops';
import { Clock } from '../../../core/time/clock';
import { MATERIAL_DEFAULTS } from '../../../shared/material/material-defaults';
import { formatDayYear } from '../../../shared/staff/staff-format';
import { formatIsoDate } from '../../../shared/time/ist';
import { rupeesText } from '../../sales/data/sale.models';
import { ExpensesStore } from '../data/expenses-store';
import { Expense, formatAmount, salaryPeriodName } from '../data/expense.models';
import {
  PaymentFields,
  PaymentModel,
  injectPayers,
  paymentInput,
  paymentRules,
} from './payment-fields';

export interface ExpensePaymentDialogData {
  readonly expense: Expense;
}

/**
 * A payment towards an expense or salary: up to its balance, from the company or an owner's own
 * money. Several payments may mix the two; one paid before a salary period ends is an advance.
 */
@Component({
  selector: 'app-expense-payment-dialog',
  providers: [MATERIAL_DEFAULTS],
  imports: [PaymentFields, MatButton, MatDialogTitle, MatDialogContent, MatDialogActions],
  template: `
    <h2 mat-dialog-title>Record payment</h2>
    <form novalidate (submit)="save($event)">
      <mat-dialog-content>
        <div class="flex flex-col gap-5 pt-1">
          <p class="text-sm leading-[1.4] text-muted">
            {{ expense.title }}: {{ amount(expense.amountPaise) }}, {{ amount(expense.paidPaise) }}
            paid.
          </p>
          <app-payment-fields
            [f]="f"
            [owners]="payers.owners()"
            [defaultPayer]="payers.me()"
            [hint]="amount(expense.balancePaise) + ' due'"
          />
          @if (advance()) {
            <p class="-mt-2 text-[13px] leading-[1.4] text-muted">
              Paid before {{ day(expense.periodEnd ?? '') }}: shown as an advance on this salary.
            </p>
          }
          @if (error()) {
            <p role="alert" class="text-sm leading-[1.3] font-medium text-danger">{{ error() }}</p>
          }
        </div>
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" [disabled]="busy()" (click)="ref.close()">Cancel</button>
        <button mat-flat-button type="submit" [disabled]="busy()">Record payment</button>
      </mat-dialog-actions>
    </form>
  `,
})
export class ExpensePaymentDialog {
  protected readonly expense = inject<ExpensePaymentDialogData>(MAT_DIALOG_DATA).expense;
  /** Closes with the snackbar text; undefined when cancelled. */
  protected readonly ref = inject<MatDialogRef<ExpensePaymentDialog, string>>(MatDialogRef);
  private readonly store = inject(ExpensesStore);
  protected readonly payers = injectPayers();
  private readonly today = formatIsoDate(inject(Clock).now());

  protected readonly amount = formatAmount;
  protected readonly day = formatDayYear;

  protected readonly model = signal<PaymentModel>({
    amount: rupeesText(this.expense.balancePaise),
    paidOn: this.today,
    method: 'upi',
    paidFrom: 'company',
    payerId: '',
    note:
      this.expense.kind === 'salary' && this.expense.periodStart && this.expense.periodEnd
        ? `${salaryPeriodName(this.expense.periodStart, this.expense.periodEnd)} salary`
        : '',
  });

  protected readonly f = form(this.model, (p) =>
    paymentRules(p, {
      active: () => true,
      limit: () => this.expense.balancePaise,
      today: () => this.today,
    }),
  );

  protected readonly advance = computed(() => {
    const end = this.expense.kind === 'salary' ? this.expense.periodEnd : null;
    return !!end && this.model().paidOn < end;
  });

  protected readonly error = signal('');
  protected readonly busy = signal(false);

  /** One Save's ids: a resend after a lost answer replays instead of paying twice. */
  private readonly attempt = new Attempt();

  protected async save(event: Event): Promise<void> {
    event.preventDefault();
    const first = this.f().errorSummary()[0];
    if (first) {
      this.error.set(first.message ?? 'Check the form');
      return;
    }
    const payment = paymentInput(this.model());
    this.busy.set(true);
    this.error.set('');
    try {
      await this.store.pay(this.expense, payment, this.attempt);
      const rest = this.expense.balancePaise - payment.amountPaise;
      this.ref.close(
        `${formatAmount(payment.amountPaise)} paid${rest > 0 ? ` · ${formatAmount(rest)} still due` : ' · paid in full'}`,
      );
    } catch (e) {
      this.attempt.settle(e);
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }
}
