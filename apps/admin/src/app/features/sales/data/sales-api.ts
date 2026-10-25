import { Service, inject } from '@angular/core';
import { dbError } from '../../../core/arena/arena-api';
import { AppError } from '../../../core/auth/auth-api';
import { Supabase } from '../../../core/supabase/supabase';
import { Attempt, SyncOp, pushOps } from '../../../core/sync/push-ops';
import { OverviewData, withAverage } from '../../overview/data/overview.models';
import {
  Bill,
  BillDetail,
  BillDiscount,
  BillExtension,
  BillHistoryEntry,
  BillLine,
  BillPayment,
  PayMethod,
  PaymentStatus,
  billRef,
} from './sale.models';

/** A payment taken late, recorded from the dashboard. */
export interface PaymentEntry {
  readonly amountPaise: number;
  readonly method: PayMethod;
  readonly note: string | null;
  /** This action's ids, reused when the same Save is sent again (NG-002). */
  readonly attempt?: Attempt;
}

/** Money given back to the customer (allowed on a voided bill too). */
export interface RefundEntry {
  readonly amountPaise: number;
  readonly method: PayMethod;
  readonly reason: string;
  /** This action's ids, reused when the same Save is sent again (NG-002). */
  readonly attempt?: Attempt;
}

/** Move all or part of one payment to the method it was really taken by. */
export interface MethodCorrection {
  readonly paymentId: string;
  readonly method: PayMethod;
  /** Null moves what is left of that payment. */
  readonly amountPaise: number | null;
  readonly reason: string;
  /** This action's ids, reused when the same Save is sent again (NG-002). */
  readonly attempt?: Attempt;
}

/** Edit bill (bill.adjust): the new total; collected is set to match by `method`. */
export interface BillEdit {
  readonly billedPaise: number;
  readonly method: PayMethod;
  readonly reason: string;
  readonly attempt?: Attempt;
}

/**
 * The arena's closed bills: read through arena_sales() / arena_sale() (owner level); every write
 * (void, late payment, refund, method correction) is an op through sync_push — the same path,
 * permission checks and audit records as the floor app. Nothing is edited in place: each write
 * appends a row (or marks the bill void) and the history keeps who, when and why. Tests provide
 * SampleSalesApi.
 */
@Service({ factory: () => new SupabaseSalesApi() })
export abstract class SalesApi {
  /** Bills that closed in [from, to), newest first. */
  abstract list(arenaId: string, from: Date, to: Date): Promise<Bill[]>;
  abstract get(arenaId: string, id: string): Promise<BillDetail>;
  /** The Overview's figures for a period and the one before it (arena_overview). */
  abstract overview(arenaId: string, q: OverviewQuery): Promise<OverviewData>;
  abstract void(arenaId: string, bill: Bill, reason: string): Promise<void>;
  abstract recordPayment(arenaId: string, bill: Bill, entry: PaymentEntry): Promise<void>;
  abstract refund(arenaId: string, bill: Bill, entry: RefundEntry): Promise<void>;
  abstract correct(arenaId: string, bill: Bill, correction: MethodCorrection): Promise<void>;
  abstract edit(arenaId: string, bill: Bill, change: BillEdit): Promise<void>;
}

/** What the Overview asks arena_overview for. */
export interface OverviewQuery {
  readonly from: Date;
  readonly to: Date;
  readonly prevFrom: Date;
  readonly prevTo: Date;
  readonly bucket: 'hour' | 'day' | 'month';
  /** Start of today (IST): the latest bills are those closed since. */
  readonly today: Date;
}

