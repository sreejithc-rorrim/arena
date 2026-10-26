import { AppError } from '../../../core/auth/auth-api';
import { Attempt, PushRefusal } from '../../../core/sync/push-ops';
import { addDays, daysBetween, formatIsoDate } from '../../../shared/time/ist';
import { SAMPLE_TEAM } from '../../team/data/team-api.sample';
import {
  CATEGORY_MESSAGES,
  CategoryInput,
  EXPENSES_MESSAGES,
  ExpenseInput,
  ExpensesApi,
  NewExpense,
  PaymentInput,
  SalaryInput,
  addOps,
  categoryOp,
  payOp,
  reverseOp,
  salaryOp,
  updateOp,
  voidOp,
} from './expenses-api';
import {
  EXPENSE_METHODS,
  Expense,
  ExpenseCategory,
  ExpenseDetail,
  ExpenseHistoryEntry,
  ExpenseMethod,
  ExpensePayment,
  ExpensesData,
  MAX_RANGE_DAYS,
  MAX_SALARY_SPAN,
  PaidFrom,
  StaffSalary,
  StaffSalaryRecord,
  addMonths,
  monthOf,
  overlapping,
  salaryTitle,
  weekOf,
} from './expense.models';

/** A seeded payment: paid on (days from today), rupees, method, paid from, payer staff id. */
type SeedPayment = readonly [number, number, ExpenseMethod, PaidFrom, string?];

interface Seed {
  readonly id: string;
  readonly title: string;
  readonly rupees: number;
  /** A cost's day, in days from today. */
  readonly day?: number;
  readonly category?: string;
  readonly staff?: string;
  /** A salary's period. */
  readonly period?: { first: string; last: string };
  readonly notes?: string;
  readonly payments?: readonly SeedPayment[];
  /** Voided, its payments reversed. */
  readonly voidReason?: string;
}

const CATEGORIES: readonly ExpenseCategory[] = [
  { id: 'c-rent', name: 'Rent', sortOrder: 0, active: true },
  { id: 'c-power', name: 'Electricity', sortOrder: 1, active: true },
  { id: 'c-net', name: 'Internet', sortOrder: 2, active: true },
  { id: 'c-fix', name: 'Repairs', sortOrder: 3, active: true },
  { id: 'c-snacks', name: 'Snacks', sortOrder: 4, active: false },
];

/**
 * The sample arena's costs and salaries around `today` (an IST day): rent part paid from the
 * owner's own money, electricity paid by the company, last month's internet, an unpaid repair,
 * a voided duplicate (its payment reversed), Ravi's last month paid company + personal and this
 * month's advance, Priya's last week unpaid. Arjun Rao has no agreed salary yet.
 */
function seeds(today: string): Seed[] {
  const month = monthOf(today);
  const prev = monthOf(addMonths(today, -1));
  const lastWeek = weekOf(addDays(weekOf(today).first, -7));
  const from = (day: string) => daysBetween(today, day);
  return [
    {
      id: 'e-rent',
      title: 'Shop rent',
      rupees: 40000,
      day: from(month.first),
      category: 'c-rent',
      payments: [[from(month.first), 15000, 'bank', 'personal', 'st0']],
    },
    {
      id: 'e-power',
      title: 'Electricity bill',
      rupees: 2300.5,
      day: from(month.first),
      category: 'c-power',
      notes: 'Meter 4471',
      payments: [[from(month.first), 2300.5, 'upi', 'company']],
    },
    {
      id: 'e-net',
      title: 'Fibre internet',
      rupees: 1199,
      day: from(prev.first) + 2,
      category: 'c-net',
      payments: [[from(prev.first) + 2, 1199, 'card', 'company']],
    },
    { id: 'e-fix', title: 'Controller repair', rupees: 850, day: 0, category: 'c-fix' },
    {
      id: 'e-dup',
      title: 'Controller repair (again)',
      rupees: 500,
      day: 0,
      category: 'c-fix',
      payments: [[0, 500, 'cash', 'company']],
      voidReason: 'Entered twice',
    },
    {
      id: 's-ravi-prev',
      title: salaryTitle('Ravi Kumar', prev.first, prev.last),
      rupees: 18000,
      staff: 'st1',
      period: prev,
      payments: [
        [from(prev.last) - 5, 10000, 'bank', 'company'],
        [from(month.first), 8000, 'upi', 'personal', 'st0'],
      ],
    },
    {
      id: 's-ravi-cur',
      title: salaryTitle('Ravi Kumar', month.first, month.last),
      rupees: 18000,
      staff: 'st1',
      period: month,
      payments: [[0, 5000, 'cash', 'company']],
    },
    {
      id: 's-priya-week',
      title: salaryTitle('Priya Nair', lastWeek.first, lastWeek.last),
      rupees: 4500,
      staff: 'st2',
      period: lastWeek,
    },
  ];
}

