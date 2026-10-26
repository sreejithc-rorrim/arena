import { Component, computed, inject, input, output, resource } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatIcon } from '@angular/material/icon';
import { MatProgressBar } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { DetailPane } from '../../../shared/list-detail/detail-pane';
import { DetailSection } from '../../../shared/list-detail/detail-section';
import { LineRow } from '../../../shared/list-detail/line-row';
import { formatDayYear } from '../../../shared/staff/staff-format';
import { StatTile } from '../../../shared/stat-tile/stat-tile';
import { StatusPill } from '../../../shared/status-pill/status-pill';
import { TeamMember } from '../../team/data/team.models';
import { ExpensesStore } from '../data/expenses-store';
import {
  Expense,
  StaffSalaryRecord,
  agreedLabel,
  expenseState,
  formatAmount,
  salaryPeriodName,
} from '../data/expense.models';
import { AgreedSalaryDialog, AgreedSalaryDialogData } from '../dialogs/agreed-salary-dialog';
import { SalaryDialog, SalaryDialogData, SalaryDialogResult } from '../dialogs/salary-dialog';

/**
 * One staff member's pay: the agreed salary over time (a raise is a new row from its first day)
 * and every salary period recorded for them, newest first, each opening its expense with its
 * payments. Totals leave voided periods out.
 */
