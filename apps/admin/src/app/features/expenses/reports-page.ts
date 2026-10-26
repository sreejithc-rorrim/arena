import { DOCUMENT } from '@angular/common';
import { Component, computed, effect, inject, input, resource } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatCard } from '@angular/material/card';
import { MatIcon } from '@angular/material/icon';
import { MatMenu, MatMenuItem, MatMenuTrigger } from '@angular/material/menu';
import { MatProgressBar } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTabNavPanel } from '@angular/material/tabs';
import { ArenaContext } from '../../core/arena/arena-context';
import { toAppError } from '../../core/auth/auth-api';
import { Session } from '../../core/auth/session';
import { PageHeader } from '../../core/layout/page-header';
import { Clock } from '../../core/time/clock';
import { injectNow } from '../../core/time/ticker';
import { formatIsoDate } from '../../shared/time/ist';
import { chartScale } from '../overview/data/overview.models';
import { ExpensePeriodPicker } from './components/expense-period';
import { ExpenseTabs } from './components/expense-tabs';
import {
  ExpenseReportMeta,
  csvName,
  downloadCsv,
  expensePaymentsCsv,
  expensesCsv,
} from './components/expenses-csv';
import { ExpensesStore } from './data/expenses-store';
import {
  MonthRow,
  addMonths,
  byCategory,
  byMonth,
  cashTotals,
  changeLabel,
  expensePeriodFor,
  expenseTotals,
  formatAmount,
  formatMonth,
  monthOf,
  periodLabel,
  salariesByStaff,
} from './data/expense.models';

/**
 * Expenses › Reports for the period picked: what was incurred (by expense date) and paid out
 * (by payment date), by category, salaries by staff member, paid vs unpaid, company money vs
 * owners' own, and each owner's contribution; this month against the one before, and twelve
 * months side by side. Owners' own money is never counted as company cash out. No profit or
 * loss: takings are on Sales. Both CSVs carry whose money paid each payment.
 */
