import { DOCUMENT } from '@angular/common';
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
import { MatButton, MatIconButton } from '@angular/material/button';
import { MatChipListbox, MatChipListboxChange, MatChipOption } from '@angular/material/chips';
import { MatDialog } from '@angular/material/dialog';
import { MatFormField, MatLabel, MatPrefix } from '@angular/material/form-field';
import { MatIcon } from '@angular/material/icon';
import { MatInput } from '@angular/material/input';
import { MatMenu, MatMenuItem, MatMenuTrigger } from '@angular/material/menu';
import { MatProgressBar } from '@angular/material/progress-bar';
import { MatOption, MatSelect, MatSelectChange } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTabNavPanel } from '@angular/material/tabs';
import { Router } from '@angular/router';
import { ArenaContext } from '../../core/arena/arena-context';
import { toAppError } from '../../core/auth/auth-api';
import { Session } from '../../core/auth/session';
import { Clock } from '../../core/time/clock';
import { injectNow } from '../../core/time/ticker';
import { ListDetail } from '../../shared/list-detail/list-detail';
import { ListPaneHeader } from '../../shared/list-detail/list-pane-header';
import { ListRow } from '../../shared/list-detail/list-row';
import { StatusPill } from '../../shared/status-pill/status-pill';
import { formatIsoDate, formatTime } from '../../shared/time/ist';
import { TeamStore } from '../team/data/team-store';
import { ExpenseDetail } from './components/expense-detail';
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
  Expense,
  OWNER_PREFIX,
  PaymentLine,
  SALARIES,
  STATUS_FILTERS,
  StatusFilter,
  cashTotals,
  expensePeriodFor,
  expenseIcon,
  expenseState,
  expenseSubtitle,
  expenseTotals,
  formatAmount,
  matchesFilters,
  missingStandard,
  nextSortOrder,
  periodLabel,
  summaryLine,
} from './data/expense.models';
import { CategoriesDialog } from './dialogs/categories-dialog';
import { ExpenseDialog, ExpenseDialogData, ExpenseDialogResult } from './dialogs/expense-dialog';
import { SalaryDialog, SalaryDialogData, SalaryDialogResult } from './dialogs/salary-dialog';

const PAGE = 40;

/**
 * Expenses: what the arena owes and has paid for a period of IST days — running costs by
 * category, and staff salaries — filtered by category, payment state, whose money paid it and
 * search. Two rows of figures, kept apart: by expense date (incurred = paid + unpaid) and by
 * payment date (out of the company account; owners' own money; salaries). An owner's own money
 * is their contribution, never company cash out. The period, filters and selection are in the
 * URL (`?range=…&category=…&status=…&paid=…&id=…`).
 */
