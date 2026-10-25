import { Service, inject } from '@angular/core';
import { dbError } from '../../../core/arena/arena-api';
import { Supabase } from '../../../core/supabase/supabase';
import { SyncOp, pushOps } from '../../../core/sync/push-ops';
import { BillingPolicy, POLICY_COLUMNS, parsePolicy, policyJson } from './billing-policy';
import {
  BusinessHours,
  DEFAULT_DISCOUNT_OPTIONS,
  Discount,
  DiscountOptions,
  DiscountUsage,
  DurationModel,
  Holiday,
  PricingData,
  PricingRule,
  Rate,
  RateChange,
  TypeInput,
  WeekWindows,
} from './pricing.models';

/**
 * The price list: station types, rates and opening hours read through arena_pricing() (owner
 * level), day/time rules, holidays and the billing policy from their tables (RLS); written as activity.* /
 * rate.* / settings.save / holiday.* / policy.save ops through sync_push. Tests provide
 * SamplePricingApi.
 */
@Service({ factory: () => new SupabasePricingApi() })
export abstract class PricingApi {
  abstract load(arenaId: string): Promise<PricingData>;
  abstract saveType(arenaId: string, type: TypeInput): Promise<void>;
  /** Deletes a never-used type with its prices, or turns a used one off (past bills keep it). */
  abstract removeType(arenaId: string, id: string): Promise<'deleted' | 'retired'>;
  abstract saveRates(arenaId: string, changes: readonly RateChange[]): Promise<void>;
  abstract saveHours(arenaId: string, hours: BusinessHours): Promise<void>;
  /**
   * Adds or edits the holiday on `holiday.day`; `replacing` is the day it was on before when the
   * edit moved it (that day is cleared in the same batch, after the new one is saved).
   */
  abstract saveHoliday(arenaId: string, holiday: Holiday, replacing?: string): Promise<void>;
  abstract deleteHoliday(arenaId: string, day: string): Promise<void>;
  abstract savePolicy(arenaId: string, policy: BillingPolicy): Promise<void>;
  abstract saveRule(arenaId: string, rule: PricingRule): Promise<void>;
  abstract deleteRule(arenaId: string, id: string): Promise<void>;
  /** Every rule id, first-tried first (priorities become 1, 2, 3…). */
  abstract reorderRules(arenaId: string, ids: readonly string[]): Promise<void>;
  abstract saveDiscount(arenaId: string, discount: Discount): Promise<void>;
  abstract setDiscountActive(arenaId: string, id: string, active: boolean): Promise<void>;
  /** Only a preset or coupon no bill used; a used one is turned off instead. */
  abstract deleteDiscount(arenaId: string, id: string): Promise<void>;
  abstract saveDiscountOptions(arenaId: string, options: DiscountOptions): Promise<void>;
  /** The bills a preset or coupon was used on, newest first, a page at a time. */
  abstract discountUsage(
    arenaId: string,
    id: string,
    limit: number,
    cursor: string | null,
  ): Promise<DiscountUsage>;
}

export const PRICING_MESSAGES: Readonly<Record<string, string>> = {
  invalid_code: 'Use up to 12 letters, digits or _ for the code',
  invalid_name: 'Enter a name of up to 40 characters',
  duplicate: 'Another type already uses that code',
  code_locked: 'A type keeps its code once created',
  activity_busy: 'A session of this type is running · end it on the floor first',
  activity_missing: 'That type is gone. Refresh',
  activity_has_stations: 'Stations still offer this type · remove them first',
  setting_not_shared: 'That setting cannot be saved here',
  invalid_window: 'Pick at least one day, and an end after the start',
  invalid_adjustment: 'Enter a change of up to −100% / +500%, or a rupee amount',
  unknown_type: 'One of those station types is gone. Refresh',
  stale: 'The rules were changed elsewhere. Refresh and try again',
  invalid_discount: 'Check the amount, limits and dates',
  kind_locked: 'Bills already used it, so it stays a preset or a coupon',
  discount_used: 'Bills already used it · turn it off instead',
  invalid_discount_options: 'Enter a whole percent from 0 to 100',
};

export function ruleOps(r: PricingRule): SyncOp[] {
  return [
    {
      kind: 'rule.upsert',
      payload: {
        id: r.id,
        name: r.name,
        priority: r.priority,
        active: r.active,
        days: r.days,
        start_min: r.startMin,
        end_min: r.endMin,
        holiday_mode: r.holidayMode,
        valid_from: r.validFrom,
        valid_until: r.validUntil,
        activity_codes: r.activityCodes,
        adjust_kind: r.adjustKind,
        adjust_value: r.adjustValue,
      },
    },
  ];
}

