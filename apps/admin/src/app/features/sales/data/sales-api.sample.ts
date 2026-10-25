import { AppError } from '../../../core/auth/auth-api';
import { istDayStart } from '../../../shared/time/ist';
import { OverviewData, withAverage } from '../../overview/data/overview.models';
import {
  BillEdit,
  MethodCorrection,
  OverviewQuery,
  PaymentEntry,
  RefundEntry,
  SALES_MESSAGES,
  SalesApi,
} from './sales-api';
import {
  Bill,
  BillDetail,
  BillDiscount,
  BillPayment,
  PayMethod,
  PaymentStatus,
  billRef,
} from './sale.models';

interface Spec {
  readonly id: string;
  /** IST day (0 = today) and hh:mm the bill closed. */
  readonly day: number;
  readonly close: string;
  readonly minutes: number;
  readonly customer: string;
  readonly returning?: boolean;
  readonly station: string;
  readonly game?: string;
  readonly players?: number;
  readonly billed: number;
  readonly payments: readonly (readonly [PayMethod, number])[];
  readonly status?: PaymentStatus;
  readonly voidReason?: string;
  readonly discount?: BillDiscount;
}

/** Sample bills in rupees, closing at fixed IST times relative to `now` (today first). */
const SPECS: readonly Spec[] = [
  {
    id: '3f9a2c10-0000-4000-8000-000000000001',
    day: 0,
    close: '18:40',
    minutes: 60,
    customer: 'Kiran Rao',
    returning: true,
    station: 'HEX',
    game: 'EA SPORTS FC 25',
    players: 2,
    billed: 240,
    payments: [['upi', 240]],
  },
  {
    id: '71b0e4aa-0000-4000-8000-000000000002',
    day: 0,
    close: '17:15',
    minutes: 90,
    customer: 'Aditya Shah',
    returning: true,
    station: 'VOID',
    game: 'Tekken 8',
    players: 4,
    billed: 720,
    payments: [
      ['upi', 500],
      ['cash', 220],
    ],
  },
  {
    id: 'c41d7e22-0000-4000-8000-000000000003',
    day: 0,
    close: '15:05',
    minutes: 30,
    customer: 'Guest',
    station: 'GHOST',
    billed: 60,
    payments: [['cash', 60]],
  },
  {
    id: '0e55b981-0000-4000-8000-000000000004',
    day: 0,
    close: '13:30',
    minutes: 120,
    customer: 'Meera Pillai',
    station: 'RIFT',
    game: 'Gran Turismo 7',
    billed: 360,
    payments: [['upi', 200]],
    status: 'partial',
  },
  {
    id: 'a8c3f017-0000-4000-8000-000000000005',
    day: 1,
    close: '21:10',
    minutes: 60,
    customer: 'Kiran Rao',
    returning: true,
    station: 'HEX',
    game: 'Mortal Kombat 1',
    billed: 120,
    payments: [['cash', 120]],
    voidReason: 'Duplicate bill',
  },
  {
    id: '5d2e9b44-0000-4000-8000-000000000006',
    day: 1,
    close: '19:00',
    minutes: 60,
    customer: 'Rahul Verma',
    station: 'VOID',
    game: 'EA SPORTS FC 25',
    billed: 120,
    payments: [['upi', 120]],
  },
  {
    id: 'e7f61c03-0000-4000-8000-000000000007',
    day: 4,
    close: '16:20',
    minutes: 60,
    customer: 'Sana Khan',
    station: 'VR Bay',
    billed: 300,
    payments: [],
    status: 'waived',
  },
  {
    id: '9b8a7c6d-0000-4000-8000-000000000008',
    day: 12,
    close: '20:45',
    minutes: 90,
    customer: 'Aditya Shah',
    station: 'Pool Table 1',
    billed: 270,
    payments: [['card', 270]],
  },
  {
    id: '44d1a9e0-0000-4000-8000-000000000009',
    day: 45,
    close: '18:00',
    minutes: 60,
    customer: 'Nikhil Menon',
    station: 'HEX',
    game: 'EA SPORTS FC 25',
    billed: 150,
    payments: [['cash', 150]],
  },
];

/** Methods, collected and refunded from a ledger. */
function totals(payments: readonly BillPayment[]) {
  const methods: Partial<Record<PayMethod, number>> = {};
  let paid = 0;
  let refunded = 0;
  for (const p of payments) {
    methods[p.method] = (methods[p.method] ?? 0) + p.amountPaise;
    paid += p.amountPaise;
    if (p.amountPaise < 0 && !p.correction) refunded -= p.amountPaise;
  }
  return { methods, paidPaise: paid, refundedPaise: refunded };
}