@Component({
  selector: 'app-expenses-page',
  imports: [
    ListDetail,
    ListPaneHeader,
    ListRow,
    StatusPill,
    ExpenseDetail,
    ExpensePeriodPicker,
    ExpenseTabs,
    MatTabNavPanel,
    MatButton,
    MatIconButton,
    MatChipListbox,
    MatChipOption,
    MatFormField,
    MatLabel,
    MatPrefix,
    MatIcon,
    MatInput,
    MatMenu,
    MatMenuItem,
    MatMenuTrigger,
    MatProgressBar,
    MatSelect,
    MatOption,
  ],
  template: `
    <app-list-detail
      listLabel="Expenses"
      detailLabel="Expense"
      emptyText="Pick an expense to see its payments and history"
      [open]="!!selected()"
      (closed)="close()"
    >
      <ng-container list>
        <app-list-pane-header title="Expenses">
          <span actions class="flex items-center gap-1">
            <button
              mat-icon-button
              type="button"
              aria-label="Expense categories"
              (click)="openCategories()"
            >
              <mat-icon aria-hidden="true">category</mat-icon>
            </button>
            <button mat-flat-button type="button" [matMenuTriggerFor]="addMenu">
              <mat-icon aria-hidden="true">add</mat-icon>Add
            </button>
          </span>
          <mat-menu #addMenu="matMenu">
            <button mat-menu-item type="button" (click)="addExpense()">
              <mat-icon aria-hidden="true">receipt</mat-icon>Expense
            </button>
            <button mat-menu-item type="button" (click)="addSalary()">
              <mat-icon aria-hidden="true">badge</mat-icon>Salary
            </button>
          </mat-menu>
          <app-expense-tabs active="expenses" [panel]="tabPanel" />
          <mat-form-field class="arena-search">
            <mat-icon matPrefix aria-hidden="true">search</mat-icon>
            <input
              matInput
              type="search"
              aria-label="Search expenses"
              placeholder="Title, notes, category, staff or owner"
              [value]="query()"
              (input)="query.set($any($event.target).value)"
            />
          </mat-form-field>
          <app-expense-period [period]="period()" />
          <mat-chip-listbox
            aria-label="Payment state"
            [value]="status()"
            (change)="pickStatus($event)"
          >
            @for (s of statuses; track s.key) {
              <mat-chip-option [value]="s.key">{{ s.label }}</mat-chip-option>
            }
          </mat-chip-listbox>
          <div class="arena-dense grid grid-cols-2 gap-2">
            <mat-form-field>
              <mat-label>Category</mat-label>
              <mat-select [value]="category() ?? ''" (selectionChange)="pickCategory($event)">
                <mat-option value="">All</mat-option>
                <mat-option [value]="salaries">Salaries</mat-option>
                @for (c of store.categories() ?? []; track c.id) {
                  <mat-option [value]="c.id">{{ c.name }}{{ c.active ? '' : ' (off)' }}</mat-option>
                }
              </mat-select>
            </mat-form-field>
            <mat-form-field>
              <mat-label>Paid from</mat-label>
              <mat-select [value]="source() ?? ''" (selectionChange)="pickSource($event)">
                <mat-option value="">Any</mat-option>
                <mat-option value="company">Company</mat-option>
                <mat-option value="personal">Personal (any owner)</mat-option>
                @for (o of owners(); track o.id) {
                  <mat-option [value]="ownerPrefix + o.id">Personal · {{ o.name }}</mat-option>
                }
              </mat-select>
            </mat-form-field>
          </div>
          <div class="flex flex-col gap-2" aria-label="Totals" role="group">
            <span class="text-[11.5px] leading-none font-medium tracking-wide text-subtle uppercase"
              >By expense date</span
            >
            <dl class="grid grid-cols-3 gap-2">
              <div class="flex flex-col gap-1">
                <dt class="text-[12px] leading-none text-muted">Incurred</dt>
                <dd class="text-[15px] leading-none font-semibold tabular-nums">
                  {{ amount(totals().incurredPaise) }}
                </dd>
              </div>
              <div class="flex flex-col gap-1">
                <dt class="text-[12px] leading-none text-muted">Paid</dt>
                <dd class="text-[15px] leading-none font-semibold tabular-nums">
                  {{ amount(totals().paidPaise) }}
                </dd>
              </div>
              <div class="flex flex-col gap-1">
                <dt class="text-[12px] leading-none text-muted">Unpaid</dt>
                <dd
                  class="text-[15px] leading-none font-semibold tabular-nums"
                  [class.text-warning]="totals().unpaidPaise > 0"
                >
                  {{ amount(totals().unpaidPaise) }}
                </dd>
              </div>
            </dl>
            @if (totals().paidPaise > 0) {
              <p class="text-[12px] leading-[1.3] text-muted">
                Paid: company {{ amount(totals().paidCompanyPaise) }} · personal
                {{ amount(totals().paidPersonalPaise) }}
              </p>
            }
            <span
              class="mt-1 text-[11.5px] leading-none font-medium tracking-wide text-subtle uppercase"
              >By payment date</span
            >
            <dl class="grid grid-cols-3 gap-2">
              <div class="flex flex-col gap-1">
                <dt class="text-[12px] leading-none text-muted">From company</dt>
                <dd class="text-[15px] leading-none font-semibold tabular-nums">
                  {{ amount(cash().companyPaise) }}
                </dd>
              </div>
              <div class="flex flex-col gap-1">
                <dt class="text-[12px] leading-none text-muted">Paid personally</dt>
                <dd class="text-[15px] leading-none font-semibold tabular-nums">
                  {{ amount(cash().personalPaise) }}
                </dd>
              </div>
              <div class="flex flex-col gap-1">
                <dt class="text-[12px] leading-none text-muted">Salaries paid</dt>
                <dd class="text-[15px] leading-none font-semibold tabular-nums">
                  {{ amount(cash().salariesPaise) }}
                </dd>
              </div>
            </dl>
            @if (cash().owners.length) {
              <p class="text-[12px] leading-[1.3] text-muted">Personally: {{ ownersLine() }}</p>
            }
            @if (store.data(); as d) {
              <p class="text-[12px] leading-[1.3] text-muted">
                {{ amount(d.owedTotalPaise) }} owed overall, any date · {{ d.owedCount }} expense{{
                  d.owedCount === 1 ? '' : 's'
                }}
              </p>
            }
          </div>
          <div class="flex items-center gap-2">
            <p class="min-w-0 flex-1 text-[13px] leading-[1.3] text-muted" aria-live="polite">
              {{ summary() }}
            </p>
            <div class="arena-compact flex flex-none items-center">
              <button
                mat-icon-button
                type="button"
                [attr.aria-label]="refreshLabel()"
                [disabled]="store.loading()"
                (click)="refresh()"
              >
                <mat-icon aria-hidden="true">refresh</mat-icon>
              </button>
              <button
                mat-button
                type="button"
                [disabled]="!filtered().length && !cashLines().length"
                [matMenuTriggerFor]="exportMenu"
              >
                <mat-icon aria-hidden="true">download</mat-icon>Export
              </button>
              <mat-menu #exportMenu="matMenu">
                <button mat-menu-item type="button" (click)="exportExpenses()">
                  Expenses (CSV)
                </button>
                <button mat-menu-item type="button" (click)="exportPayments()">
                  Payments ledger (CSV)
                </button>
              </mat-menu>
            </div>
          </div>
          <details class="text-[12.5px] leading-[1.45] text-muted">
            <summary class="cursor-pointer">What these totals mean</summary>
            <ul class="mt-1 flex list-disc flex-col gap-0.5 pl-5">
              <li>
                By expense date: expenses dated in {{ label() }} (a salary on its period's last
                day). Incurred = paid + unpaid, whenever it was paid. Voided ones do not count.
              </li>
              <li>
                By payment date: money paid out in {{ label() }}, reversals taken off. From company
                is the arena's own account.
              </li>
              <li>
                Paid personally is owners' own money: their contribution to the arena, never counted
                as company cash out.
              </li>
              <li>Owed overall: still owed on every expense, whatever its date.</li>
            </ul>
          </details>
        </app-list-pane-header>
        @if (store.loading()) {
          <mat-progress-bar mode="indeterminate" aria-label="Loading expenses" />
        }
        <mat-tab-nav-panel #tabPanel class="flex min-h-0 flex-1 flex-col overflow-y-auto p-2">
          @if (store.metaError(); as error) {
            <div
              class="mb-2 flex items-center gap-2 rounded-card bg-danger-soft px-3 py-2 text-[13px] leading-[1.4] text-danger"
            >
              <p role="alert" class="min-w-0 flex-1">Categories couldn't load: {{ error }}</p>
              <button mat-button type="button" (click)="store.loadMeta(true)">Try again</button>
            </div>
          }
          @if (store.loadError(); as error) {
            <div class="flex flex-col items-center gap-3 px-4 py-12 text-center">
              <p role="alert" class="text-sm text-danger">{{ error }}</p>
              <button mat-stroked-button type="button" (click)="store.load(period(), true)">
                Try again
              </button>
            </div>
          } @else if (!store.loading() || store.expenses().length) {
            <ul class="flex flex-col gap-0.5" aria-label="Expenses">
              @for (e of visible(); track e.id) {
                <li>
                  <app-list-row
                    [title]="e.title"
                    [subtitle]="subtitle(e)"
                    [icon]="icon(e)"
                    [selected]="e.id === selected()?.id"
                    [queryParams]="{ id: e.id }"
                    queryParamsHandling="merge"
                  >
                    <span
                      class="text-sm leading-none font-semibold tabular-nums"
                      [class.line-through]="e.voided"
                      [class.text-muted]="e.voided"
                      >{{ amount(e.amountPaise) }}</span
                    >
                    @let state = stateOf(e);
                    <app-status-pill [tone]="state.tone">{{ state.label }}</app-status-pill>
                  </app-list-row>
                </li>
              }
            </ul>
            @if (!store.expenses().length) {
              <div class="flex flex-col items-center gap-3 px-4 py-12 text-center">
                <p class="text-sm leading-[1.4] text-muted">No expenses in {{ label() }}.</p>
                @if (store.categories()?.length === 0) {
                  <p class="text-[13px] leading-[1.45] text-muted">
                    Start with the standard categories (Rent, Electricity, Internet, Repairs…), or
                    add your own under Categories.
                  </p>
                  <button
                    mat-stroked-button
                    type="button"
                    [disabled]="adding()"
                    (click)="addStandard()"
                  >
                    <mat-icon aria-hidden="true">library_add</mat-icon>Add the standard categories
                  </button>
                }
              </div>
            } @else if (!filtered().length) {
              <p class="px-4 py-12 text-center text-sm leading-[1.4] text-muted">
                No expenses match these filters.
              </p>
            }
            @if (filtered().length > visible().length) {
              <div class="flex justify-center py-2">
                <button
                  mat-stroked-button
                  type="button"
                  (click)="shownCount.set(shownCount() + page)"
                >
                  Show more · {{ filtered().length - visible().length }} left
                </button>
              </div>
            }
          }
        </mat-tab-nav-panel>
      </ng-container>
      <ng-container detail>
        @if (selected(); as expense) {
          <app-expense-detail [expense]="expense" (closed)="close()" />
        }
      </ng-container>
    </app-list-detail>
  `,
})
export class ExpensesPage {
  protected readonly store = inject(ExpensesStore);
  private readonly team = inject(TeamStore);
  private readonly arena = inject(ArenaContext);
  private readonly session = inject(Session);
  private readonly clock = inject(Clock);
  private readonly router = inject(Router);
  private readonly snack = inject(MatSnackBar);
  private readonly dialog = inject(MatDialog);
  private readonly document = inject(DOCUMENT);

