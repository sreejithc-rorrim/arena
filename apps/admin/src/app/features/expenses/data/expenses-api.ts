import { Service, inject } from '@angular/core';
import { dbError } from '../../../core/arena/arena-api';
import { AppError } from '../../../core/auth/auth-api';
import { Supabase } from '../../../core/supabase/supabase';
import { Attempt, PushRefusal, SyncOp, pushOps } from '../../../core/sync/push-ops';
import {
  Expense,
  ExpenseCategory,
  ExpenseDetail,
  ExpenseHistoryEntry,
  ExpenseKind,
  ExpenseMethod,
  ExpensePayment,
  ExpensePaymentStatus,
  ExpensesData,
  PaidFrom,
  PaymentLine,
  SalaryPeriod,
  StaffSalary,
  StaffSalaryRecord,
} from './expense.models';

/** A payment to record: with a new expense, or later (expense.pay). */
export interface PaymentInput {
  readonly amountPaise: number;
  readonly method: ExpenseMethod;
  /** IST day the money went out (today or before). */
  readonly paidOn: string;
  readonly paidFrom: PaidFrom;
  /** The owner whose own money it was: personal only, null for company. */
  readonly payerStaffId: string | null;
  readonly note: string | null;
}

/** An expense's details (expense.add, expense.update): every field, as the owner left them. */
export interface ExpenseInput {
  readonly kind: ExpenseKind;
  readonly title: string;
  readonly amountPaise: number;
  readonly notes: string | null;
  /** A salary's person; optional on a cost. */
  readonly staffId: string | null;
  /** A cost's category and day. */
  readonly categoryId: string | null;
  readonly expenseDate: string | null;
  /** A salary's first and last day. */
  readonly periodStart: string | null;
  readonly periodEnd: string | null;
}

/** An agreed salary from a day on (staff_salary.set; the same day again corrects that row). */
export interface SalaryInput {
  readonly staffId: string;
  readonly effectiveFrom: string;
  readonly period: SalaryPeriod;
  readonly amountPaise: number;
  readonly note: string | null;
}

/** A new expense, optionally paid at once and (a salary) saved as the agreed salary first. */
export interface NewExpense extends ExpenseInput {
  readonly payment: PaymentInput | null;
  readonly agreed: SalaryInput | null;
  /** This action's ids, reused when the same Save is sent again (NG-002). */
  readonly attempt?: Attempt;
}

/** A category to add or change (expense_category.upsert). */
export interface CategoryInput {
  readonly id: string;
  readonly name: string;
  readonly sortOrder: number;
  readonly active: boolean;
}

/**
 * The arena's expenses: read through arena_expenses() / arena_expense() / arena_staff_salary()
 * and the RLS-visible categories and agreed salaries (all `money` only); every write is an op
 * through sync_push, with the server's checks and audit history. Payments are never edited: a
 * mistake is reversed by a new row that keeps the payment's source, payer, method and day.
 * Tests provide SampleExpensesApi.
 */
@Service({ factory: () => new SupabaseExpensesApi() })
export abstract class ExpensesApi {
  /** Expenses dated `first`…`last` (IST days), the payments made then, and what is owed overall. */
  abstract list(arenaId: string, first: string, last: string): Promise<ExpensesData>;
  abstract get(arenaId: string, id: string): Promise<ExpenseDetail>;
  abstract staffSalary(arenaId: string, staffId: string): Promise<StaffSalaryRecord>;
  abstract categories(arenaId: string): Promise<ExpenseCategory[]>;
  /** Every agreed salary of the arena (each person's history). */
  abstract salaries(arenaId: string): Promise<StaffSalary[]>;
  /** The standard category names (expense_category_catalog). */
  abstract catalog(): Promise<string[]>;
  abstract saveCategories(arenaId: string, categories: readonly CategoryInput[]): Promise<void>;
  /** Deleted when no expense uses it, else turned off (kept for those expenses). */
  abstract removeCategory(arenaId: string, id: string): Promise<'deleted' | 'retired'>;
  abstract add(arenaId: string, entry: NewExpense): Promise<void>;
  abstract update(
    arenaId: string,
    expense: Expense,
    change: ExpenseInput,
    attempt?: Attempt,
  ): Promise<void>;
  abstract pay(
    arenaId: string,
    expense: Expense,
    payment: PaymentInput,
    attempt?: Attempt,
  ): Promise<void>;
  abstract reverse(
    arenaId: string,
    payment: ExpensePayment,
    reason: string,
    attempt?: Attempt,
  ): Promise<void>;
  /** Voids it; with `reversePayments`, each payment is reversed first. Resolves with how many. */
  abstract void(
    arenaId: string,
    expense: Expense,
    reason: string,
    reversePayments: boolean,
    attempt?: Attempt,
  ): Promise<number>;
  abstract setSalary(arenaId: string, salary: SalaryInput, attempt?: Attempt): Promise<void>;
}

