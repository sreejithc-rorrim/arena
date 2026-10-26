import { AppError } from '../../core/auth/auth-api';
import { NOW, PageTest, startPage } from '../../testing/page-test';
import { expensePaymentsCsv, expensesCsv } from './components/expenses-csv';
import {
  PaymentLine,
  cashTotals,
  expensePeriodFor,
  salaryPeriodOptions,
} from './data/expense.models';

/** NOW is Tue 13 Oct 2026, 7:30 pm IST; the default period is October 2026. */
describe('Expenses', () => {
  let t: PageTest;

  const titles = () =>
    t.rows().map((r) => r.querySelector('span.truncate.font-semibold')?.textContent?.trim());
  const totals = () => t.text(t.doc().querySelector('[role="group"][aria-label="Totals"]'));
  const detail = () => t.doc().querySelector('app-expense-detail') as HTMLElement | null;
  const dialog = () => t.dialog()!;
  const chip = (label: string) =>
    [...t.doc().querySelectorAll('mat-chip-option')]
      .find((c) => t.text(c) === label)
      ?.querySelector('button') as HTMLButtonElement;
  const field = (label: string, scope: ParentNode = dialog()) =>
    [...scope.querySelectorAll('mat-form-field')].find((f) =>
      f.querySelector('mat-label')?.textContent?.includes(label),
    ) as HTMLElement;
  const alert = () => t.text(dialog().querySelector('[role="alert"]'));
  const lastOp = () => t.expenses.ops[t.expenses.ops.length - 1];

  async function pick(label: string, option: string, scope?: ParentNode) {
    (field(label, scope).querySelector('.mat-mdc-select-trigger') as HTMLElement).click();
    await t.settle();
    (
      [...t.doc().querySelectorAll('mat-option')].find((o) => t.text(o) === option) as HTMLElement
    ).click();
    await t.settle();
  }

  async function toggle(label: string) {
    (
      [...dialog().querySelectorAll('mat-button-toggle button')].find(
        (b) => t.text(b) === label,
      ) as HTMLButtonElement
    ).click();
    await t.settle();
  }

  async function type(label: string, value: string) {
    t.type(label, value, dialog());
    await t.settle();
  }

  async function submit(label: string) {
    t.button(label, dialog().querySelector('mat-dialog-actions')!)!.click();
    await t.settle();
  }

  afterEach(() => t?.cleanup());

  it("lists the month's expenses and keeps company money apart from owners' own", async () => {
    t = await startPage('/expenses');
    expect(titles()).toEqual([
      'Ravi Kumar salary, October 2026',
      'Controller repair',
      'Controller repair (again)',
      'Priya Nair salary, Week 5–11 Oct 2026',
      'Shop rent',
      'Electricity bill',
    ]);
    // By expense date: the voided duplicate does not count; incurred = paid + unpaid.
    expect(totals()).toContain('Incurred ₹65,650.50 Paid ₹22,300.50 Unpaid ₹43,350');
    expect(totals()).toContain('Paid: company ₹7,300.50 · personal ₹15,000');
    // By payment date: the reversed duplicate nets to nothing; an owner's money is not company cash.
    expect(totals()).toContain(
      'From company ₹7,300.50 Paid personally ₹23,000 Salaries paid ₹13,000',
    );
    expect(totals()).toContain('Personally: Arjun Mehra ₹23,000');
    expect(totals()).toContain('₹43,350 owed overall, any date · 4 expenses');
  });

  it('the payment-state chip filters the list; the choice is in the URL', async () => {
    t = await startPage('/expenses');
    chip('Unpaid').click();
    await t.settle();
    expect(t.url()).toBe('/expenses?status=unpaid');
    expect(titles()).toEqual(['Controller repair', 'Priya Nair salary, Week 5–11 Oct 2026']);
  });

  it('paid from one owner: their expenses, and only their money in the cash figures', async () => {
    t = await startPage('/expenses?paid=owner:st0');
    expect(titles()).toEqual(['Shop rent']);
    expect(totals()).toContain('From company ₹0 Paid personally ₹23,000');
  });

  it('the Salaries category keeps salary periods and salary payments', async () => {
    t = await startPage('/expenses?category=salaries');
    expect(titles()).toEqual([
      'Ravi Kumar salary, October 2026',
      'Priya Nair salary, Week 5–11 Oct 2026',
    ]);
    expect(totals()).toContain('From company ₹5,000 Paid personally ₹8,000 Salaries paid ₹13,000');
  });

  it('search matches notes, category, staff and the owner who paid', async () => {
    t = await startPage('/expenses');
    const input = t.doc().querySelector('input[type="search"]') as HTMLInputElement;
    input.value = 'meter 44';
    input.dispatchEvent(new Event('input'));
    await t.settle();
    expect(titles()).toEqual(['Electricity bill']);
    input.value = 'nobody';
    input.dispatchEvent(new Event('input'));
    await t.settle();
    expect(t.doc().body.textContent).toContain('No expenses match these filters.');
  });

  it('a list that fails to load says so and Try again reads it again', async () => {
    t = await startPage('/expenses', 1440, (apis) => {
      vi.spyOn(apis.expenses, 'list').mockRejectedValueOnce(
        new AppError('network', 'No connection. Try again'),
      );
    });
    expect(t.text(t.doc().querySelector('mat-tab-nav-panel [role="alert"]'))).toBe(
      'No connection. Try again',
    );
    expect(titles()).toEqual([]);
    t.button('Try again')!.click();
    await t.settle();
    expect(titles().length).toBe(6);
  });

  it('Salaries: agreed salaries that fail to load are an error, not "no agreed salary"', async () => {
    t = await startPage('/expenses/salaries', 1440, (apis) => {
      vi.spyOn(apis.expenses, 'salaries').mockRejectedValueOnce(
        new AppError('network', 'No connection. Try again'),
      );
    });
    expect(t.text(t.doc().querySelector('mat-tab-nav-panel [role="alert"]'))).toBe(
      "Agreed salaries couldn't load: No connection. Try again",
    );
    expect(t.doc().body.textContent).not.toContain('No agreed salary');
    t.button('Try again')!.click();
    await t.settle();
    expect(t.text(t.doc().querySelector('ul[aria-label="Staff salaries"]'))).toContain(
      '₹18,000 a month',
    );
  });

  it('an arena with no categories and nothing recorded offers the standard ones', async () => {
    t = await startPage('/expenses', 1440, (apis) => {
      apis.expenses.categoryList = [];
      apis.expenses.expenses = [];
    });
    expect(t.doc().body.textContent).toContain('No expenses in October 2026.');
    t.button('Add the standard categories')!.click();
    await t.settle();
    expect(t.expenses.categoryList.map((c) => c.name)).toContain('Electricity');
    expect(t.snack()).toBe('10 categories added');
  });

  it('adds an expense paid in full from an owner’s own money in one push', async () => {
    t = await startPage('/expenses');
    t.button('Add')!.click();
    await t.settle();
    t.button('Expense', t.doc().querySelector('.mat-mdc-menu-panel')!)!.click();
    await t.settle();
    await submit('Add expense');
    expect(alert()).toBe('Pick a category');
    await pick('Category', 'Repairs');
    expect((field('Title').querySelector('input') as HTMLInputElement).value).toBe('Repairs');
    await type('Amount', '1200');
    await toggle('In full');
    // Company money names nobody: no owner to pick.
    expect(field('Owner who paid')).toBeUndefined();
    await toggle('Personal');
    expect(t.text(field('Owner who paid').querySelector('.mat-mdc-select-value'))).toBe(
      'Arjun Mehra',
    );
    await submit('Add expense');
    expect(t.dialog()).toBeNull();
    const op = lastOp() as { kind: string; payload: Record<string, unknown> };
    expect(op.kind).toBe('expense.add');
    expect(op.payload['amount_paise']).toBe(120_000);
    expect(op.payload['payment']).toMatchObject({
      amount_paise: 120_000,
      paid_from: 'personal',
      payer_staff_id: 'st0',
    });
    expect(t.url()).toContain('id=');
    expect(t.text(detail()!.querySelector('app-stat-tile:nth-child(3)'))).toContain('₹0 · ₹1,200');
  });

  it('a payment more than is due is refused in the form', async () => {
    t = await startPage('/expenses?id=e-fix');
    t.button('Record payment', detail()!)!.click();
    await t.settle();
    expect((field('Amount paid').querySelector('input') as HTMLInputElement).value).toBe('850');
    await type('Amount paid', '900');
    await submit('Record payment');
    expect(alert()).toBe('That is more than the ₹850 due');
    expect(t.expenses.ops.length).toBe(0);
  });

  it('mixes sources on one salary: company advance, then an owner pays the rest', async () => {
    t = await startPage('/expenses?id=s-ravi-cur');
    expect(t.text(detail())).toContain('Advance');
    t.button('Record payment', detail()!)!.click();
    await t.settle();
    expect((field('Amount paid').querySelector('input') as HTMLInputElement).value).toBe('13000');
    expect((field('Note').querySelector('input') as HTMLInputElement).value).toBe(
      'October 2026 salary',
    );
    await type('Amount paid', '8000');
    await toggle('Personal');
    await submit('Record payment');
    expect(t.snack()).toBe('₹8,000 paid · ₹5,000 still due');
    const tiles = t.text(detail()!.querySelector('[stats]'));
    expect(tiles).toContain('Paid ₹13,000');
    expect(tiles).toContain('Company · Personal ₹5,000 · ₹8,000');
    expect(tiles).toContain('Balance ₹5,000');
  });

  it('reverses a payment with its own source and a reason', async () => {
    t = await startPage('/expenses?id=e-rent');
    t.button('Reverse', detail()!)!.click();
    await t.settle();
    expect(t.text(dialog())).toContain('Personal · Arjun Mehra');
    await submit('Reverse payment');
    expect(alert()).toBe('Give a reason for the reversal');
    t.type('Reason', 'Paid from the wrong account', dialog());
    await t.settle();
    await submit('Reverse payment');
    expect(t.snack()).toBe('₹15,000 payment reversed');
    expect(lastOp()).toMatchObject({
      kind: 'expense.payment_reverse',
      payload: { payment_id: 'e-rent-p1', reason: 'Paid from the wrong account' },
    });
    expect(t.text(detail())).toContain('Reversed');
  });

  it('voids an expense with money on it only when its payments are reversed too', async () => {
    t = await startPage('/expenses?id=e-rent');
    t.button('Void', detail()!.querySelector('[actions]')!)!.click();
    await t.settle();
    expect(t.text(dialog())).toContain('Also reverse the ₹15,000 paid (personal ₹15,000)');
    await submit('Void');
    expect(alert()).toBe('Tick "Also reverse" to void it with the money paid on it');
    (dialog().querySelector('mat-checkbox input') as HTMLInputElement).click();
    await t.settle();
    await submit('Void');
    expect(t.snack()).toBe('Voided · 1 payment reversed');
    expect(lastOp()).toMatchObject({
      kind: 'expense.void',
      payload: { expense_id: 'e-rent', reason: 'Entered twice', reverse_payments: true },
    });
    expect(totals()).toContain('Incurred ₹25,650.50');
  });

  it('Salaries: the agreed salary fills in the month; a recorded month pays what is left', async () => {
    t = await startPage('/expenses/salaries');
    const row = (name: string) =>
      [...t.doc().querySelectorAll('ul[aria-label="Staff salaries"] > li')].find(
        (li) => li.querySelector('span.truncate.font-semibold')?.textContent?.trim() === name,
      ) as HTMLElement;
    expect(t.text(row('Ravi Kumar'))).toContain('₹18,000 a month');
    expect(t.text(row('Ravi Kumar'))).toContain('Part paid');
    expect(t.text(row('Arjun Rao'))).toContain('No agreed salary');
    expect(t.text(row('Arjun Rao'))).toContain('Not recorded');

    // Ravi's October is recorded: the dialog pays the ₹13,000 left on it.
    t.button('Record salary')!.click();
    await t.settle();
    await pick('Staff member', 'Ravi Kumar');
    expect(t.text(dialog())).toContain(
      'October 2026 is already recorded: ₹18,000 owed, ₹5,000 paid',
    );
    expect((field('Amount paid').querySelector('input') as HTMLInputElement).value).toBe('13000');
    // November is not: the agreed salary fills in.
    await pick('Month', 'November 2026');
    expect((field('Salary owed').querySelector('input') as HTMLInputElement).value).toBe('18000');
    expect(t.text(field('Salary owed').querySelector('mat-hint'))).toBe(
      'Agreed ₹18,000 a month from 1 Aug 2026',
    );
  });

  it('Salaries: a first month saves the agreed salary and records it in one push', async () => {
    t = await startPage('/expenses/salaries');
    t.button('Record Oct 2026')!.click();
    await t.settle();
    await pick('Staff member', 'Arjun Rao');
    expect((field('Salary owed').querySelector('input') as HTMLInputElement).value).toBe('');
    await type('Salary owed', '15000');
    expect(t.text(dialog())).toContain("Save as Arjun Rao's agreed monthly salary from 1 Oct 2026");
    await submit('Record salary');
    expect(t.snack()).toBe("Arjun Rao's salary for October 2026 recorded");
    const kinds = t.expenses.ops.map((o) => o.kind);
    expect(kinds).toEqual(['staff_salary.set', 'expense.add']);
    expect(t.expenses.ops[1].payload).toMatchObject({
      kind: 'salary',
      staff_id: 'st3',
      period_start: '2026-10-01',
      period_end: '2026-10-31',
      amount_paise: 1_500_000,
      title: 'Arjun Rao salary, October 2026',
    });
  });

  it('Reports: owner contributions, funding split and this month against the last', async () => {
    t = await startPage('/expenses/reports');
    const body = t.text(t.doc().querySelector('mat-tab-nav-panel'))!;
    expect(body).toContain('From company account ₹7,300.50');
    expect(body).toContain('Paid personally by owners ₹23,000');
    expect(body).toContain('Owner contributions');
    expect(body).toMatch(/Arjun Mehra ₹23,000/);
    expect(body).toContain('This month vs last month');
    expect(body).toContain('Incurred ₹65,650.50 ₹19,199');
  });

  it('is hidden from members without the Money permission', async () => {
    t = await startPage('/sales', 1440, (apis) => {
      apis.arena.memberships = apis.arena.memberships.map((m) => ({
        ...m,
        role: 'staff',
        perms: ['reports'],
      }));
    });
    expect(t.doc().querySelector('a[href="/expenses"]')).toBeNull();
    await t.harness.navigateByUrl('/expenses');
    await t.settle();
    expect(t.url()).not.toBe('/expenses');
    expect(t.doc().querySelector('app-expenses-page')).toBeNull();
  });

  it('compact: the detail opens over the list', async () => {
    t = await startPage('/expenses?id=e-power', 390);
    expect(t.doc().querySelector('section[role="dialog"] app-expense-detail')).not.toBeNull();
  });
});