  /** `?range=` — today | week | month | prev_month | year | custom (default month). */
  readonly rangeParam = input<string>(undefined, { alias: 'range' });
  /** `?from=` / `?to=` — the first and last IST day of a custom range (YYYY-MM-DD). */
  readonly fromParam = input<string>(undefined, { alias: 'from' });
  readonly toParam = input<string>(undefined, { alias: 'to' });
  /** `?category=` — a category id, or `salaries`. */
  readonly categoryParam = input<string>(undefined, { alias: 'category' });
  /** `?status=` — unpaid | partial | paid | voided. */
  readonly statusParam = input<string>(undefined, { alias: 'status' });
  /** `?paid=` — company | personal | owner:<staff id>. */
  readonly paidParam = input<string>(undefined, { alias: 'paid' });
  /** `?id=` — the selected expense. */
  readonly id = input<string>();

  protected readonly statuses = STATUS_FILTERS;
  protected readonly salaries = SALARIES;
  protected readonly ownerPrefix = OWNER_PREFIX;
  protected readonly page = PAGE;
  protected readonly amount = formatAmount;
  protected readonly icon = expenseIcon;
  protected readonly stateOf = expenseState;

  /** Today's IST date; changes at midnight IST, which moves the presets along. */
  private readonly now = injectNow(60_000);
  protected readonly today = computed(() => formatIsoDate(this.now()));
  protected readonly period = computed(() =>
    expensePeriodFor(this.rangeParam(), this.fromParam(), this.toParam(), this.today()),
  );
  protected readonly label = computed(() => periodLabel(this.period()));
  protected readonly category = computed(() => this.categoryParam() || null);
  protected readonly status = computed<StatusFilter | null>(() => {
    const s = this.statusParam();
    return STATUS_FILTERS.some((f) => f.key === s) ? (s as StatusFilter) : null;
  });
  protected readonly source = computed(() => this.paidParam() || null);
  protected readonly query = signal('');
  protected readonly adding = signal(false);
  protected readonly shownCount = linkedSignal({
    source: () => [this.period(), this.category(), this.status(), this.source(), this.query()],
    computation: () => PAGE,
  });