/** Server codes (sync_push / the expense reads) worded for the Expenses screens. */
export const EXPENSES_MESSAGES: Readonly<Record<string, string>> = {
  forbidden: 'Only members with the Money permission can do that',
  not_found: 'That is no longer in the records. Refresh',
  invalid_range: 'Pick at most 400 days',
  duplicate: 'That was already recorded. Refresh',
  missing_reference: 'Something it refers to is no longer there. Refresh',
  invalid: 'Check the values and try again',
  invalid_payload: 'Check the values and try again',
  server_error: 'The server could not save that. Try again',
  unknown_op: 'This server does not have expenses yet. Apply the latest migrations',
  invalid_name: 'Give the category a name of up to 40 characters',
  invalid_kind: 'Pick a running cost or a salary',
  title_required: 'Give the expense a title',
  title_too_long: 'Keep the title to 80 characters',
  notes_too_long: 'Keep the notes to 1,000 characters',
  note_too_long: 'Keep the note to 200 characters',
  amount_invalid: 'Enter an amount from ₹0.01 to ₹1,00,00,000',
  amount_zero: 'Enter an amount',
  amount_negative: 'Enter an amount more than ₹0',
  amount_below_paid: 'The amount cannot be less than what is already paid. Reverse a payment first',
  category_required: 'Pick a category',
  category_retired: 'That category is turned off. Turn it on in Categories or pick another',
  staff_required: 'Pick the staff member',
  staff_removed: 'That person was removed from the team',
  own_record: 'You cannot record or change your own salary. Ask an owner',
  period_required: 'Pick the salary period',
  invalid_period: 'A salary period ends on or after it starts and covers at most 62 days',
  salary_period_taken: 'A salary is already recorded for part of that period',
  invalid_salary_period: 'Pick monthly or weekly',
  date_required: 'Pick a date',
  date_out_of_range: 'Pick a date from 2000 to a year from today',
  date_in_future: 'A payment cannot be dated after today',
  invalid_method: 'Pick how it was paid',
  invalid_paid_from: 'Pick who paid: the company or an owner',
  payer_required: 'Pick the owner who paid',
  payer_not_allowed: 'A company payment has no personal payer',
  payer_not_owner: 'Only an owner can pay from their own money',
  overpayment: 'That is more than is due on this expense',
  voided: 'This expense is void: it takes no changes or payments',
  already_reversed: 'That payment was already reversed',
  reason_required: 'Give a reason',
  reason_too_long: 'Keep the reason to 500 characters',
  void_reason_required: 'Give a reason for the void',
  expense_has_payments: 'This expense has payments: reverse them to void it',
  reversal_mismatch: 'That reversal does not match its payment. Refresh',
};

/** Category writes: a clash is a name already in use. */
export const CATEGORY_MESSAGES: Readonly<Record<string, string>> = {
  ...EXPENSES_MESSAGES,
  duplicate: 'A category with that name already exists',
};

type Row = Record<string, unknown>;

const text = (v: unknown) => (v == null ? null : String(v));
const rows = (v: unknown) => (v as Row[] | null) ?? [];

