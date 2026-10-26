import {
  Component,
  computed,
  effect,
  inject,
  input,
  linkedSignal,
  resource,
  signal,
} from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatFormField, MatLabel, MatPrefix } from '@angular/material/form-field';
import { MatIcon } from '@angular/material/icon';
import { MatInput } from '@angular/material/input';
import { MatProgressBar } from '@angular/material/progress-bar';
import { MatOption, MatSelect, MatSelectChange } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTabNavPanel } from '@angular/material/tabs';
import { Router } from '@angular/router';
import { ArenaContext } from '../../core/arena/arena-context';
import { toAppError } from '../../core/auth/auth-api';
import { Session } from '../../core/auth/session';
import { injectNow } from '../../core/time/ticker';
import { ListDetail } from '../../shared/list-detail/list-detail';
import { ListPaneHeader } from '../../shared/list-detail/list-pane-header';
import { ListRow } from '../../shared/list-detail/list-row';
import { PillTone, StatusPill } from '../../shared/status-pill/status-pill';
import { addDays, formatIsoDate } from '../../shared/time/ist';
import { TeamStore } from '../team/data/team-store';
import { TeamMember, isEmployee } from '../team/data/team.models';
import { ExpenseTabs } from './components/expense-tabs';
import { StaffSalaryDetail } from './components/staff-salary-detail';
import { ExpensesStore } from './data/expenses-store';
import {
  Expense,
  MAX_SALARY_SPAN,
  MonthSalary,
  StaffSalary,
  agreedOn,
  formatAmount,
  formatMonth,
  formatMonthShort,
  monthOf,
  salaryInMonth,
  salaryPeriodOptions,
} from './data/expense.models';
import { ExpensePaymentDialog, ExpensePaymentDialogData } from './dialogs/expense-payment-dialog';
import { SalaryDialog, SalaryDialogData, SalaryDialogResult } from './dialogs/salary-dialog';

interface SalaryRow {
  readonly staff: TeamMember;
  readonly agreed: StaffSalary | null;
  readonly month: MonthSalary;
  readonly state: { readonly label: string; readonly tone: PillTone };
  /** The row's one action: pay what is left on a period, or record the month (or a week). */
  readonly action: { readonly label: string; readonly pay: Expense | null } | null;
}

/**
 * Salaries: every staff member with their agreed salary and, for the month picked
 * (`?month=2026-10-01`, default this one), what is recorded, paid and left — a week or other
 * dates that share a day with the month count in it. One button per person records the month
 * (the agreed salary fills in) or pays what is left. Nothing is generated or paid by itself.
 * `?staff=` opens their salary history.
 */
