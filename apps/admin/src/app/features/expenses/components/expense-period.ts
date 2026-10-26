import { Component, inject, input, signal } from '@angular/core';
import { MatChipListbox, MatChipListboxChange, MatChipOption } from '@angular/material/chips';
import { MatFormField, MatLabel } from '@angular/material/form-field';
import { MatInput } from '@angular/material/input';
import { Router } from '@angular/router';
import { DEFAULT_RANGE, EXPENSE_RANGES, ExpensePeriod, rangeProblem } from '../data/expense.models';

/**
 * The period chips (Today · This week · This month · Previous month · This year · Dates…) and,
 * for Dates…, the first and last day (at most 400, ahead of today too: rent falling due). The
 * choice goes in the URL (`?range=custom&from=…&to=…`), so it survives a reload and the tabs.
 */
@Component({
  selector: 'app-expense-period',
  imports: [MatChipListbox, MatChipOption, MatFormField, MatLabel, MatInput],
  host: { class: 'flex flex-col gap-2' },
  template: `
    <mat-chip-listbox aria-label="Period" [value]="period().range" (change)="pickRange($event)">
      @for (r of ranges; track r.key) {
        <mat-chip-option [value]="r.key" [selectable]="r.key !== period().range">{{
          r.label
        }}</mat-chip-option>
      }
    </mat-chip-listbox>
    @if (period().range === 'custom') {
      <div class="flex flex-wrap gap-2">
        <mat-form-field class="w-44">
          <mat-label>From</mat-label>
          <input
            matInput
            type="date"
            aria-label="First day"
            [value]="period().first"
            (change)="pickDates($any($event.target).value, period().last)"
          />
        </mat-form-field>
        <mat-form-field class="w-44">
          <mat-label>To</mat-label>
          <input
            matInput
            type="date"
            aria-label="Last day"
            [value]="period().last"
            (change)="pickDates(period().first, $any($event.target).value)"
          />
        </mat-form-field>
      </div>
      @if (dateError()) {
        <p role="alert" class="text-[13px] leading-[1.3] text-danger">{{ dateError() }}</p>
      }
    }
  `,
})
export class ExpensePeriodPicker {
  private readonly router = inject(Router);

  readonly period = input.required<ExpensePeriod>();

  protected readonly ranges = EXPENSE_RANGES;
  protected readonly dateError = signal('');

  protected pickRange(event: MatChipListboxChange): void {
    if (!event.value) return;
    this.dateError.set('');
    if (event.value === 'custom') {
      // Start from the days on screen, so "Dates…" then one change picks another day.
      const p = this.period();
      void this.router.navigate([], {
        queryParams: { range: 'custom', from: p.first, to: p.last },
        queryParamsHandling: 'merge',
      });
      return;
    }
    void this.router.navigate([], {
      queryParams: {
        range: event.value === DEFAULT_RANGE ? null : event.value,
        from: null,
        to: null,
      },
      queryParamsHandling: 'merge',
    });
  }

  protected pickDates(first: string, last: string): void {
    // One end moved past the other takes the other along (the period becomes that one day).
    let from = first;
    let to = last;
    if (from && to && from > to) {
      if (from !== this.period().first) to = from;
      else from = to;
    }
    const problem = rangeProblem(from, to);
    this.dateError.set(problem ?? '');
    if (problem) return;
    void this.router.navigate([], {
      queryParams: { range: 'custom', from, to },
      queryParamsHandling: 'merge',
    });
  }
}