function toExpensePayment(p: Row): ExpensePayment {
  return {
    id: String(p['id']),
    kind: p['kind'] === 'reversal' ? 'reversal' : 'payment',
    amountPaise: Number(p['amount_paise'] ?? 0),
    method: p['method'] as ExpenseMethod,
    paidOn: String(p['paid_on']),
    paidFrom: p['paid_from'] === 'personal' ? 'personal' : 'company',
    payerStaffId: text(p['payer_staff_id']),
    payerName: text(p['payer_name']),
    note: text(p['note']),
    reversesId: text(p['reverses_id']),
    reversed: p['reversed'] === true,
    by: text(p['created_by_name']),
    at: String(p['created_at'] ?? ''),
  };
}

export function toExpense(r: Row): Expense {
  return {
    id: String(r['id']),
    kind: r['kind'] === 'salary' ? 'salary' : 'general',
    title: String(r['title'] ?? ''),
    categoryId: text(r['category_id']),
    categoryName: text(r['category_name']),
    staffId: text(r['staff_id']),
    staffName: text(r['staff_name']),
    periodStart: text(r['period_start']),
    periodEnd: text(r['period_end']),
    amountPaise: Number(r['amount_paise'] ?? 0),
    paidPaise: Number(r['paid_paise'] ?? 0),
    paidCompanyPaise: Number(r['paid_company_paise'] ?? 0),
    paidPersonalPaise: Number(r['paid_personal_paise'] ?? 0),
    balancePaise: Number(r['balance_paise'] ?? 0),
    paymentStatus: (r['payment_status'] as ExpensePaymentStatus) ?? 'unpaid',
    voided: r['status'] === 'voided',
    voidReason: text(r['void_reason']),
    expenseDate: String(r['expense_date']),
    notes: text(r['notes']),
    createdByName: text(r['created_by_name']),
    createdAt: String(r['created_at'] ?? ''),
    payments: rows(r['payments']).map(toExpensePayment),
  };
}

function toDetail(r: Row): ExpenseDetail {
  const json = (v: unknown) =>
    v && typeof v === 'object' ? (v as Readonly<Record<string, unknown>>) : null;
  return {
    ...toExpense(r),
    history: rows(r['history']).map((h): ExpenseHistoryEntry => ({
      at: String(h['at']),
      action: String(h['action']),
      by: text(h['by_name']),
      reason: text(h['reason']),
      before: json(h['before']),
      after: json(h['after']),
    })),
  };
}

function toPaymentLine(p: Row): PaymentLine {
  return {
    id: String(p['id']),
    expenseId: String(p['expense_id']),
    expenseTitle: String(p['expense_title'] ?? ''),
    expenseKind: p['expense_kind'] === 'salary' ? 'salary' : 'general',
    expenseVoided: p['expense_status'] === 'voided',
    categoryName: text(p['category_name']),
    staffId: text(p['staff_id']),
    staffName: text(p['staff_name']),
    kind: p['kind'] === 'reversal' ? 'reversal' : 'payment',
    amountPaise: Number(p['amount_paise'] ?? 0),
    method: p['method'] as ExpenseMethod,
    paidOn: String(p['paid_on']),
    paidFrom: p['paid_from'] === 'personal' ? 'personal' : 'company',
    payerStaffId: text(p['payer_staff_id']),
    payerName: text(p['payer_name']),
    note: text(p['note']),
    reversesId: text(p['reverses_id']),
  };
}

export function toExpensesData(d: Row | null): ExpensesData {
  return {
    expenses: rows(d?.['expenses']).map(toExpense),
    payments: rows(d?.['payments']).map(toPaymentLine),
    owedTotalPaise: Number(d?.['owed_total_paise'] ?? 0),
    owedCount: Number(d?.['owed_count'] ?? 0),
  };
}

function toSalary(s: Row, staffId?: string): StaffSalary {
  return {
    id: String(s['id']),
    staffId: staffId ?? String(s['staff_id']),
    effectiveFrom: String(s['effective_from']),
    period: s['period'] === 'weekly' ? 'weekly' : 'monthly',
    amountPaise: Number(s['amount_paise'] ?? 0),
    note: text(s['note']),
  };
}

// ------------------------------------------------------------------- ops (sample shares them)

