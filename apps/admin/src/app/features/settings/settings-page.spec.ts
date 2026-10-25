import { PageTest, startPage } from '../../testing/page-test';

describe('Settings', () => {
  let t: PageTest;

  afterEach(() => t?.cleanup());

  it('lists the groups and opens Arena on a wide screen', async () => {
    t = await startPage('/settings');
    expect(t.rows().map(t.rowText)).toEqual([
      ['Arena', 'Name, area, hours, what you rent out'],
      ['Station types', 'What you sell: consoles, tables, grounds…'],
      ['Accessory types', 'Controller, VR headset, wheel…'],
      ['Games', 'Library, platforms, where each is playable'],
      ['Billing', 'Payment methods, discount limits'],
      ['Billing rules', 'Rounding, grace, minimum charge'],
      ['Sessions', 'Time options and warnings'],
      ['Owners & access', 'Who owns the venue, inviting an owner'],
      ['Staff', 'Staff terms'],
    ]);
    const arena = t.doc().querySelector('app-arena-settings') as HTMLElement;
    expect(t.text(arena.querySelector('h2'))).toBe('Arena');
    const name = arena.querySelector('input') as HTMLInputElement;
    expect(name.value).toBe('404 Arena Koramangala');
    expect(name.disabled).toBe(false);
    expect([...arena.querySelectorAll('input')].slice(0, 3).map((i) => i.value)).toEqual([
      '404 Arena Koramangala',
      'Koramangala',
      '080 4110 2209',
    ]);
  });

  it('saves the arena name, area and phone; the switcher picks up the new name', async () => {
    t = await startPage('/settings/arena');
    const arena = t.doc().querySelector('app-arena-settings') as HTMLElement;
    t.type('Arena name', '404 Arena HSR', arena);
    t.type('Area', 'HSR Layout', arena);
    await t.settle();
    t.button('Save', t.doc().querySelector('app-unsaved-bar')!)!.click();
    await t.settle();
    expect(t.snack()).toBe('Settings saved · the floor app updates on next refresh');
    expect(t.text(arena.querySelector('h2 + div'))).toContain('404 Arena HSR · HSR Layout');
    expect(t.text(t.doc().querySelector('app-shell, app-root'))).toContain('404 Arena HSR');
    expect(t.doc().querySelector('app-unsaved-bar')).toBeNull();
  });

  it('refuses a phone with letters', async () => {
    t = await startPage('/settings/arena');
    const arena = t.doc().querySelector('app-arena-settings') as HTMLElement;
    t.type('Phone', 'call me', arena);
    await t.settle();
    t.button('Save', t.doc().querySelector('app-unsaved-bar')!)!.click();
    await t.settle();
    expect(t.text(arena.querySelector('[role="alert"]'))).toBe(
      'Use 6 to 20 digits, spaces, +, ( ) or - for the phone',
    );
  });

  it('saves opening hours only (business_hours carries no happy-hour windows)', async () => {
    t = await startPage('/settings/arena');
    const arena = t.doc().querySelector('app-arena-settings') as HTMLElement;
    const monday = arena.querySelector('mat-slide-toggle button') as HTMLButtonElement;
    expect(monday.getAttribute('aria-checked')).toBe('false');
    monday.click();
    await t.settle();
    t.type('Closes at', '00:00', arena);
    await t.settle();
    t.button('Save', t.doc().querySelector('app-unsaved-bar')!)!.click();
    await t.settle();
    expect(t.pricing.hours.open['1']).toEqual({ start: 600, end: 1440 });
    expect(t.pricing.hours.open['2']).toEqual({ start: 840, end: 1380 });
    expect(Object.keys(t.pricing.hours)).toEqual(['open']);
    expect(t.snack()).toBe('Settings saved · the floor app updates on next refresh');
  });

  it('refuses a closing time before the opening time', async () => {
    t = await startPage('/settings/arena');
    const arena = t.doc().querySelector('app-arena-settings') as HTMLElement;
    t.type('Closes at', '13:00', arena);
    await t.settle();
    t.button('Save', t.doc().querySelector('app-unsaved-bar')!)!.click();
    await t.settle();
    expect(t.text(arena.querySelector('[role="alert"]'))).toBe(
      'Tuesday: closing time must be after opening time',
    );
  });

  it('billing: payment switches save the floor options; the last method stays on', async () => {
    t = await startPage('/settings/billing');
    const billing = t.doc().querySelector('app-billing-settings') as HTMLElement;
    const rows = () => [...billing.querySelectorAll('app-toggle-row')];
    const labels = rows().map((r) => t.text(r.querySelector('span span')));
    expect(labels).toEqual([
      'Prices include GST',
      'Cash',
      'UPI',
      'Card',
      'Other',
      'Discount needs a reason',
    ]);
    const sw = (label: string) =>
      rows()
        .find((r) => t.text(r.querySelector('span span')) === label)!
        .querySelector('button') as HTMLButtonElement;
    expect(['Cash', 'UPI', 'Card', 'Other'].map((l) => sw(l).getAttribute('aria-checked'))).toEqual(
      ['true', 'true', 'true', 'true'],
    );
    for (const l of ['Cash', 'Card', 'Other']) {
      sw(l).click();
      await t.settle();
    }
    sw('UPI').click(); // the last one: refused
    await t.settle();
    expect(t.snack()).toBe('Keep at least one payment method on');
    expect(sw('UPI').getAttribute('aria-checked')).toBe('true');
    t.button('Save', t.doc().querySelector('app-unsaved-bar')!)!.click();
    await t.settle();
    expect(t.floorOptions.writes).toEqual([
      { payment_methods: ['upi'], start_presets: [30, 60, 90, 120], warn_minutes: 5 },
    ]);
    // GST and invoices still await the owner's rules.
    expect(billing.querySelectorAll('app-not-connected').length).toBe(1);
  });

  it('sessions: time options and the warning save the floor options', async () => {
    t = await startPage('/settings/sessions');
    const sessions = t.doc().querySelector('app-session-settings') as HTMLElement;
    const chip = (label: string) =>
      [...sessions.querySelectorAll('mat-chip-option')].find((c) => t.text(c) === label)!;
    const selected = () =>
      [...sessions.querySelectorAll('mat-chip-option.mat-mdc-chip-selected')].map((c) => t.text(c));
    expect(selected()).toEqual(['30m', '1h', '1h 30m', '2h', '5 min']);
    (chip('15m').querySelector('button, .mdc-evolution-chip__action') as HTMLElement).click();
    (chip('2h').querySelector('button, .mdc-evolution-chip__action') as HTMLElement).click();
    (chip('10 min').querySelector('button, .mdc-evolution-chip__action') as HTMLElement).click();
    await t.settle();
    t.button('Save', t.doc().querySelector('app-unsaved-bar')!)!.click();
    await t.settle();
    expect(t.floorOptions.writes.at(-1)).toEqual({
      payment_methods: ['cash', 'upi', 'card', 'other'],
      start_presets: [15, 30, 60, 90],
      warn_minutes: 10,
    });
    expect(t.snack()).toBe('Settings saved · the floor app updates on next refresh');
    expect(sessions.querySelector('app-not-connected')).toBeNull();
  });

  describe('billing rules', () => {
    const rules = () => t.doc().querySelector('app-billing-rules') as HTMLElement;
    const bar = () => t.doc().querySelector('app-unsaved-bar') as HTMLElement | null;
    /** Each select's label and shown value. */
    const values = () =>
      [...rules().querySelectorAll('mat-form-field')].map(
        (f) =>
          `${t.text(f.querySelector('mat-label'))}: ${t.text(f.querySelector('.mat-mdc-select-value'))}`,
      );
    async function pick(label: string, option: string) {
      const field = [...rules().querySelectorAll('mat-form-field')].find(
        (f) => t.text(f.querySelector('mat-label')) === label,
      );
      (field!.querySelector('.mat-mdc-select-trigger') as HTMLElement).click();
      await t.settle();
      const opt = [...t.doc().querySelectorAll('mat-option')].find((o) => t.text(o) === option);
      (opt as HTMLElement).click();
      await t.settle();
    }

    it('shows the arena’s rules (the defaults until it saves its own)', async () => {
      t = await startPage('/settings/rules');
      expect(t.text(rules().querySelector('h2'))).toBe('Billing rules');
      expect(t.text(rules().querySelector('h2 + div'))).toBe(
        'Per minute (exact) · bills rounded to nearest ₹1',
      );
      expect(values()).toEqual([
        'Charge partial time: Per minute (exact)',
        'Grace period: None',
        'Minimum charge: None',
        'If they leave early: Bill the time actually played',
        'Round the final bill to: ₹1',
        'Rounding direction: To the nearest',
        'Round once or per segment: Once, on the session total',
        'Part-used block: Charge the whole block',
        'Cleaning gap between sessions: None',
      ]);
      expect(bar()).toBeNull();
    });

    it('saves the whole policy with policy.save; block rounding shows for blocks only', async () => {
      t = await startPage('/settings/rules');
      await pick('Charge partial time', 'In 15-minute blocks');
      expect(values()[1]).toBe('Block rounding: Always round up');
      await pick('Block rounding', 'Round to nearest');
      await pick('Grace period', '5 min');
      await pick('Round the final bill to', '₹10');
      (rules().querySelector('mat-slide-toggle button') as HTMLButtonElement).click();
      await t.settle();
      t.button('Save', bar()!)!.click();
      await t.settle();
      await t.settle();
      expect(t.snack()).toBe('Billing rules saved · new sessions use them');
      expect(t.pricing.ops).toEqual([
        {
          kind: 'policy.save',
          payload: {
            policy: {
              billing_unit: 'block_15',
              block_rounding: 'nearest',
              grace_minutes: 5,
              minimum_charge_minutes: 0,
              early_exit: 'actual',
              rounding_scope: 'session',
              late_arrival: 'actual',
              vr_unit_rounding: 'up',
              money_rounding_paise: 1000,
              money_rounding_dir: 'nearest',
              payment_timing: 'either',
              allow_extend_past_close: true,
              cleaning_gap_minutes: 0,
            },
          },
        },
      ]);
      expect(bar()).toBeNull();
      expect(values()[0]).toBe('Charge partial time: In 15-minute blocks');
    });

    it('keeps rules the editor does not offer, and shows a saved value outside the choices', async () => {
      t = await startPage('/settings/rules', 1440, (apis) => {
        apis.pricing.policy = {
          ...apis.pricing.policy,
          lateArrival: 'planned',
          paymentTiming: 'end',
          graceMinutes: 7,
        };
      });
      expect(values()[1]).toBe('Grace period: 7 min');
      await pick('Minimum charge', '10 min');
      t.button('Save', bar()!)!.click();
      await t.settle();
      const policy = (t.pricing.ops[0].payload as { policy: Record<string, unknown> }).policy;
      expect(policy).toMatchObject({
        late_arrival: 'planned',
        payment_timing: 'end',
        grace_minutes: 7,
        minimum_charge_minutes: 10,
      });
    });

    it('discard puts the saved rules back; a refusal keeps the draft', async () => {
      t = await startPage('/settings/rules');
      await pick('If they leave early', 'Bill the full booked duration');
      t.pricing.failNext = 'forbidden';
      t.button('Save', bar()!)!.click();
      await t.settle();
      expect(t.text(rules().querySelector('[role="alert"]'))).toBe(
        'You need the Settings permission for that',
      );
      expect(bar()).not.toBeNull();
      t.button('Discard', bar()!)!.click();
      await t.settle();
      expect(values()[3]).toBe('If they leave early: Bill the time actually played');
      expect(bar()).toBeNull();
      expect(t.pricing.ops).toEqual([]);
    });
  });

  describe('station types', () => {
    const types = () => t.doc().querySelector('app-station-types') as HTMLElement;
    const field = (label: string) => {
      const f = [...(t.dialog() ?? t.doc()).querySelectorAll('mat-form-field')].find((x) =>
        x.querySelector('mat-label')?.textContent?.includes(label),
      );
      return f?.querySelector('input') as HTMLInputElement;
    };
    const fill = (label: string, value: string) => {
      field(label).value = value;
      field(label).dispatchEvent(new Event('input'));
    };
    const rowOf = (name: string) =>
      [...types().querySelectorAll('li')].find((li) => li.textContent?.includes(name))!;

    it('lists every type, on or off, with how it is billed', async () => {
      t = await startPage('/settings/types');
      const names = [...types().querySelectorAll('li span.font-medium')].map((e) => t.text(e));
      expect(names).toEqual(['PlayStation 5', 'VR', 'Pool']);
      expect(t.text(rowOf('PlayStation 5'))).toContain(
        'PS5 · By the minute, hourly rate · controllers · games · 4 stations',
      );
    });

    it('a new arena has none and says what to add', async () => {
      t = await startPage('/settings/types', 1440, (apis) => {
        apis.pricing.types = [];
      });
      expect(t.text(types())).toContain(
        'No station types yet. Pick one from the catalog (PlayStation, Pool table, Football turf…) or add your own.',
      );
    });

    it('adds a type with a code that follows its name', async () => {
      t = await startPage('/settings/types');
      t.button('Custom', types())!.click();
      await t.settle();
      // Happy hours are pricing rules now: the type has no happy-hour switch.
      expect(t.text(t.dialog())).not.toMatch(/happy/i);
      fill('Name', 'Racing Simulator');
      await t.settle();
      expect(field('Code').value).toBe('RACINGSIMULA');
      fill('Code', 'race');
      t.button('Add type', t.dialog()!)!.click();
      await t.settle();
      await t.settle();
      expect(t.dialog()).toBeNull();
      expect(t.snack()).toBe('Racing Simulator added · set its price in Pricing');
      expect(t.pricing.types.at(-1)?.code).toBe('RACE');
    });

    it('a taken code is refused in the dialog', async () => {
      t = await startPage('/settings/types');
      t.button('Custom', types())!.click();
      await t.settle();
      fill('Name', 'Another');
      fill('Code', 'PS5');
      t.button('Add type', t.dialog()!)!.click();
      await t.settle();
      expect(t.text(t.dialog()!.querySelector('[role="alert"]'))).toBe(
        'Another type already uses that code',
      );
    });

    it('a type with stations cannot be turned off or removed', async () => {
      t = await startPage('/settings/types');
      (
        rowOf('PlayStation 5').querySelector('mat-slide-toggle button') as HTMLButtonElement
      ).click();
      await t.settle();
      expect(t.snack()).toBe('Remove PlayStation 5 from its 4 stations first');
      expect(t.pricing.types.find((x) => x.id === 't-ps5')?.active).toBe(true);
      (
        rowOf('PlayStation 5').querySelector(
          'button[aria-label="Remove PlayStation 5"]',
        ) as HTMLButtonElement
      ).click();
      await t.settle();
      expect(t.text(t.dialog())).toContain('4 stations offer it');
    });

    it('removes a type no station offers: never used → deleted', async () => {
      t = await startPage('/settings/types');
      (
        rowOf('Pool').querySelector('button[aria-label="Remove Pool"]') as HTMLButtonElement
      ).click();
      await t.settle();
      t.button('Remove', t.dialog()!.querySelector('mat-dialog-actions')!)!.click();
      await t.settle();
      expect(t.pricing.types.some((x) => x.id === 't-pool')).toBe(false);
      expect(t.snack()).toBe('Pool deleted');
    });
  });

  describe('accessory types', () => {
    const kinds = () => t.doc().querySelector('app-accessory-types') as HTMLElement;

    it('lists kinds with whether they count as a controller', async () => {
      t = await startPage('/settings/accessories');
      const lines = [...kinds().querySelectorAll('li')].map((li) => t.text(li));
      expect(lines[0]).toContain('Controller Counts as a controller · 2 on stations');
      expect(lines[1]).toContain('VR headset Tracked only · 1 on stations');
    });

    it('adds a kind that is tracked only', async () => {
      t = await startPage('/settings/accessories');
      t.button('Custom', kinds())!.click();
      await t.settle();
      t.type('Name', 'Steering wheel', t.dialog()!);
      t.button('Add type', t.dialog()!)!.click();
      await t.settle();
      await t.settle();
      expect(t.snack()).toBe('Steering wheel added');
      expect(t.accessories.ops.at(-1)).toEqual({
        kind: 'accessory_kind.upsert',
        payload: expect.objectContaining({ name: 'Steering wheel', counts_as_controller: false }),
      });
    });

    it('a kind still on accessories is turned off, not deleted', async () => {
      t = await startPage('/settings/accessories');
      (
        kinds().querySelector('button[aria-label="Remove VR headset"]') as HTMLButtonElement
      ).click();
      await t.settle();
      t.button('Remove', t.dialog()!.querySelector('mat-dialog-actions')!)!.click();
      await t.settle();
      await t.settle();
      expect(t.snack()).toBe('VR headset turned off');
      expect(t.accessories.kindList.find((k) => k.id === 'k-vr')?.active).toBe(false);
    });
  });

  it('billing: manual discount limits save as discount_options', async () => {
    t = await startPage('/settings/billing');
    const billing = t.doc().querySelector('app-billing-settings') as HTMLElement;
    t.type('Max staff discount', '15', billing);
    await t.settle();
    t.button('Save', t.doc().querySelector('app-unsaved-bar')!)!.click();
    await t.settle();
    await t.settle();
    expect(t.pricing.discountOptions).toEqual({ manualMaxPercent: 15, reasonRequired: true });
    expect(t.floorOptions.writes).toEqual([]);
  });
});
