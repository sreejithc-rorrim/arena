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
import { MatSnackBar } from '@angular/material/snack-bar';
import { Router } from '@angular/router';
import { ArenaContext } from '../../core/arena/arena-context';
import { Session } from '../../core/auth/session';
import { Clock } from '../../core/time/clock';
import { injectNow } from '../../core/time/ticker';
import { ListDetail } from '../../shared/list-detail/list-detail';
import { ListPaneHeader } from '../../shared/list-detail/list-pane-header';
import { ListRow } from '../../shared/list-detail/list-row';
import { formatRupees } from '../../shared/money/rupees.pipe';
import { StatusPill } from '../../shared/status-pill/status-pill';
import { formatDate, formatIsoDate, formatTime, istDayStartOf } from '../../shared/time/ist';
import { BillDetail } from './components/bill-detail';
import { ReportMeta, billsCsv, paymentsCsv } from './components/sales-csv';
import { SalesStore } from './data/sales-store';
import { MissedBillDialog } from './dialogs/missed-bill-dialog';
import {
  Bill,
  METHOD_FILTERS,
  SALES_RANGES,
  asMethod,
  billFlags,
  billState,
  matchesSearch,
  methodName,
  periodFor,
  periodProblem,
  summarize,
  summaryLine,
} from './data/sale.models';

const PAGE = 40;

/**
 * Sales (design: `if (p === 'sales')`): the arena's closed bills for a period of IST days (a
 * preset, or any dates up to 93 days), filtered by payment method and search, with the period's
 * totals — expected, collected, outstanding — and two CSV reports (bills; payments ledger). The
 * period, method and selected bill are in the URL (`?range=custom&from=…&to=…&method=upi&id=…`);
 * on a wide screen the first bill is shown when none is chosen, as in the design. "Today" moves
 * to the new day at midnight IST.
 */