@Component({
  selector: 'app-expense-reports-page',
  imports: [
    PageHeader,
    ExpenseTabs,
    ExpensePeriodPicker,
    MatTabNavPanel,
    MatButton,
    MatCard,
    MatIcon,
    MatMenu,
    MatMenuItem,
    MatMenuTrigger,
    MatProgressBar,
  ],
  template: `
    <div class="flex min-w-0 flex-1 flex-col">
      <app-page-header title="Expenses">
        <button
          mat-stroked-button
          type="button"
          [disabled]="!store.data()"
          [matMenuTriggerFor]="exportMenu"
        >
          <mat-icon aria-hidden="true">download</mat-icon>Export
        </button>
        <mat-menu #exportMenu="matMenu">
          <button mat-menu-item type="button" (click)="exportExpenses()">Expenses (CSV)</button>
          <button mat-menu-item type="button" (click)="exportPayments()">
            Payments ledger (CSV)
          </button>
        </mat-menu>
      </app-page-header>
      <div class="flex flex-col gap-3 border-b border-border px-5 pb-3">
        <app-expense-tabs active="reports" [panel]="tabPanel" />
        <app-expense-period [period]="period()" />
      </div>
      @if (store.loading() || months.isLoading()) {
        <mat-progress-bar mode="indeterminate" aria-label="Loading the reports" />
      }
      <mat-tab-nav-panel #tabPanel class="flex flex-col gap-4 p-5">
        @if (store.loadError(); as error) {
          <mat-card appearance="outlined">
            <div class="flex flex-col items-start gap-3 p-5">
              <p role="alert" class="text-sm text-danger">{{ error }}</p>
              <button mat-stroked-button type="button" (click)="store.load(period(), true)">
                Try again
              </button>
            </div>
          </mat-card>
        }

        <div class="grid grid-cols-[repeat(auto-fit,minmax(190px,1fr))] gap-4">
          @for (k of kpis(); track k.label) {
            <mat-card appearance="outlined">
              <div class="flex flex-col gap-2.5 px-5 py-4.5">
                <div class="flex items-center justify-between gap-2">
                  <span class="text-sm leading-none font-medium text-muted">{{ k.label }}</span>
                  <span class="icon text-xl text-subtle" aria-hidden="true">{{ k.icon }}</span>
                </div>
                <span class="font-display text-[30px] leading-none font-bold tabular-nums">{{
                  k.value
                }}</span>
                <span class="text-[13px] leading-[1.3] text-muted">{{ k.sub }}</span>
              </div>
            </mat-card>
          }
        </div>

        <div class="grid grid-cols-[repeat(auto-fit,minmax(min(100%,340px),1fr))] gap-4">
          <mat-card appearance="outlined">
            <div class="flex flex-col gap-3.5 p-5">
              <div class="flex flex-col gap-1.5">
                <h2 class="text-base leading-[1.2] font-semibold">This month vs last month</h2>
                <p class="text-[13px] leading-[1.3] text-muted">
                  {{ monthName(compare().now.first) }} against
                  {{ monthName(compare().before.first) }}
                </p>
              </div>
              @if (months.error(); as e) {
                <p role="alert" class="text-[13px] leading-[1.45] text-danger">
                  {{ message(e) }}
                </p>
              } @else {
                <table class="w-full text-sm">
                  <thead>
                    <tr class="text-left text-[12px] text-muted">
                      <th scope="col" class="pb-2 font-medium">
                        <span class="sr-only">Figure</span>
                      </th>
                      <th scope="col" class="pb-2 text-right font-medium">
                        {{ shortMonth(compare().now) }}
                      </th>
                      <th scope="col" class="pb-2 text-right font-medium">
                        {{ shortMonth(compare().before) }}
                      </th>
                      <th scope="col" class="pb-2 text-right font-medium">Change</th>
                    </tr>
                  </thead>
                  <tbody>
                    @for (r of compareRows(); track r.label) {
                      <tr class="border-t border-border">
                        <th scope="row" class="py-2 text-left font-normal">{{ r.label }}</th>
                        <td class="py-2 text-right font-semibold tabular-nums">{{ r.now }}</td>
                        <td class="py-2 text-right text-muted tabular-nums">{{ r.before }}</td>
                        <td class="py-2 text-right text-muted tabular-nums">{{ r.change }}</td>
                      </tr>
                    }
                  </tbody>
                </table>
              }
            </div>
          </mat-card>

          <mat-card appearance="outlined">
            <div class="flex flex-col gap-3.5 p-5">
              <div class="flex flex-col gap-1.5">
                <h2 class="text-base leading-[1.2] font-semibold">Paid vs unpaid</h2>
                <p class="text-[13px] leading-[1.3] text-muted">
                  Expenses dated in {{ label() }}, whenever they were paid
                </p>
              </div>
              <div
                class="flex h-3 gap-0.5 overflow-hidden rounded-[6px] bg-surface-sunken"
                role="img"
                [attr.aria-label]="paidShare() + '% of what was incurred is paid'"
              >
                <div class="bg-primary" [style.width.%]="paidShare()"></div>
                @if (totals().unpaidPaise > 0) {
                  <div class="flex-1 bg-warning"></div>
                }
              </div>
              @for (r of paidRows(); track r.label) {
                <div class="flex items-center gap-2.5">
                  <span class="size-2.5 rounded-[3px]" [class]="r.swatch" aria-hidden="true"></span>
                  <span class="flex-1 text-sm leading-[1.2]">{{ r.label }}</span>
                  <span class="text-[13px] leading-none text-muted">{{ r.count }}</span>
                  <span
                    class="min-w-24 text-right text-sm leading-none font-semibold tabular-nums"
                    >{{ r.value }}</span
                  >
                </div>
              }
            </div>
          </mat-card>
        </div>

        <mat-card appearance="outlined">
          <div class="flex flex-col gap-4 p-5">
            <div class="flex flex-col gap-1.5">
              <h2 class="text-base leading-[1.2] font-semibold">Twelve months</h2>
              <p class="text-[13px] leading-[1.3] text-muted">
                Incurred (by expense date) beside what was paid out (by payment date), up to
                {{ monthName(compare().now.first) }}
              </p>
            </div>
            <div class="flex gap-2.5" aria-hidden="true">
              <div
                class="flex h-60 min-w-11 flex-col justify-between pb-5.5 text-right font-mono text-[11px] leading-none font-medium text-subtle"
              >
                <span>{{ scale().top }}</span
                ><span>{{ scale().mid }}</span
                ><span>₹0</span>
              </div>
              <div class="flex min-w-0 flex-1 flex-col gap-2">
                <div
                  class="flex h-[218px] items-end gap-2 border-b border-border-strong bg-[linear-gradient(var(--arena-border)_1px,transparent_1px)] bg-[length:100%_50%]"
                >
                  @for (m of monthRows(); track m.first) {
                    <div class="flex h-full flex-1 items-end gap-0.5" [title]="monthTip(m)">
                      <div
                        class="flex-1 rounded-t-[4px] bg-primary"
                        [style.height.%]="height(m.incurredPaise)"
                      ></div>
                      <div class="flex h-full flex-1 flex-col justify-end">
                        <div
                          class="rounded-t-[4px] bg-warning"
                          [style.height.%]="height(m.personalPaise)"
                        ></div>
                        <div class="bg-subtle" [style.height.%]="height(m.companyPaise)"></div>
                      </div>
                    </div>
                  }
                </div>
                <div class="flex gap-2">
                  @for (m of monthRows(); track m.first) {
                    <span
                      class="min-w-0 flex-1 text-center font-mono text-[11px] leading-none font-medium whitespace-nowrap text-subtle"
                      >{{ m.label }}</span
                    >
                  }
                </div>
              </div>
            </div>
            <div
              class="flex flex-wrap gap-4 text-[13px] leading-none text-muted"
              aria-hidden="true"
            >
              <span class="flex items-center gap-1.5"
                ><span class="size-2.5 rounded-[3px] bg-primary"></span>Incurred</span
              >
              <span class="flex items-center gap-1.5"
                ><span class="size-2.5 rounded-[3px] bg-subtle"></span>Paid from company</span
              >
              <span class="flex items-center gap-1.5"
                ><span class="size-2.5 rounded-[3px] bg-warning"></span>Paid personally</span
              >
            </div>
            <table class="sr-only">
              <caption>
                Expenses by month
              </caption>
              <thead>
                <tr>
                  <th scope="col">Month</th>
                  <th scope="col">Incurred</th>
                  <th scope="col">Paid from company</th>
                  <th scope="col">Paid personally</th>
                  <th scope="col">Unpaid</th>
                </tr>
              </thead>
              <tbody>
                @for (m of monthRows(); track m.first) {
                  <tr>
                    <th scope="row">{{ monthName(m.first) }}</th>
                    <td>{{ amount(m.incurredPaise) }}</td>
                    <td>{{ amount(m.companyPaise) }}</td>
                    <td>{{ amount(m.personalPaise) }}</td>
                    <td>{{ amount(m.unpaidPaise) }}</td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        </mat-card>

        <div class="grid grid-cols-[repeat(auto-fit,minmax(min(100%,340px),1fr))] gap-4">
          <mat-card appearance="outlined">
            <div class="flex flex-col gap-3.5 p-5">
              <div class="flex flex-col gap-1.5">
                <h2 class="text-base leading-[1.2] font-semibold">By category</h2>
                <p class="text-[13px] leading-[1.3] text-muted">Incurred in {{ label() }}</p>
              </div>
              @for (c of categories(); track c.key) {
                <div class="flex flex-col gap-1.5">
                  <div class="flex items-center gap-2.5">
                    <span class="min-w-0 flex-1 truncate text-sm leading-[1.2]">{{ c.name }}</span>
                    <span class="text-[13px] leading-none text-muted">{{ c.count }}</span>
                    <span
                      class="min-w-24 text-right text-sm leading-none font-semibold tabular-nums"
                      >{{ amount(c.paise) }}</span
                    >
                  </div>
                  <div
                    class="h-1.5 overflow-hidden rounded-full bg-surface-sunken"
                    aria-hidden="true"
                  >
                    <div class="h-full bg-primary" [style.width.%]="share(c.paise)"></div>
                  </div>
                </div>
              } @empty {
                <p class="text-[13px] leading-[1.45] text-muted">Nothing incurred.</p>
              }
            </div>
          </mat-card>

          <mat-card appearance="outlined">
            <div class="flex flex-col gap-3.5 p-5">
              <div class="flex flex-col gap-1.5">
                <h2 class="text-base leading-[1.2] font-semibold">Funding</h2>
                <p class="text-[13px] leading-[1.3] text-muted">
                  Paid out in {{ label() }}, by payment date
                </p>
              </div>
              <div
                class="flex h-3 gap-0.5 overflow-hidden rounded-[6px] bg-surface-sunken"
                role="img"
                [attr.aria-label]="companyShare() + '% from the company account'"
              >
                <div class="bg-subtle" [style.width.%]="companyShare()"></div>
                @if (cash().personalPaise > 0) {
                  <div class="flex-1 bg-warning"></div>
                }
              </div>
              <div class="flex items-center gap-2.5">
                <span class="size-2.5 rounded-[3px] bg-subtle" aria-hidden="true"></span>
                <span class="flex-1 text-sm leading-[1.2]">From company account</span>
                <span class="min-w-24 text-right text-sm leading-none font-semibold tabular-nums">{{
                  amount(cash().companyPaise)
                }}</span>
              </div>
              <div class="flex items-center gap-2.5">
                <span class="size-2.5 rounded-[3px] bg-warning" aria-hidden="true"></span>
                <span class="flex-1 text-sm leading-[1.2]">Paid personally by owners</span>
                <span class="min-w-24 text-right text-sm leading-none font-semibold tabular-nums">{{
                  amount(cash().personalPaise)
                }}</span>
              </div>
              <div
                class="flex justify-between border-t border-border pt-3 text-[13px] leading-none text-muted"
              >
                <span>Of which salaries</span>
                <span class="font-medium tabular-nums">{{ amount(cash().salariesPaise) }}</span>
              </div>

              <h3 class="pt-2 text-sm leading-[1.2] font-semibold">Owner contributions</h3>
              <p class="-mt-2 text-[12.5px] leading-[1.4] text-muted">
                Owners' own money paid for the arena; reversals are taken off. Not a debt the arena
                records.
              </p>
              @for (o of cash().owners; track o.staffId) {
                <div class="flex items-center gap-2.5">
                  <span class="min-w-0 flex-1 truncate text-sm leading-[1.2]">{{ o.name }}</span>
                  @if (o.reversedPaise > 0) {
                    <span class="text-[12.5px] leading-none text-muted"
                      >{{ amount(o.paidPaise) }} − {{ amount(o.reversedPaise) }} reversed</span
                    >
                  }
                  <span
                    class="min-w-24 text-right text-sm leading-none font-semibold tabular-nums"
                    >{{ amount(o.netPaise) }}</span
                  >
                </div>
              } @empty {
                <p class="text-[13px] leading-[1.45] text-muted">
                  No owner paid from their own money.
                </p>
              }
            </div>
          </mat-card>
        </div>

        <mat-card appearance="outlined">
          <div class="flex flex-col gap-3.5 p-5">
            <div class="flex flex-col gap-1.5">
              <h2 class="text-base leading-[1.2] font-semibold">Salaries by staff member</h2>
              <p class="text-[13px] leading-[1.3] text-muted">
                Salary periods ending in {{ label() }}
              </p>
            </div>
            @if (staff().length) {
              <div class="overflow-x-auto">
                <table class="w-full min-w-[520px] text-sm">
                  <thead>
                    <tr class="text-left text-[12px] text-muted">
                      <th scope="col" class="pb-2 font-medium">Staff member</th>
                      <th scope="col" class="pb-2 text-right font-medium">Periods</th>
                      <th scope="col" class="pb-2 text-right font-medium">Owed</th>
                      <th scope="col" class="pb-2 text-right font-medium">Company</th>
                      <th scope="col" class="pb-2 text-right font-medium">Personal</th>
                      <th scope="col" class="pb-2 text-right font-medium">Left to pay</th>
                    </tr>
                  </thead>
                  <tbody>
                    @for (s of staff(); track s.staffId) {
                      <tr class="border-t border-border">
                        <th scope="row" class="py-2 text-left font-normal">{{ s.name }}</th>
                        <td class="py-2 text-right tabular-nums">{{ s.periods }}</td>
                        <td class="py-2 text-right font-semibold tabular-nums">
                          {{ amount(s.owedPaise) }}
                        </td>
                        <td class="py-2 text-right tabular-nums">
                          {{ amount(s.paidCompanyPaise) }}
                        </td>
                        <td class="py-2 text-right tabular-nums">
                          {{ amount(s.paidPersonalPaise) }}
                        </td>
                        <td
                          class="py-2 text-right tabular-nums"
                          [class.text-warning]="s.balancePaise > 0"
                        >
                          {{ amount(s.balancePaise) }}
                        </td>
                      </tr>
                    }
                  </tbody>
                </table>
              </div>
            } @else {
              <p class="text-[13px] leading-[1.45] text-muted">No salary recorded.</p>
            }
          </div>
        </mat-card>
      </mat-tab-nav-panel>
    </div>
  `,
})
export class ReportsPage {
  protected readonly store = inject(ExpensesStore);
  private readonly arena = inject(ArenaContext);
  private readonly session = inject(Session);
  private readonly clock = inject(Clock);
  private readonly snack = inject(MatSnackBar);
  private readonly document = inject(DOCUMENT);