function paymentPayload(p: PaymentInput, paymentId: string): Record<string, unknown> {
  return {
    payment_id: paymentId,
    amount_paise: p.amountPaise,
    method: p.method,
    paid_on: p.paidOn,
    paid_from: p.paidFrom,
    payer_staff_id: p.paidFrom === 'personal' ? p.payerStaffId : null,
    note: p.note,
  };
}

function detailsPayload(e: ExpenseInput): Record<string, unknown> {
  return {
    title: e.title,
    amount_paise: e.amountPaise,
    notes: e.notes,
    staff_id: e.staffId,
    ...(e.kind === 'salary'
      ? { period_start: e.periodStart, period_end: e.periodEnd }
      : { category_id: e.categoryId, expense_date: e.expenseDate }),
  };
}

export function salaryOp(s: SalaryInput, opId?: string): SyncOp {
  return {
    kind: 'staff_salary.set',
    opId,
    payload: {
      staff_id: s.staffId,
      effective_from: s.effectiveFrom,
      period: s.period,
      amount_paise: s.amountPaise,
      note: s.note,
    },
  };
}

/** The agreed salary first (when asked), then the expense with its payment: one push. */
export function addOps(e: NewExpense, expenseId: string, paymentId: string): SyncOp[] {
  const add: SyncOp = {
    kind: 'expense.add',
    opId: e.attempt?.id('op'),
    payload: {
      expense_id: expenseId,
      kind: e.kind,
      ...detailsPayload(e),
      ...(e.payment ? { payment: paymentPayload(e.payment, paymentId) } : {}),
    },
  };
  return e.agreed ? [salaryOp(e.agreed, e.attempt?.id('salary-op')), add] : [add];
}

export function updateOp(expense: Expense, change: ExpenseInput, opId?: string): SyncOp {
  return {
    kind: 'expense.update',
    opId,
    payload: { expense_id: expense.id, ...detailsPayload({ ...change, kind: expense.kind }) },
  };
}

export function payOp(expense: Expense, p: PaymentInput, paymentId: string, opId?: string): SyncOp {
  return {
    kind: 'expense.pay',
    opId,
    payload: { expense_id: expense.id, ...paymentPayload(p, paymentId) },
  };
}

export function reverseOp(
  payment: ExpensePayment,
  reason: string,
  reversalId: string,
  opId?: string,
): SyncOp {
  return {
    kind: 'expense.payment_reverse',
    opId,
    payload: { payment_id: payment.id, reversal_id: reversalId, reason },
  };
}

export function voidOp(
  expense: Expense,
  reason: string,
  reversePayments: boolean,
  opId?: string,
): SyncOp {
  return {
    kind: 'expense.void',
    opId,
    payload: { expense_id: expense.id, reason, reverse_payments: reversePayments },
  };
}

export function categoryOp(c: CategoryInput): SyncOp {
  return {
    kind: 'expense_category.upsert',
    payload: { id: c.id, name: c.name, sort_order: c.sortOrder, active: c.active },
  };
}

class SupabaseExpensesApi extends ExpensesApi {
  private readonly supabase = inject(Supabase);

