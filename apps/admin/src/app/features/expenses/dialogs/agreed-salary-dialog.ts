import { Component, inject, signal } from '@angular/core';
import { FormField, form, validate } from '@angular/forms/signals';
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
import { MatOption, MatSelect } from '@angular/material/select';
import { toAppError } from '../../../core/auth/auth-api';
import { Attempt } from '../../../core/sync/push-ops';
import { Clock } from '../../../core/time/clock';
import { MATERIAL_DEFAULTS } from '../../../shared/material/material-defaults';
import { formatDayYear } from '../../../shared/staff/staff-format';
import { addDays, formatIsoDate, istDayStartOf } from '../../../shared/time/ist';
import { parseRupees, rupeesText } from '../../sales/data/sale.models';
import { ExpensesStore } from '../data/expenses-store';
import {
  MAX_SALARY_NOTE,
  SalaryPeriod,
  StaffSalary,
  agreedLabel,
  formatAmount,
  monthOf,
} from '../data/expense.models';

export interface AgreedSalaryDialogData {
  readonly staffId: string;
  readonly staffName: string;
  /** Their agreed salary now (the form starts from it); null: none yet. */
  readonly current: StaffSalary | null;
}

/**
 * The agreed salary from a day on: a raise is a new row from its first day, and the same day
 * again corrects that row (audited). Salary periods already recorded keep their amounts; the
 * quick salary form fills in the agreed salary in force at a new period's start.
 */
@Component({
  selector: 'app-agreed-salary-dialog',
  providers: [MATERIAL_DEFAULTS],
  imports: [
    FormField,
    MatButton,
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
    <h2 mat-dialog-title>{{ data.current ? 'Change salary' : 'Set salary' }}</h2>
    <form novalidate (submit)="save($event)">
      <mat-dialog-content>
        <div class="flex flex-col gap-5 pt-1">
          <p class="text-sm leading-[1.4] text-muted">
            What {{ data.staffName }} is agreed to be paid.
            @if (data.current; as c) {
              Now {{ label(c) }}.
            }
            Periods already recorded keep their amounts.
          </p>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <mat-form-field>
              <mat-label>From</mat-label>
              <input matInput type="date" [formField]="f.effectiveFrom" />
              <mat-hint>The first day it applies</mat-hint>
            </mat-form-field>
            <mat-form-field>
              <mat-label>Paid</mat-label>
              <mat-select [formField]="f.period">
                <mat-option value="monthly">Monthly</mat-option>
                <mat-option value="weekly">Weekly (Monday to Sunday)</mat-option>
              </mat-select>
            </mat-form-field>
          </div>
          <mat-form-field>
            <mat-label>{{
              model().period === 'weekly' ? 'Salary a week (₹)' : 'Salary a month (₹)'
            }}</mat-label>
            <input matInput inputmode="decimal" autocomplete="off" [formField]="f.amount" />
          </mat-form-field>
          <mat-form-field>
            <mat-label>Note (optional)</mat-label>
            <input matInput autocomplete="off" [formField]="f.note" />
          </mat-form-field>
          @if (error()) {
            <p role="alert" class="text-sm leading-[1.3] font-medium text-danger">{{ error() }}</p>
          }
        </div>
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" [disabled]="busy()" (click)="ref.close()">Cancel</button>
        <button mat-flat-button type="submit" [disabled]="busy()">Save salary</button>
      </mat-dialog-actions>
    </form>
  `,
})
export class AgreedSalaryDialog {
  protected readonly data = inject<AgreedSalaryDialogData>(MAT_DIALOG_DATA);
  /** Closes with the snackbar text; undefined when cancelled. */
  protected readonly ref = inject<MatDialogRef<AgreedSalaryDialog, string>>(MatDialogRef);
  private readonly store = inject(ExpensesStore);
  private readonly today = formatIsoDate(inject(Clock).now());

  protected readonly label = agreedLabel;

  protected readonly model = signal({
    effectiveFrom: monthOf(this.today).first,
    period: (this.data.current?.period ?? 'monthly') as SalaryPeriod,
    amount: this.data.current ? rupeesText(this.data.current.amountPaise) : '',
    note: '',
  });

  protected readonly f = form(this.model, (p) => {
    validate(p.effectiveFrom, ({ value }) => {
      const day = value();
      if (!istDayStartOf(day) || day < '2000-01-01') {
        return { kind: 'day', message: 'Pick the first day it applies' };
      }
      return day > addDays(this.today, 366)
        ? { kind: 'far', message: 'Pick a day within the next year' }
        : null;
    });
    validate(p.amount, ({ value }) =>
      parseRupees(value()) === null
        ? { kind: 'amount', message: 'Enter the salary in rupees, like 18000' }
        : null,
    );
    validate(p.note, ({ value }) =>
      value().trim().length > MAX_SALARY_NOTE
        ? { kind: 'note', message: `Keep the note to ${MAX_SALARY_NOTE} characters` }
        : null,
    );
  });

  protected readonly error = signal('');
  protected readonly busy = signal(false);

  /** One Save's ids: a resend after a lost answer replays instead of saving twice. */
  private readonly attempt = new Attempt();

  protected async save(event: Event): Promise<void> {
    event.preventDefault();
    const first = this.f().errorSummary()[0];
    if (first) {
      this.error.set(first.message ?? 'Check the form');
      return;
    }
    const m = this.model();
    const amountPaise = parseRupees(m.amount) ?? 0;
    this.busy.set(true);
    this.error.set('');
    try {
      await this.store.setSalary(
        {
          staffId: this.data.staffId,
          effectiveFrom: m.effectiveFrom,
          period: m.period,
          amountPaise,
          note: m.note.trim() || null,
        },
        this.attempt,
      );
      this.ref.close(
        `${this.data.staffName}: ${formatAmount(amountPaise)} a ${m.period === 'weekly' ? 'week' : 'month'} from ${formatDayYear(m.effectiveFrom)}`,
      );
    } catch (e) {
      this.attempt.settle(e);
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }
}