@Component({
  selector: 'app-staff-salary-detail',
  imports: [
    DetailPane,
    DetailSection,
    LineRow,
    StatTile,
    StatusPill,
    MatButton,
    MatIcon,
    MatProgressBar,
  ],
  template: `
    @let s = staff();
    <app-detail-pane
      [crumb]="'Expenses / Salaries / ' + s.name"
      icon="badge"
      [heading]="s.name"
      [subtitle]="subtitle()"
      (closed)="closed.emit()"
    >
      <div actions class="arena-compact flex flex-wrap gap-2">
        <button mat-flat-button type="button" (click)="record()">
          <mat-icon aria-hidden="true">add</mat-icon>Record salary
        </button>
        <button mat-stroked-button type="button" [disabled]="!full()" (click)="changeSalary()">
          <mat-icon aria-hidden="true">edit</mat-icon
          >{{ current() ? 'Change salary' : 'Set salary' }}
        </button>
      </div>
      @if (!s.active) {
        <span chip><app-status-pill tone="info">Inactive</app-status-pill></span>
      }

      <div stats class="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <app-stat-tile label="Agreed" [value]="agreedShort()" />
        <app-stat-tile label="Owed, all periods" [value]="amount(totals().owed)" />
        <app-stat-tile label="Paid" [value]="amount(totals().paid)" />
        <app-stat-tile label="Balance" [value]="amount(totals().balance)" />
      </div>

      @if (data.isLoading() && !data.hasValue()) {
        <mat-progress-bar mode="indeterminate" aria-label="Loading their salary" />
      }
      @if (data.error(); as error) {
        <app-detail-section>
          <p role="alert" class="text-sm text-danger">{{ message(error) }}</p>
          <div>
            <button mat-stroked-button type="button" (click)="data.reload()">Try again</button>
          </div>
        </app-detail-section>
      }
      @if (full(); as r) {
        <div class="grid grid-cols-1 items-start gap-5 lg:grid-cols-2">
          <app-detail-section
            heading="Agreed salary"
            subtitle="Fills in the amount when a month or week is recorded."
          >
            <ol class="flex flex-col gap-3" aria-label="Agreed salaries">
              @for (a of r.salaries; track a.id; let first = $first) {
                <li class="flex items-start gap-3">
                  <span
                    class="icon grid size-8 flex-none place-items-center rounded-full text-[18px]"
                    [class.bg-primary-soft]="first"
                    [class.text-primary-text]="first"
                    [class.bg-surface-sunken]="!first"
                    [class.text-muted]="!first"
                    aria-hidden="true"
                    >{{ first ? 'payments' : 'history' }}</span
                  >
                  <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span class="text-sm leading-[1.3] font-medium">{{ label(a) }}</span>
                    @if (a.note) {
                      <span class="text-[12.5px] leading-[1.4] text-muted">“{{ a.note }}”</span>
                    }
                  </span>
                </li>
              } @empty {
                <li class="text-[13px] leading-[1.45] text-muted">
                  No agreed salary yet. Set one, or save it when recording their first month.
                </li>
              }
            </ol>
          </app-detail-section>

          <app-detail-section heading="Salary periods">
            <ul class="flex flex-col gap-3" aria-label="Salary periods">
              @for (p of r.periods; track p.id) {
                <li>
                  <app-line-row
                    [title]="periodName(p)"
                    [subtitle]="periodLine(p)"
                    [value]="p.voided ? 'Void' : amount(p.amountPaise)"
                    link="/expenses"
                    [queryParams]="{ id: p.id }"
                  />
                </li>
              } @empty {
                <li class="text-[13px] leading-[1.45] text-muted">No salary recorded yet.</li>
              }
            </ul>
          </app-detail-section>
        </div>
      }
    </app-detail-pane>
  `,
})
export class StaffSalaryDetail {
  private readonly store = inject(ExpensesStore);
  private readonly arena = inject(ArenaContext);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);

  readonly staff = input.required<TeamMember>();
  /** The month the Salaries tab shows (its first day): Record salary starts there. */
  readonly month = input.required<string>();
  readonly closed = output<void>();

  protected readonly data = resource({
    params: () => ({
      arena: this.arena.current().id,
      id: this.staff().id,
      revision: this.store.revision(),
    }),
    loader: ({ params }) => this.store.staffRecord(params.id),
  });
  protected readonly full = computed<StaffSalaryRecord | undefined>(() => {
    const r = this.data.hasValue() ? this.data.value() : undefined;
    return r?.staffId === this.staff().id ? r : undefined;
  });

  protected readonly amount = formatAmount;
  protected readonly label = agreedLabel;

  /** Their newest agreed salary (it may start later; periods use the one in force then). */
  protected readonly current = computed(() => this.full()?.salaries[0] ?? null);
  protected readonly subtitle = computed(() => {
    const c = this.current();
    return c ? `Agreed ${agreedLabel(c)}` : this.full() ? 'No agreed salary yet' : '';
  });
  protected readonly agreedShort = computed(() => {
    const c = this.current();
    return c ? `${formatAmount(c.amountPaise)} / ${c.period === 'weekly' ? 'week' : 'month'}` : '—';
  });
  protected readonly totals = computed(() => {
    const active = (this.full()?.periods ?? []).filter((p) => !p.voided);
    return {
      owed: active.reduce((n, p) => n + p.amountPaise, 0),
      paid: active.reduce((n, p) => n + p.paidPaise, 0),
      balance: active.reduce((n, p) => n + p.balancePaise, 0),
    };
  });

  protected periodName(p: Expense): string {
    return p.periodStart && p.periodEnd ? salaryPeriodName(p.periodStart, p.periodEnd) : p.title;
  }

  protected periodLine(p: Expense): string {
    const state = expenseState(p).label;
    if (p.voided) return state;
    const paid = [
      p.paidCompanyPaise ? `company ${formatAmount(p.paidCompanyPaise)}` : '',
      p.paidPersonalPaise ? `personal ${formatAmount(p.paidPersonalPaise)}` : '',
    ].filter(Boolean);
    return [
      state,
      paid.length ? `paid ${paid.join(' + ')}` : '',
      p.balancePaise > 0 ? `${formatAmount(p.balancePaise)} due` : '',
      p.periodEnd ? `ends ${formatDayYear(p.periodEnd)}` : '',
    ]
      .filter(Boolean)
      .join(' · ');
  }

  protected message(error: unknown): string {
    return toAppError(error).message;
  }

  protected record(): void {
    this.dialog
      .open<SalaryDialog, SalaryDialogData, SalaryDialogResult>(SalaryDialog, {
        data: { staffId: this.staff().id, month: this.month() },
        width: '560px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((r) => this.say(r?.snack));
  }

  protected changeSalary(): void {
    this.dialog
      .open<AgreedSalaryDialog, AgreedSalaryDialogData, string>(AgreedSalaryDialog, {
        data: { staffId: this.staff().id, staffName: this.staff().name, current: this.current() },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((snack) => this.say(snack));
  }

  private say(snack: string | undefined): void {
    if (snack) this.snack.open(snack, undefined, { duration: 3200 });
  }
}
