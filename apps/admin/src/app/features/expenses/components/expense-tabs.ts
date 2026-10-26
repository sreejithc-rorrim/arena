import { Component, input } from '@angular/core';
import { MatTabLink, MatTabNav, MatTabNavPanel } from '@angular/material/tabs';
import { RouterLink } from '@angular/router';

export type ExpenseTab = 'expenses' | 'salaries' | 'reports';

const TABS: readonly { key: ExpenseTab; label: string; link: string }[] = [
  { key: 'expenses', label: 'Expenses', link: '/expenses' },
  { key: 'salaries', label: 'Salaries', link: '/expenses/salaries' },
  { key: 'reports', label: 'Reports', link: '/expenses/reports' },
];

/**
 * The Expenses screen's sections as links. The period in the URL goes along (`range`, `from`,
 * `to`); the selection (`id`, `staff`) and the list filters stay behind.
 */
@Component({
  selector: 'app-expense-tabs',
  imports: [MatTabNav, MatTabLink, RouterLink],
  template: `
    <nav
      mat-tab-nav-bar
      mat-stretch-tabs="false"
      mat-align-tabs="start"
      aria-label="Expenses sections"
      [tabPanel]="panel()"
    >
      @for (t of tabs; track t.key) {
        <a
          mat-tab-link
          [routerLink]="t.link"
          [queryParams]="keep"
          queryParamsHandling="merge"
          [active]="t.key === active()"
          >{{ t.label }}</a
        >
      }
    </nav>
  `,
})
export class ExpenseTabs {
  readonly active = input.required<ExpenseTab>();
  /** The page's content under the tabs (mat-tab-nav-panel). */
  readonly panel = input.required<MatTabNavPanel>();

  protected readonly tabs = TABS;
  /** Merged into the URL's query: everything but the period is cleared. */
  protected readonly keep = {
    id: null,
    staff: null,
    category: null,
    status: null,
    paid: null,
    month: null,
  };
}