function build(spec: Spec, now: Date, n: number): BillDetail {
  const [h, m] = spec.close.split(':').map(Number);
  const at = new Date(istDayStart(now, spec.day).getTime() + (h * 60 + m) * 60_000);
  const startedAt = new Date(at.getTime() - spec.minutes * 60_000);
  const payments: BillPayment[] = spec.payments.map(([method, rupees], i) => ({
    id: `${spec.id}-p${i}`,
    at: at.toISOString(),
    amountPaise: rupees * 100,
    method,
    refund: false,
    correction: false,
    reason: null,
    note: null,
    by: n % 2 ? 'Rohan Das' : 'Priya Nair',
  }));
  const players = spec.players ?? 1;
  const bill: Bill = {
    id: spec.id,
    ref: billRef(spec.id),
    at: at.toISOString(),
    startedAt: startedAt.toISOString(),
    endedAt: at.toISOString(),
    recordedAt: startedAt.toISOString(),
    endRecordedAt: at.toISOString(),
    voided: !!spec.voidReason,
    paymentStatus: spec.status ?? 'paid',
    customer: spec.customer,
    guest: spec.customer === 'Guest',
    returning: spec.returning ?? false,
    stations: [spec.station],
    activities: [spec.station.startsWith('Pool') ? 'Pool' : 'PlayStation 5'],
    games: spec.game ? [spec.game] : [],
    players,
    playerMinutes: spec.minutes * players,
    billedPaise: spec.billed * 100,
    ...totals(payments),
    payments,
    startedBy: 'Priya Nair',
    voidReason: spec.voidReason ?? null,
    voidedAt: spec.voidReason ? at.toISOString() : null,
    voidedBy: spec.voidReason ? 'Arjun Mehra' : null,
    discountPaise: spec.discount?.amountPaise ?? 0,
    discount: spec.discount ?? null,
  };
  return {
    ...bill,
    lines: [
      {
        station: spec.station,
        activity: bill.activities[0],
        controllers: players,
        start: startedAt.toISOString(),
        end: at.toISOString(),
        playedMinutes: spec.minutes,
        billedMinutes: spec.minutes,
        amountPaise: spec.billed * 100,
      },
    ],
    extensions: [],
    history: spec.voidReason
      ? [
          {
            at: at.toISOString(),
            action: 'void',
            by: 'Arjun Mehra',
            reason: spec.voidReason,
            before: null,
            after: null,
          },
        ]
      : [],
    voidRecord: spec.voidReason ? { at: at.toISOString(), by: 'Arjun Mehra' } : null,
    rule: null,
  };
}

/**
 * Deterministic bills for tests and offline previews. Voids, late payments, refunds and method
 * corrections change them in memory, with the server's limits (`refund_exceeds_paid`,
 * `overpayment`, `voided`, `already_corrected` …) so screens show the same refusals.
 */
export class SampleSalesApi extends SalesApi {
  readonly bills: BillDetail[];
  /** Set to make the next call fail with this code. */
  failNext: string | null = null;
  /** The signed-in name recorded on changes. */
  by = 'Arjun Mehra';

  constructor(private readonly now: Date) {
    super();
    this.bills = SPECS.map((spec, i) => build(spec, now, i));
  }

  async list(_arenaId: string, from: Date, to: Date): Promise<Bill[]> {
    this.fail();
    const days = (to.getTime() - from.getTime()) / 86_400_000;
    if (!(days > 0) || days > 93) throw this.error('invalid_range');
    return this.bills
      .filter((b) => Date.parse(b.at) >= from.getTime() && Date.parse(b.at) < to.getTime())
      .sort((a, b) => Date.parse(b.at) - Date.parse(a.at));
  }

  /** Reads of the Overview's figures (laziness checks). */
  overviewReads = 0;