const nameOf = (staffId: string | null) =>
  staffId ? (SAMPLE_TEAM.find((s) => s.id === staffId)?.name ?? null) : null;

/** 10:00 IST on an IST day, plus `minutes`. */
const at = (day: string, minutes = 0) =>
  new Date(Date.parse(`${day}T10:00:00+05:30`) + minutes * 60_000).toISOString();

/** Paid (by source), balance and status from the payments, as the server derives them. */
function derive(e: ExpenseDetail): ExpenseDetail {
  const sum = (from?: PaidFrom) =>
    e.payments.filter((p) => !from || p.paidFrom === from).reduce((n, p) => n + p.amountPaise, 0);
  const paid = sum();
  return {
    ...e,
    paidPaise: paid,
    paidCompanyPaise: sum('company'),
    paidPersonalPaise: sum('personal'),
    balancePaise: e.voided ? 0 : e.amountPaise - paid,
    paymentStatus: paid <= 0 ? 'unpaid' : paid >= e.amountPaise ? 'paid' : 'partial',
  };
}

/** The payment's negative twin: same source, payer, method and day (expense_payments check). */
function reversalOf(p: ExpensePayment, id: string, reason: string, by: string, when: string) {
  return {
    ...p,
    id,
    kind: 'reversal',
    amountPaise: -p.amountPaise,
    note: reason,
    reversesId: p.id,
    reversed: false,
    by,
    at: when,
  } satisfies ExpensePayment;
}

/** The editable fields as the audit log keys them (_expense_fields). */
function auditFields(e: Expense): Record<string, unknown> {
  return {
    title: e.title,
    category_id: e.categoryId,
    staff_id: e.staffId,
    period_start: e.periodStart,
    period_end: e.periodEnd,
    amount_paise: e.amountPaise,
    expense_date: e.expenseDate,
    notes: e.notes,
  };
}

/**
 * Deterministic in-memory ExpensesApi for tests, seeded around `now`. Writes apply like the
 * server would (the same refusal codes, payments append-only, reversals keeping source and
 * payer, a batch applying op by op) and are recorded in `ops` with the payloads the real API
 * sends.
 */
export class SampleExpensesApi extends ExpensesApi {
  categoryList: ExpenseCategory[] = [...CATEGORIES];
  salaryList: StaffSalary[];
  expenses: ExpenseDetail[] = [];
  catalogNames = [
    'Rent',
    'Electricity',
    'Internet',
    'Water',
    'Repairs',
    'Maintenance',
    'Equipment',
    'Cleaning',
    'Supplies',
    'Other',
  ];
  /** Every write, in order, as `kind` + payload. */
  readonly ops: { kind: string; payload: unknown }[] = [];
  /** Reads of the list, as `first…last` (laziness checks). */
  readonly listReads: string[] = [];
  /** Set to make the next call fail with this code. */
  failNext: string | null = null;
  /** The signed-in name recorded on changes. */
  by = 'Arjun Mehra';
  readonly today: string;
  private clock = 0;

