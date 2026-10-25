import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';
import { ArenaApi, accessOf } from '../app/core/arena/arena-api';
import { AuthApi } from '../app/core/auth/auth-api';
import { FloorApi } from '../app/core/floor/floor-api';
import { Supabase } from '../app/core/supabase/supabase';
import { billsCsv, paymentsCsv } from '../app/features/sales/components/sales-csv';
import {
  PAY_METHODS,
  PayMethod,
  methodName,
  summarize,
} from '../app/features/sales/data/sale.models';
import { SalesApi } from '../app/features/sales/data/sales-api';
import { formatIsoDate } from '../app/shared/time/ist';
import { IT_RUN, handoff, need } from './it-env';

/**
 * Dashboard phase 2 (tool/sync_it.sh step 5): the session the staff device ran with the
 * dashboard's game (floor.json, written by test/sync/cross_app_test.dart) is on the owner's Sales
 * list with the bill the server priced and exactly one payment; the owner of another arena sees
 * none of it.
 */
describe.skipIf(!IT_RUN)('integration · dashboard phase 2 (owner sees the floor)', () => {
  it('shows the staff’s bill with one payment, and nothing to another arena', async () => {
    const arenaId = need('AO_IT_ARENA');
    const password = need('AO_IT_PASSWORD');
    const floorRun = handoff.read<{ session_id: string; billed_paise: number; paid_paise: number }>(
      'floor.json',
    );
    const auth = TestBed.inject(AuthApi);
    const sales = TestBed.inject(SalesApi);
    // The floor phase plays its session yesterday 13:00–13:30 IST (inside opening hours).
    const from = new Date(Date.now() - 48 * 3_600_000);
    const to = new Date(Date.now() + 3_600_000);

    await auth.signIn(need('AO_IT_OWNER_EMAIL'), password);
    const bills = await sales.list(arenaId, from, to);
    const bill = bills.find((b) => b.id === floorRun.session_id);
    if (!bill) {
      throw new Error(
        `session ${floorRun.session_id} not on the Sales list (${bills.length} bills in range; ` +
          `newest: ${bills
            .slice(0, 3)
            .map((b) => `${b.id} ${b.at}`)
            .join(', ')})`,
      );
    }
    expect(bill).toMatchObject({
      billedPaise: floorRun.billed_paise,
      paidPaise: floorRun.paid_paise,
      voided: false,
    });
    const detail = await sales.get(arenaId, floorRun.session_id);
    expect(detail.payments).toHaveLength(1);
    expect(detail.payments[0]).toMatchObject({ amountPaise: floorRun.paid_paise, refund: false });

    // Reconciliation against the database itself (read through RLS as the owner): the bill on the
    // Sales list is the session row's billed total and the net of its payments ledger, per method.
    const db = await TestBed.inject(Supabase).client();
    const { data: row } = await db
      .from('sessions')
      .select('billed_amount_paise, status, actual_ended_at')
      .eq('id', floorRun.session_id)
      .single();
    expect(row).toMatchObject({ billed_amount_paise: bill.billedPaise, status: 'completed' });
    expect(row?.actual_ended_at && Date.parse(row.actual_ended_at)).toBe(Date.parse(bill.at));
    const { data: ledger } = await db
      .from('payments')
      .select('amount_paise, method')
      .eq('session_id', floorRun.session_id);
    const net = (ledger ?? []).reduce((sum, p) => sum + Number(p.amount_paise), 0);
    expect(net).toBe(bill.paidPaise);
    const byMethod: Record<string, number> = {};
    for (const p of ledger ?? [])
      byMethod[p.method] = (byMethod[p.method] ?? 0) + Number(p.amount_paise);
    expect(bill.methods).toEqual(byMethod);
    // The day's summary on the dashboard is the sum of the same bills.
    const summary = summarize(bills);
    expect(summary.takingsPaise).toBe(
      bills.filter((b) => !b.voided).reduce((sum, b) => sum + b.paidPaise, 0),
    );

    // The game the floor played now has history: deleting it is refused, archiving keeps it.
    const floor = TestBed.inject(FloorApi);
    const { game_id: gameId } = handoff.read<{ game_id: string }>('dashboard.json');
    const usage = await floor.gameUsage(arenaId, gameId);
    expect(usage.records).toBeGreaterThan(0);
    await expect(floor.deleteGame(arenaId, gameId)).rejects.toMatchObject({
      code: 'game_has_history',
    });
    await floor.setGameActive(arenaId, gameId, false);
    expect((await floor.games(arenaId)).find((g) => g.id === gameId)?.active).toBe(false);
    expect((await sales.get(arenaId, floorRun.session_id)).payments).toHaveLength(1);
    await auth.signOut();

    // Another arena's owner: the owner-only RPC refuses, direct reads return nothing (RLS), and
    // the game cannot be touched.
    await auth.signIn(need('AO_IT_OUTSIDER_EMAIL'), password);
    await expect(sales.list(arenaId, from, to)).rejects.toMatchObject({ code: 'forbidden' });
    expect(await floor.plays(arenaId, from)).toEqual([]);
    await expect(
      floor.members(arenaId, { since: from, since30: from, search: '', limit: 10, offset: 0 }),
    ).rejects.toMatchObject({ code: 'forbidden' });
    await expect(floor.deleteGame(arenaId, gameId)).rejects.toMatchObject({ code: 'forbidden' });
    await auth.signOut();

    // The floor staff who ran the bill: a member of this arena, but not owner level — the owner's
    // sales report is refused on the server, whatever the dashboard shows.
    await auth.signIn(need('AO_IT_STAFF_EMAIL'), password);
    await expect(sales.list(arenaId, from, to)).rejects.toMatchObject({ code: 'forbidden' });
    await expect(sales.get(arenaId, floorRun.session_id)).rejects.toMatchObject({
      code: 'forbidden',
    });
    expect(accessOf(await TestBed.inject(ArenaApi).myArenas())).toBe('staff');
    await auth.signOut();
  }, 120_000);

  it('owner corrections append to the ledger, and both exports reconcile with the database', async () => {
    const arenaId = need('AO_IT_ARENA');
    const password = need('AO_IT_PASSWORD');
    const floorRun = handoff.read<{ session_id: string; billed_paise: number; paid_paise: number }>(
      'floor.json',
    );
    const auth = TestBed.inject(AuthApi);
    const sales = TestBed.inject(SalesApi);
    const from = new Date(Date.now() - 48 * 3_600_000);
    const to = new Date(Date.now() + 3_600_000);
    await auth.signIn(need('AO_IT_OWNER_EMAIL'), password);
    try {
      const before = (await sales.list(arenaId, from, to)).find(
        (b) => b.id === floorRun.session_id,
      );
      if (!before) throw new Error(`session ${floorRun.session_id} not on the Sales list`);
      // A void without a reason is refused by the server and changes nothing.
      await expect(sales.void(arenaId, before, '  ')).rejects.toMatchObject({
        code: 'void_reason_required',
      });
      // The staff keyed the payment under the wrong method: the owner moves it, with a reason.
      const original = before.payments.find((p) => !p.refund);
      if (!original) throw new Error('the floor bill has no payment');
      const right: PayMethod = original.method === 'upi' ? 'cash' : 'upi';
      await sales.correct(arenaId, before, {
        paymentId: original.id,
        method: right,
        amountPaise: null,
        reason: 'IT: keyed under the wrong method',
      });
      await expect(
        sales.correct(arenaId, before, {
          paymentId: original.id,
          method: 'card',
          amountPaise: null,
          reason: 'again',
        }),
      ).rejects.toMatchObject({ code: 'already_corrected' });
      await sales.refund(arenaId, before, {
        amountPaise: 100,
        method: right,
        reason: 'IT: ₹1 back',
      });

      const bills = await sales.list(arenaId, from, to);
      const bill = bills.find((b) => b.id === floorRun.session_id)!;
      expect(bill.paidPaise).toBe(floorRun.paid_paise - 100);
      expect(bill.refundedPaise).toBe(100);
      expect(bill.methods[original.method] ?? 0).toBe(0);
      expect(bill.methods[right]).toBe(floorRun.paid_paise - 100);
      expect(bill.payments.filter((p) => p.correction)).toHaveLength(2);
      const detail = await sales.get(arenaId, bill.id);
      expect(detail.history).toEqual([
        expect.objectContaining({
          action: 'payment_correct',
          reason: 'IT: keyed under the wrong method',
        }),
      ]);
      expect(detail.history[0].by).toBeTruthy();

      // The database itself, read through RLS as the owner: every payment row of these bills.
      const db = await TestBed.inject(Supabase).client();
      const ids = bills.length ? bills.map((b) => b.id) : ['00000000-0000-0000-0000-000000000000'];
      const singles = await db
        .from('payments')
        .select('amount_paise, method')
        .in('session_id', ids);
      expect(singles.error).toBeNull();
      const rows = singles.data ?? [];
      const dbNet = rows.reduce((n, r) => n + Number(r.amount_paise), 0);
      const paise = (cell: string | undefined) => Math.round(Number(cell ?? 0) * 100);
      const meta = {
        arena: 'IT arena',
        period: { range: 'custom' as const, first: formatIsoDate(from), last: formatIsoDate(to) },
        generatedAt: new Date(),
        generatedBy: null,
        filters: null,
      };

      // Bills report: collected on the bills that count + on voided bills = the ledger's net.
      const report = billsCsv(bills, meta).trim().split('\n');
      const counted = report.find((l) => l.startsWith('Total —'))?.split(',');
      const voided = report.find((l) => l.startsWith('On '))?.split(',');
      expect(paise(counted?.[22]) + paise(voided?.[22])).toBe(dbNet);
      // Payments ledger: one line per row in the database, and the same net per method.
      const ledger = paymentsCsv(bills, meta).trim().split('\n');
      const head = ledger.findIndex((l) => l.startsWith('Received date,'));
      expect(ledger.slice(head + 1).filter((l) => !l.startsWith('Net '))).toHaveLength(rows.length);
      expect(paise(ledger.find((l) => l.startsWith('Net total,'))?.split(',')[9])).toBe(dbNet);
      for (const m of PAY_METHODS) {
        const inDb = rows
          .filter((r) => r.method === m)
          .reduce((n, r) => n + Number(r.amount_paise), 0);
        const line = ledger.find((l) => l.startsWith(`Net ${methodName(m)},`));
        expect(paise(line?.split(',')[9])).toBe(inDb);
      }
    } finally {
      await auth.signOut();
    }
  }, 120_000);
});