  async list(arenaId: string, first: string, last: string): Promise<ExpensesData> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('arena_expenses', {
      p_arena: arenaId,
      p_first: first,
      p_last: last,
    });
    if (error) throw expensesError(error);
    return toExpensesData(data as Row | null);
  }

  async get(arenaId: string, id: string): Promise<ExpenseDetail> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('arena_expense', { p_arena: arenaId, p_id: id });
    if (error) throw expensesError(error);
    return toDetail(data as Row);
  }

  async staffSalary(arenaId: string, staffId: string): Promise<StaffSalaryRecord> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('arena_staff_salary', {
      p_arena: arenaId,
      p_staff: staffId,
    });
    if (error) throw expensesError(error);
    const r = (data ?? {}) as Row;
    const id = String(r['staff_id'] ?? staffId);
    return {
      staffId: id,
      name: String(r['name'] ?? ''),
      removed: r['removed'] === true,
      salaries: rows(r['salaries']).map((s) => toSalary(s, id)),
      periods: rows(r['periods']).map(toExpense),
    };
  }

  async categories(arenaId: string): Promise<ExpenseCategory[]> {
    const client = await this.supabase.client();
    const { data, error } = await client
      .from('expense_categories')
      .select('id, name, sort_order, active')
      .eq('arena_id', arenaId)
      .order('sort_order')
      .order('name');
    if (error) throw expensesError(error);
    return rows(data).map((c) => ({
      id: String(c['id']),
      name: String(c['name']),
      sortOrder: Number(c['sort_order'] ?? 0),
      active: c['active'] !== false,
    }));
  }

  async salaries(arenaId: string): Promise<StaffSalary[]> {
    const client = await this.supabase.client();
    const { data, error } = await client
      .from('staff_salaries')
      .select('id, staff_id, effective_from, period, amount_paise, note')
      .eq('arena_id', arenaId)
      .order('effective_from', { ascending: false });
    if (error) throw expensesError(error);
    return rows(data).map((s) => toSalary(s));
  }

  async catalog(): Promise<string[]> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('expense_category_catalog');
    if (error) throw expensesError(error);
    return rows(data).map((c) => String(c['name']));
  }

  saveCategories(arenaId: string, categories: readonly CategoryInput[]): Promise<void> {
    return this.push(arenaId, categories.map(categoryOp), CATEGORY_MESSAGES).then(() => undefined);
  }

  async removeCategory(arenaId: string, id: string): Promise<'deleted' | 'retired'> {
    const [result] = await this.push(
      arenaId,
      [{ kind: 'expense_category.remove', payload: { id } }],
      CATEGORY_MESSAGES,
    );
    return result?.['removed'] === 'retired' ? 'retired' : 'deleted';
  }

  async add(arenaId: string, entry: NewExpense): Promise<void> {
    const ids = entry.attempt;
    await this.push(
      arenaId,
      addOps(
        entry,
        ids?.id('expense') ?? crypto.randomUUID(),
        ids?.id('payment') ?? crypto.randomUUID(),
      ),
    );
  }

  async update(
    arenaId: string,
    expense: Expense,
    change: ExpenseInput,
    attempt?: Attempt,
  ): Promise<void> {
    await this.push(arenaId, [updateOp(expense, change, attempt?.id('op'))]);
  }

  async pay(
    arenaId: string,
    expense: Expense,
    payment: PaymentInput,
    attempt?: Attempt,
  ): Promise<void> {
    await this.push(arenaId, [
      payOp(expense, payment, attempt?.id('payment') ?? crypto.randomUUID(), attempt?.id('op')),
    ]);
  }

  async reverse(
    arenaId: string,
    payment: ExpensePayment,
    reason: string,
    attempt?: Attempt,
  ): Promise<void> {
    await this.push(arenaId, [
      reverseOp(payment, reason, attempt?.id('reversal') ?? crypto.randomUUID(), attempt?.id('op')),
    ]);
  }

  async void(
    arenaId: string,
    expense: Expense,
    reason: string,
    reversePayments: boolean,
    attempt?: Attempt,
  ): Promise<number> {
    const [result] = await this.push(arenaId, [
      voidOp(expense, reason, reversePayments, attempt?.id('op')),
    ]);
    return Number(result?.['reversed'] ?? 0);
  }

  async setSalary(arenaId: string, salary: SalaryInput, attempt?: Attempt): Promise<void> {
    await this.push(arenaId, [salaryOp(salary, attempt?.id('op'))]);
  }

  /**
   * Through pushOps: the other devices hear of the change only once it is recorded. A refusal
   * keeps its PushRefusal (and what part of a batch was applied) for the caller.
   */
  private async push(
    arenaId: string,
    ops: readonly SyncOp[],
    messages = EXPENSES_MESSAGES,
  ): Promise<Record<string, unknown>[]> {
    const client = await this.supabase.client();
    try {
      return await pushOps(client, arenaId, ops, messages);
    } catch (e) {
      throw e instanceof AppError && !(e instanceof PushRefusal) && messages[e.code]
        ? new AppError(e.code, messages[e.code])
        : e;
    }
  }
}

export function expensesError(e: Parameters<typeof dbError>[0]): AppError {
  const error = dbError(e);
  return EXPENSES_MESSAGES[error.code]
    ? new AppError(error.code, EXPENSES_MESSAGES[error.code])
    : error;
}
