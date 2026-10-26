import { Component, computed, inject, input } from '@angular/core';
import { FieldTree, FormField, SchemaPathTree, validate } from '@angular/forms/signals';
import { MatButtonToggle, MatButtonToggleGroup } from '@angular/material/button-toggle';
import { MatFormField, MatHint, MatLabel } from '@angular/material/form-field';
import { MatInput } from '@angular/material/input';
import { MatOption, MatSelect } from '@angular/material/select';
import { Session } from '../../../core/auth/session';
import { istDayStartOf } from '../../../shared/time/ist';
import { TeamStore } from '../../team/data/team-store';
import { TeamMember } from '../../team/data/team.models';
import { parseRupees } from '../../sales/data/sale.models';
import { PaymentInput } from '../data/expenses-api';
import {
  EXPENSE_METHODS,
  ExpenseMethod,
  MAX_PAYMENT_NOTE,
  PaidFrom,
  expenseMethodName,
  formatAmount,
} from '../data/expense.models';

/** A payment as typed: rupees as text, the owner who paid only when it was their own money. */
export interface PaymentModel {
  amount: string;
  paidOn: string;
  method: ExpenseMethod;
  paidFrom: PaidFrom;
  /** An owner's staff profile id; '' for company money. */
  payerId: string;
  note: string;
}

export interface PaymentRuleOptions {
  /** The payment is being recorded (a "Pay now" off: nothing is checked). */
  readonly active: () => boolean;
  /** What is still due: more is refused. */
  readonly limit: () => number;
  /** The arena's today (IST): a payment is never dated after it. */
  readonly today: () => string;
  /** The amount is the expense's own (paid in full): not typed, not checked here. */
  readonly fixedAmount?: () => boolean;
}

/**
 * The server's payment checks (_expense_pay), in the form: an amount up to what is due, a day
 * up to today, and for an owner's own money the owner who paid. Checked only while `active`.
 */
export function paymentRules(p: SchemaPathTree<PaymentModel>, o: PaymentRuleOptions): void {
  validate(p.amount, ({ value }) => {
    if (!o.active() || o.fixedAmount?.()) return null;
    const paise = parseRupees(value());
    if (paise === null) {
      return { kind: 'amount', message: 'Enter the amount paid in rupees, like 2300 or 2300.50' };
    }
    if (paise > o.limit()) {
      return { kind: 'limit', message: `That is more than the ${formatAmount(o.limit())} due` };
    }
    return null;
  });
  validate(p.paidOn, ({ value }) => {
    if (!o.active()) return null;
    const day = value();
    if (!istDayStartOf(day) || day < '2000-01-01') {
      return { kind: 'day', message: 'Pick the day it was paid' };
    }
    return day > o.today()
      ? { kind: 'future', message: 'A payment cannot be dated after today' }
      : null;
  });
  validate(p.payerId, ({ value, valueOf }) =>
    o.active() && valueOf(p.paidFrom) === 'personal' && !value()
      ? { kind: 'payer', message: 'Pick the owner who paid' }
      : null,
  );
  validate(p.note, ({ value }) =>
    o.active() && value().trim().length > MAX_PAYMENT_NOTE
      ? { kind: 'note', message: `Keep the note to ${MAX_PAYMENT_NOTE} characters` }
      : null,
  );
}

/** What the API sends for a checked payment model. */
export function paymentInput(m: PaymentModel): PaymentInput {
  const personal = m.paidFrom === 'personal';
  return {
    amountPaise: parseRupees(m.amount) ?? 0,
    method: m.method,
    paidOn: m.paidOn,
    paidFrom: m.paidFrom,
    payerStaffId: personal ? m.payerId || null : null,
    note: m.note.trim() || null,
  };
}

/** The owners who can pay from their own money: active, not removed. */
export function payers(staff: readonly TeamMember[] | null): TeamMember[] {
  return (staff ?? []).filter((s) => s.role === 'owner' && s.active && !s.removed);
}

/**
 * The team (read if not yet), the owners who can pay personally and the signed-in one among
 * them (the default payer). Call in a component's injection context.
 */