  /** Like arena_overview, over the sample bills (IST buckets, voided bills left out). */
  async overview(_arenaId: string, q: OverviewQuery): Promise<OverviewData> {
    this.fail();
    this.overviewReads++;
    const within = (from: Date, to: Date) =>
      this.bills.filter(
        (b) => Date.parse(b.at) >= from.getTime() && Date.parse(b.at) < to.getTime(),
      );
    const cur = within(q.from, q.to);
    const live = cur.filter((b) => !b.voided);
    const minutes = (b: Bill) =>
      Math.max(0, Math.round((Date.parse(b.endedAt ?? b.at) - Date.parse(b.startedAt)) / 60_000));
    const totals = (bills: readonly Bill[]) =>
      withAverage({
        takingsPaise: bills.reduce((n, b) => n + b.paidPaise, 0),
        bills: bills.length,
        minutes: bills.reduce((n, b) => n + minutes(b), 0),
      });
    const ist = (at: string) => new Date(Date.parse(at) + 330 * 60_000);
    const bucketStart = (at: string) => {
      const d = ist(at);
      const y = d.getUTCFullYear();
      const m = d.getUTCMonth();
      const start =
        q.bucket === 'month'
          ? Date.UTC(y, m, 1)
          : q.bucket === 'day'
            ? Date.UTC(y, m, d.getUTCDate())
            : Date.UTC(y, m, d.getUTCDate(), d.getUTCHours());
      return new Date(start - 330 * 60_000).toISOString();
    };
    const buckets = new Map<string, number>();
    for (const b of live)
      buckets.set(bucketStart(b.at), (buckets.get(bucketStart(b.at)) ?? 0) + b.paidPaise);
    const methods: Partial<Record<PayMethod, { paise: number; bills: number }>> = {};
    for (const b of live) {
      for (const [m, v] of Object.entries(b.methods) as [PayMethod, number][]) {
        const row = methods[m] ?? { paise: 0, bills: 0 };
        methods[m] = { paise: row.paise + v, bills: row.bills + (v > 0 ? 1 : 0) };
      }
    }
    const games = new Map<string, number>();
    for (const b of live) {
      for (const g of b.games) games.set(g, (games.get(g) ?? 0) + minutes(b) / b.games.length);
    }
    const staff = new Map<string, { bills: number; paise: number }>();
    for (const b of live) {
      if (!b.startedBy) continue;
      const s = staff.get(b.startedBy) ?? { bills: 0, paise: 0 };
      staff.set(b.startedBy, { bills: s.bills + 1, paise: s.paise + b.paidPaise });
    }
    const byType = new Map<string, number>();
    for (const b of live) {
      const code = b.activities[0] === 'Pool' ? 'POOL' : 'PS5';
      byType.set(code, (byType.get(code) ?? 0) + (b.billedPaise ?? 0));
    }
    return {
      totals: {
        ...totals(live),
        discountPaise: live.reduce((n, b) => n + b.discountPaise, 0),
        discounts: live.filter((b) => b.discountPaise > 0).length,
      },
      previous: totals(within(q.prevFrom, q.prevTo).filter((b) => !b.voided)),
      buckets: [...buckets]
        .sort((a, b) => a[0].localeCompare(b[0]))
        .map(([start, paise]) => ({ start, paise })),
      methods,
      byType,
      topGames: [...games]
        .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
        .slice(0, 5)
        .map(([name, m]) => ({ name, minutes: Math.round(m) })),
      byStaff: [...staff]
        .map(([name, s]) => ({ name, ...s }))
        .sort((a, b) => b.paise - a.paise || a.name.localeCompare(b.name)),
      latest: cur
        .filter((b) => Date.parse(b.at) >= q.today.getTime())
        .sort((a, b) => Date.parse(b.at) - Date.parse(a.at))
        .slice(0, 8),
    };
  }

  async get(_arenaId: string, id: string): Promise<BillDetail> {
    this.fail();
    return this.find(id);
  }

  async void(_arenaId: string, bill: Bill, reason: string): Promise<void> {
    this.fail();
    if (!reason.trim()) throw this.error('void_reason_required');
    const b = this.find(bill.id);
    if (b.voided) return;
    const at = this.now.toISOString();
    this.put({
      ...b,
      voided: true,
      voidReason: reason.trim(),
      voidedAt: at,
      voidedBy: this.by,
      voidRecord: { at, by: this.by },
      history: [
        ...b.history,
        { at, action: 'void', by: this.by, reason: reason.trim(), before: null, after: null },
      ],
    });
  }

  async recordPayment(_arenaId: string, bill: Bill, entry: PaymentEntry): Promise<void> {
    this.fail();
    const b = this.find(bill.id);
    if (b.voided) throw this.error('voided');
    if (b.paymentStatus !== 'waived' && b.paidPaise + entry.amountPaise > (b.billedPaise ?? 0)) {
      throw this.error('overpayment');
    }
    this.addPayments(b, [
      this.entry(entry.method, entry.amountPaise, false, false, null, entry.note),
    ]);
  }

