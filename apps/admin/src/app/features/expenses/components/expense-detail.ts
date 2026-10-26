import { Component, computed, inject, input, output, resource } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatIcon } from '@angular/material/icon';
import { MatProgressBar } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { DetailPane } from '../../../shared/list-detail/detail-pane';
import { DetailRow } from '../../../shared/list-detail/detail-row';
import { DetailSection } from '../../../shared/list-detail/detail-section';
import { formatDayYear } from '../../../shared/staff/staff-format';
import { StatTile } from '../../../shared/stat-tile/stat-tile';
import { StatusPill } from '../../../shared/status-pill/status-pill';
import { formatDate, formatTime } from '../../../shared/time/ist';
import { ExpensesStore } from '../data/expenses-store';
import {
  Expense,
  ExpenseDetail as Detail,
  ExpenseHistoryEntry,
  ExpensePayment,
  expenseIcon,
  expenseMethodName,
  expenseState,
  expenseWhen,
  formatAmount,
  isAdvance,
  salaryPeriodName,
  sourceLabel,
} from '../data/expense.models';
import { ExpenseDialog, ExpenseDialogData, ExpenseDialogResult } from '../dialogs/expense-dialog';
import { ExpensePaymentDialog, ExpensePaymentDialogData } from '../dialogs/expense-payment-dialog';
import { ReversePaymentDialog, ReversePaymentDialogData } from '../dialogs/reverse-payment-dialog';
import { VoidExpenseDialog, VoidExpenseDialogData } from '../dialogs/void-expense-dialog';

/** The changed fields of an expense.update audit entry, in words. */
const FIELD_NAMES: Readonly<Record<string, string>> = {
  title: 'title',
  category_id: 'category',
  staff_id: 'staff member',
  period_start: 'period',
  period_end: 'period',
  expense_date: 'date',
  notes: 'notes',
};

/**
 * One expense or salary period: what is owed, what was paid and from whose money (company or an
 * owner's own), what is left, and every change with who, when and why. Payments are never
 * edited: a mistake is reversed (same source, owner, method and day) and the original stays.
 * The list's summary shows at once; payments and history load from arena_expense().
 */