  constructor(now: Date) {
    super();
    this.today = formatIsoDate(now);
    this.salaryList = [
      agreed('sal-ravi', 'st1', addMonths(this.today, -2), 'monthly', 1800000),
      agreed('sal-priya', 'st2', addMonths(this.today, -1), 'weekly', 450000),
    ];
    this.expenses = seeds(this.today).map((s) => this.build(s));
  }

  async list(_arenaId: string, first: string, last: string): Promise<ExpensesData> {
    this.fail();
    const span = daysBetween(first, last);
    if (!(span >= 0) || span + 1 > MAX_RANGE_DAYS) throw this.error('invalid_range');
    this.listReads.push(`${first}…${last}`);
    const within = (day: string) => day >= first && day <= last;
    const open = this.expenses.filter((e) => !e.voided && e.balancePaise > 0);
    return {
      expenses: this.expenses
        .filter((e) => within(e.expenseDate))
        .sort(
          (a, b) =>
            b.expenseDate.localeCompare(a.expenseDate) || b.createdAt.localeCompare(a.createdAt),
        )
        .map(strip),
      payments: this.expenses
        .flatMap((e) => e.payments.filter((p) => within(p.paidOn)).map((p) => ({ e, p })))
        .sort((a, b) => b.p.paidOn.localeCompare(a.p.paidOn) || b.p.at.localeCompare(a.p.at))
        .map(({ e, p }) => ({
          id: p.id,
          expenseId: e.id,
          expenseTitle: e.title,
          expenseKind: e.kind,
          expenseVoided: e.voided,
          categoryName: e.categoryName,
          staffId: e.staffId,
          staffName: e.staffName,
          kind: p.kind,
          amountPaise: p.amountPaise,
          method: p.method,
          paidOn: p.paidOn,
          paidFrom: p.paidFrom,
          payerStaffId: p.payerStaffId,
          payerName: p.payerName,
          note: p.note,
          reversesId: p.reversesId,
        })),
      owedTotalPaise: open.reduce((n, e) => n + e.balancePaise, 0),
      owedCount: open.length,
    };
  }

  async get(_arenaId: string, id: string): Promise<ExpenseDetail> {
    this.fail();
    const e = this.expenses.find((x) => x.id === id);
    if (!e) throw this.error('not_found');
    return e;
  }

  async staffSalary(_arenaId: string, staffId: string): Promise<StaffSalaryRecord> {
    this.fail();
    const member = SAMPLE_TEAM.find((s) => s.id === staffId);
    if (!member) throw this.error('not_found');
    return {
      staffId,
      name: member.name,
      removed: member.removed,
      salaries: this.salaryList
        .filter((s) => s.staffId === staffId)
        .sort((a, b) => b.effectiveFrom.localeCompare(a.effectiveFrom)),
      periods: this.expenses
        .filter((e) => e.kind === 'salary' && e.staffId === staffId)
        .sort((a, b) => (b.periodStart ?? '').localeCompare(a.periodStart ?? ''))
        .map(strip),
    };
  }

  async categories(): Promise<ExpenseCategory[]> {
    this.fail();
    return [...this.categoryList].sort(
      (a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name),
    );
  }

  async salaries(): Promise<StaffSalary[]> {
    this.fail();
    return [...this.salaryList].sort((a, b) => b.effectiveFrom.localeCompare(a.effectiveFrom));
  }

  async catalog(): Promise<string[]> {
    this.fail();
    return [...this.catalogNames];
  }

  async saveCategories(_arenaId: string, categories: readonly CategoryInput[]): Promise<void> {
    this.fail();
    const ops = categories.map((c) => () => {
      this.ops.push(categoryOp(c));
      const name = c.name.trim();
      if (!name || name.length > 40) throw this.refuse('invalid_name', CATEGORY_MESSAGES);
      if (
        this.categoryList.some((x) => x.id !== c.id && x.name.toLowerCase() === name.toLowerCase())
      ) {
        throw this.refuse('duplicate', CATEGORY_MESSAGES);
      }
      const next = { id: c.id, name, sortOrder: c.sortOrder, active: c.active };
      this.categoryList = this.categoryList.some((x) => x.id === c.id)
        ? this.categoryList.map((x) => (x.id === c.id ? next : x))
        : [...this.categoryList, next];
      return 'expense_category.upsert';
    });
    this.batch(ops);
  }