  /** Owners whose own money may have paid (removed ones are gone from the picker). */
  protected readonly owners = computed(() =>
    (this.team.staff() ?? []).filter((s) => s.role === 'owner' && !s.removed),
  );

  protected readonly filtered = computed(() => {
    const f = {
      query: this.query(),
      category: this.category(),
      status: this.status(),
      source: this.source(),
    };
    return this.store.expenses().filter((e) => matchesFilters(e, f));
  });
  protected readonly visible = computed(() => this.filtered().slice(0, this.shownCount()));
  protected readonly totals = computed(() => expenseTotals(this.filtered()));
  /**
   * The payments behind the payment-date figures: the category, paid-from and search filters
   * apply to them (a payment state is an expense's, not a payment's).
   */
  protected readonly cashLines = computed(() => {
    const category = this.category();
    const categoryName =
      category && category !== SALARIES
        ? ((this.store.categories() ?? []).find((c) => c.id === category)?.name ?? null)
        : null;
    const source = this.source();
    const q = this.query().trim().toLowerCase();
    return this.store.payments().filter((p) => {
      if (category === SALARIES && p.expenseKind !== 'salary') return false;
      if (category && category !== SALARIES && p.categoryName !== categoryName) return false;
      if (source === 'company' && p.paidFrom !== 'company') return false;
      if (source === 'personal' && p.paidFrom !== 'personal') return false;
      if (
        source?.startsWith(OWNER_PREFIX) &&
        p.payerStaffId !== source.slice(OWNER_PREFIX.length)
      ) {
        return false;
      }
      return !q || paymentText(p).includes(q);
    });
  });
  protected readonly cash = computed(() => cashTotals(this.cashLines()));
  protected readonly ownersLine = computed(() =>
    this.cash()
      .owners.map((o) => `${o.name} ${formatAmount(o.netPaise)}`)
      .join(' · '),
  );
  protected readonly summary = computed(() => summaryLine(this.filtered()));
  protected readonly refreshLabel = computed(() => {
    const at = this.store.loadedAt();
    return at ? `Refresh (updated ${formatTime(at)})` : 'Refresh';
  });

