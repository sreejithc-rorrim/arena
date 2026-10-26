import { Component, inject, signal } from '@angular/core';
import { MatButton } from '@angular/material/button';
import {
  MAT_DIALOG_DATA,
  MatDialogActions,
  MatDialogContent,
  MatDialogRef,
  MatDialogTitle,
} from '@angular/material/dialog';
import { MatFormField, MatHint, MatLabel } from '@angular/material/form-field';
import { MatInput } from '@angular/material/input';
import { toAppError } from '../../../core/auth/auth-api';
import { Attempt } from '../../../core/sync/push-ops';
import { MATERIAL_DEFAULTS } from '../../../shared/material/material-defaults';
import { formatDayYear } from '../../../shared/staff/staff-format';
import { ExpensesStore } from '../data/expenses-store';
import {
  Expense,
  ExpensePayment,
  MAX_REASON,
  expenseMethodName,
  formatAmount,
  sourceLabel,
} from '../data/expense.models';

export interface ReversePaymentDialogData {
  readonly expense: Expense;
  readonly payment: ExpensePayment;
}

/**
 * Undoes a payment entered by mistake: a reversal row of the same amount, source, owner, method
 * and day (none of them can change), so the money leaves the same bucket in the same period.
 * The original stays in the records. Needs a reason. Closes with the snackbar text.
 */
@Component({
  selector: 'app-reverse-payment-dialog',
  providers: [MATERIAL_DEFAULTS],
  imports: [
    MatButton,
    MatDialogTitle,
    MatDialogContent,
    MatDialogActions,
    MatFormField,
    MatHint,
    MatLabel,
    MatInput,
  ],
  template: `
    <h2 mat-dialog-title>Reverse payment?</h2>
    <form novalidate (submit)="confirm($event)">
      <mat-dialog-content>
        <div class="flex flex-col gap-5 pt-1">
          <p class="text-sm leading-[1.4] text-muted">
            The payment stays in the records with a reversal beside it, and
            {{ amount(payment.amountPaise) }} is due again on {{ expense.title }}.
          </p>
          <dl
            class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 rounded-card bg-surface-sunken px-4 py-3 text-sm"
          >
            <dt class="text-muted">Amount</dt>
            <dd class="font-medium tabular-nums">{{ amount(payment.amountPaise) }}</dd>
            <dt class="text-muted">Paid on</dt>
            <dd>{{ day(payment.paidOn) }}</dd>
            <dt class="text-muted">Method</dt>
            <dd>{{ method(payment.method) }}</dd>
            <dt class="text-muted">Paid from</dt>
            <dd>{{ source(payment) }}</dd>
          </dl>
          <mat-form-field>
            <mat-label>Reason</mat-label>
            <input
              matInput
              autocomplete="off"
              required
              [value]="reason()"
              (input)="reason.set($any($event.target).value)"
            />
            <mat-hint>For example: entered twice, wrong amount</mat-hint>
          </mat-form-field>
          @if (error()) {
            <p role="alert" class="text-sm leading-[1.3] font-medium text-danger">{{ error() }}</p>
          }
        </div>
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" [disabled]="busy()" (click)="ref.close()">Cancel</button>
        <button mat-flat-button type="submit" class="danger-fill" [disabled]="busy()">
          Reverse payment
        </button>
      </mat-dialog-actions>
    </form>
  `,
})
export class ReversePaymentDialog {
  private readonly data = inject<ReversePaymentDialogData>(MAT_DIALOG_DATA);
  protected readonly ref = inject<MatDialogRef<ReversePaymentDialog, string>>(MatDialogRef);
  private readonly store = inject(ExpensesStore);

  protected readonly expense = this.data.expense;
  protected readonly payment = this.data.payment;
  protected readonly amount = formatAmount;
  protected readonly day = formatDayYear;
  protected readonly method = expenseMethodName;
  protected readonly source = sourceLabel;

  protected readonly reason = signal('');
  protected readonly error = signal('');
  protected readonly busy = signal(false);

  /** One Save's ids: a resend after a lost answer replays instead of reversing twice. */
  private readonly attempt = new Attempt();

  protected async confirm(event: Event): Promise<void> {
    event.preventDefault();
    const reason = this.reason().trim();
    if (!reason) {
      this.error.set('Give a reason for the reversal');
      return;
    }
    if (reason.length > MAX_REASON) {
      this.error.set(`Keep the reason to ${MAX_REASON} characters`);
      return;
    }
    this.busy.set(true);
    this.error.set('');
    try {
      await this.store.reverse(this.payment, reason, this.attempt);
      this.ref.close(`${formatAmount(this.payment.amountPaise)} payment reversed`);
    } catch (e) {
      this.attempt.settle(e);
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }
}
