import { AppError } from '../../../core/auth/auth-api';
import { BillingPolicy, DEFAULT_POLICY } from './billing-policy';
import {
  PRICING_MESSAGES,
  PricingApi,
  discountOps,
  holidayOps,
  policyOps,
  ruleOps,
} from './pricing-api';
import {
  BusinessHours,
  DEFAULT_DISCOUNT_OPTIONS,
  Discount,
  DiscountOptions,
  DiscountUsage,
  Holiday,
  PricingData,
  PricingRule,
  Rate,
  RateChange,
  StationType,
  TypeInput,
} from './pricing.models';

const OPEN = { start: 840, end: 1380 };

/** The server's default hours (open Tue–Sun 2–11 pm). */
export function defaultHours(): BusinessHours {
  return {
    open: { '1': null, '2': OPEN, '3': OPEN, '4': OPEN, '5': OPEN, '6': OPEN, '7': OPEN },
  };
}

function type(id: string, code: string, name: string, o: Partial<StationType> = {}): StationType {
  return {
    id,
    code,
    name,
    overtimeGraceMinutes: 0,
    usesControllers: false,
    usesGames: false,
    durationModel: 'hourly',
    sortOrder: 0,
    active: true,
    stations: 0,
    ...o,
  };
}

/** A deterministic price list (paise); changes are applied in memory like the server would. */
export class SamplePricingApi extends PricingApi {
  types: StationType[];
  rates: Rate[];
  hours: BusinessHours = defaultHours();
  /** Ordered by day; one past (Independence Day) and two to come, for a sample "now" in Oct 2026. */
  holidays: Holiday[];
  policy: BillingPolicy = DEFAULT_POLICY;
  rules: PricingRule[] = [];
  discounts: Discount[] = [];
  discountOptions: DiscountOptions = DEFAULT_DISCOUNT_OPTIONS;
  /** Bills per discount id (the usage report), newest first. */
  usage = new Map<string, DiscountUsage['rows'][number][]>();

  /** Every holiday / policy write, in order, as `kind` + payload (what sync_push would get). */
  readonly ops: { kind: string; payload: unknown }[] = [];
  /** Set to make the next call fail with this code. */
  failNext: string | null = null;

  constructor(empty = false) {
    super();
    this.types = empty
      ? []
      : [
          type('t-ps5', 'PS5', 'PlayStation 5', {
            usesControllers: true,
            usesGames: true,
            stations: 4,
          }),
          type('t-vr', 'VR', 'VR', {
            usesGames: true,
            durationModel: 'unit',
            stations: 1,
            sortOrder: 1,
          }),
          type('t-pool', 'POOL', 'Pool', { stations: 0, sortOrder: 2, active: false }),
        ];
    const ps5 = (cc: number, pricePaise: number): Rate => ({
      activityCode: 'PS5',
      controllerCount: cc,
      unitMinutes: 60,
      pricePaise,
    });
    this.holidays = empty
      ? []
      : [
          { day: '2026-08-15', name: 'Independence Day', closed: false },
          { day: '2026-11-08', name: 'Diwali', closed: false },
          { day: '2026-12-25', name: 'Christmas', closed: true },
        ];
    if (!empty) {
      this.rules = [
        {
          id: 'r-happy',
          name: 'Happy hours',
          priority: 1,
          active: true,
          days: [2, 3, 4, 5],
          startMin: 840,
          endMin: 1020,
          holidayMode: 'skip',
          validFrom: null,
          validUntil: null,
          activityCodes: ['PS5'],
          adjustKind: 'percent',
          adjustValue: -20,
        },
        {
          id: 'r-weekend',
          name: 'Weekend evening',
          priority: 2,
          active: true,
          days: [6, 7],
          startMin: 1080,
          endMin: 1380,
          holidayMode: 'any',
          validFrom: null,
          validUntil: null,
          activityCodes: [],
          adjustKind: 'percent',
          adjustValue: 20,
        },
      ];
      this.discounts = [
        {
          id: 'd-student',
          kind: 'preset',
          name: 'Student',
          code: null,
          valueKind: 'percent',
          value: 10,
          maxDiscountPaise: null,
          minBillPaise: null,
          activityCodes: [],
          validFrom: null,
          validUntil: null,
          maxUses: null,
          active: true,
        },
        {
          id: 'd-diwali',
          kind: 'coupon',
          name: 'Diwali',
          code: 'DIWALI20',
          valueKind: 'percent',
          value: 20,
          maxDiscountPaise: 10000,
          minBillPaise: null,
          activityCodes: ['PS5'],
          validFrom: null,
          validUntil: '2026-11-15T18:29:59.000Z',
          maxUses: 50,
          active: true,
        },
      ];
      this.usage.set('d-diwali', [
        {
          billId: '3f9a2c10-0000-4000-8000-000000000001',
          at: '2026-10-13T13:10:00.000Z',
          customer: 'Kiran Rao',
          billedPaise: 12000,
          amountPaise: 3000,
          status: 'completed',
          by: 'Priya Nair',
        },
      ]);
    }
    this.rates = empty
      ? []
      : [
          ps5(1, 15000),
          ps5(2, 22000),
          {
            activityCode: 'VR',
            controllerCount: null,
            unitMinutes: 30,
            pricePaise: 20000,
          },
        ];
  }