export function injectPayers() {
  const team = inject(TeamStore);
  const session = inject(Session);
  void team.load();
  const owners = computed(() => payers(team.staff()));
  const me = computed(() => owners().find((o) => o.userId === session.user()?.id)?.id ?? '');
  return { team, owners, me };
}

let nextId = 0;

/**
 * The payment block of the expense, salary and payment dialogs: amount, day, method, and whose
 * money paid — the company's, or an owner's own (picked by their owner record, never typed).
 * An owner's own money is their contribution: it is never counted as company cash out.
 */
@Component({
  selector: 'app-payment-fields',
  imports: [
    FormField,
    MatButtonToggleGroup,
    MatButtonToggle,
    MatFormField,
    MatHint,
    MatLabel,
    MatInput,
    MatSelect,
    MatOption,
  ],
  host: { class: 'flex flex-col gap-4' },
  template: `
    @let p = f();
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
      @if (showAmount()) {
        <mat-form-field>
          <mat-label>Amount paid (₹)</mat-label>
          <input matInput inputmode="decimal" autocomplete="off" [formField]="p.amount" />
          @if (hint()) {
            <mat-hint>{{ hint() }}</mat-hint>
          }
        </mat-form-field>
      }
      <mat-form-field>
        <mat-label>Paid on</mat-label>
        <input matInput type="date" [formField]="p.paidOn" />
      </mat-form-field>
    </div>
    <mat-form-field>
      <mat-label>Method</mat-label>
      <mat-select [formField]="p.method">
        @for (m of methods; track m) {
          <mat-option [value]="m">{{ methodName(m) }}</mat-option>
        }
      </mat-select>
    </mat-form-field>
    <div class="flex flex-col gap-2">
      <span [id]="id + '-from'" class="text-[13px] leading-none font-medium text-muted"
        >Paid from</span
      >
      <mat-button-toggle-group
        class="arena-seg self-start"
        hideSingleSelectionIndicator
        [attr.aria-labelledby]="id + '-from'"
        [attr.aria-describedby]="id + '-from-sub'"
        [formField]="p.paidFrom"
        (change)="sourcePicked($event.value)"
      >
        <mat-button-toggle value="company">Company</mat-button-toggle>
        <mat-button-toggle value="personal">Personal</mat-button-toggle>
      </mat-button-toggle-group>
      <span [id]="id + '-from-sub'" class="text-[12.5px] leading-[1.35] text-muted">{{
        personal()
          ? 'An owner’s own money: counted as their contribution, not as company cash'
          : 'Out of the arena’s own account'
      }}</span>
    </div>
    @if (personal()) {
      <mat-form-field>
        <mat-label>Owner who paid</mat-label>
        <mat-select [formField]="p.payerId">
          @for (o of owners(); track o.id) {
            <mat-option [value]="o.id">{{ o.name }}</mat-option>
          }
        </mat-select>
        @if (!owners().length) {
          <mat-hint>No active owner to pick</mat-hint>
        }
      </mat-form-field>
    }
    <mat-form-field>
      <mat-label>Note (optional)</mat-label>
      <input matInput autocomplete="off" [formField]="p.note" />
    </mat-form-field>
  `,
})
export class PaymentFields {
  readonly f = input.required<FieldTree<PaymentModel>>();
  /** The owners who can pay from their own money. */
  readonly owners = input.required<readonly TeamMember[]>();
  /** Picked when Personal is chosen and no owner is: the signed-in owner. */
  readonly defaultPayer = input('');
  /** Under the amount, e.g. "₹25,000 due". */
  readonly hint = input('');
  /** Off when the amount is the expense's own (paid in full). */
  readonly showAmount = input(true);

  protected readonly id = `pay-${++nextId}`;
  protected readonly methods = EXPENSE_METHODS;
  protected readonly methodName = expenseMethodName;
  protected readonly personal = computed(() => this.f().paidFrom().value() === 'personal');

  protected sourcePicked(from: PaidFrom): void {
    const payer = this.f().payerId();
    if (from === 'personal' && !payer.value()) payer.value.set(this.defaultPayer());
    // Company money names nobody.
    if (from === 'company') payer.value.set('');
  }
}
