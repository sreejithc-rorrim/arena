import { Service, inject } from '@angular/core';
import { dbError } from '../../../core/arena/arena-api';
import { AppError } from '../../../core/auth/auth-api';
import { Supabase } from '../../../core/supabase/supabase';
import { Attempt, SyncOp, pushOps } from '../../../core/sync/push-ops';
import { SALES_MESSAGES } from './sales-api';
import { PayMethod } from './sale.models';

/** What a missed bill covers: one station, type, game and controller count over a past window. */
export interface MissedPlay {
  readonly stationId: string;
  readonly activityCode: string;
  readonly gameId: string | null;
  readonly controllers: number | null;
  readonly startedAt: Date;
  readonly endedAt: Date;
}

/** A missed bill to add: `customerId` null adds a walk-in customer first. */
export interface MissedBill extends MissedPlay {
  readonly customerId: string | null;
  readonly method: PayMethod;
  /** The price the owner was shown (session_quote); the server refuses any other. */
  readonly billedPaise: number;
  /** What the customer actually paid (0 or more): the bill is recorded at this amount. */
  readonly paidPaise: number;
  readonly reason: string;
  readonly attempt: Attempt;
}

/** Server codes of session_quote / session.record worded for the dialog. */
export const MISSED_BILL_MESSAGES: Readonly<Record<string, string>> = {
  ...SALES_MESSAGES,
  not_found: 'That customer, station or game is not in the records. Refresh',
  invalid_time: 'The end must be after the start, at most 24 hours later',
  time_in_future: 'A missed bill is for play that already happened',
  overlap: 'That station already has play recorded at that time',
  no_rate: 'There is no price for that type and controller count',
  activity_not_offered: 'That station does not offer this type',
  price_mismatch: 'The price changed. Check the new price and save again',
  invalid_total: 'Enter the amount paid in rupees, 0 or more',
  invalid_payload: 'Pick the station, times and payment method',
};

/**
 * Missed bills (bill_edit; owners hold it): the price of a past single session on the current
 * price list (session_quote), and adding it already ended and paid what the customer actually
 * paid (session.record).
 */
@Service()
export class MissedBillApi {
  private readonly supabase = inject(Supabase);

  async quote(arenaId: string, play: MissedPlay): Promise<number> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('session_quote', {
      p_arena: arenaId,
      p_resource: play.stationId,
      p_activity: play.activityCode,
      p_controllers: play.controllers,
      p_from: play.startedAt.toISOString(),
      p_to: play.endedAt.toISOString(),
    });
    if (error) {
      const e = dbError(error);
      throw MISSED_BILL_MESSAGES[e.code] ? new AppError(e.code, MISSED_BILL_MESSAGES[e.code]) : e;
    }
    return Number((data as Record<string, unknown>)['total'] ?? 0);
  }

  async record(arenaId: string, bill: MissedBill): Promise<void> {
    const ops: SyncOp[] = [];
    let customerId = bill.customerId;
    if (!customerId) {
      customerId = bill.attempt.id('customer');
      ops.push({
        kind: 'customer.create',
        opId: bill.attempt.id('customer-op'),
        payload: { id: customerId, name: 'Walk-in', notes: null, is_guest: true },
      });
    }
    ops.push({
      kind: 'session.record',
      opId: bill.attempt.id('session'),
      payload: {
        session_id: bill.attempt.id('session'),
        payment_id: bill.attempt.id('payment'),
        customer_id: customerId,
        resource_id: bill.stationId,
        activity_code: bill.activityCode,
        game_id: bill.gameId,
        controller_count: bill.controllers,
        started_at: bill.startedAt.toISOString(),
        ended_at: bill.endedAt.toISOString(),
        method: bill.method,
        billed_amount_paise: bill.billedPaise,
        paid_amount_paise: bill.paidPaise,
        reason: bill.reason,
      },
    });
    const client = await this.supabase.client();
    await pushOps(client, arenaId, ops, MISSED_BILL_MESSAGES);
  }
}