describe('expense helpers', () => {
  const line = (over: Partial<PaymentLine>): PaymentLine => ({
    id: 'p',
    expenseId: 'e',
    expenseTitle: 'Rent',
    expenseKind: 'general',
    expenseVoided: false,
    categoryName: 'Rent',
    staffId: null,
    staffName: null,
    kind: 'payment',
    amountPaise: 100_000,
    method: 'upi',
    paidOn: '2026-10-01',
    paidFrom: 'company',
    payerStaffId: null,
    payerName: null,
    note: null,
    reversesId: null,
    ...over,
  });

  it('periods are whole months, weeks and years in IST', () => {
    expect(expensePeriodFor(undefined, undefined, undefined, '2026-10-13')).toEqual({
      range: 'month',
      first: '2026-10-01',
      last: '2026-10-31',
    });
    expect(expensePeriodFor('week', undefined, undefined, '2026-10-13')).toMatchObject({
      first: '2026-10-12',
      last: '2026-10-18',
    });
    expect(expensePeriodFor('prev_month', undefined, undefined, '2026-03-31')).toMatchObject({
      first: '2026-02-01',
      last: '2026-02-28',
    });
    // A backwards custom range falls back to this month.
    expect(expensePeriodFor('custom', '2026-10-10', '2026-10-01', '2026-10-13').range).toBe(
      'month',
    );
  });

  it('the quick form offers next month first, then back twelve', () => {
    const months = salaryPeriodOptions('monthly', '2026-10-13');
    expect(months.length).toBe(14);
    expect(months[0].label).toBe('November 2026');
    expect(months[1]).toMatchObject({ first: '2026-10-01', last: '2026-10-31' });
    const weeks = salaryPeriodOptions('weekly', '2026-10-13');
    expect(weeks[1]).toMatchObject({ first: '2026-10-12', last: '2026-10-18' });
  });

  it('mixed sources: personal money is an owner contribution, never company cash', () => {
    const c = cashTotals([
      line({ amountPaise: 1_000_000, expenseKind: 'salary' }),
      line({
        id: 'p2',
        amountPaise: 800_000,
        expenseKind: 'salary',
        paidFrom: 'personal',
        payerStaffId: 'st0',
        payerName: 'Arjun Mehra',
      }),
      line({
        id: 'p3',
        kind: 'reversal',
        amountPaise: -800_000,
        expenseKind: 'salary',
        paidFrom: 'personal',
        payerStaffId: 'st0',
        payerName: 'Arjun Mehra',
        reversesId: 'p2',
      }),
    ]);
    expect(c.companyPaise).toBe(1_000_000);
    expect(c.personalPaise).toBe(0);
    expect(c.salariesCompanyPaise).toBe(1_000_000);
    expect(c.owners).toEqual([
      {
        staffId: 'st0',
        name: 'Arjun Mehra',
        paidPaise: 800_000,
        reversedPaise: 800_000,
        netPaise: 0,
      },
    ]);
  });

  it('both CSVs say whose money paid', () => {
    const meta = {
      arena: '404 Arena',
      period: { range: 'month' as const, first: '2026-10-01', last: '2026-10-31' },
      generatedAt: NOW,
      generatedBy: null,
      filters: null,
    };
    const payments = expensePaymentsCsv(
      [line({ paidFrom: 'personal', payerStaffId: 'st0', payerName: 'Arjun Mehra' })],
      meta,
    );
    expect(payments).toContain('Paid from,Payer');
    expect(payments).toContain('2026-10-01,Payment,1000.00,UPI,Personal,Arjun Mehra,Rent');
    expect(payments).toContain('Personal · Arjun Mehra,1000.00');
    const expenses = expensesCsv([], meta);
    expect(expenses).toContain('Paid from company (INR),Paid personally (INR)');
  });
});
