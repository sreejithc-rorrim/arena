import { TestBed } from '@angular/core/testing';
import { VenueApi, VenueStore, VenueType } from '../../../core/venue/venue';
import { PageTest, startPage } from '../../../testing/page-test';
import { MissedBill, MissedBillApi } from '../data/missed-bill-api';
import { ADDED_LATER_NOTE } from '../data/sale.models';

/** Prices every missed play at `price` and keeps the bills added. */
class FakeMissedBillApi {
  price = 15000;
  readonly added: MissedBill[] = [];

  async quote(): Promise<number> {
    return this.price;
  }

  async record(_arenaId: string, bill: MissedBill): Promise<void> {
    this.added.push(bill);
  }
}

const PS5: VenueType = { code: 'PS5', usesGames: true, usesControllers: true, active: true };

/** Sales › Missed bill on the sample floor; today's price is ₹150 until a test changes it. */
describe('Add missed bill', () => {
  let t: PageTest;
  let api: FakeMissedBillApi;

  const dialog = () => t.dialog()!;
  const field = (label: string) =>
    [...dialog().querySelectorAll('mat-form-field')].find((f) =>
      f.querySelector('mat-label')?.textContent?.includes(label),
    ) as HTMLElement;
  const amountInput = () => field('Amount paid').querySelector('input') as HTMLInputElement;
  const amountHint = () => t.text(field('Amount paid').querySelector('mat-hint'));
  const addBill = () => t.button('Add bill', dialog())!;

  async function pick(label: string, option: string) {
    (field(label).querySelector('.mat-mdc-select-trigger') as HTMLElement).click();
    await t.settle();
    (
      [...t.doc().querySelectorAll('mat-option')].find((o) => t.text(o) === option) as HTMLElement
    ).click();
    await t.settle();
  }

  async function type(label: string, value: string) {
    t.type(label, value, dialog());
    await t.settle();
  }

  /** Opens the dialog with HEX and one controller picked: priced, amount filled in. */
  async function open() {
    api = new FakeMissedBillApi();
    TestBed.overrideProvider(MissedBillApi, { useValue: api });
    TestBed.overrideProvider(VenueApi, {
      useValue: { load: async () => ({ types: [PS5], noun: 'station', hoursSaved: true }) },
    });
    t = await startPage('/sales');
    TestBed.inject(VenueStore).types.set([PS5]);
    t.button('Missed bill')!.click();
    await t.settle();
    await pick('Station', 'HEX');
    await pick('Controllers', '1');
  }

  afterEach(() => t?.cleanup());

  it('fills the amount paid with the price and shows how it differs', async () => {
    await open();
    expect(amountInput().value).toBe('150');
    expect(amountHint()).toBe("Same as today's price");
    await type('Amount paid', '100');
    expect(amountHint()).toBe("₹50 less than today's price");
    await type('Amount paid', '170');
    expect(amountHint()).toBe("₹20 more than today's price");
  });

  it('keeps Add bill off until the amount paid and the reason are valid', async () => {
    await open();
    expect(addBill().disabled).toBe(true);
    await type('Reason', '   ');
    expect(addBill().disabled).toBe(true);
    await type('Reason', 'Power cut');
    expect(addBill().disabled).toBe(false);

    await type('Amount paid', '');
    expect(addBill().disabled).toBe(true);
    for (const bad of ['abc', '-5', '12.345']) {
      await type('Amount paid', bad);
      expect(addBill().disabled).toBe(true);
      expect(amountHint()).toBe('Enter the amount paid in rupees, like 120 or 120.50');
    }
    await type('Amount paid', '0');
    expect(addBill().disabled).toBe(false);
    expect(amountHint()).toBe("₹150 less than today's price");
  });

  it('adds the bill at the amount paid, with the price shown and the reason trimmed', async () => {
    await open();
    await type('Amount paid', '120.50');
    await type('Reason', '  Old rate  ');
    addBill().click();
    await t.settle();
    expect(t.dialog()).toBeNull();
    expect(api.added).toHaveLength(1);
    expect(api.added[0]).toMatchObject({
      stationId: 's-hex',
      activityCode: 'PS5',
      controllers: 1,
      method: 'cash',
      customerId: null,
      billedPaise: 15000,
      paidPaise: 12050,
      reason: 'Old rate',
    });
  });

  it('a typed amount survives a new price; a cleared one follows the price again', async () => {
    await open();
    await type('Amount paid', '100');
    api.price = 30000;
    await pick('Controllers', '2');
    expect(amountInput().value).toBe('100');
    expect(amountHint()).toBe("₹200 less than today's price");

    await type('Amount paid', '');
    api.price = 15000;
    await pick('Controllers', '1');
    expect(amountInput().value).toBe('150');
  });
});

describe('A missed bill in the Sales detail', () => {
  let t: PageTest;

  afterEach(() => t?.cleanup());

  it("shows the amount paid against today's price, never as rounding", async () => {
    // S-3F9A2C priced ₹240 on today's list, added later at the ₹200 the customer paid.
    t = await startPage('/sales?id=3f9a2c10-0000-4000-8000-000000000001', 1440, ({ sales }) => {
      const b = sales.bills[0];
      const pay = { ...b.payments[0], amountPaise: 20000, note: ADDED_LATER_NOTE, reason: 'Power cut' };
      sales.bills[0] = {
        ...b,
        billedPaise: 20000,
        paidPaise: 20000,
        methods: { [pay.method]: 20000 },
        payments: [pay],
        history: [
          {
            at: b.at,
            action: 'record',
            by: 'Priya Nair',
            reason: 'Power cut',
            before: null,
            after: {
              billed_paise: 20000,
              quoted_paise: 24000,
              paid_paise: 20000,
              difference_paise: -4000,
            },
          },
        ],
      };
    });
    const detail = t.text(t.doc().querySelector('app-bill-detail'));
    expect(detail).toContain('Adjusted to amount paid −₹40');
    expect(detail).not.toContain('Rounding');
    expect(detail).toContain("Priced ₹240 on today's list; ₹200 paid.");
    expect(detail).toContain('Total ₹200');
  });
});