@Component({
  selector: 'app-sales-page',
  imports: [
    ListDetail,
    ListPaneHeader,
    ListRow,
    StatusPill,
    BillDetail,
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
  ],
  template: `
    <app-list-detail
      listLabel="Bills"
      detailLabel="Bill"
      emptyText="Pick a bill to see its lines, payments and history"
      [open]="!!selected()"
      (closed)="close()"
    >
      <ng-container list>
        <app-list-pane-header title="Sales">
          <button actions mat-flat-button type="button" (click)="addMissed()">
            <mat-icon aria-hidden="true">add</mat-icon>Add missed bill
          </button>
          <mat-form-field class="arena-search">
            <mat-icon matPrefix aria-hidden="true">search</mat-icon>
            <input
              matInput
              type="search"
              aria-label="Search bills"
              placeholder="Bill, member, station or staff"
              [value]="query()"
              (input)="query.set($any($event.target).value)"
            />
          </mat-form-field>
          <div class="flex flex-wrap gap-1.5">
            <mat-chip-listbox
              aria-label="Date range"
              [value]="period().range"
              (change)="pickRange($event)"
            >
              @for (r of ranges; track r.key) {
                <mat-chip-option [value]="r.key" [selectable]="r.key !== period().range">{{
                  r.label
                }}</mat-chip-option>
              }
            </mat-chip-listbox>
            <mat-chip-listbox
              aria-label="Payment method"
              [value]="method()"
              (change)="pickMethod($event)"
            >
              @for (m of methods; track m.key) {
                <mat-chip-option [value]="m.key">{{ m.label }}</mat-chip-option>
              }
            </mat-chip-listbox>
          </div>
          @if (period().range === 'custom') {
            <div class="flex flex-wrap gap-2">
              <mat-form-field class="w-44">
                <mat-label>From</mat-label>
                <input
                  matInput
                  type="date"
                  aria-label="First day"
                  [value]="period().first"
                  [max]="today()"
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
                  [max]="today()"
                  (change)="pickDates(period().first, $any($event.target).value)"
                />
              </mat-form-field>
            </div>
            @if (dateError()) {
              <p role="alert" class="text-[13px] leading-[1.3] text-danger">{{ dateError() }}</p>
            }
          }
          <dl class="grid grid-cols-3 gap-2" aria-label="Totals">
            <div class="flex flex-col gap-1">
              <dt class="text-[12px] leading-none text-muted">Expected</dt>
              <dd class="text-[15px] leading-none font-semibold tabular-nums">
                {{ rupees(totals().expectedPaise) }}
              </dd>
            </div>
            <div class="flex flex-col gap-1">
              <dt class="text-[12px] leading-none text-muted">Collected</dt>
              <dd class="text-[15px] leading-none font-semibold tabular-nums">
                {{ rupees(totals().takingsPaise) }}
              </dd>
            </div>
            <div class="flex flex-col gap-1">
              <dt class="text-[12px] leading-none text-muted">Outstanding</dt>
              <dd
                class="text-[15px] leading-none font-semibold tabular-nums"
                [class.text-warning]="totals().duePaise > 0"
              >
                {{ rupees(totals().duePaise) }}
              </dd>
            </div>
          </dl>
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
                [disabled]="!filtered().length"
                [matMenuTriggerFor]="exportMenu"
              >
                <mat-icon aria-hidden="true">download</mat-icon>Export
              </button>
              <mat-menu #exportMenu="matMenu">
                <button mat-menu-item type="button" (click)="exportBills()">
                  Bills report (CSV)
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
              <li>Bills belong to the day they closed (IST). Voided bills do not count.</li>
              <li>Expected: the final bills, after rounding, waived ones included.</li>
              <li>Collected: payments minus refunds on those bills, whenever they came in.</li>
              <li>Outstanding: still owed on bills that are not waived.</li>
              <li>Written off: what a waive left unpaid. Refunded: money given back.</li>
              <li>On voided bills: money taken before a void, until it is refunded.</li>
            </ul>
          </details>
        </app-list-pane-header>
        @if (store.loading()) {
          <mat-progress-bar mode="indeterminate" aria-label="Loading bills" />
        }
        <div class="flex min-h-0 flex-1 flex-col overflow-y-auto p-2">
          @if (store.loadError(); as error) {
            <div class="flex flex-col items-center gap-3 px-4 py-12 text-center">
              <p role="alert" class="text-sm text-danger">{{ error }}</p>
              <button mat-stroked-button type="button" (click)="store.load(period(), true)">
                Try again
              </button>
            </div>
          } @else if (!store.loading() || store.bills().length) {
            <ul class="flex flex-col gap-0.5" aria-label="Bills">
              @for (b of visible(); track b.id) {
                <li>
                  <app-list-row
                    [title]="b.customer"
                    [subtitle]="subtitle(b)"
                    [selected]="b.id === selected()?.id"
                    [queryParams]="{ id: b.id }"
                    queryParamsHandling="merge"
                  >
                    <span class="text-sm leading-none font-semibold tabular-nums">{{
                      b.voided ? '—' : rupees(b.billedPaise ?? 0)
                    }}</span>
                    @let state = stateOf(b);
                    <span class="flex items-center gap-1">
                      <!-- The first change flag (added later, edited…) next to the state. -->
                      @if (flagsOf(b)[0]; as flag) {
                        <app-status-pill [tone]="flag.tone">{{ flag.label }}</app-status-pill>
                      }
                      @if (state.tone) {
                        <app-status-pill [tone]="state.tone">{{ state.label }}</app-status-pill>
                      } @else {
                        <span class="text-xs leading-none text-muted">{{ state.label }}</span>
                      }
                    </span>
                  </app-list-row>
                </li>
              }
            </ul>
            @if (!filtered().length) {
              <p class="px-4 py-12 text-center text-sm leading-[1.4] text-muted">
                No bills match these filters.
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
        </div>
      </ng-container>
      <ng-container detail>
        @if (selected(); as bill) {
          <app-bill-detail [bill]="bill" (closed)="close()" />
        }
      </ng-container>
    </app-list-detail>
  `,
})
export class SalesPage {
  protected readonly store = inject(SalesStore);
  private readonly arena = inject(ArenaContext);
  private readonly session = inject(Session);
  private readonly clock = inject(Clock);
  private readonly router = inject(Router);
  private readonly snack = inject(MatSnackBar);
  private readonly dialog = inject(MatDialog);
  private readonly document = inject(DOCUMENT);

  /** `?range=` — today | yesterday | 7d | 30d | custom (default today). */
  readonly rangeParam = input<string>(undefined, { alias: 'range' });
  /** `?from=` / `?to=` — the first and last IST day of a custom range (YYYY-MM-DD). */
  readonly fromParam = input<string>(undefined, { alias: 'from' });
  readonly toParam = input<string>(undefined, { alias: 'to' });
  /** `?method=` — upi | cash, or all. */
  readonly methodParam = input<string>(undefined, { alias: 'method' });
  /** `?id=` — the selected bill. */
  readonly id = input<string>();

  protected readonly ranges = SALES_RANGES;
  protected readonly methods = METHOD_FILTERS;
  protected readonly page = PAGE;
  protected readonly rupees = formatRupees;
  protected readonly stateOf = billState;
  protected readonly flagsOf = (b: Bill) => billFlags(b);

  /** Today's IST date; changes at midnight IST, which moves "Today" (and 7/30 days) along. */
  private readonly now = injectNow(60_000);
  protected readonly today = computed(() => formatIsoDate(this.now()));
  protected readonly period = computed(() =>
    periodFor(
      this.rangeParam(),
      this.fromParam(),
      this.toParam(),
      istDayStartOf(this.today()) ?? this.clock.now(),
    ),
  );
  protected readonly method = computed(() => asMethod(this.methodParam()));
  protected readonly query = signal('');
  protected readonly dateError = signal('');
  protected readonly shownCount = linkedSignal({
    source: () => [this.period(), this.method(), this.query()],
    computation: () => PAGE,
  });