  async removeCategory(_arenaId: string, id: string): Promise<'deleted' | 'retired'> {
    this.fail();
    this.ops.push({ kind: 'expense_category.remove', payload: { id } });
    if (!this.categoryList.some((c) => c.id === id)) throw this.refuse('not_found');
    if (this.expenses.some((e) => e.categoryId === id)) {
      this.categoryList = this.categoryList.map((c) => (c.id === id ? { ...c, active: false } : c));
      return 'retired';
    }
    this.categoryList = this.categoryList.filter((c) => c.id !== id);
    return 'deleted';
  }

  async add(_arenaId: string, entry: NewExpense): Promise<void> {
    this.fail();
    const ids = entry.attempt ?? new Attempt();
    const expenseId = ids.id('expense');
    this.ops.push(...addOps(entry, expenseId, ids.id('payment')));
    const ops: (() => string)[] = [];
    if (entry.agreed) {
      const agreed = entry.agreed;
      ops.push(() => {
        this.putSalary(agreed);
        return 'staff_salary.set';
      });
    }
    ops.push(() => {
      if (this.expenses.some((e) => e.id === expenseId)) throw this.refuse('duplicate');
      this.check(entry, null);
      const e = derive({
        ...this.details(entry),
        id: expenseId,
        kind: entry.kind,
        paidPaise: 0,
        paidCompanyPaise: 0,
        paidPersonalPaise: 0,
        balancePaise: 0,
        paymentStatus: 'unpaid',
        voided: false,
        voidReason: null,
        createdByName: this.by,
        createdAt: this.stamp(),
        payments: [],
        history: [],
      });
      if (entry.payment) this.checkPayment(e, entry.payment);
      const added = { ...e, history: [this.entry('add', null, null, auditFields(e))] };
      this.expenses.push(
        entry.payment ? this.paid(added, entry.payment, ids.id('payment')) : added,
      );
      return 'expense.add';
    });
    this.batch(ops);
  }

  async update(
    _arenaId: string,
    expense: Expense,
    change: ExpenseInput,
    attempt?: Attempt,
  ): Promise<void> {
    this.fail();
    this.ops.push(updateOp(expense, change, attempt?.id('op')));
    const old = this.find(expense.id);
    if (old.voided) throw this.refuse('voided');
    const input = { ...change, kind: old.kind };
    this.check(input, old);
    if (input.amountPaise < old.paidPaise) throw this.refuse('amount_below_paid');
    const next = derive({ ...old, ...this.details(input) });
    const before = auditFields(old);
    const after = auditFields(next);
    const changed = Object.keys(after).filter((k) => before[k] !== after[k]);
    if (!changed.length) return;
    const pick = (o: Record<string, unknown>) => Object.fromEntries(changed.map((k) => [k, o[k]]));
    this.put({
      ...next,
      history: [...old.history, this.entry('update', null, pick(before), pick(after))],
    });
  }

  async pay(
    _arenaId: string,
    expense: Expense,
    payment: PaymentInput,
    attempt?: Attempt,
  ): Promise<void> {
    this.fail();
    const id = attempt?.id('payment') ?? crypto.randomUUID();
    this.ops.push(payOp(expense, payment, id, attempt?.id('op')));
    const e = this.find(expense.id);
    if (e.voided) throw this.refuse('voided');
    if (e.payments.some((p) => p.id === id)) throw this.refuse('duplicate');
    this.checkPayment(e, payment);
    this.put(this.paid(e, payment, id));
  }