  /** An expense opened by link that is not in the loaded period. */
  private readonly linked = resource({
    params: () => {
      const id = this.id();
      if (!id || this.store.loading() || this.store.byId().has(id)) return undefined;
      return { id, revision: this.store.revision() };
    },
    loader: ({ params }) => this.store.get(params.id),
  });
  protected readonly selected = computed<Expense | undefined>(() => {
    const id = this.id();
    if (!id) return undefined;
    const listed = this.store.byId().get(id);
    if (listed) return listed;
    const linked = this.linked.hasValue() ? this.linked.value() : undefined;
    return linked?.id === id ? linked : undefined;
  });

  constructor() {
    void this.team.load();
    // Load (and reload on an arena, period or day change) the current arena's expenses.
    effect(() => {
      const period = this.period();
      if (this.arena.current().id) void this.store.load(period);
    });
  }

  protected subtitle(e: Expense): string {
    return expenseSubtitle(e);
  }

  protected pickStatus(event: MatChipListboxChange): void {
    this.navigate({ status: event.value || null });
  }

  protected pickCategory(event: MatSelectChange): void {
    this.navigate({ category: event.value || null });
  }

  protected pickSource(event: MatSelectChange): void {
    this.navigate({ paid: event.value || null });
  }

  protected close(): void {
    this.navigate({ id: null });
  }