  protected readonly filtered = computed(() => {
    const method = this.method();
    const q = this.query();
    return this.store
      .bills()
      .filter((b) => (!method || (b.methods[method] ?? 0) > 0) && matchesSearch(b, q));
  });
  protected readonly visible = computed(() => this.filtered().slice(0, this.shownCount()));
  protected readonly totals = computed(() => summarize(this.filtered()));
  protected readonly summary = computed(() => summaryLine(this.totals(), this.method()));
  protected readonly refreshLabel = computed(() => {
    const at = this.store.loadedAt();
    return at ? `Refresh (updated ${formatTime(at)})` : 'Refresh';
  });

  /** A bill opened by link that is not in the loaded period. */
  private readonly linked = resource({
    params: () => {
      const id = this.id();
      if (!id || this.store.loading() || this.store.byId().has(id)) return undefined;
      return { id, revision: this.store.revision() };
    },
    loader: ({ params }) => this.store.get(params.id),
  });
  protected readonly selected = computed<Bill | undefined>(() => {
    const id = this.id();
    if (id) {
      const listed = this.store.byId().get(id);
      if (listed) return listed;
      const linked = this.linked.hasValue() ? this.linked.value() : undefined;
      return linked?.id === id ? linked : undefined;
    }
    // Nothing is opened (and no bill detail read) until a bill is picked.
    return undefined;
  });

  constructor() {
    // Load (and reload on an arena, period or day change) the current arena's bills.
    effect(() => {
      const period = this.period();
      if (this.arena.current().id) void this.store.load(period);
    });
  }

  protected subtitle(b: Bill): string {
    const when =
      this.period().range === 'today'
        ? formatTime(b.at)
        : `${formatDate(b.at)}, ${formatTime(b.at)}`;
    return [b.ref, b.stations.join(', '), when].filter(Boolean).join(' · ');
  }

  protected pickRange(event: MatChipListboxChange): void {
    if (!event.value) return;
    this.dateError.set('');
    if (event.value === 'custom') {
      // Start from the days on screen, so "Dates…" then one change picks an earlier day.
      const p = this.period();
      void this.router.navigate([], {
        queryParams: { range: 'custom', from: p.first, to: p.last },
        queryParamsHandling: 'merge',
      });
      return;
    }
    void this.router.navigate([], {
      queryParams: { range: event.value === 'today' ? null : event.value, from: null, to: null },
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
    const problem = periodProblem(from, to);
    this.dateError.set(problem ?? '');
    if (problem) return;
    void this.router.navigate([], {
      queryParams: { range: 'custom', from, to },
      queryParamsHandling: 'merge',
    });
  }

  protected pickMethod(event: MatChipListboxChange): void {
    void this.router.navigate([], {
      queryParams: { method: event.value || null },
      queryParamsHandling: 'merge',
    });
  }

  protected close(): void {
    void this.router.navigate([], { queryParams: { id: null }, queryParamsHandling: 'merge' });
  }

  /** A bill played but never started on the floor: added already ended and paid. */
  protected addMissed(): void {
    this.dialog
      .open<MissedBillDialog, void, boolean>(MissedBillDialog, {
        width: '560px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((added) => {
        if (!added) return;
        this.snack.open('Missed bill added', undefined, { duration: 3200 });
        void this.store.refresh();
      });
  }

  protected refresh(): void {
    void this.store.refresh();
  }

  protected exportBills(): void {
    const bills = this.filtered();
    this.download(billsCsv(bills, this.meta()), 'bills');
    this.snack.open(`${bills.length} bill${bills.length === 1 ? '' : 's'} exported`, undefined, {
      duration: 3200,
    });
  }

  protected exportPayments(): void {
    const bills = this.filtered();
    const rows = bills.reduce((n, b) => n + b.payments.length, 0);
    this.download(paymentsCsv(bills, this.meta()), 'payments');
    this.snack.open(
      `${rows} payment${rows === 1 ? '' : 's'} of ${bills.length} bill${bills.length === 1 ? '' : 's'} exported`,
      undefined,
      { duration: 3200 },
    );
  }

  /** What the report covers and who made it, written at the top of every export. */
  private meta(): ReportMeta {
    const method = this.method();
    const q = this.query().trim();
    const filters = [
      method ? `bills paid by ${methodName(method)}` : '',
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

  private download(csv: string, what: string): void {
    const p = this.period();
    const slug = this.arena
      .current()
      .name.toLowerCase()
      .replace(/[^a-z0-9]+/g, '-');
    const days = p.first === p.last ? p.first : `${p.first}_to_${p.last}`;
    try {
      // A byte-order mark so spreadsheet apps read ₹ and names as UTF-8.
      const url = URL.createObjectURL(new Blob(['﻿', csv], { type: 'text/csv' }));
      const a = this.document.createElement('a');
      a.href = url;
      a.download = `${slug || 'arena'}-${what}-${days}.csv`;
      a.click();
      setTimeout(() => URL.revokeObjectURL(url));
    } catch {
      // Download blocked (e.g. a sandboxed preview): the snackbar still reports the count.
    }
  }
}