  async load(): Promise<PricingData> {
    this.fail();
    return {
      types: [...this.types],
      rates: [...this.rates],
      hours: this.hours,
      holidays: [...this.holidays],
      policy: this.policy,
      rules: [...this.rules].sort(
        (a, b) => a.priority - b.priority || a.name.localeCompare(b.name),
      ),
      discounts: [...this.discounts],
      discountOptions: this.discountOptions,
    };
  }

  async saveRule(_arenaId: string, rule: PricingRule): Promise<void> {
    this.fail();
    this.ops.push(...ruleOps(rule));
    const exists = this.rules.some((r) => r.id === rule.id);
    this.rules = exists
      ? this.rules.map((r) => (r.id === rule.id ? { ...rule } : r))
      : [...this.rules, { ...rule }];
  }

  async deleteRule(_arenaId: string, id: string): Promise<void> {
    this.fail();
    this.ops.push({ kind: 'rule.delete', payload: { id } });
    this.rules = this.rules.filter((r) => r.id !== id);
  }

  async reorderRules(_arenaId: string, ids: readonly string[]): Promise<void> {
    this.fail();
    this.ops.push({ kind: 'rule.reorder', payload: { ids } });
    if (ids.length !== this.rules.length || !this.rules.every((r) => ids.includes(r.id))) {
      throw this.error('stale');
    }
    this.rules = this.rules.map((r) => ({ ...r, priority: ids.indexOf(r.id) + 1 }));
  }

  async saveDiscount(_arenaId: string, d: Discount): Promise<void> {
    this.fail();
    this.ops.push(...discountOps(d));
    if (d.code && this.discounts.some((x) => x.id !== d.id && x.code === d.code)) {
      throw this.error('duplicate');
    }
    const exists = this.discounts.some((x) => x.id === d.id);
    this.discounts = exists
      ? this.discounts.map((x) => (x.id === d.id ? { ...d } : x))
      : [...this.discounts, { ...d }];
  }

  async setDiscountActive(_arenaId: string, id: string, active: boolean): Promise<void> {
    this.fail();
    this.ops.push({ kind: 'discount.set_active', payload: { id, active } });
    this.discounts = this.discounts.map((x) => (x.id === id ? { ...x, active } : x));
  }

  async deleteDiscount(_arenaId: string, id: string): Promise<void> {
    this.fail();
    this.ops.push({ kind: 'discount.delete', payload: { id } });
    if (this.usage.get(id)?.length) throw this.error('discount_used');
    this.discounts = this.discounts.filter((x) => x.id !== id);
  }

  async saveDiscountOptions(_arenaId: string, options: DiscountOptions): Promise<void> {
    this.fail();
    this.ops.push({ kind: 'settings.save', payload: { key: 'discount_options', options } });
    this.discountOptions = { ...options };
  }