  /** `?range=` / `?from=` / `?to=` — the period, as on the Expenses tab. */
  readonly rangeParam = input<string>(undefined, { alias: 'range' });
  readonly fromParam = input<string>(undefined, { alias: 'from' });
  readonly toParam = input<string>(undefined, { alias: 'to' });

  protected readonly amount = formatAmount;
  protected readonly monthName = formatMonth;

  private readonly now = injectNow(60_000);
  private readonly today = computed(() => formatIsoDate(this.now()));
  protected readonly period = computed(() =>
    expensePeriodFor(this.rangeParam(), this.fromParam(), this.toParam(), this.today()),
  );
  protected readonly label = computed(() => periodLabel(this.period()));

  protected readonly totals = computed(() => expenseTotals(this.store.expenses()));
  protected readonly cash = computed(() => cashTotals(this.store.payments()));
  protected readonly categories = computed(() => byCategory(this.store.expenses()));
  protected readonly staff = computed(() => salariesByStaff(this.store.expenses()));

  /** The month compared and charted up to: the month picked, else the current one. */
  private readonly lastMonth = computed(() => {
    const p = this.period();
    return p.range === 'month' || p.range === 'prev_month' ? p.first : monthOf(this.today()).first;
  });
  private readonly firstMonth = computed(() => addMonths(this.lastMonth(), -11));
  /** Twelve months of expenses and payments (one read, at most 366 days). */
  protected readonly months = resource({
    params: () => {
      const arena = this.arena.current().id;
      return arena
        ? {
            arena,
            first: this.firstMonth(),
            last: monthOf(this.lastMonth()).last,
            revision: this.store.revision(),
          }
        : undefined;
    },
    loader: ({ params }) => this.store.list(params.first, params.last),
  });
  protected readonly monthRows = computed<MonthRow[]>(() =>
    this.months.hasValue()
      ? byMonth(this.months.value(), this.firstMonth(), this.lastMonth())
      : byMonth(
          { expenses: [], payments: [], owedTotalPaise: 0, owedCount: 0 },
          this.firstMonth(),
          this.lastMonth(),
        ),
  );
  protected readonly compare = computed(() => {
    const rows = this.monthRows();
    return { now: rows[rows.length - 1]!, before: rows[rows.length - 2]! };
  });
  protected readonly compareRows = computed(() => {
    const { now, before } = this.compare();
    const row = (label: string, a: number, b: number) => ({
      label,
      now: formatAmount(a),
      before: formatAmount(b),
      change: changeLabel(a, b),
    });
    return [
      row('Incurred', now.incurredPaise, before.incurredPaise),
      row('Paid from company', now.companyPaise, before.companyPaise),
      row('Paid personally', now.personalPaise, before.personalPaise),
      row('Unpaid', now.unpaidPaise, before.unpaidPaise),
    ];
  });
  protected readonly scale = computed(() =>
    chartScale(
      this.monthRows().map((m) => ({
        paise: Math.max(
          m.incurredPaise,
          Math.max(0, m.companyPaise) + Math.max(0, m.personalPaise),
        ),
        label: m.label,
        tip: '',
        future: false,
      })),
    ),
  );

