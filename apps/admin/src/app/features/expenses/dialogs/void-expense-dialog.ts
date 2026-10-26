import { Component, computed, inject, signal } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatCheckbox } from '@angular/material/checkbox';
import {
  MAT_DIALOG_DATA,
  MatDialogActions,
  MatDialogContent,
  MatDialogRef,
  MatDialogTitle,
} from '@angular/material/dialog';
import { MatFormField, MatLabel } from '@angular/material/form-field';
import { MatInput } from '@angular/material/input';
import { MatOption, MatSelect } from '@angular/material/select';
import { toAppError } from '../../../core/auth/auth-api';
import { Attempt } from '../../../core/sync/push-ops';
import { MATERIAL_DEFAULTS } from '../../../shared/material/material-defaults';
import { ExpensesStore } from '../data/expenses-store';
import { EXPENSE_VOID_REASONS, Expense, MAX_REASON, formatAmount } from '../data/expense.models';

export interface VoidExpenseDialogData {
  readonly expense: Expense;
}

const OTHER = 'Other…';

/**
 * Voids an expense entered by mistake: it stays in the records, marked void with who, when and
 * why, and drops out of every total. With money paid on it, the owner must also confirm that
 * each payment is reversed (each keeping its own source and owner); the server refuses the void
 * otherwise. Closes with the snackbar text.
 */
@Component({
  selector: 'app-void-expense-dialog',
  providers: [MATERIAL_DEFAULTS],
  imports: [
    MatButton,
    MatCheckbox,
    MatDialogTitle,
    MatDialogContent,
    MatDialogActions,
    MatFormField,
    MatLabel,
    MatInput,
    MatSelect,
    MatOption,
  ],
  template: `
    <h2 mat-dialog-title>Void {{ expense.kind === 'salary' ? 'salary' : 'expense' }}?</h2>
    <form novalidate (submit)="confirm($event)">
      <mat-dialog-content>
        <div class="flex flex-col gap-5 pt-1">
          <p class="text-sm leading-[1.4] text-muted">
            {{ expense.title }} ({{ amount(expense.amountPaise) }}) stays in the records, marked
            void, and drops out of every total.
          </p>
          <mat-form-field>
            <mat-label>Reason</mat-label>
            <mat-select [value]="choice()" (selectionChange)="choice.set($event.value)">
              @for (r of reasons; track r) {
                <mat-option [value]="r">{{ r }}</mat-option>
              }
            </mat-select>
          </mat-form-field>
          @if (choice() === other) {
            <mat-form-field>
              <mat-label>Describe the reason</mat-label>
              <input
                matInput
                autocomplete="off"
                required
                [value]="text()"
                (input)="text.set($any($event.target).value)"
              />
            </mat-form-field>
          }
          @if (expense.paidPaise > 0) {
            <mat-checkbox [checked]="reverse()" (change)="reverse.set($event.checked)">
              Also reverse the {{ amount(expense.paidPaise) }} paid ({{ split() }})
            </mat-checkbox>
            <p class="-mt-3 text-[13px] leading-[1.4] text-muted">
              Each payment gets a reversal of the same source, owner, method and day.
            </p>
          }
          @if (error()) {
            <p role="alert" class="text-sm leading-[1.3] font-medium text-danger">{{ error() }}</p>
          }
        </div>
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" [disabled]="busy()" (click)="ref.close()">Cancel</button>
        <button mat-flat-button type="submit" class="danger-fill" [disabled]="busy()">Void</button>
      </mat-dialog-actions>
    </form>
  `,
})
export class VoidExpenseDialog {
  protected readonly expense = inject<VoidExpenseDialogData>(MAT_DIALOG_DATA).expense;
  protected readonly ref = inject<MatDialogRef<VoidExpenseDialog, string>>(MatDialogRef);
  private readonly store = inject(ExpensesStore);

  protected readonly other = OTHER;
  protected readonly reasons: readonly string[] = [...EXPENSE_VOID_REASONS, OTHER];
  protected readonly amount = formatAmount;
  protected readonly choice = signal<string>(EXPENSE_VOID_REASONS[0]);
  protected readonly text = signal('');
  protected readonly reverse = signal(false);
  protected readonly split = computed(() => {
    const e = this.expense;
    return [
      e.paidCompanyPaise ? `company ${formatAmount(e.paidCompanyPaise)}` : '',
      e.paidPersonalPaise ? `personal ${formatAmount(e.paidPersonalPaise)}` : '',
    ]
      .filter(Boolean)
      .join(', ');
  });
  private readonly reason = computed(() =>
    this.choice() === OTHER ? this.text().trim() : this.choice(),
  );
  protected readonly error = signal('');
  protected readonly busy = signal(false);

  /** One Save's ids: a resend after a lost answer replays instead of voiding twice. */
  private readonly attempt = new Attempt();

  protected async confirm(event: Event): Promise<void> {
    event.preventDefault();
    const reason = this.reason();
    if (!reason) {
      this.error.set('Give a reason for the void');
      return;
    }
    if (reason.length > MAX_REASON) {
      this.error.set(`Keep the reason to ${MAX_REASON} characters`);
      return;
    }
    const paid = this.expense.paidPaise > 0;
    if (paid && !this.reverse()) {
      this.error.set('Tick "Also reverse" to void it with the money paid on it');
      return;
    }
    this.busy.set(true);
    this.error.set('');
    try {
      const reversed = await this.store.void(this.expense, reason, paid, this.attempt);
      this.ref.close(
        `Voided${reversed ? ` · ${reversed} payment${reversed === 1 ? '' : 's'} reversed` : ''}`,
      );
    } catch (e) {
      this.attempt.settle(e);
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }
}