  /** Reads of the usage report, by discount id (lazy-loading checks). */
  readonly usageReads: string[] = [];

  async discountUsage(
    _arenaId: string,
    id: string,
    limit: number,
    cursor: string | null,
  ): Promise<DiscountUsage> {
    this.fail();
    this.usageReads.push(id);
    const all = this.usage.get(id) ?? [];
    const from = cursor ? Number(cursor) : 0;
    const rows = all.slice(from, from + limit);
    return {
      uses: all.length,
      activeUses: all.filter((u) => u.status !== 'voided').length,
      rows,
      next: from + limit < all.length ? String(from + limit) : null,
    };
  }

  async saveType(_arenaId: string, t: TypeInput): Promise<void> {
    this.fail();
    const code = t.code.trim().toUpperCase();
    if (!/^[A-Z0-9_]{1,12}$/.test(code)) throw this.error('invalid_code');
    const existing = this.types.find((x) => x.id === t.id);
    if (existing && existing.code !== code) throw this.error('code_locked');
    if (this.types.some((x) => x.id !== t.id && x.code === code)) throw this.error('duplicate');
    const next: StationType = {
      ...t,
      code,
      overtimeGraceMinutes: t.overtimeGraceMinutes ?? existing?.overtimeGraceMinutes ?? 0,
      stations: existing?.stations ?? 0,
    };
    this.types = existing
      ? this.types.map((x) => (x.id === t.id ? next : x))
      : [...this.types, next];
  }

  /** Types with `used` ids have history: they are turned off instead of deleted. */
  used = new Set<string>(['t-ps5']);

  async removeType(_arenaId: string, id: string): Promise<'deleted' | 'retired'> {
    this.fail();
    const t = this.types.find((x) => x.id === id);
    if (!t) return 'deleted';
    if (t.stations > 0) throw this.error('activity_has_stations');
    if (this.used.has(id)) {
      this.types = this.types.map((x) => (x.id === id ? { ...x, active: false } : x));
      return 'retired';
    }
    this.types = this.types.filter((x) => x.id !== id);
    this.rates = this.rates.filter((r) => r.activityCode !== t.code);
    return 'deleted';
  }

  async saveRates(_arenaId: string, changes: readonly RateChange[]): Promise<void> {
    this.fail();
    for (const c of changes) {
      const same = (r: Rate) =>
        r.activityCode === c.activityCode && r.controllerCount === c.controllerCount;
      this.rates = this.rates.filter((r) => !same(r));
      if (c.pricePaise != null) {
        this.rates.push({ ...c, pricePaise: c.pricePaise });
      }
    }
  }

  async saveHours(_arenaId: string, hours: BusinessHours): Promise<void> {
    this.fail();
    this.hours = { open: hours.open };
  }

  /** Like the server: an upsert by day, then the old day's delete when the holiday moved. */
  async saveHoliday(_arenaId: string, holiday: Holiday, replacing?: string): Promise<void> {
    this.fail();
    for (const op of holidayOps(holiday, replacing)) {
      this.ops.push(op);
      const day = String(op.payload['day']);
      this.holidays = this.holidays.filter((h) => h.day !== day);
      if (op.kind === 'holiday.upsert') this.holidays.push({ ...holiday });
    }
    this.holidays.sort((a, b) => a.day.localeCompare(b.day));
  }

  async deleteHoliday(_arenaId: string, day: string): Promise<void> {
    this.fail();
    this.ops.push({ kind: 'holiday.delete', payload: { day } });
    this.holidays = this.holidays.filter((h) => h.day !== day);
  }

  async savePolicy(_arenaId: string, policy: BillingPolicy): Promise<void> {
    this.fail();
    this.ops.push(...policyOps(policy));
    this.policy = { ...policy };
  }

  private error(code: string): AppError {
    return new AppError(code, PRICING_MESSAGES[code] ?? code);
  }

  private fail(): void {
    const code = this.failNext;
    if (!code) return;
    this.failNext = null;
    throw new AppError(
      code,
      code === 'forbidden' ? 'You need the Settings permission for that' : code,
    );
  }
}