/** Server codes (sync_push / arena_sales) worded for the Sales screen. */
export const SALES_MESSAGES: Readonly<Record<string, string>> = {
  not_found: 'That bill is not in the records. Refresh',
  invalid_range: 'Pick a shorter date range',
  forbidden: 'Your access does not allow that',
  void_reason_required: 'Give a reason for the void',
  refund_reason_required: 'Give a reason for the refund',
  reason_required: 'Give a reason',
  reason_too_long: 'Keep the reason under 500 characters',
  refund_exceeds_paid: 'That is more than was collected on this bill',
  overpayment: 'That is more than is due on this bill',
  voided: 'This bill is void: it takes refunds, not payments',
  same_method: 'That payment is already recorded that way',
  already_corrected: 'All of that payment was already moved',
  amount_invalid: 'That is more than is left of that payment',
  not_a_payment: 'A refund cannot be moved to another method',
  invalid_method: 'Pick a payment method',
  amount_zero: 'Enter an amount',
  duplicate: 'That was already recorded. Refresh',
  invalid_total: 'Enter the bill amount in rupees',
  not_ended: 'This bill is still running. End it first',
  waived: 'This bill was waived: it owes nothing',
  same_total: 'Nothing to change: the bill is already that amount and paid',
  stale: 'This bill changed since you opened it. Close it and open it again',
};

type Row = Record<string, unknown>;

const text = (v: unknown) => (v == null ? null : String(v));

export function toPayment(p: Row): BillPayment {
  return {
    id: String(p['id']),
    at: String(p['at']),
    amountPaise: Number(p['amount_paise']),
    method: p['method'] as PayMethod,
    refund: p['refund'] === true,
    correction: p['correction'] === true,
    reason: text(p['reason']),
    note: text(p['note']),
    by: text(p['by']),
  };
}

/** Time order; the two rows of one correction share a time, so its refund comes first. */
function ledgerOrder(a: BillPayment, b: BillPayment): number {
  return Date.parse(a.at) - Date.parse(b.at) || Number(b.refund) - Number(a.refund);
}

export function toBill(r: Row): Bill {
  const id = String(r['id']);
  const strings = (v: unknown) => ((v as string[] | null) ?? []).map(String);
  return {
    id,
    ref: billRef(id),
    at: String(r['at']),
    startedAt: String(r['started_at']),
    endedAt: text(r['ended_at']),
    recordedAt: text(r['recorded_at']),
    endRecordedAt: text(r['end_recorded_at']),
    voided: r['status'] === 'voided',
    paymentStatus: (r['payment_status'] as PaymentStatus) ?? 'unpaid',
    customer: String(r['customer'] ?? 'Guest'),
    guest: r['guest'] === true,
    returning: r['returning'] === true,
    stations: strings(r['stations']),
    activities: strings(r['activities']),
    games: strings(r['games']),
    players: Number(r['players'] ?? 1),
    playerMinutes: Number(r['player_minutes'] ?? 0),
    billedPaise: r['billed_paise'] == null ? null : Number(r['billed_paise']),
    paidPaise: Number(r['paid_paise'] ?? 0),
    refundedPaise: Number(r['refunded_paise'] ?? 0),
    methods: Object.fromEntries(
      Object.entries((r['methods'] as Record<string, number> | null) ?? {}).map(([m, v]) => [
        m,
        Number(v),
      ]),
    ) as Partial<Record<PayMethod, number>>,
    payments: ((r['payments'] as Row[] | null) ?? []).map(toPayment).sort(ledgerOrder),
    startedBy: text(r['started_by']),
    voidReason: text(r['void_reason']),
    voidedAt: text(r['voided_at']),
    voidedBy: text(r['voided_by']),
    discountPaise: Number(r['discount_paise'] ?? 0),
    discount: toDiscount(r['discount'] as Row | null),
  };
}

function toDiscount(d: Row | null): BillDiscount | null {
  if (!d) return null;
  return {
    source: (d['source'] as BillDiscount['source']) ?? 'preset',
    name: String(d['name'] ?? ''),
    code: text(d['code']),
    discountId: text(d['discount_id']),
    valueKind: d['value_kind'] === 'flat' ? 'flat' : 'percent',
    value: Number(d['value'] ?? 0),
    amountPaise: Number(d['amount_paise'] ?? 0),
    reason: text(d['reason']),
    by: text(d['by']),
  };
}

