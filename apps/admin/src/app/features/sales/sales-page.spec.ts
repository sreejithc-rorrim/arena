import { TestBed } from '@angular/core/testing';
import { NOW, PageTest, startPage } from '../../testing/page-test';
import { ReportMeta, billsCsv, paymentsCsv, textCell } from './components/sales-csv';
import { SampleSalesApi } from './data/sales-api.sample';
import { SalesStore } from './data/sales-store';
import {
  Bill,
  dayNumbers,
  parseRupees,
  periodFor,
  rangeBounds,
  summarize,
  summaryLine,
} from './data/sale.models';

/** NOW is Tue 13 Oct 2026, 7:30 pm IST. */
describe('Sales', () => {
  let t: PageTest;

  const detail = () => t.doc().querySelector('app-bill-detail') as HTMLElement | null;
  const titles = () =>
    t.rows().map((r) => r.querySelector('span.truncate.font-semibold')?.textContent?.trim());
  const trailing = (r: HTMLElement) =>
    [...r.querySelectorAll(':scope > span:last-child > *')].map((e) => e.textContent?.trim());
  const summary = () => t.text(t.doc().querySelector('p[aria-live]'));
  const totals = () => t.text(t.doc().querySelector('dl[aria-label="Totals"]'));
  const chip = (label: string) =>
    [...t.doc().querySelectorAll('mat-chip-option')]
      .find((c) => c.textContent?.includes(label))
      ?.querySelector('button') as HTMLButtonElement;
  const dateInput = (label: 'First day' | 'Last day') =>
    t.doc().querySelector(`input[aria-label="${label}"]`) as HTMLInputElement | null;
  const bill = (ref: string) => t.sales.bills.find((b) => b.ref === ref)!;

  afterEach(() => t?.cleanup());

  it("lists today's bills, newest first, with expected, collected and outstanding", async () => {
    t = await startPage('/sales');
    expect(titles()).toEqual(['Kiran Rao', 'Aditya Shah', 'Guest', 'Meera Pillai']);
    expect(trailing(t.rows()[0])).toEqual(['₹240', 'UPI']);
    expect(trailing(t.rows()[1])).toEqual(['₹720', 'Split']);
    expect(trailing(t.rows()[3])).toEqual(['₹360', 'Part paid']);
    expect(t.rows()[0].textContent).toContain('S-3F9A2C · HEX · 6:40 pm');
    expect(totals()).toBe('Expected ₹1,380 Collected ₹1,220 Outstanding ₹160');
    expect(summary()).toBe('4 bills · UPI ₹940 · Cash ₹280');
  });

  it('the method chip keeps bills paid that way and says so; the choice is in the URL', async () => {
    t = await startPage('/sales');
    chip('Cash').click();
    await t.settle();
    expect(t.url()).toBe('/sales?method=cash');
    expect(titles()).toEqual(['Aditya Shah', 'Guest']);
    // The split bill keeps its UPI part: it is named as such, not counted as cash.
    expect(summary()).toBe('2 bills paid by Cash · Cash ₹280 · UPI ₹500');
    expect(totals()).toBe('Expected ₹780 Collected ₹780 Outstanding ₹0');
  });

  it('a voided bill is listed as Void and drops out of the totals', async () => {
    t = await startPage('/sales?range=yesterday');
    expect(titles()).toEqual(['Kiran Rao', 'Rahul Verma']);
    expect(trailing(t.rows()[0])).toEqual(['—', 'Void']);
    expect(t.rows()[0].textContent).toContain('12 Oct, 9:10 pm');
    expect(totals()).toBe('Expected ₹120 Collected ₹120 Outstanding ₹0');
    expect(summary()).toBe('1 bill · UPI ₹120 · Cash ₹0 · ₹120 on voided bills');
  });

  it('opens any earlier day, beyond the 30-day chip', async () => {
    t = await startPage('/sales?range=custom&from=2026-08-29&to=2026-08-29');
    expect(titles()).toEqual(['Nikhil Menon']);
    expect(dateInput('First day')?.value).toBe('2026-08-29');
    expect(dateInput('Last day')?.value).toBe('2026-08-29');
    expect(summary()).toBe('1 bill · UPI ₹0 · Cash ₹150');
    expect(t.rows()[0].textContent).toContain('6:00 pm');
  });

  it('"Dates…" starts from the days on screen; the range is checked before it loads', async () => {
    t = await startPage('/sales?range=7d');
    chip('Dates').click();
    await t.settle();
    expect(t.url()).toBe('/sales?range=custom&from=2026-10-07&to=2026-10-13');
    const first = dateInput('First day')!;
    first.value = '2026-09-01';
    first.dispatchEvent(new Event('change'));
    await t.settle();
    expect(t.url()).toBe('/sales?range=custom&from=2026-09-01&to=2026-10-13');
    expect(t.rows().length).toBe(8);
    first.value = '2026-06-01';
    first.dispatchEvent(new Event('change'));
    await t.settle();
    expect(t.text(t.doc().querySelector('app-list-pane-header [role="alert"]'))).toBe(
      'Pick at most 93 days',
    );
    expect(t.url()).toBe('/sales?range=custom&from=2026-09-01&to=2026-10-13');
    // Moving one end past the other makes it a single day.
    const last = dateInput('Last day')!;
    last.value = '2026-08-30';
    last.dispatchEvent(new Event('change'));
    await t.settle();
    expect(t.url()).toBe('/sales?range=custom&from=2026-08-30&to=2026-08-30');
  });

  it('a crafted backwards range in the URL falls back to today', async () => {
    t = await startPage('/sales?range=custom&from=2026-10-10&to=2026-10-01');
    expect(titles()).toEqual(['Kiran Rao', 'Aditya Shah', 'Guest', 'Meera Pillai']);
  });

  it('search matches the bill, member, station or staff', async () => {
    t = await startPage('/sales?range=30d');
    const input = t.doc().querySelector('input[type="search"]') as HTMLInputElement;
    input.value = 'rift';
    input.dispatchEvent(new Event('input'));
    await t.settle();
    expect(titles()).toEqual(['Meera Pillai']);
    input.value = 'nobody';
    input.dispatchEvent(new Event('input'));
    await t.settle();
    expect(t.doc().body.textContent).toContain('No bills match these filters.');
  });

  it('Refresh reads the server again', async () => {
    t = await startPage('/sales');
    await t.sales.recordPayment('a1', bill('S-0E55B9'), {
      amountPaise: 16_000,
      method: 'cash',
      note: null,
    });
    expect(totals()).toContain('Outstanding ₹160');
    (t.doc().querySelector('button[aria-label^="Refresh"]') as HTMLButtonElement).click();
    await t.settle();
    expect(totals()).toBe('Expected ₹1,380 Collected ₹1,380 Outstanding ₹0');
  });

  it('wide: opens nothing until a bill is picked (no detail read)', async () => {
    t = await startPage('/sales');
    expect(detail()).toBeNull();
    expect(t.text(t.doc().querySelector('app-list-detail'))).toContain(
      'Pick a bill to see its lines, payments and history',
    );
  });

  it('shows a picked bill with its times, lines, payments and history', async () => {
    t = await startPage('/sales?id=3f9a2c10-0000-4000-8000-000000000001');
    expect(detail()?.querySelector('h2')?.textContent?.trim()).toBe('S-3F9A2C');
    const text = t.text(detail());
    expect(text).toContain('Paid · UPI');
    expect(text).toContain('HEX · 5:40 pm–6:40 pm · 1h');
    expect(text).toContain('UPI · 13 Oct 6:40 pm · Priya Nair');
    expect(text).toContain('Member Kiran Rao · Returning');
    expect(text).toContain('Player-hours 2h');
    expect(text).toContain('Started 13 Oct, 5:40 pm');
    expect(text).toContain('No voids, waives or corrections.');
  });

  it('records a late payment, never more than is due', async () => {
    t = await startPage('/sales?id=0e55b981-0000-4000-8000-000000000004');
    expect(t.text(detail())).toContain('Due ₹160');
    t.button('Record payment', detail()!)?.click();
    await t.settle();
    expect(t.text(t.dialog())).toContain('Still due: ₹160.');
    t.type('Amount', '200', t.dialog()!);
    t.button('Record payment', t.dialog()!)?.click();
    await t.settle();
    expect(t.text(t.dialog()?.querySelector('[role="alert"]'))).toBe('That is more than ₹160');
    t.type('Amount', '160', t.dialog()!);
    t.type('Note', 'Paid next morning', t.dialog()!);
    t.button('Record payment', t.dialog()!)?.click();
    await t.settle();
    expect(t.dialog()).toBeNull();
    expect(t.snack()).toBe('Payment recorded on S-0E55B9');
    expect(bill('S-0E55B9').paymentStatus).toBe('paid');
    expect(totals()).toBe('Expected ₹1,380 Collected ₹1,380 Outstanding ₹0');
    expect(t.text(detail())).toContain('Cash · 13 Oct 7:30 pm · Arjun Mehra');
    expect(t.text(detail())).toContain('Paid next morning');
  });

  it('money taken before a void can be refunded, with a reason, so the till reconciles', async () => {
    t = await startPage('/sales?range=yesterday&id=a8c3f017-0000-4000-8000-000000000005');
    expect(t.text(detail())).toContain('Voiding does not refund it');
    expect(t.text(detail())).toContain('Voided Arjun Mehra · 12 Oct 9:10 pm');
    expect(t.button('Record payment', detail()!)).toBeUndefined();
    t.button('Refund', detail()!)?.click();
    await t.settle();
    expect(t.text(t.dialog())).toContain('This bill is void.');
    t.button('Record refund', t.dialog()!)?.click();
    await t.settle();
    expect(t.text(t.dialog()?.querySelector('[role="alert"]'))).toBe('Give a reason');
    t.type('Reason', 'Returned to customer', t.dialog()!);
    t.button('Record refund', t.dialog()!)?.click();
    await t.settle();
    expect(t.dialog()).toBeNull();
    expect(t.snack()).toBe('Refund recorded on S-A8C3F0');
    expect(summary()).toBe('1 bill · UPI ₹120 · Cash ₹0');
    expect(t.text(detail())).toContain('Cash refund');
    expect(t.text(detail())).toContain('Reason: Returned to customer');
    expect(bill('S-A8C3F0').paidPaise).toBe(0);
  });

  it('moves a payment keyed under the wrong method; the history says who, why and how much', async () => {
    t = await startPage('/sales?id=3f9a2c10-0000-4000-8000-000000000001');
    t.button('Correct method', detail()!)?.click();
    await t.settle();
    expect(t.text(t.dialog())).toContain('The original stays on record');
    t.button('Move payment', t.dialog()!)?.click();
    await t.settle();
    expect(t.text(t.dialog()?.querySelector('[role="alert"]'))).toBe('Give a reason');
    t.type('Reason', 'Paid in cash, keyed as UPI', t.dialog()!);
    t.button('Move payment', t.dialog()!)?.click();
    await t.settle();
    expect(t.snack()).toBe('Payment moved on S-3F9A2C');
    // What was collected does not change; only the split does.
    expect(totals()).toBe('Expected ₹1,380 Collected ₹1,220 Outstanding ₹160');
    expect(summary()).toBe('4 bills · UPI ₹700 · Cash ₹520');
    const text = t.text(detail());
    expect(text).toContain('Paid · Cash');
    expect(text).toContain('Payment moved · ₹240 UPI → Cash Arjun Mehra · 13 Oct 7:30 pm');
    expect(text).toContain('Reason: Paid in cash, keyed as UPI');
    // The two rows of the move: not a refund, not new money.
    expect(text).toContain('UPI corrected out');
    expect(text).toContain('Cash corrected in');
    expect(t.text(t.doc().querySelector('p[aria-live]'))).not.toContain('Refunded');
  });

  it('a part of a payment can move; never more than is left of it', async () => {
    t = await startPage('/sales?id=71b0e4aa-0000-4000-8000-000000000002');
    t.button('Correct method', detail()!)?.click();
    await t.settle();
    t.type('Amount', '100', t.dialog()!);
    t.type('Reason', '₹100 of the UPI was cash', t.dialog()!);
    t.button('Move payment', t.dialog()!)?.click();
    await t.settle();
    expect(t.dialog()).toBeNull();
    t.button('Correct method', detail()!)?.click();
    await t.settle();
    expect(t.text(t.dialog())).toContain('UPI ₹500 (₹400 left)');
    t.type('Amount', '450', t.dialog()!);
    t.type('Reason', 'x', t.dialog()!);
    t.button('Move payment', t.dialog()!)?.click();
    await t.settle();
    expect(t.text(t.dialog()?.querySelector('[role="alert"]'))).toBe('That is more than ₹400');
  });

  it('only the permissions the server checks unlock the money actions', async () => {
    t = await startPage('/sales?id=0e55b981-0000-4000-8000-000000000004', 1440, ({ arena }) => {
      arena.memberships[0] = { ...arena.memberships[0], role: 'staff', perms: ['reports'] };
    });
    expect(t.text(detail())).toContain('Due ₹160');
    for (const label of ['Record payment', 'Refund', 'Correct method']) {
      expect(t.button(label, detail()!)).toBeUndefined();
    }
    t.cleanup();
    TestBed.resetTestingModule();
    t = await startPage('/sales?id=0e55b981-0000-4000-8000-000000000004', 1440, ({ arena }) => {
      arena.memberships[0] = { ...arena.memberships[0], role: 'staff', perms: ['money'] };
    });
    expect(t.button('Correct method', detail()!)).toBeDefined();
    expect(t.button('Refund', detail()!)).toBeUndefined();
    expect(t.button('Record payment', detail()!)).toBeUndefined();
  });

  it('voiding asks for a reason, then marks the bill void', async () => {
    t = await startPage('/sales?id=71b0e4aa-0000-4000-8000-000000000002');
    t.button('Void', detail()!)?.click();
    await t.settle();
    expect(t.dialog()?.querySelector('h2')?.textContent).toContain('Void S-71B0E4?');
    expect(t.text(t.dialog())).toContain('₹720 was collected on it; voiding does not refund it.');
    t.button('Void bill', t.dialog()!)?.click();
    await t.settle();
    expect(t.dialog()).toBeNull();
    expect(t.snack()).toBe('S-71B0E4 voided');
    expect(bill('S-71B0E4').voidReason).toBe('Wrong amount');
    expect(trailing(t.rows()[1])).toEqual(['—', 'Void']);
    expect(summary()).toBe('3 bills · UPI ₹440 · Cash ₹60 · ₹720 on voided bills');
    expect(totals()).toBe('Expected ₹660 Collected ₹500 Outstanding ₹160');
    expect(t.text(detail())).toContain('Voided · Wrong amount · by Arjun Mehra, 13 Oct 7:30 pm');
    expect(t.text(detail())).toContain('Voided Arjun Mehra · 13 Oct 7:30 pm');
    expect(t.button('Void', detail()!)).toBeUndefined();
  });

  it('a written reason is required when the reason is "Other"', async () => {
    t = await startPage('/sales?id=3f9a2c10-0000-4000-8000-000000000001');
    t.button('Void', detail()!)?.click();
    await t.settle();
    (t.dialog()!.querySelector('.mat-mdc-select-trigger') as HTMLElement).click();
    await t.settle();
    (
      [...t.doc().querySelectorAll('mat-option')].find((o) =>
        o.textContent?.includes('Other'),
      ) as HTMLElement
    ).click();
    await t.settle();
    t.button('Void bill', t.dialog()!)?.click();
    await t.settle();
    expect(t.text(t.dialog()?.querySelector('[role="alert"]'))).toBe('Give a reason for the void');
    t.type('Describe the reason', 'Test bill made during training', t.dialog()!);
    t.button('Void bill', t.dialog()!)?.click();
    await t.settle();
    expect(t.dialog()).toBeNull();
    expect(bill('S-3F9A2C').voidReason).toBe('Test bill made during training');
  });

  it('an open bill another device voids is shown voided after the live refresh', async () => {
    t = await startPage('/sales?id=71b0e4aa-0000-4000-8000-000000000002');
    expect(t.button('Void', detail()!)).toBeDefined();
    // Another owner voids it; the realtime nudge refreshes the store.
    await t.sales.void('', bill('S-71B0E4'), 'Duplicate');
    await TestBed.inject(SalesStore).refresh();
    await t.settle();
    expect(t.text(detail())).toContain('Voided · Duplicate');
    expect(t.button('Void', detail()!)).toBeUndefined();
  });

  it('a refused void stays in the dialog', async () => {
    t = await startPage('/sales?id=3f9a2c10-0000-4000-8000-000000000001');
    t.button('Void', detail()!)?.click();
    await t.settle();
    t.sales.failNext = 'forbidden';
    t.button('Void bill', t.dialog()!)?.click();
    await t.settle();
    expect(t.text(t.dialog()?.querySelector('[role="alert"]'))).toBe('Only an owner can do that');
  });

  it('a linked bill outside the range still opens', async () => {
    t = await startPage('/sales?id=9b8a7c6d-0000-4000-8000-000000000008');
    expect(detail()?.querySelector('h2')?.textContent?.trim()).toBe('S-9B8A7C');
    expect(detail()?.textContent).toContain('Paid · Card');
  });

  it('exports the bills report from the menu', async () => {
    t = await startPage('/sales');
    t.button('Export')?.click();
    await t.settle();
    t.button('Bills report (CSV)')?.click();
    await t.settle();
    expect(t.snack()).toBe('4 bills exported');
  });
});