  async reverse(
    _arenaId: string,
    payment: ExpensePayment,
    reason: string,
    attempt?: Attempt,
  ): Promise<void> {
    this.fail();
    const id = attempt?.id('reversal') ?? crypto.randomUUID();
    this.ops.push(reverseOp(payment, reason, id, attempt?.id('op')));
    const e = this.expenses.find((x) => x.payments.some((p) => p.id === payment.id));
    const original = e?.payments.find((p) => p.id === payment.id);
    if (!e || !original || original.kind !== 'payment') throw this.refuse('not_found');
    if (!reason.trim()) throw this.refuse('reason_required');
    if (reason.trim().length > 500) throw this.refuse('reason_too_long');
    if (original.reversed) throw this.refuse('already_reversed');
    const next = this.reversed(e, original, id, reason.trim());
    this.put({
      ...next,
      history: [
        ...e.history,
        this.entry(
          'payment_reverse',
          reason.trim(),
          { paid_paise: e.paidPaise },
          { paid_paise: next.paidPaise, payment_id: original.id },
        ),
      ],
    });
  }

  async void(
    _arenaId: string,
    expense: Expense,
    reason: string,
    reversePayments: boolean,
    attempt?: Attempt,
  ): Promise<number> {
    this.fail();
    this.ops.push(voidOp(expense, reason, reversePayments, attempt?.id('op')));
    const e = this.find(expense.id);
    if (e.voided) return 0;
    if (!reason.trim()) throw this.refuse('void_reason_required');
    if (reason.trim().length > 500) throw this.refuse('reason_too_long');
    const open = e.payments.filter((p) => p.kind === 'payment' && !p.reversed);
    if (open.length && !reversePayments) throw this.refuse('expense_has_payments');
    this.put(this.voided(e, reason.trim(), this.stamp()));
    return open.length;
  }

  async setSalary(_arenaId: string, s: SalaryInput, attempt?: Attempt): Promise<void> {
    this.fail();
    this.ops.push(salaryOp(s, attempt?.id('op')));
    this.putSalary(s);
  }

  // ------------------------------------------------------------------------------- internals

  /** Applies ops one by one like sync_push; the first refusal names what did apply. */
  private batch(ops: readonly (() => string)[]): void {
    const applied: string[] = [];
    let refusal: PushRefusal | null = null;
    for (const op of ops) {
      try {
        applied.push(op());
      } catch (e) {
        refusal ??= e as PushRefusal;
      }
    }
    if (refusal) throw new PushRefusal(refusal.code, refusal.message, applied);
  }

  private putSalary(s: SalaryInput): void {
    if (!s.staffId) throw this.refuse('staff_required');
    if (!SAMPLE_TEAM.some((m) => m.id === s.staffId)) throw this.refuse('not_found');
    if (!s.effectiveFrom) throw this.refuse('date_required');
    if (!(s.amountPaise > 0) || s.amountPaise > 1_000_000_000) throw this.refuse('amount_invalid');
    const same = this.salaryList.find(
      (x) => x.staffId === s.staffId && x.effectiveFrom === s.effectiveFrom,
    );
    const row: StaffSalary = {
      ...s,
      note: s.note?.trim() || null,
      id: same?.id ?? `sal-${++this.clock}`,
    };
    this.salaryList = same
      ? this.salaryList.map((x) => (x.id === same.id ? row : x))
      : [...this.salaryList, row];
  }

  /** The server's field checks (_expense_check) for a new or edited expense. */
  private check(e: ExpenseInput, old: ExpenseDetail | null): void {
    if (!e.title.trim()) throw this.refuse('title_required');
    if (e.title.trim().length > 80) throw this.refuse('title_too_long');
    if (!(e.amountPaise > 0) || e.amountPaise > 1_000_000_000) throw this.refuse('amount_invalid');
    if ((e.notes ?? '').trim().length > 1000) throw this.refuse('notes_too_long');
    if (e.kind === 'salary') {
      if (!e.staffId) throw this.refuse('staff_required');
      if (!e.periodStart || !e.periodEnd) throw this.refuse('period_required');
      const span = daysBetween(e.periodStart, e.periodEnd);
      if (!(span >= 0) || span > MAX_SALARY_SPAN) throw this.refuse('invalid_period');
      if (overlapping(this.expenses, e.staffId, e.periodStart, e.periodEnd, old?.id).length) {
        throw this.refuse('salary_period_taken');
      }
      return;
    }
    if (!e.categoryId) throw this.refuse('category_required');
    const category = this.categoryList.find((c) => c.id === e.categoryId);
    if (!category) throw this.refuse('not_found');
    if (!category.active && category.id !== old?.categoryId) throw this.refuse('category_retired');
    if (!e.expenseDate) throw this.refuse('date_required');
    if (e.expenseDate < '2000-01-01' || e.expenseDate > addDays(this.today, 366)) {
      throw this.refuse('date_out_of_range');
    }
  }