export function toDetail(r: Row): BillDetail {
  const voided = r['voided'] as Row | null;
  const rule = r['rule'] as Row | null;
  const json = (v: unknown) =>
    v && typeof v === 'object' ? (v as Readonly<Record<string, unknown>>) : null;
  return {
    ...toBill(r),
    lines: ((r['lines'] as Row[] | null) ?? []).map((l): BillLine => ({
      station: String(l['station'] ?? ''),
      activity: String(l['activity'] ?? ''),
      controllers: l['controllers'] == null ? null : Number(l['controllers']),
      start: text(l['start']),
      end: text(l['end']),
      playedMinutes: Number(l['played_minutes'] ?? 0),
      billedMinutes: Number(l['billed_minutes'] ?? 0),
      amountPaise: Number(l['amount_paise'] ?? 0),
    })),
    extensions: ((r['extensions'] as Row[] | null) ?? []).map((e): BillExtension => ({
      at: String(e['at']),
      addedMinutes: Number(e['added_minutes'] ?? 0),
      addedPaise: Number(e['added_amount_paise'] ?? 0),
      reason: text(e['reason']),
      by: text(e['by']),
    })),
    history: ((r['history'] as Row[] | null) ?? []).map((h): BillHistoryEntry => ({
      at: String(h['at']),
      action: String(h['action']),
      by: text(h['by']),
      reason: text(h['reason']),
      before: json(h['before']),
      after: json(h['after']),
    })),
    voidRecord: voided ? { at: String(voided['at']), by: text(voided['by']) } : null,
    rule: rule
      ? {
          name: String(rule['name'] ?? ''),
          adjustKind: rule['adjust_kind'] === 'per_hour' ? 'per_hour' : 'percent',
          adjustValue: Number(rule['adjust_value'] ?? 0),
        }
      : null,
  };
}

function scopeOf(bill: Bill) {
  return { scope: 'single', parent_id: bill.id };
}

class SupabaseSalesApi extends SalesApi {
  private readonly supabase = inject(Supabase);