  protected readonly kpis = computed(() => {
    const t = this.totals();
    const c = this.cash();
    const owners = c.owners.length;
    return [
      {
        label: 'Incurred',
        icon: 'receipt_long',
        value: formatAmount(t.incurredPaise),
        sub: `${t.count} expense${t.count === 1 ? '' : 's'} by expense date`,
      },
      {
        label: 'Unpaid',
        icon: 'pending_actions',
        value: formatAmount(t.unpaidPaise),
        sub: `Of those · ${formatAmount(this.store.data()?.owedTotalPaise ?? 0)} owed overall`,
      },
      {
        label: 'From company account',
        icon: 'account_balance',
        value: formatAmount(c.companyPaise),
        sub: 'Paid out, by payment date',
      },
      {
        label: 'Paid personally',
        icon: 'volunteer_activism',
        value: formatAmount(c.personalPaise),
        sub: owners
          ? `By ${owners} owner${owners === 1 ? '' : 's'}, by payment date`
          : 'By owners, by payment date',
      },
    ];
  });

  protected readonly paidShare = computed(() => {
    const t = this.totals();
    return t.incurredPaise ? Math.round((t.paidPaise / t.incurredPaise) * 100) : 0;
  });
  protected readonly companyShare = computed(() => {
    const c = this.cash();
    const out = Math.max(0, c.companyPaise) + Math.max(0, c.personalPaise);
    return out ? Math.round((Math.max(0, c.companyPaise) / out) * 100) : 0;
  });
  protected readonly paidRows = computed(() => {
    const active = this.store.expenses().filter((e) => !e.voided);
    const count = (s: string) => active.filter((e) => e.paymentStatus === s).length;
    const t = this.totals();
    return [
      {
        label: 'Paid',
        swatch: 'bg-primary',
        count: `${count('paid')} paid · ${count('partial')} part paid`,
        value: formatAmount(t.paidPaise),
      },
      {
        label: 'Unpaid',
        swatch: 'bg-warning',
        count: `${count('unpaid') + count('partial')} with money due`,
        value: formatAmount(t.unpaidPaise),
      },
    ];
  });