  /** The server's payment checks (_expense_pay). */
  private checkPayment(e: Expense, p: PaymentInput): void {
    if (p.amountPaise === 0) throw this.refuse('amount_zero');
    if (!(p.amountPaise > 0)) throw this.refuse('amount_negative');
    if (!EXPENSE_METHODS.includes(p.method)) throw this.refuse('invalid_method');
    if (!p.paidOn) throw this.refuse('date_required');
    if (p.paidOn > this.today) throw this.refuse('date_in_future');
    if (p.paidOn < '2000-01-01') throw this.refuse('date_out_of_range');
    if (p.paidFrom !== 'company' && p.paidFrom !== 'personal') {
      throw this.refuse('invalid_paid_from');
    }
    if (p.paidFrom === 'company' && p.payerStaffId) throw this.refuse('payer_not_allowed');
    if (p.paidFrom === 'personal') {
      if (!p.payerStaffId) throw this.refuse('payer_required');
      const payer = SAMPLE_TEAM.find((m) => m.id === p.payerStaffId);
      if (!payer) throw this.refuse('not_found');
      if (payer.role !== 'owner' || !payer.active || payer.removed) {
        throw this.refuse('payer_not_owner');
      }
    }
    if ((p.note ?? '').trim().length > 200) throw this.refuse('note_too_long');
    if (p.amountPaise > e.amountPaise - e.paidPaise) throw this.refuse('overpayment');
  }

  private paid(e: ExpenseDetail, p: PaymentInput, id: string): ExpenseDetail {
    const personal = p.paidFrom === 'personal';
    const row: ExpensePayment = {
      id,
      kind: 'payment',
      amountPaise: p.amountPaise,
      method: p.method,
      paidOn: p.paidOn,
      paidFrom: p.paidFrom,
      payerStaffId: personal ? p.payerStaffId : null,
      payerName: personal ? nameOf(p.payerStaffId) : null,
      note: p.note?.trim() || null,
      reversesId: null,
      reversed: false,
      by: this.by,
      at: this.stamp(),
    };
    return derive({ ...e, payments: [...e.payments, row] });
  }

  private reversed(e: ExpenseDetail, p: ExpensePayment, id: string, reason: string) {
    return derive({
      ...e,
      payments: [
        ...e.payments.map((x) => (x.id === p.id ? { ...x, reversed: true } : x)),
        reversalOf(p, id, reason, this.by, this.stamp()),
      ],
    });
  }

  /** Every open payment reversed, then the expense marked void (one audit row, as op_expense_void). */
  private voided(e: ExpenseDetail, reason: string, when: string): ExpenseDetail {
    let next = e;
    for (const p of e.payments.filter((x) => x.kind === 'payment' && !x.reversed)) {
      next = this.reversed(next, p, `${p.id}-r`, reason);
    }
    return derive({
      ...next,
      voided: true,
      voidReason: reason,
      history: [
        ...e.history,
        {
          ...this.entry(
            'void',
            reason,
            {
              amount_paise: e.amountPaise,
              paid_paise: e.paidPaise,
              payment_status: e.paymentStatus,
            },
            { status: 'voided', reversed_payments: next.payments.length - e.payments.length },
          ),
          at: when,
        },
      ],
    });
  }