describe('sales helpers', () => {
  const META: ReportMeta = {
    arena: '404 Arena Koramangala',
    period: periodFor('today', undefined, undefined, NOW),
    generatedAt: NOW,
    generatedBy: 'Arjun Mehra <arjun@404arena.in>',
    filters: null,
  };
  /** The sample bills that closed today (0) or yesterday (1). */
  const day = (n: 0 | 1) => {
    const { from, to } = rangeBounds(n === 0 ? 'today' : 'yesterday', NOW);
    return new SampleSalesApi(NOW).bills.filter(
      (b) => Date.parse(b.at) >= from.getTime() && Date.parse(b.at) < to.getTime(),
    );
  };

  it('ranges are IST calendar days', () => {
    const today = rangeBounds('today', NOW);
    expect(today.from.toISOString()).toBe('2026-10-12T18:30:00.000Z');
    expect(today.to.toISOString()).toBe('2026-10-13T18:30:00.000Z');
    expect(rangeBounds('yesterday', NOW).from.toISOString()).toBe('2026-10-11T18:30:00.000Z');
    expect(rangeBounds('7d', NOW).from.toISOString()).toBe('2026-10-06T18:30:00.000Z');
    // Just after midnight IST it is already the next day.
    const late = rangeBounds('today', new Date('2026-10-13T18:45:00Z'));
    expect(late.from.toISOString()).toBe('2026-10-13T18:30:00.000Z');
  });

  it('a custom period is any IST days up to 93; anything else is today', () => {
    expect(periodFor('custom', '2026-09-01', '2026-09-30', NOW)).toEqual({
      range: 'custom',
      first: '2026-09-01',
      last: '2026-09-30',
    });
    expect(periodFor('custom', '2026-07-01', '2026-10-13', NOW).range).toBe('today');
    expect(periodFor('custom', '2026-02-30', '2026-03-01', NOW).range).toBe('today');
    expect(periodFor('custom', undefined, '2026-03-01', NOW).range).toBe('today');
    expect(periodFor('30d', undefined, undefined, NOW)).toEqual({
      range: '30d',
      first: '2026-09-14',
      last: '2026-10-13',
    });
  });

  it('the summary reconciles: expected + overpaid = collected + outstanding + written off', () => {
    const bill = (o: Partial<Bill>): Bill => ({
      id: crypto.randomUUID(),
      ref: 'S-1',
      at: NOW.toISOString(),
      startedAt: NOW.toISOString(),
      endedAt: NOW.toISOString(),
      recordedAt: NOW.toISOString(),
      endRecordedAt: null,
      voided: false,
      paymentStatus: 'paid',
      customer: 'Guest',
      guest: true,
      returning: false,
      stations: [],
      activities: [],
      games: [],
      players: 1,
      playerMinutes: 0,
      billedPaise: 0,
      paidPaise: 0,
      refundedPaise: 0,
      methods: {},
      payments: [],
      startedBy: null,
      voidReason: null,
      voidedAt: null,
      voidedBy: null,
      discountPaise: 0,
      discount: null,
      ...o,
    });
    const s = summarize([
      // ₹300 paid by UPI, then ₹50 refunded in cash: net ₹250, nothing due.
      bill({
        billedPaise: 25_000,
        paidPaise: 25_000,
        refundedPaise: 5_000,
        methods: { upi: 30_000, cash: -5_000 },
      }),
      // Part paid: ₹100 of ₹400 in cash, ₹300 due.
      bill({
        paymentStatus: 'partial',
        billedPaise: 40_000,
        paidPaise: 10_000,
        methods: { cash: 10_000 },
      }),
      // Waived after ₹20: ₹180 written off, nothing due.
      bill({
        paymentStatus: 'waived',
        billedPaise: 20_000,
        paidPaise: 2_000,
        methods: { cash: 2_000 },
      }),
      // Paid ₹10 too much (an advance larger than the final bill).
      bill({ billedPaise: 10_000, paidPaise: 11_000, methods: { upi: 11_000 } }),
      // Voided after ₹200 was taken: not in the totals or the count, but still in the till.
      bill({ voided: true, billedPaise: 20_000, paidPaise: 20_000, methods: { cash: 20_000 } }),
    ]);
    expect(s).toEqual({
      count: 4,
      expectedPaise: 95_000,
      takingsPaise: 48_000,
      byMethod: { upi: 41_000, cash: 7_000, card: 0, other: 0 },
      duePaise: 30_000,
      writtenOffPaise: 18_000,
      overpaidPaise: 1_000,
      refundedPaise: 5_000,
      voidedCount: 1,
      voidedPaidPaise: 20_000,
    });
    expect(s.expectedPaise + s.overpaidPaise).toBe(s.takingsPaise + s.duePaise + s.writtenOffPaise);
    expect(Object.values(s.byMethod).reduce((a, b) => a + b, 0)).toBe(s.takingsPaise);
    expect(summaryLine(s)).toBe(
      '4 bills · UPI ₹410 · Cash ₹70 · Refunded ₹50 · Written off ₹180 · Overpaid ₹10 · ₹200 on voided bills',
    );
    expect(summaryLine(s, 'cash')).toBe(
      '4 bills paid by Cash · Cash ₹70 · UPI ₹410 · Refunded ₹50 · Written off ₹180 · Overpaid ₹10 · ₹200 on voided bills',
    );
  });

  it('typed rupees become exact paise', () => {
    expect(parseRupees('120')).toBe(12_000);
    expect(parseRupees('120.5')).toBe(12_050);
    expect(parseRupees('1,200.50')).toBe(120_050);
    expect(parseRupees('₹ 60')).toBe(6_000);
    expect(parseRupees('0.10')).toBe(10);
    expect(parseRupees('0')).toBeNull();
    expect(parseRupees('1.234')).toBeNull();
    expect(parseRupees('-5')).toBeNull();
    expect(parseRupees('abc')).toBeNull();
  });

  it('numbers each business day in start order', () => {
    const today = day(0);
    const no = dayNumbers(today);
    // Today's bills started 11:30 (RIFT), 2:35 (GHOST), 3:45 (VOID), 5:40 pm (HEX).
    expect(today.map((b) => `${b.ref}:${no.get(b.id)}`).sort()).toEqual([
      'S-71B0E4:3',
      'S-0E55B9:1',
      'S-3F9A2C:4',
      'S-C41D7E:2',
    ]);
  });

  it('text cells never run as formulas', () => {
    expect(textCell('Kiran')).toBe('Kiran');
    expect(textCell('a,b')).toBe('"a,b"');
    expect(textCell('=HYPERLINK("http://x","y")')).toBe(`"'=HYPERLINK(""http://x"",""y"")"`);
    expect(textCell('+91 98000')).toBe("'+91 98000");
    expect(textCell('-5')).toBe("'-5");
    expect(textCell('@SUM(A1)')).toBe("'@SUM(A1)");
    expect(textCell(null)).toBe('');
  });

  it('the bills report: header block, the spreadsheet columns, totals that match the screen', () => {
    const lines = billsCsv(day(0), META).trim().split('\n');
    expect(lines.slice(0, 6)).toEqual([
      '404 Arena Koramangala — Sales report (bills)',
      'Arena,404 Arena Koramangala',
      'Period,2026-10-13 (IST calendar days; a bill belongs to the day it closed)',
      'Time zone,"Asia/Kolkata (IST, UTC+05:30)"',
      'Generated,2026-10-13 19:30 IST (2026-10-13T14:00:00.000Z)',
      'Generated by,Arjun Mehra <arjun@404arena.in>',
    ]);
    const head = lines.findIndex((l) => l.startsWith('Business date,'));
    expect(lines[head - 1]).toBe('');
    expect(lines[head].split(',')).toEqual([
      'Business date',
      'No.',
      'Bill',
      'Bill ID',
      'Start',
      'End',
      'Minutes',
      'Hours',
      'Stations',
      'Activities',
      'Games',
      'Players',
      'Player-hours',
      'Customer',
      'Customer type',
      'Bill amount (₹)',
      'Expected (₹)',
      'Cash (₹)',
      'UPI (₹)',
      'Card (₹)',
      'Other (₹)',
      'Collected (₹)',
      'Refunded (₹)',
      'Outstanding (₹)',
      'Written off (₹)',
      'Status',
      'Void reason',
      'Voided by',
      'Voided at',
      'Started by',
      'Recorded on server',
    ]);
    // Oldest first, numbered per day.
    expect(lines[head + 1]).toBe(
      '2026-10-13,1,S-0E55B9,0e55b981-0000-4000-8000-000000000004,11:30,13:30,120,2.00,RIFT,PlayStation 5,Gran Turismo 7,1,2.00,Meera Pillai,New,360.00,360.00,0.00,200.00,0.00,0.00,200.00,0.00,160.00,0.00,Part paid,,,,Priya Nair,2026-10-13 11:30',
    );
    expect(lines[head + 4]).toBe(
      '2026-10-13,4,S-3F9A2C,3f9a2c10-0000-4000-8000-000000000001,17:40,18:40,60,1.00,HEX,PlayStation 5,EA SPORTS FC 25,2,2.00,Kiran Rao,Returning,240.00,240.00,0.00,240.00,0.00,0.00,240.00,0.00,0.00,0.00,Paid,,,,Priya Nair,2026-10-13 17:40',
    );
    const total = lines[head + 5].split(',');
    expect(total[0]).toBe('Total — 4 bills (voided bills excluded)');
    expect([total[6], total[7], total[12]]).toEqual(['300', '5.00', '10.50']);
    expect(total.slice(15, 25)).toEqual([
      '1380.00',
      '1380.00',
      '280.00',
      '940.00',
      '0.00',
      '0.00',
      '1220.00',
      '0.00',
      '160.00',
      '0.00',
    ]);
    expect(lines.length).toBe(head + 6);
  });

  it('the payments ledger lists every row and nets to the bills report', () => {
    const yesterday = day(1);
    const bills = billsCsv(yesterday, META).trim().split('\n');
    const counted = bills.find((l) => l.startsWith('Total —'))!.split(',');
    const voided = bills.find((l) => l.startsWith('On 1 voided bill '))!.split(',');
    expect(counted[21]).toBe('120.00');
    expect(voided[21]).toBe('120.00');
    expect(voided[16]).toBe('0.00');

    const lines = paymentsCsv(yesterday, META).trim().split('\n');
    const head = lines.findIndex((l) => l.startsWith('Received date,'));
    expect(lines.slice(head + 1)).toEqual([
      '2026-10-12,19:00,S-5D2E9B,5d2e9b44-0000-4000-8000-000000000006,2026-10-12,Paid,Rahul Verma,UPI,Payment,120.00,,,Rohan Das,2026-10-12T13:30:00.000Z',
      '2026-10-12,21:10,S-A8C3F0,a8c3f017-0000-4000-8000-000000000005,2026-10-12,Void,Kiran Rao,Cash,Payment,120.00,,,Priya Nair,2026-10-12T15:40:00.000Z',
      'Net Cash,,,,,,,,,120.00',
      'Net UPI,,,,,,,,,120.00',
      'Net total,,,,,,,,,240.00',
    ]);
    // Collected on bills that count + on voided bills = the ledger's net.
    expect(Number(counted[21]) + Number(voided[21])).toBe(240);
  });
});