  async list(arenaId: string, from: Date, to: Date): Promise<Bill[]> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('arena_sales', {
      p_arena: arenaId,
      p_from: from.toISOString(),
      p_to: to.toISOString(),
    });
    if (error) throw salesError(error);
    return (data as Row[]).map(toBill);
  }

  async overview(arenaId: string, q: OverviewQuery): Promise<OverviewData> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('arena_overview', {
      p_arena: arenaId,
      p_from: q.from.toISOString(),
      p_to: q.to.toISOString(),
      p_prev_from: q.prevFrom.toISOString(),
      p_prev_to: q.prevTo.toISOString(),
      p_bucket: q.bucket,
      p_today: q.today.toISOString(),
    });
    if (error) throw salesError(error);
    const d = (data ?? {}) as Record<string, Row & Row[]>;
    const totals = (t: Row | undefined) =>
      withAverage({
        takingsPaise: Number(t?.['takings_paise'] ?? 0),
        bills: Number(t?.['bills'] ?? 0),
        minutes: Number(t?.['minutes'] ?? 0),
      });
    return {
      totals: {
        ...totals(d['totals']),
        discountPaise: Number(d['totals']?.['discount_paise'] ?? 0),
        discounts: Number(d['totals']?.['discounts'] ?? 0),
      },
      previous: totals(d['previous']),
      buckets: ((d['buckets'] as Row[] | undefined) ?? []).map((b) => ({
        start: String(b['start']),
        paise: Number(b['paise'] ?? 0),
      })),
      methods: Object.fromEntries(
        Object.entries((d['methods'] as Row | undefined) ?? {}).map(([m, v]) => [
          m,
          { paise: Number((v as Row)['paise'] ?? 0), bills: Number((v as Row)['bills'] ?? 0) },
        ]),
      ),
      byType: new Map(
        Object.entries((d['by_type'] as Row | undefined) ?? {}).map(([k, v]) => [k, Number(v)]),
      ),
      topGames: ((d['top_games'] as Row[] | undefined) ?? []).map((g) => ({
        name: String(g['name']),
        minutes: Number(g['minutes'] ?? 0),
      })),
      byStaff: ((d['by_staff'] as Row[] | undefined) ?? []).map((u) => ({
        name: String(u['name']),
        bills: Number(u['bills'] ?? 0),
        paise: Number(u['paise'] ?? 0),
      })),
      latest: ((d['latest'] as Row[] | undefined) ?? []).map(toBill),
    };
  }

  async get(arenaId: string, id: string): Promise<BillDetail> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('arena_sale', { p_arena: arenaId, p_id: id });
    if (error) throw salesError(error);
    return toDetail(data as Row);
  }

  void(arenaId: string, bill: Bill, reason: string): Promise<void> {
    return this.push(arenaId, {
      kind: 'session.void',
      payload: { session_id: bill.id, reason },
    });
  }

  recordPayment(arenaId: string, bill: Bill, entry: PaymentEntry): Promise<void> {
    return this.push(arenaId, {
      kind: 'payment.record',
      opId: entry.attempt?.id('op'),
      payload: {
        ...scopeOf(bill),
        payment_id: entry.attempt?.id('payment') ?? crypto.randomUUID(),
        amount_paise: entry.amountPaise,
        method: entry.method,
        note: entry.note,
      },
    });
  }

  refund(arenaId: string, bill: Bill, entry: RefundEntry): Promise<void> {
    return this.push(arenaId, {
      kind: 'payment.record',
      opId: entry.attempt?.id('op'),
      payload: {
        ...scopeOf(bill),
        payment_id: entry.attempt?.id('payment') ?? crypto.randomUUID(),
        amount_paise: entry.amountPaise,
        method: entry.method,
        is_refund: true,
        reason: entry.reason,
      },
    });
  }

  correct(arenaId: string, bill: Bill, correction: MethodCorrection): Promise<void> {
    return this.push(arenaId, {
      kind: 'payment.correct',
      opId: correction.attempt?.id('op'),
      payload: {
        ...scopeOf(bill),
        payment_id: correction.paymentId,
        method: correction.method,
        ...(correction.amountPaise == null ? {} : { amount_paise: correction.amountPaise }),
        reason: correction.reason,
        refund_id: correction.attempt?.id('refund') ?? crypto.randomUUID(),
        new_payment_id: correction.attempt?.id('payment') ?? crypto.randomUUID(),
      },
    });
  }

  edit(arenaId: string, bill: Bill, change: BillEdit): Promise<void> {
    return this.push(arenaId, {
      kind: 'bill.adjust',
      opId: change.attempt?.id('op'),
      payload: {
        ...scopeOf(bill),
        billed_amount_paise: change.billedPaise,
        method: change.method,
        reason: change.reason,
        payment_id: change.attempt?.id('payment') ?? crypto.randomUUID(),
        // What the owner saw: the server refuses the edit as stale if either moved.
        expected_billed_paise: bill.billedPaise,
        expected_paid_paise: bill.paidPaise,
      },
    });
  }

  /** Through pushOps: the other devices hear of the change only once it is recorded. */
  private async push(arenaId: string, op: SyncOp): Promise<void> {
    const client = await this.supabase.client();
    try {
      await pushOps(client, arenaId, [op], SALES_MESSAGES);
    } catch (e) {
      throw e instanceof AppError && SALES_MESSAGES[e.code]
        ? new AppError(e.code, SALES_MESSAGES[e.code])
        : e;
    }
  }
}

function salesError(e: Parameters<typeof dbError>[0]): AppError {
  const error = dbError(e);
  return SALES_MESSAGES[error.code] ? new AppError(error.code, SALES_MESSAGES[error.code]) : error;
}