export function discountOps(d: Discount): SyncOp[] {
  return [
    {
      kind: 'discount.upsert',
      payload: {
        id: d.id,
        kind: d.kind,
        name: d.name,
        code: d.code,
        value_kind: d.valueKind,
        value: d.value,
        max_discount_paise: d.maxDiscountPaise,
        min_bill_paise: d.minBillPaise,
        activity_codes: d.activityCodes,
        valid_from: d.validFrom,
        valid_until: d.validUntil,
        max_uses: d.maxUses,
        active: d.active,
      },
    },
  ];
}

export function parseRule(r: Record<string, unknown>): PricingRule {
  const str = (v: unknown) => (v == null ? null : String(v));
  return {
    id: String(r['id']),
    name: String(r['name']),
    priority: Number(r['priority'] ?? 0),
    active: r['active'] !== false,
    days: ((r['days'] as unknown[] | null) ?? []).map(Number),
    startMin: Number(r['start_min'] ?? 0),
    endMin: Number(r['end_min'] ?? 1440),
    holidayMode: (r['holiday_mode'] as PricingRule['holidayMode']) ?? 'any',
    validFrom: str(r['valid_from']),
    validUntil: str(r['valid_until']),
    activityCodes: ((r['activity_codes'] as unknown[] | null) ?? []).map(String),
    adjustKind: r['adjust_kind'] === 'per_hour' ? 'per_hour' : 'percent',
    adjustValue: Number(r['adjust_value'] ?? 0),
  };
}

export function parseDiscount(r: Record<string, unknown>): Discount {
  const str = (v: unknown) => (v == null ? null : String(v));
  const num = (v: unknown) => (v == null ? null : Number(v));
  return {
    id: String(r['id']),
    kind: r['kind'] === 'coupon' ? 'coupon' : 'preset',
    name: String(r['name']),
    code: str(r['code']),
    valueKind: r['value_kind'] === 'flat' ? 'flat' : 'percent',
    value: Number(r['value'] ?? 0),
    maxDiscountPaise: num(r['max_discount_paise']),
    minBillPaise: num(r['min_bill_paise']),
    activityCodes: ((r['activity_codes'] as unknown[] | null) ?? []).map(String),
    validFrom: str(r['valid_from']),
    validUntil: str(r['valid_until']),
    maxUses: num(r['max_uses']),
    active: r['active'] !== false,
  };
}

export function parseDiscountOptions(v: unknown): DiscountOptions {
  const o = (v ?? {}) as Record<string, unknown>;
  if (!v) return DEFAULT_DISCOUNT_OPTIONS;
  return {
    manualMaxPercent: Number(o['manual_max_percent'] ?? 0),
    reasonRequired: o['reason_required'] !== false,
  };
}

export const RULE_COLUMNS =
  'id, name, priority, active, days, start_min, end_min, holiday_mode, valid_from, valid_until, activity_codes, adjust_kind, adjust_value';
export const DISCOUNT_COLUMNS =
  'id, kind, name, code, value_kind, value, max_discount_paise, min_bill_paise, activity_codes, valid_from, valid_until, max_uses, active';

/**
 * holiday.upsert (keyed by day), then holiday.delete of the day it moved from, if it moved: the
 * new day is saved before the old one is cleared, so a refusal never loses the holiday.
 */
export function holidayOps(h: Holiday, replacing?: string): SyncOp[] {
  return [
    { kind: 'holiday.upsert', payload: { day: h.day, name: h.name, closed: h.closed } },
    ...(replacing && replacing !== h.day
      ? [{ kind: 'holiday.delete', payload: { day: replacing } }]
      : []),
  ];
}

/** policy.save: the whole policy inside `policy`. */
export function policyOps(policy: BillingPolicy): SyncOp[] {
  return [{ kind: 'policy.save', payload: { policy: policyJson(policy) } }];
}

export function typeOps(type: TypeInput): SyncOp[] {
  return [
    {
      kind: 'activity.upsert',
      payload: {
        id: type.id,
        code: type.code,
        name: type.name,
        uses_controllers: type.usesControllers,
        uses_games: type.usesGames,
        duration_model: type.durationModel,
        sort_order: type.sortOrder,
        active: type.active,
        ...(type.overtimeGraceMinutes == null
          ? {}
          : { overtime_grace_minutes: type.overtimeGraceMinutes }),
      },
    },
  ];
}