  constructor() {
    effect(() => {
      const period = this.period();
      if (this.arena.current().id) void this.store.load(period);
    });
  }

  protected shortMonth(m: MonthRow): string {
    return m.label;
  }

  protected height(paise: number): number {
    const top = this.scale().topPaise;
    return paise > 0 ? Math.max(1, (paise / top) * 100) : 0;
  }

  protected share(paise: number): number {
    const total = this.totals().incurredPaise;
    return total ? Math.max(1, (paise / total) * 100) : 0;
  }

  protected monthTip(m: MonthRow): string {
    return `${formatMonth(m.first)}: incurred ${formatAmount(m.incurredPaise)}, paid from company ${formatAmount(m.companyPaise)}, paid personally ${formatAmount(m.personalPaise)}`;
  }

  protected message(error: unknown): string {
    return toAppError(error).message;
  }

  protected exportExpenses(): void {
    const expenses = this.store.expenses();
    downloadCsv(
      this.document,
      expensesCsv(expenses, this.meta()),
      csvName(this.arena.current().name, 'expenses', this.period()),
    );
    this.say(`${expenses.length} expense${expenses.length === 1 ? '' : 's'} exported`);
  }

  protected exportPayments(): void {
    const payments = this.store.payments();
    downloadCsv(
      this.document,
      expensePaymentsCsv(payments, this.meta()),
      csvName(this.arena.current().name, 'expense-payments', this.period()),
    );
    this.say(`${payments.length} payment${payments.length === 1 ? '' : 's'} exported`);
  }

  private meta(): ExpenseReportMeta {
    const user = this.session.user();
    return {
      arena: this.arena.current().name,
      period: this.period(),
      generatedAt: this.clock.now(),
      generatedBy: user ? `${user.name} <${user.email}>` : null,
      filters: null,
    };
  }

  private say(message: string): void {
    this.snack.open(message, undefined, { duration: 3200 });
  }
}