  async refund(_arenaId: string, bill: Bill, entry: RefundEntry): Promise<void> {
    this.fail();
    const b = this.find(bill.id);
    if (!entry.reason.trim()) throw this.error('refund_reason_required');
    if (entry.amountPaise > b.paidPaise) throw this.error('refund_exceeds_paid');
    this.addPayments(b, [
      this.entry(entry.method, -entry.amountPaise, true, false, entry.reason.trim(), null),
    ]);
  }

  async correct(_arenaId: string, bill: Bill, c: MethodCorrection): Promise<void> {
    this.fail();
    const b = this.find(bill.id);
    if (!c.reason.trim()) throw this.error('reason_required');
    const original = b.payments.find((p) => p.id === c.paymentId);
    if (!original) throw this.error('not_found');
    if (original.refund) throw this.error('not_a_payment');
    if (original.method === c.method) throw this.error('same_method');
    const moved = b.history
      .filter((h) => h.action === 'payment_correct' && h.before?.['payment_id'] === original.id)
      .reduce((n, h) => n + Number(h.after?.['amount_paise'] ?? 0), 0);
    const left = original.amountPaise - moved;
    if (left <= 0) throw this.error('already_corrected');
    const amount = c.amountPaise ?? left;
    if (amount <= 0 || amount > left) throw this.error('amount_invalid');
    const reason = c.reason.trim();
    const out = this.entry(original.method, -amount, true, true, reason, 'Method correction');
    const into = this.entry(c.method, amount, false, true, reason, 'Method correction');
    const updated = this.addPayments(b, [out, into]);
    this.put({
      ...updated,
      history: [
        ...updated.history,
        {
          at: this.now.toISOString(),
          action: 'payment_correct',
          by: this.by,
          reason,
          before: {
            payment_id: original.id,
            method: original.method,
            amount_paise: original.amountPaise,
          },
          after: { method: c.method, amount_paise: amount, refund_id: out.id, payment_id: into.id },
        },
      ],
    });
  }

  async edit(_arenaId: string, bill: Bill, change: BillEdit): Promise<void> {
    this.fail();
    const b = this.find(bill.id);
    const reason = change.reason.trim();
    if (!reason) throw this.error('reason_required');
    if (b.voided) throw this.error('voided');
    if (b.paymentStatus === 'waived') throw this.error('waived');
    const diff = change.billedPaise - b.paidPaise;
    if (diff === 0 && change.billedPaise === b.billedPaise) throw this.error('same_total');
    const rows = diff
      ? [this.entry(change.method, diff, diff < 0, false, reason, 'Bill edited')]
      : [];
    const updated = this.addPayments({ ...b, billedPaise: change.billedPaise }, rows);
    this.put({
      ...updated,
      history: [
        ...updated.history,
        {
          at: this.now.toISOString(),
          action: 'bill_adjust',
          by: this.by,
          reason,
          before: { billed_paise: b.billedPaise, paid_paise: b.paidPaise },
          after: { billed_paise: change.billedPaise, paid_paise: change.billedPaise },
        },
      ],
    });
  }

  private entry(
    method: PayMethod,
    amountPaise: number,
    refund: boolean,
    correction: boolean,
    reason: string | null,
    note: string | null,
  ): BillPayment {
    return {
      id: crypto.randomUUID(),
      at: this.now.toISOString(),
      amountPaise,
      method,
      refund,
      correction,
      reason,
      note,
      by: this.by,
    };
  }

  /** Appends ledger rows; the status follows them unless the bill is waived or void. */
  private addPayments(b: BillDetail, rows: readonly BillPayment[]): BillDetail {
    const payments = [...b.payments, ...rows];
    const t = totals(payments);
    const billed = b.billedPaise ?? 0;
    const paymentStatus: PaymentStatus =
      b.voided || b.paymentStatus === 'waived'
        ? b.paymentStatus
        : t.paidPaise >= billed
          ? 'paid'
          : t.paidPaise > 0
            ? 'partial'
            : 'unpaid';
    return this.put({ ...b, ...t, payments, paymentStatus });
  }

  private find(id: string): BillDetail {
    const bill = this.bills.find((b) => b.id === id);
    if (!bill) throw this.error('not_found');
    return bill;
  }

  private put(bill: BillDetail): BillDetail {
    const i = this.bills.findIndex((b) => b.id === bill.id);
    this.bills[i] = bill;
    return bill;
  }

  private error(code: string): AppError {
    return new AppError(code, SALES_MESSAGES[code] ?? code);
  }

  private fail(): void {
    const code = this.failNext;
    if (!code) return;
    this.failNext = null;
    throw new AppError(code, code === 'forbidden' ? 'Only an owner can do that' : code);
  }
}