/** The only rate band: day/time price changes (happy hours too) are pricing rules. */
export const RATE_BAND = 'standard';

export function rateOps(changes: readonly RateChange[]): SyncOp[] {
  return changes.map((c) =>
    c.pricePaise == null
      ? {
          kind: 'rate.delete',
          payload: {
            activity_code: c.activityCode,
            band: RATE_BAND,
            controller_count: c.controllerCount,
          },
        }
      : {
          kind: 'rate.upsert',
          payload: {
            activity_code: c.activityCode,
            band: RATE_BAND,
            controller_count: c.controllerCount,
            unit_minutes: c.unitMinutes,
            price_paise: c.pricePaise,
          },
        },
  );
}

/** arena_pricing's rates; rows of any other (older) band are left out: they never price. */
export function parseRates(rows: readonly Record<string, unknown>[]): Rate[] {
  return rows
    .filter((r) => (r['band'] ?? RATE_BAND) === RATE_BAND)
    .map((r) => ({
      activityCode: String(r['activity_code']),
      controllerCount: r['controller_count'] == null ? null : Number(r['controller_count']),
      unitMinutes: Number(r['unit_minutes'] ?? 60),
      pricePaise: Number(r['price_paise']),
    }));
}

function toWeek(v: unknown): WeekWindows {
  const out: Record<string, { start: number; end: number } | null> = {};
  for (const [day, w] of Object.entries((v as Record<string, unknown>) ?? {})) {
    const win = w as { start?: number; end?: number } | null;
    out[day] =
      win && win.start != null && win.end != null ? { start: +win.start, end: +win.end } : null;
  }
  return out;
}

class SupabasePricingApi extends PricingApi {
  private readonly supabase = inject(Supabase);

  async load(arenaId: string): Promise<PricingData> {
    const client = await this.supabase.client();
    const [pricing, holidays, policy, rules, discounts, options] = await Promise.all([
      client.rpc('arena_pricing', { p_arena: arenaId }),
      client.from('holidays').select('day, name, closed').eq('arena_id', arenaId).order('day'),
      // The live policy is the oldest active row (as _pricing_snapshot reads it).
      client
        .from('billing_policies')
        .select(POLICY_COLUMNS)
        .eq('arena_id', arenaId)
        .eq('active', true)
        .order('created_at')
        .limit(1)
        .maybeSingle(),
      client
        .from('pricing_rules')
        .select(RULE_COLUMNS)
        .eq('arena_id', arenaId)
        .order('priority')
        .order('name'),
      client
        .from('discounts')
        .select(DISCOUNT_COLUMNS)
        .eq('arena_id', arenaId)
        .order('kind')
        .order('name'),
      client
        .from('settings')
        .select('json')
        .eq('arena_id', arenaId)
        .eq('key', 'discount_options')
        .maybeSingle(),
    ]);
    for (const { error } of [pricing, holidays, policy, rules, discounts, options]) {
      if (error) throw dbError(error);
    }
    const d = pricing.data as {
      types: Record<string, unknown>[];
      rates: Record<string, unknown>[];
      hours: { open?: unknown };
    };
    return {
      types: d.types.map((t) => ({
        id: String(t['id']),
        code: String(t['code']),
        name: String(t['name']),
        usesControllers: t['uses_controllers'] === true,
        usesGames: t['uses_games'] === true,
        durationModel: (t['duration_model'] as DurationModel) ?? 'hourly',
        sortOrder: Number(t['sort_order'] ?? 0),
        active: t['active'] !== false,
        overtimeGraceMinutes: Number(t['overtime_grace_minutes'] ?? 0),
        stations: Number(t['stations'] ?? 0),
      })),
      rates: parseRates(d.rates),
      hours: { open: toWeek(d.hours?.open) },
      holidays: ((holidays.data as Record<string, unknown>[] | null) ?? []).map((h) => ({
        day: String(h['day']),
        name: String(h['name']),
        closed: h['closed'] === true,
      })),
      policy: parsePolicy(policy.data as Record<string, unknown> | null),
      rules: ((rules.data as Record<string, unknown>[] | null) ?? []).map(parseRule),
      discounts: ((discounts.data as Record<string, unknown>[] | null) ?? []).map(parseDiscount),
      discountOptions: parseDiscountOptions((options.data as { json?: unknown } | null)?.json),
    };
  }

  async saveRule(arenaId: string, rule: PricingRule): Promise<void> {
    await pushOps(await this.supabase.client(), arenaId, ruleOps(rule), PRICING_MESSAGES);
  }