  protected addExpense(): void {
    this.dialog
      .open<ExpenseDialog, ExpenseDialogData, ExpenseDialogResult>(ExpenseDialog, {
        data: {},
        width: '560px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((r) => this.added(r));
  }

  protected addSalary(): void {
    this.dialog
      .open<SalaryDialog, SalaryDialogData, SalaryDialogResult>(SalaryDialog, {
        data: {},
        width: '560px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((r) => this.added(r));
  }

  protected openCategories(): void {
    this.dialog.open(CategoriesDialog, { width: '560px', maxWidth: 'calc(100vw - 32px)' });
  }

  /** The empty arena's first step: every standard category at once. */
  protected async addStandard(): Promise<void> {
    this.adding.set(true);
    try {
      const names = missingStandard(await this.store.catalog(), this.store.categories() ?? []);
      const start = nextSortOrder(this.store.categories() ?? []);
      await this.store.saveCategories(
        names.map((name, i) => ({
          id: crypto.randomUUID(),
          name,
          sortOrder: start + i,
          active: true,
        })),
      );
      this.say(`${names.length} categories added`);
    } catch (e) {
      this.say(toAppError(e).message);
    } finally {
      this.adding.set(false);
    }
  }

  protected refresh(): void {
    void this.store.refresh();
  }

  protected exportExpenses(): void {
    const expenses = this.filtered();
    downloadCsv(
      this.document,
      expensesCsv(expenses, this.meta()),
      csvName(this.arena.current().name, 'expenses', this.period()),
    );
    this.say(`${expenses.length} expense${expenses.length === 1 ? '' : 's'} exported`);
  }

  protected exportPayments(): void {
    const payments = this.cashLines();
    downloadCsv(
      this.document,
      expensePaymentsCsv(payments, this.meta()),
      csvName(this.arena.current().name, 'expense-payments', this.period()),
    );
    this.say(`${payments.length} payment${payments.length === 1 ? '' : 's'} exported`);
  }

  private added(r: { id: string; snack: string } | undefined): void {
    if (!r) return;
    this.say(r.snack);
    this.navigate({ id: r.id });
  }

  /** What the report covers and who made it, written at the top of every export. */
  private meta(): ExpenseReportMeta {
    const category = this.category();
    const categoryName =
      category === SALARIES
        ? 'Salaries'
        : (this.store.categories() ?? []).find((c) => c.id === category)?.name;
    const status = STATUS_FILTERS.find((s) => s.key === this.status())?.label;
    const source = this.source();
    const owner = source?.startsWith(OWNER_PREFIX)
      ? this.owners().find((o) => o.id === source.slice(OWNER_PREFIX.length))?.name
      : null;
    const q = this.query().trim();
    const filters = [
      categoryName ? `category ${categoryName}` : '',
      status ? `state ${status} (expenses only)` : '',
      source === 'company' ? 'paid from company' : '',
      source === 'personal' ? 'paid personally' : '',
      owner ? `paid personally by ${owner}` : '',
      q ? `search "${q}"` : '',
    ].filter(Boolean);
    const user = this.session.user();
    return {
      arena: this.arena.current().name,
      period: this.period(),
      generatedAt: this.clock.now(),
      generatedBy: user ? `${user.name} <${user.email}>` : null,
      filters: filters.length ? filters.join('; ') : null,
    };
  }

  private navigate(queryParams: Record<string, string | null>): void {
    void this.router.navigate([], { queryParams, queryParamsHandling: 'merge' });
  }

  private say(message: string): void {
    this.snack.open(message, undefined, { duration: 3200 });
  }
}

/** What the search matches on a payment line (lower case). */
function paymentText(p: PaymentLine): string {
  return [p.expenseTitle, p.categoryName, p.staffName, p.payerName, p.note]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
}