  private details(e: ExpenseInput) {
    const salary = e.kind === 'salary';
    return {
      title: e.title.trim(),
      amountPaise: e.amountPaise,
      notes: e.notes?.trim() || null,
      staffId: e.staffId,
      staffName: nameOf(e.staffId),
      categoryId: salary ? null : e.categoryId,
      categoryName: salary
        ? null
        : (this.categoryList.find((c) => c.id === e.categoryId)?.name ?? null),
      periodStart: salary ? e.periodStart : null,
      periodEnd: salary ? e.periodEnd : null,
      expenseDate: (salary ? e.periodEnd : e.expenseDate) ?? this.today,
    };
  }

  private build(s: Seed): ExpenseDetail {
    const salary = !!s.period;
    const day = s.period ? s.period.last : addDays(this.today, s.day ?? 0);
    const created = at(s.period ? s.period.first : day);
    const base: ExpenseDetail = {
      id: s.id,
      kind: salary ? 'salary' : 'general',
      title: s.title,
      categoryId: s.category ?? null,
      categoryName: CATEGORIES.find((c) => c.id === s.category)?.name ?? null,
      staffId: s.staff ?? null,
      staffName: nameOf(s.staff ?? null),
      periodStart: s.period?.first ?? null,
      periodEnd: s.period?.last ?? null,
      amountPaise: Math.round(s.rupees * 100),
      paidPaise: 0,
      paidCompanyPaise: 0,
      paidPersonalPaise: 0,
      balancePaise: 0,
      paymentStatus: 'unpaid',
      voided: false,
      voidReason: null,
      expenseDate: day,
      notes: s.notes ?? null,
      createdByName: this.by,
      createdAt: created,
      payments: (s.payments ?? []).map(([d, rupees, method, paidFrom, payer], i) => {
        const paidOn = addDays(this.today, d);
        return {
          id: `${s.id}-p${i + 1}`,
          kind: 'payment',
          amountPaise: Math.round(rupees * 100),
          method,
          paidOn,
          paidFrom,
          payerStaffId: payer ?? null,
          payerName: nameOf(payer ?? null),
          note: null,
          reversesId: null,
          reversed: false,
          by: this.by,
          at: at(paidOn, i + 1),
        } satisfies ExpensePayment;
      }),
      history: [],
    };
    const e = derive({
      ...base,
      history: [
        {
          at: created,
          action: 'add',
          by: this.by,
          reason: null,
          before: null,
          after: auditFields(base),
        },
      ],
    });
    return s.voidReason ? this.voided(e, s.voidReason, at(day, 30)) : e;
  }

  private entry(
    action: string,
    reason: string | null,
    before: Record<string, unknown> | null,
    after: Record<string, unknown> | null,
  ): ExpenseHistoryEntry {
    return { at: this.stamp(), action, by: this.by, reason, before, after };
  }

  /** Increasing record times (today from 11:00 IST) so new rows sort after the seeds. */
  private stamp(): string {
    return at(this.today, 60 + ++this.clock);
  }

  private find(id: string): ExpenseDetail {
    const e = this.expenses.find((x) => x.id === id);
    if (!e) throw this.refuse('not_found');
    return e;
  }

  private put(e: ExpenseDetail): void {
    this.expenses = this.expenses.map((x) => (x.id === e.id ? e : x));
  }

  private refuse(code: string, messages = EXPENSES_MESSAGES): PushRefusal {
    return new PushRefusal(code, messages[code] ?? code, []);
  }

  private error(code: string): AppError {
    return new AppError(code, EXPENSES_MESSAGES[code] ?? code);
  }

  private fail(): void {
    const code = this.failNext;
    if (!code) return;
    this.failNext = null;
    throw this.error(code);
  }
}

function agreed(
  id: string,
  staffId: string,
  effectiveFrom: string,
  period: StaffSalary['period'],
  amountPaise: number,
): StaffSalary {
  return { id, staffId, effectiveFrom, period, amountPaise, note: null };
}

function strip({ history: _, ...e }: ExpenseDetail): Expense {
  return e;
}