@Component({
  selector: 'app-expense-detail',
  imports: [
    DetailPane,
    DetailSection,
    DetailRow,
    StatTile,
    StatusPill,
    MatButton,
    MatIcon,
    MatProgressBar,
  ],
  template: `
    @let e = shown();
    <app-detail-pane
      [crumb]="(e.kind === 'salary' ? 'Expenses / Salaries / ' : 'Expenses / ') + e.title"
      [icon]="icon(e)"
      [heading]="e.title"
      [subtitle]="when()"
      (closed)="closed.emit()"
    >
      @if (!e.voided) {
        <div actions class="arena-compact flex flex-wrap gap-2">
          @if (e.balancePaise > 0) {
            <button mat-flat-button type="button" (click)="pay()">
              <mat-icon aria-hidden="true">payments</mat-icon>Record payment
            </button>
          }
          <button mat-stroked-button type="button" (click)="edit()">
            <mat-icon aria-hidden="true">edit</mat-icon>Edit
          </button>
          <button mat-button type="button" class="danger-action" (click)="voidIt()">
            <mat-icon aria-hidden="true">block</mat-icon>Void
          </button>
        </div>
      }
      <span chip class="flex flex-wrap items-center gap-1.5">
        <app-status-pill [tone]="state().tone">{{ state().label }}</app-status-pill>
        @if (e.kind === 'salary') {
          <app-status-pill tone="info">Salary</app-status-pill>
        }
      </span>
      <span
        big
        class="flex-none font-display text-[32px] leading-none font-bold tabular-nums"
        [class.text-muted]="e.voided"
        [class.line-through]="e.voided"
        >{{ amount(e.amountPaise) }}</span
      >

      <div stats class="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <app-stat-tile label="Amount" [value]="amount(e.amountPaise)" />
        <app-stat-tile label="Paid" [value]="amount(e.paidPaise)" />
        <app-stat-tile label="Company · Personal" [value]="split()" />
        <app-stat-tile
          [label]="e.voided ? 'Expense' : 'Balance'"
          [value]="e.voided ? 'Void' : amount(e.balancePaise)"
        />
      </div>

      @if (e.voided) {
        <div
          role="note"
          class="flex items-start gap-3 rounded-card bg-danger-soft px-4 py-3 text-sm leading-[1.45]"
        >
          <mat-icon class="flex-none text-danger" aria-hidden="true">block</mat-icon>
          <span class="min-w-0">
            <span class="font-semibold">Voided</span>
            {{ voidWho() }}. It counts in no total.
            @if (e.voidReason) {
              <span class="mt-1 block text-muted">“{{ e.voidReason }}”</span>
            }
          </span>
        </div>
      }

      <app-detail-section heading="Details">
        <dl class="grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-2 md:grid-cols-3">
          @for (f of facts(); track f.label) {
            <div class="flex min-w-0 flex-col gap-1">
              <dt class="text-[12.5px] leading-none text-muted">{{ f.label }}</dt>
              <dd class="text-sm leading-[1.35] font-medium [overflow-wrap:anywhere]">
                {{ f.value }}
              </dd>
            </div>
          }
        </dl>
        @if (e.notes) {
          <div class="flex flex-col gap-1">
            <span class="text-[12.5px] leading-none text-muted">Notes</span>
            <p class="text-sm leading-[1.45] whitespace-pre-line [overflow-wrap:anywhere]">
              {{ e.notes }}
            </p>
          </div>
        }
      </app-detail-section>

      @if (detail.isLoading() && !detail.hasValue()) {
        <mat-progress-bar mode="indeterminate" aria-label="Loading the expense" />
      }
      @if (detail.error(); as error) {
        <app-detail-section>
          <p role="alert" class="text-sm text-danger">{{ message(error) }}</p>
          <div>
            <button mat-stroked-button type="button" (click)="detail.reload()">Try again</button>
          </div>
        </app-detail-section>
      }

      <div class="grid grid-cols-1 items-start gap-5 lg:grid-cols-2">
        <app-detail-section heading="Payments">
          <ol class="flex flex-col gap-3" aria-label="Payments">
            @for (p of e.payments; track p.id) {
              <li class="flex items-start gap-3">
                <span
                  class="icon grid size-8 flex-none place-items-center rounded-full text-[18px]"
                  [class.bg-danger-soft]="p.kind === 'reversal'"
                  [class.text-danger]="p.kind === 'reversal'"
                  [class.bg-success-soft]="p.kind === 'payment' && !p.reversed"
                  [class.text-success]="p.kind === 'payment' && !p.reversed"
                  [class.bg-surface-sunken]="p.kind === 'payment' && p.reversed"
                  [class.text-muted]="p.kind === 'payment' && p.reversed"
                  aria-hidden="true"
                  >{{ p.kind === 'reversal' ? 'undo' : 'payments' }}</span
                >
                <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                  <span
                    class="flex flex-wrap items-center gap-1.5 text-sm leading-[1.3] font-medium"
                  >
                    {{ p.kind === 'reversal' ? 'Reversal' : method(p.method) }}
                    <app-status-pill [tone]="p.paidFrom === 'company' ? 'info' : 'primary'">{{
                      source(p)
                    }}</app-status-pill>
                    @if (advance(e, p)) {
                      <app-status-pill tone="warning">Advance</app-status-pill>
                    }
                    @if (p.reversed) {
                      <app-status-pill tone="danger">Reversed</app-status-pill>
                    }
                  </span>
                  <span class="text-[12.5px] leading-[1.3] text-muted">{{ paymentSub(p) }}</span>
                  @if (p.note) {
                    <span class="text-[12.5px] leading-[1.4] text-muted">“{{ p.note }}”</span>
                  }
                </span>
                <span class="flex flex-none flex-col items-end gap-1">
                  <span
                    class="text-sm leading-[1.3] font-semibold tabular-nums"
                    [class.text-danger]="p.amountPaise < 0"
                    [class.line-through]="p.reversed"
                    >{{ amount(p.amountPaise) }}</span
                  >
                  @if (p.kind === 'payment' && !p.reversed && !e.voided && full()) {
                    <button
                      mat-button
                      type="button"
                      class="arena-compact danger-action"
                      [attr.aria-label]="'Reverse the ' + amount(p.amountPaise) + ' payment'"
                      (click)="reverse(p)"
                    >
                      Reverse
                    </button>
                  }
                </span>
              </li>
            } @empty {
              <li class="text-[13px] leading-[1.45] text-muted">No payments recorded.</li>
            }
          </ol>
          @if (e.payments.length) {
            <div class="h-px bg-border" role="presentation"></div>
            <app-detail-row label="Paid by the company" [value]="amount(e.paidCompanyPaise)" />
            <app-detail-row label="Paid personally" [value]="amount(e.paidPersonalPaise)" />
            <app-detail-row label="Paid" [value]="amount(e.paidPaise)" [strong]="true" />
          }
          @if (!e.voided) {
            <app-detail-row label="Balance" [value]="amount(e.balancePaise)" />
          }
        </app-detail-section>

        <app-detail-section heading="History">
          @if (full(); as d) {
            <ol class="flex flex-col gap-3" aria-label="History">
              @for (h of d.history; track $index) {
                <li class="flex items-start gap-3">
                  <span
                    class="icon grid size-8 flex-none place-items-center rounded-full bg-surface-sunken text-[18px] text-muted"
                    aria-hidden="true"
                    >{{ historyIcon(h) }}</span
                  >
                  <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span class="text-sm leading-[1.3] font-medium">{{ historyLabel(h) }}</span>
                    <span class="text-[12.5px] leading-[1.3] text-muted">{{ historyWho(h) }}</span>
                    @if (h.reason) {
                      <span class="text-[12.5px] leading-[1.4] text-muted">“{{ h.reason }}”</span>
                    }
                  </span>
                </li>
              } @empty {
                <li class="text-[13px] leading-[1.45] text-muted">No changes recorded.</li>
              }
            </ol>
          } @else {
            <p class="text-[13px] leading-[1.45] text-muted">Loading…</p>
          }
        </app-detail-section>
      </div>
    </app-detail-pane>
  `,
})
export class ExpenseDetail {
  private readonly store = inject(ExpensesStore);
  private readonly arena = inject(ArenaContext);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);

  /** The list's summary of the expense (shown until the full one loads). */
  readonly expense = input.required<Expense>();
  readonly closed = output<void>();

  protected readonly detail = resource({
    params: () => ({
      arena: this.arena.current().id,
      id: this.expense().id,
      revision: this.store.revision(),
    }),
    loader: ({ params }) => this.store.get(params.id),
  });
  /** The loaded expense, once it matches the selected one. */
  protected readonly full = computed<Detail | undefined>(() => {
    const d = this.detail.hasValue() ? this.detail.value() : undefined;
    return d?.id === this.expense().id ? d : undefined;
  });
  protected readonly shown = computed<Expense>(() => this.full() ?? this.expense());

  protected readonly amount = formatAmount;
  protected readonly icon = expenseIcon;
  protected readonly method = expenseMethodName;
  protected readonly source = sourceLabel;
  protected readonly advance = isAdvance;
  protected readonly state = computed(() => expenseState(this.shown()));
  protected readonly when = computed(() => {
    const e = this.shown();
    return [e.kind === 'salary' ? e.staffName : e.categoryName, expenseWhen(e)]
      .filter(Boolean)
      .join(' · ');
  });
  protected readonly split = computed(() => {
    const e = this.shown();
    return `${formatAmount(e.paidCompanyPaise)} · ${formatAmount(e.paidPersonalPaise)}`;
  });
  protected readonly facts = computed(() => {
    const e = this.shown();
    const out: { label: string; value: string }[] = [];
    if (e.kind === 'salary') {
      out.push(
        { label: 'Staff member', value: e.staffName ?? '—' },
        {
          label: 'Period',
          value: e.periodStart && e.periodEnd ? salaryPeriodName(e.periodStart, e.periodEnd) : '—',
        },
      );
      if (e.periodStart && e.periodEnd) {
        out.push({
          label: 'Days',
          value: `${formatDayYear(e.periodStart)} – ${formatDayYear(e.periodEnd)}`,
        });
      }
    } else {
      out.push(
        { label: 'Category', value: e.categoryName ?? '—' },
        { label: 'Date', value: formatDayYear(e.expenseDate) },
      );
      if (e.staffName) out.push({ label: 'For', value: e.staffName });
    }
    out.push({
      label: 'Added',
      value: [e.createdByName, this.stamp(e.createdAt)].filter(Boolean).join(' · '),
    });
    return out;
  });
  protected readonly voidWho = computed(() => {
    const v = [...(this.full()?.history ?? [])].reverse().find((h) => h.action === 'void');
    return v ? `by ${v.by ?? 'Unknown'} · ${this.stamp(v.at)}` : '';
  });

  protected paymentSub(p: ExpensePayment): string {
    const day = `Paid ${formatDayYear(p.paidOn)}`;
    return [p.kind === 'reversal' ? `${expenseMethodName(p.method)} · ${day}` : day, p.by]
      .filter(Boolean)
      .join(' · ');
  }

  protected stamp(at: string): string {
    return `${formatDate(at)}, ${formatTime(at)}`;
  }

  protected historyIcon(h: ExpenseHistoryEntry): string {
    switch (h.action) {
      case 'add':
        return 'add';
      case 'update':
        return 'edit';
      case 'payment_reverse':
        return 'undo';
      case 'void':
        return 'block';
      default:
        return 'history';
    }
  }

  protected historyLabel(h: ExpenseHistoryEntry): string {
    const paise = (v: unknown) => formatAmount(Number(v ?? 0));
    switch (h.action) {
      case 'add':
        return `Added · ${paise(h.after?.['amount_paise'])}`;
      case 'update':
        return `Edited · ${this.changes(h)}`;
      case 'payment_reverse':
        return `Payment reversed · paid ${paise(h.before?.['paid_paise'])} → ${paise(h.after?.['paid_paise'])}`;
      case 'void': {
        const n = Number(h.after?.['reversed_payments'] ?? 0);
        return `Voided${n ? ` · ${n} payment${n === 1 ? '' : 's'} reversed` : ''}`;
      }
      default:
        return h.action;
    }
  }

  protected historyWho(h: ExpenseHistoryEntry): string {
    return `${h.by ?? 'Unknown'} · ${this.stamp(h.at)}`;
  }

  protected message(error: unknown): string {
    return toAppError(error).message;
  }

  protected pay(): void {
    const expense = this.shown();
    this.dialog
      .open<ExpensePaymentDialog, ExpensePaymentDialogData, string>(ExpensePaymentDialog, {
        data: { expense },
        width: '560px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((snack) => this.say(snack));
  }

  protected edit(): void {
    this.dialog
      .open<ExpenseDialog, ExpenseDialogData, ExpenseDialogResult>(ExpenseDialog, {
        data: { expense: this.shown() },
        width: '560px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((r) => this.say(r?.snack));
  }

  protected voidIt(): void {
    this.dialog
      .open<VoidExpenseDialog, VoidExpenseDialogData, string>(VoidExpenseDialog, {
        data: { expense: this.shown() },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((snack) => this.say(snack));
  }

  protected reverse(payment: ExpensePayment): void {
    this.dialog
      .open<ReversePaymentDialog, ReversePaymentDialogData, string>(ReversePaymentDialog, {
        data: { expense: this.shown(), payment },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((snack) => this.say(snack));
  }

  /** "amount ₹18,000 → ₹15,000, notes": what an edit changed. */
  private changes(h: ExpenseHistoryEntry): string {
    const keys = Object.keys(h.after ?? {});
    const parts: string[] = [];
    if (keys.includes('amount_paise')) {
      parts.push(
        `amount ${formatAmount(Number(h.before?.['amount_paise'] ?? 0))} → ${formatAmount(Number(h.after?.['amount_paise'] ?? 0))}`,
      );
    }
    for (const k of keys) {
      const name = FIELD_NAMES[k];
      if (name && !parts.includes(name)) parts.push(name);
    }
    return parts.join(', ') || 'details';
  }

  private say(snack: string | undefined): void {
    if (snack) this.snack.open(snack, undefined, { duration: 3200 });
  }
}