@Component({
  selector: 'app-salaries-page',
  imports: [
    ListDetail,
    ListPaneHeader,
    ListRow,
    StatusPill,
    ExpenseTabs,
    StaffSalaryDetail,
    MatTabNavPanel,
    MatButton,
    MatFormField,
    MatLabel,
    MatPrefix,
    MatIcon,
    MatInput,
    MatProgressBar,
    MatSelect,
    MatOption,
  ],
  template: `
    <app-list-detail
      listLabel="Salaries"
      detailLabel="Salary"
      emptyText="Pick a staff member to see their salary and periods"
      [open]="!!selected()"
      (closed)="close()"
    >
      <ng-container list>
        <app-list-pane-header title="Expenses">
          <button actions mat-flat-button type="button" (click)="record()">
            <mat-icon aria-hidden="true">add</mat-icon>Record salary
          </button>
          <app-expense-tabs active="salaries" [panel]="tabPanel" />
          <div class="arena-dense grid grid-cols-2 gap-2">
            <mat-form-field>
              <mat-label>Month</mat-label>
              <mat-select [value]="month().first" (selectionChange)="pickMonth($event)">
                @for (o of months(); track o.first) {
                  <mat-option [value]="o.first">{{ o.label }}</mat-option>
                }
              </mat-select>
            </mat-form-field>
            <mat-form-field class="arena-search">
              <mat-icon matPrefix aria-hidden="true">search</mat-icon>
              <input
                matInput
                type="search"
                aria-label="Search staff"
                placeholder="Name"
                [value]="query()"
                (input)="query.set($any($event.target).value)"
              />
            </mat-form-field>
          </div>
          <dl class="grid grid-cols-3 gap-2" aria-label="Month totals">
            <div class="flex flex-col gap-1">
              <dt class="text-[12px] leading-none text-muted">Owed</dt>
              <dd class="text-[15px] leading-none font-semibold tabular-nums">
                {{ amount(totals().owed) }}
              </dd>
            </div>
            <div class="flex flex-col gap-1">
              <dt class="text-[12px] leading-none text-muted">Paid</dt>
              <dd class="text-[15px] leading-none font-semibold tabular-nums">
                {{ amount(totals().paid) }}
              </dd>
            </div>
            <div class="flex flex-col gap-1">
              <dt class="text-[12px] leading-none text-muted">Left to pay</dt>
              <dd
                class="text-[15px] leading-none font-semibold tabular-nums"
                [class.text-warning]="totals().balance > 0"
              >
                {{ amount(totals().balance) }}
              </dd>
            </div>
          </dl>
          <p class="text-[13px] leading-[1.3] text-muted" aria-live="polite">{{ summary() }}</p>
        </app-list-pane-header>
        @if (monthData.isLoading() || team.loading()) {
          <mat-progress-bar mode="indeterminate" aria-label="Loading salaries" />
        }
        <mat-tab-nav-panel #tabPanel class="flex min-h-0 flex-1 flex-col overflow-y-auto p-2">
          @if (team.loadError() || monthError() || metaError(); as error) {
            <div class="flex flex-col items-center gap-3 px-4 py-12 text-center">
              <p role="alert" class="text-sm text-danger">{{ error }}</p>
              <button mat-stroked-button type="button" (click)="retry()">Try again</button>
            </div>
          } @else {
            <ul class="flex flex-col gap-0.5" aria-label="Staff salaries">
              @for (r of filtered(); track r.staff.id) {
                <li class="flex items-center gap-1">
                  <app-list-row
                    class="block min-w-0 flex-1"
                    [title]="r.staff.name"
                    [subtitle]="subtitle(r)"
                    [initials]="initials(r.staff.name)"
                    [selected]="r.staff.id === selected()?.id"
                    [queryParams]="{ staff: r.staff.id }"
                    queryParamsHandling="merge"
                  >
                    @if (r.month.owedPaise > 0) {
                      <span class="text-sm leading-none font-semibold tabular-nums">{{
                        amount(r.month.balancePaise > 0 ? r.month.balancePaise : r.month.owedPaise)
                      }}</span>
                    }
                    <app-status-pill [tone]="r.state.tone">{{ r.state.label }}</app-status-pill>
                  </app-list-row>
                  @if (r.action; as a) {
                    <button
                      mat-stroked-button
                      type="button"
                      class="arena-compact flex-none"
                      [attr.aria-label]="a.label + ' for ' + r.staff.name"
                      (click)="act(r)"
                    >
                      {{ a.label }}
                    </button>
                  }
                </li>
              }
            </ul>
            @if (team.staff() && !employees().length) {
              <p class="px-4 py-12 text-center text-sm leading-[1.4] text-muted">
                No staff yet. Add your team under Staff, then record their salaries here.
              </p>
            } @else if (employees().length && !filtered().length) {
              <p class="px-4 py-12 text-center text-sm leading-[1.4] text-muted">
                No staff match “{{ query() }}”.
              </p>
            }
          }
        </mat-tab-nav-panel>
      </ng-container>
      <ng-container detail>
        @if (selected(); as staff) {
          <app-staff-salary-detail [staff]="staff" [month]="month().first" (closed)="close()" />
        }
      </ng-container>
    </app-list-detail>
  `,
})
export class SalariesPage {
  private readonly store = inject(ExpensesStore);
  protected readonly team = inject(TeamStore);
  private readonly arena = inject(ArenaContext);
  private readonly session = inject(Session);
  private readonly router = inject(Router);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);

  /** `?month=` — the first day of the month shown (default this month). */
  readonly monthParam = input<string>(undefined, { alias: 'month' });
  /** `?staff=` — the staff member whose salary is open. */
  readonly staffParam = input<string>(undefined, { alias: 'staff' });

  protected readonly amount = formatAmount;

  private readonly now = injectNow(60_000);
  private readonly today = computed(() => formatIsoDate(this.now()));
  protected readonly months = computed(() => salaryPeriodOptions('monthly', this.today()));
  protected readonly month = computed(() => {
    const picked = this.months().find((o) => o.first === this.monthParam());
    return picked ?? monthOf(this.today());
  });
  protected readonly query = signal('');

  /**
   * The salary periods that can share a day with the month: each is dated by its last day, and
   * spans at most 62 days, so it ends between the month's first day and 61 days after its last.
   */
  protected readonly monthData = resource({
    params: () => {
      const arena = this.arena.current().id;
      const { first, last } = this.month();
      return arena
        ? { arena, first, last: addDays(last, MAX_SALARY_SPAN), revision: this.store.revision() }
        : undefined;
    },
    loader: ({ params }) => this.store.list(params.first, params.last),
  });
  protected readonly monthError = computed(() =>
    this.monthData.error() ? toAppError(this.monthData.error()).message : '',
  );
  /** Without the agreed salaries every row would wrongly say there is none. */
  protected readonly metaError = computed(() => {
    const e = this.store.metaError();
    return e ? `Agreed salaries couldn't load: ${e}` : '';
  });
  /** The month's salary periods, the last read kept while the next one loads. */
  private readonly periods = linkedSignal<Expense[], Expense[]>({
    source: () =>
      this.monthData.hasValue()
        ? this.monthData.value().expenses.filter((e) => e.kind === 'salary')
        : [],
    computation: (next, previous) =>
      next.length || !this.monthData.isLoading() ? next : (previous?.value ?? next),
  });

  /** Staff (not owners), removed ones gone; inactive ones stay (they may still be owed). */
  protected readonly employees = computed(() =>
    (this.team.staff() ?? [])
      .filter((s) => isEmployee(s) && !s.removed)
      .sort((a, b) => Number(b.active) - Number(a.active) || a.name.localeCompare(b.name)),
  );
  protected readonly rows = computed<SalaryRow[]>(() => {
    const month = this.month();
    const periods = this.periods();
    const salaries = this.store.salaries();
    const me = this.session.user()?.id;
    return this.employees().map((staff) => {
      const m = salaryInMonth(periods, staff.id, month);
      const agreed =
        agreedOn(salaries, staff.id, month.first) ?? agreedOn(salaries, staff.id, month.last);
      const weekly = agreed?.period === 'weekly';
      const open = m.periods.find((p) => p.balancePaise > 0) ?? null;
      let action: SalaryRow['action'] = null;
      // The server refuses a member recording or paying their own salary.
      if (staff.userId !== me) {
        if (open) action = { label: `Pay ${formatAmount(open.balancePaise)}`, pay: open };
        else if (weekly || !m.periods.length) {
          action = {
            label: weekly ? 'Record a week' : `Record ${formatMonthShort(month.first)}`,
            pay: null,
          };
        }
      }
      return { staff, agreed, month: m, state: monthState(m), action };
    });
  });
  protected readonly filtered = computed(() => {
    const q = this.query().trim().toLowerCase();
    return q ? this.rows().filter((r) => r.staff.name.toLowerCase().includes(q)) : this.rows();
  });
  protected readonly totals = computed(() =>
    this.filtered().reduce(
      (t, r) => ({
        owed: t.owed + r.month.owedPaise,
        paid: t.paid + r.month.paidPaise,
        balance: t.balance + r.month.balancePaise,
      }),
      { owed: 0, paid: 0, balance: 0 },
    ),
  );
  protected readonly summary = computed(() => {
    const rows = this.filtered();
    const recorded = rows.filter((r) => r.month.periods.length).length;
    return `${formatMonth(this.month().first)} · ${recorded} of ${rows.length} recorded`;
  });

  protected readonly selected = computed(() => {
    const id = this.staffParam();
    return id ? this.employees().find((s) => s.id === id) : undefined;
  });

  constructor() {
    void this.team.load();
    effect(() => {
      if (this.arena.current().id) void this.store.loadMeta();
    });
  }

  protected subtitle(r: SalaryRow): string {
    const a = r.agreed;
    const agreed = a
      ? `${formatAmount(a.amountPaise)} a ${a.period === 'weekly' ? 'week' : 'month'}`
      : 'No agreed salary';
    return [r.staff.active ? '' : 'Inactive', agreed].filter(Boolean).join(' · ');
  }

  protected initials(name: string): string {
    return name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((w) => w.charAt(0).toUpperCase())
      .join('');
  }

  protected pickMonth(event: MatSelectChange): void {
    const current = monthOf(this.today()).first;
    this.navigate({ month: event.value === current ? null : event.value });
  }

  protected close(): void {
    this.navigate({ staff: null });
  }

  protected retry(): void {
    if (this.team.loadError()) void this.team.load(true);
    if (this.store.metaError()) void this.store.loadMeta(true);
    this.monthData.reload();
  }

  /** Record salary (header): anyone, the month shown preselected. */
  protected record(staffId?: string): void {
    this.dialog
      .open<SalaryDialog, SalaryDialogData, SalaryDialogResult>(SalaryDialog, {
        data: { staffId, month: this.month().first },
        width: '560px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((r) => {
        if (r) this.say(r.snack);
      });
  }

  protected act(r: SalaryRow): void {
    const pay = r.action?.pay;
    if (!pay) {
      this.record(r.staff.id);
      return;
    }
    this.dialog
      .open<ExpensePaymentDialog, ExpensePaymentDialogData, string>(ExpensePaymentDialog, {
        data: { expense: pay },
        width: '560px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((snack) => {
        if (snack) this.say(snack);
      });
  }

  private navigate(queryParams: Record<string, string | null>): void {
    void this.router.navigate([], { queryParams, queryParamsHandling: 'merge' });
  }

  private say(message: string): void {
    this.snack.open(message, undefined, { duration: 3200 });
  }
}

/** Not recorded, unpaid, part paid or paid, for the month. */
function monthState(m: MonthSalary): { label: string; tone: PillTone } {
  if (!m.periods.length) return { label: 'Not recorded', tone: 'info' };
  if (m.balancePaise <= 0) return { label: 'Paid', tone: 'success' };
  if (m.paidPaise > 0) return { label: 'Part paid', tone: 'warning' };
  return { label: 'Unpaid', tone: 'warning' };
}