  async deleteRule(arenaId: string, id: string): Promise<void> {
    await pushOps(
      await this.supabase.client(),
      arenaId,
      [{ kind: 'rule.delete', payload: { id } }],
      PRICING_MESSAGES,
    );
  }

  async reorderRules(arenaId: string, ids: readonly string[]): Promise<void> {
    await pushOps(
      await this.supabase.client(),
      arenaId,
      [{ kind: 'rule.reorder', payload: { ids } }],
      PRICING_MESSAGES,
    );
  }

  async saveDiscount(arenaId: string, discount: Discount): Promise<void> {
    await pushOps(await this.supabase.client(), arenaId, discountOps(discount), PRICING_MESSAGES);
  }

  async setDiscountActive(arenaId: string, id: string, active: boolean): Promise<void> {
    await pushOps(
      await this.supabase.client(),
      arenaId,
      [{ kind: 'discount.set_active', payload: { id, active } }],
      PRICING_MESSAGES,
    );
  }

  async deleteDiscount(arenaId: string, id: string): Promise<void> {
    await pushOps(
      await this.supabase.client(),
      arenaId,
      [{ kind: 'discount.delete', payload: { id } }],
      PRICING_MESSAGES,
    );
  }

  async saveDiscountOptions(arenaId: string, options: DiscountOptions): Promise<void> {
    await pushOps(
      await this.supabase.client(),
      arenaId,
      [
        {
          kind: 'settings.save',
          payload: {
            key: 'discount_options',
            json: {
              manual_max_percent: options.manualMaxPercent,
              reason_required: options.reasonRequired,
            },
          },
        },
      ],
      PRICING_MESSAGES,
    );
  }

  async discountUsage(
    arenaId: string,
    id: string,
    limit: number,
    cursor: string | null,
  ): Promise<DiscountUsage> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('arena_discount_usage', {
      p_arena: arenaId,
      p_discount: id,
      p_limit: limit,
      p_cursor: cursor,
    });
    if (error) throw dbError(error);
    const d = (data ?? {}) as Record<string, unknown>;
    return {
      uses: Number(d['uses'] ?? 0),
      activeUses: Number(d['active_uses'] ?? 0),
      next: d['next'] == null ? null : String(d['next']),
      rows: ((d['rows'] as Record<string, unknown>[] | null) ?? []).map((u) => ({
        billId: String(u['bill_id']),
        at: String(u['at']),
        customer: u['customer'] == null ? null : String(u['customer']),
        billedPaise: u['billed_paise'] == null ? null : Number(u['billed_paise']),
        amountPaise: Number(u['amount_paise'] ?? 0),
        status: String(u['status'] ?? 'completed'),
        by: u['by'] == null ? null : String(u['by']),
      })),
    };
  }

  async saveHoliday(arenaId: string, holiday: Holiday, replacing?: string): Promise<void> {
    await pushOps(
      await this.supabase.client(),
      arenaId,
      holidayOps(holiday, replacing),
      PRICING_MESSAGES,
    );
  }

  async deleteHoliday(arenaId: string, day: string): Promise<void> {
    await pushOps(
      await this.supabase.client(),
      arenaId,
      [{ kind: 'holiday.delete', payload: { day } }],
      PRICING_MESSAGES,
    );
  }

  async savePolicy(arenaId: string, policy: BillingPolicy): Promise<void> {
    await pushOps(await this.supabase.client(), arenaId, policyOps(policy), PRICING_MESSAGES);
  }

  async saveType(arenaId: string, type: TypeInput): Promise<void> {
    await pushOps(await this.supabase.client(), arenaId, typeOps(type), PRICING_MESSAGES);
  }

  async removeType(arenaId: string, id: string): Promise<'deleted' | 'retired'> {
    const [result] = await pushOps(
      await this.supabase.client(),
      arenaId,
      [{ kind: 'activity.remove', payload: { id } }],
      PRICING_MESSAGES,
    );
    return result?.['removed'] === 'retired' ? 'retired' : 'deleted';
  }

  async saveRates(arenaId: string, changes: readonly RateChange[]): Promise<void> {
    await pushOps(await this.supabase.client(), arenaId, rateOps(changes), PRICING_MESSAGES);
  }

  async saveHours(arenaId: string, hours: BusinessHours): Promise<void> {
    await pushOps(
      await this.supabase.client(),
      arenaId,
      [{ kind: 'settings.save', payload: { key: 'business_hours', json: { open: hours.open } } }],
      PRICING_MESSAGES,
    );
  }
}
