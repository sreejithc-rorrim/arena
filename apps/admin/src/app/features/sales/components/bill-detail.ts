import { Clipboard } from '@angular/cdk/clipboard';
import { Component, computed, inject, input, output, resource } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatIcon } from '@angular/material/icon';
import { MatProgressBar } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { DetailPane } from '../../../shared/list-detail/detail-pane';
import { DetailRow } from '../../../shared/list-detail/detail-row';
import { DetailSection } from '../../../shared/list-detail/detail-section';
import { formatRupees } from '../../../shared/money/rupees.pipe';
import { StatTile } from '../../../shared/stat-tile/stat-tile';
import { StatusPill } from '../../../shared/status-pill/status-pill';
import { formatDate, formatMinutes, formatTime } from '../../../shared/time/ist';
import { adjustLabel } from '../../pricing/data/pricing.models';
import { SalesStore } from '../data/sales-store';
import {
  ADDED_LATER_NOTE,
  BILL_EDITED_NOTE,
  Bill,
  BillDetail as Detail,
  BillExtension,
  BillHistoryEntry,
  BillLine,
  BillPayment,
  billFlags,
  billState,
  customerType,
  duePaise,
  methodName,
  paidMethods,
  playedMinutes,
  writtenOffPaise,
  BillDiscount,
  discountLabel,
} from '../data/sale.models';
import { EditBillDialog, EditBillDialogData } from '../dialogs/edit-bill-dialog';
import { MoneyDialog, MoneyDialogData, MoneyMode, movable } from '../dialogs/money-dialog';
import { VoidDialog, VoidDialogData } from '../dialogs/void-dialog';

/** A start that reached the server this much later was sent from an offline device or clock. */
const LATE_MS = 5 * 60_000;
/** An end that reached the server this much later: possibly back-dated (offline window, BL-001). */
const LATE_END_MS = 15 * 60_000;

/**
 * Design: `if (p === 'sales')` detail. The list's summary shows at once; the charge lines (with
 * their times), extensions, payments ledger and history load from arena_sale(). Share copies a
 * plain-text receipt. Void asks for a reason (owner level, as the server requires). Record
 * payment, Refund and Correct method append to the ledger — nothing recorded is edited — and
 * every change shows in History with who, when, why and the amounts before and after.
 */
@Component({
  selector: 'app-bill-detail',
  imports: [
    DetailPane,
    DetailSection,
    DetailRow,
    StatTile,
    StatusPill,
    MatButton,
    MatIcon,
    MatProgressBar,
  ],
  template: `
    @let b = shown();
    <app-detail-pane
      [crumb]="'Sales / ' + b.ref"
      icon="receipt_long"
      [heading]="b.ref"
      [subtitle]="when()"
      (closed)="closed.emit()"
    >
      @if (!b.voided) {
        <div actions class="arena-compact flex gap-2">
          <button mat-stroked-button type="button" (click)="share()">
            <mat-icon aria-hidden="true">share</mat-icon>Share
          </button>
          @if (canEdit() && full(); as d) {
            <button mat-stroked-button type="button" (click)="editBill(d)">
              <mat-icon aria-hidden="true">edit</mat-icon>Edit
            </button>
          }
          <button mat-button type="button" class="danger-action" (click)="voidBill()">
            <mat-icon aria-hidden="true">block</mat-icon>Void
          </button>
        </div>
      }
      <span chip class="flex flex-wrap items-center gap-1.5">
        <app-status-pill [tone]="chip().tone">{{ chip().label }}</app-status-pill>
        @for (f of flags(); track f.label) {
          <app-status-pill [tone]="f.tone">{{ f.label }}</app-status-pill>
        }
      </span>
      <span
        big
        class="flex-none font-display text-[32px] leading-none font-bold tabular-nums"
        [class.text-muted]="b.voided"
        [class.line-through]="b.voided"
        >{{ rupees(b.billedPaise ?? 0) }}</span
      >

      <div stats class="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <app-stat-tile label="Time played" [value]="minutes(played())" />
        <app-stat-tile
          [label]="b.players > 1 ? 'Player-hours' : 'Players'"
          [value]="b.players > 1 ? playerHours() : b.players.toString()"
        />
        <app-stat-tile label="Collected" [value]="rupees(b.paidPaise)" />
        <app-stat-tile [label]="balance().label" [value]="balance().value" />
      </div>

      @if (addedLater(); as a) {
        <div
          role="note"
          class="flex items-start gap-3 rounded-card bg-info-soft px-4 py-3 text-sm leading-[1.45]"
        >
          <mat-icon class="flex-none text-muted" aria-hidden="true">history_edu</mat-icon>
          <span class="min-w-0">
            <span class="font-semibold">Added later</span>
            {{ a.by ? ' by ' + a.by : '' }} · {{ stamp(a.at) }}. Played but never started on the
            floor.
            @if (a.reason) {
              <span class="mt-1 block text-muted">“{{ a.reason }}”</span>
            }
          </span>
        </div>
      }
      @if (lateRecord() || lateEnd()) {
        <div
          role="note"
          class="flex items-start gap-3 rounded-card bg-warning-soft px-4 py-3 text-sm leading-[1.45]"
        >
          <mat-icon class="flex-none text-warning" aria-hidden="true">schedule</mat-icon>
          <span class="min-w-0">
            @if (lateRecord(); as late) {
              <span class="block"
                >Start reached the server {{ late }}: the device was offline or its clock was off.
                Times are the device's.</span
              >
            }
            @if (lateEnd(); as late) {
              <span class="block"
                >End reached the server {{ late }}, more than 15 minutes after the end it records:
                it was offline, or the end was dated back. The bill is priced on that end.</span
              >
            }
          </span>
        </div>
      }

      <app-detail-section heading="Details">
        <dl class="grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-2 md:grid-cols-3">
          @for (f of facts(); track f.label) {
            <div class="flex min-w-0 flex-col gap-1">
              <dt class="text-[12.5px] leading-none text-muted">{{ f.label }}</dt>
              <dd class="text-sm leading-[1.35] font-medium [overflow-wrap:anywhere]">
                {{ f.value }}
                @if (f.tag) {
                  <span class="ml-1 text-xs font-normal text-muted">· {{ f.tag }}</span>
                }
              </dd>
            </div>
          }
        </dl>
      </app-detail-section>

      @if (detail.isLoading() && !detail.hasValue()) {
        <mat-progress-bar mode="indeterminate" aria-label="Loading the bill" />
      }
      @if (detail.error(); as error) {
        <app-detail-section>
          <p role="alert" class="text-sm text-danger">{{ message(error) }}</p>
          <div>
            <button mat-stroked-button type="button" (click)="detail.reload()">Try again</button>
          </div>
        </app-detail-section>
      }
      @if (full(); as d) {
        <div class="grid grid-cols-1 items-start gap-5 lg:grid-cols-2">
          <app-detail-section heading="Amount">
            @for (line of d.lines; track $index) {
              <div class="flex items-start justify-between gap-4">
                <span class="flex min-w-0 flex-col gap-0.5">
                  <span class="text-sm leading-[1.3] font-medium">{{ lineTitle(line) }}</span>
                  <span class="text-[12.5px] leading-[1.3] text-muted">{{ lineSub(line) }}</span>
                </span>
                <span class="flex-none text-sm leading-[1.3] font-medium tabular-nums">{{
                  rupees(line.amountPaise)
                }}</span>
              </div>
            }
            @if (d.rule; as rule) {
              <p class="text-[13px] leading-[1.45] text-muted">
                Priced with the time rule {{ rule.name }} ({{ adjust(rule) }}).
              </p>
            }
            @if (d.discount; as disc) {
              <app-detail-row
                [label]="'Discount · ' + discountText(disc)"
                [value]="'−' + rupees(disc.amountPaise)"
              />
              @if (disc.reason || disc.by) {
                <p class="-mt-3 text-[12.5px] leading-[1.4] text-muted">
                  {{ discountNote(disc) }}
                </p>
              }
            }
            @if (rounding(); as r) {
              <app-detail-row label="Rounding" [value]="signed(r)" />
            }
            @if (edited(); as e) {
              <app-detail-row label="Edited" [value]="signed(e)" />
            }
            <!-- GST is not configured per arena yet. -->
            <app-detail-row label="GST" value="Not connected yet" [muted]="true" />
            <div class="h-px bg-border" role="presentation"></div>
            <app-detail-row label="Total" [value]="rupees(d.billedPaise ?? 0)" [strong]="true" />
            @if (d.paymentStatus === 'waived' && !d.voided) {
              <p class="text-[13px] leading-[1.45] text-muted">
                Waived · {{ rupees(writtenOff()) }} written off · no payment due.
              </p>
            }
            @if (d.voided) {
              <p class="text-[13px] leading-[1.45] text-danger">{{ voidNote() }}</p>
            }
          </app-detail-section>

          <app-detail-section heading="Payments">
            <ol class="flex flex-col gap-3" aria-label="Payments">
              @for (p of d.payments; track p.id) {
                <li class="flex items-start gap-3">
                  <span
                    class="icon grid size-8 flex-none place-items-center rounded-full text-[18px]"
                    [class.bg-danger-soft]="p.refund && !p.correction"
                    [class.text-danger]="p.refund && !p.correction"
                    [class.bg-success-soft]="!p.refund"
                    [class.text-success]="!p.refund"
                    [class.bg-surface-sunken]="p.correction"
                    aria-hidden="true"
                    >{{ p.refund ? 'undo' : 'payments' }}</span
                  >
                  <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span
                      class="flex flex-wrap items-center gap-1.5 text-sm leading-[1.3] font-medium"
                    >
                      {{ paymentKind(p) }}
                      @if (p.note === addedLaterNote) {
                        <app-status-pill tone="info">Added later</app-status-pill>
                      } @else if (p.note === billEditedNote) {
                        <app-status-pill tone="warning">Bill edited</app-status-pill>
                      }
                    </span>
                    <span class="text-[12.5px] leading-[1.3] text-muted">{{ paymentSub(p) }}</span>
                    @if (paymentReason(p); as why) {
                      <span class="text-[12.5px] leading-[1.4] text-muted">“{{ why }}”</span>
                    }
                  </span>
                  <span
                    class="flex-none text-sm leading-[1.3] font-semibold tabular-nums"
                    [class.text-danger]="p.amountPaise < 0"
                    >{{ signed(p.amountPaise) }}</span
                  >
                </li>
              } @empty {
                <li class="text-[13px] leading-[1.45] text-muted">No payments recorded.</li>
              }
            </ol>
            @if (d.payments.length) {
              <div class="h-px bg-border" role="presentation"></div>
              <app-detail-row label="Collected" [value]="rupees(d.paidPaise)" [strong]="true" />
            }
            @if (due(); as owed) {
              <app-detail-row label="Due" [value]="rupees(owed)" />
            }
            @if (d.voided && d.paidPaise > 0) {
              <p class="text-[13px] leading-[1.45] text-warning">
                {{ rupees(d.paidPaise) }} was collected on this bill. Voiding does not refund it:
                record a refund when the money goes back.
              </p>
            }
            @if (actions().length) {
              <div class="arena-compact flex flex-wrap gap-2">
                @for (a of actions(); track a.mode) {
                  <button mat-stroked-button type="button" (click)="money(d, a.mode)">
                    {{ a.label }}
                  </button>
                }
              </div>
            }
          </app-detail-section>
        </div>

        @if (d.extensions.length) {
          <app-detail-section heading="Extensions">
            @for (e of d.extensions; track $index) {
              <app-detail-row [label]="extensionLabel(e)" [value]="rupees(e.addedPaise)" />
              @if (e.reason) {
                <p class="-mt-3 text-[12.5px] leading-[1.4] text-muted">{{ e.reason }}</p>
              }
            }
          </app-detail-section>
        }

        <app-detail-section heading="History">
          <ol class="flex flex-col gap-3" aria-label="History">
            @for (h of d.history; track $index) {
              <li class="flex items-start gap-3">
                <span
                  class="icon grid size-8 flex-none place-items-center rounded-full bg-surface-sunken text-[18px] text-muted"
                  aria-hidden="true"
                  >{{ historyIcon(h) }}</span
                >
                <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                  <span class="text-sm leading-[1.3] font-medium">{{ historyLabel(h) }}</span>
                  <span class="text-[12.5px] leading-[1.3] text-muted">{{ historyWho(h) }}</span>
                  @if (h.reason) {
                    <span class="text-[12.5px] leading-[1.4] text-muted">“{{ h.reason }}”</span>
                  }
                </span>
              </li>
            } @empty {
              <li class="text-[13px] leading-[1.45] text-muted">
                No voids, waives, edits or corrections. Refunds and payments are listed above.
              </li>
            }
          </ol>
        </app-detail-section>
      }
    </app-detail-pane>
  `,
})
export class BillDetail {
  private readonly store = inject(SalesStore);
  private readonly arena = inject(ArenaContext);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);
  private readonly clipboard = inject(Clipboard);

  /** The list's summary of the bill (shown until the full bill loads). */
  readonly bill = input.required<Bill>();
  readonly closed = output<void>();

  protected readonly detail = resource({
    params: () => ({
      arena: this.arena.current().id,
      id: this.bill().id,
      revision: this.store.revision(),
    }),
    loader: ({ params }) => this.store.get(params.id),
  });
  /** The loaded bill, once it matches the selected one. */
  protected readonly full = computed<Detail | undefined>(() => {
    const d = this.detail.hasValue() ? this.detail.value() : undefined;
    return d?.id === this.bill().id ? d : undefined;
  });
  protected readonly shown = computed<Bill>(() => this.full() ?? this.bill());

  protected readonly rupees = formatRupees;
  protected readonly discountText = discountLabel;
  /** "Regular customer · by Priya" (the manual reason and who applied it). */
  protected discountNote(d: BillDiscount): string {
    return [d.reason, d.by ? `by ${d.by}` : null].filter(Boolean).join(' · ');
  }
  protected readonly adjust = (r: { adjustKind: 'percent' | 'per_hour'; adjustValue: number }) =>
    adjustLabel(r);
  protected readonly minutes = formatMinutes;
  protected readonly chip = computed(() => {
    const b = this.shown();
    const state = billState(b);
    if (state.tone) return { label: state.label, tone: state.tone };
    return { label: `Paid · ${state.label}`, tone: 'primary' as const };
  });
  protected readonly when = computed(
    () => `${formatDate(this.shown().at)}, ${formatTime(this.shown().at)}`,
  );
  protected readonly played = computed(() => playedMinutes(this.shown()));
  protected readonly playerHours = computed(() => formatMinutes(this.shown().playerMinutes));
  protected readonly started = computed(
    () => `${formatDate(this.shown().startedAt)}, ${formatTime(this.shown().startedAt)}`,
  );
  protected readonly ended = computed(() => {
    const b = this.shown();
    return b.endedAt ? formatTime(b.endedAt) : 'Voided while it ran';
  });
  protected readonly memberType = computed(() => customerType(this.shown()));
  protected readonly lateEnd = computed(() => {
    const b = this.shown();
    if (!b.endRecordedAt || !b.endedAt) return null;
    const late = Date.parse(b.endRecordedAt) - Date.parse(b.endedAt);
    return late > LATE_END_MS
      ? `${formatDate(b.endRecordedAt)}, ${formatTime(b.endRecordedAt)}`
      : null;
  });
  protected readonly lateRecord = computed(() => {
    const b = this.shown();
    if (!b.recordedAt) return null;
    const late = Date.parse(b.recordedAt) - Date.parse(b.startedAt);
    return late > LATE_MS ? `${formatDate(b.recordedAt)}, ${formatTime(b.recordedAt)}` : null;
  });
  protected readonly stationLine = computed(() => {
    const b = this.shown();
    const where = b.stations.join(', ') || '—';
    return b.activities.length ? `${where} · ${b.activities.join(', ')}` : where;
  });
  protected readonly due = computed(() => duePaise(this.shown()));
  protected readonly addedLaterNote = ADDED_LATER_NOTE;
  protected readonly billEditedNote = BILL_EDITED_NOTE;
  /** Added later, edited, discount, refunded (the full bill's history catches edits too). */
  protected readonly flags = computed(() => billFlags(this.shown(), this.full()?.history ?? []));
  /** The missed-bill record: who added it, when, and why (its payment carries the reason). */
  protected readonly addedLater = computed(() => {
    const p = this.shown().payments.find((x) => x.note === ADDED_LATER_NOTE);
    return p ? { by: p.by, at: p.at, reason: p.reason } : null;
  });
  /** The fourth tile: what is still owed, or what went back, else the payment method. */
  protected readonly balance = computed(() => {
    const b = this.shown();
    const owed = duePaise(b);
    if (b.voided) return { label: 'Bill', value: 'Void' };
    if (owed > 0) return { label: 'Due', value: formatRupees(owed) };
    if (b.refundedPaise > 0) return { label: 'Refunded', value: formatRupees(b.refundedPaise) };
    const methods = paidMethods(b).map(methodName);
    return { label: 'Paid by', value: methods.join(' + ') || '—' };
  });
  /** The details grid: one cell per fact, types shown only when they add to the station. */
  protected readonly facts = computed(() => {
    const b = this.shown();
    const types = b.activities.filter((a) => !b.stations.includes(a));
    const out: { label: string; value: string; tag?: string }[] = [
      {
        label: b.stations.length > 1 ? 'Stations' : 'Station',
        value: b.stations.join(', ') || '—',
      },
    ];
    if (types.length) out.push({ label: 'Type', value: types.join(', ') });
    out.push(
      { label: 'Game', value: b.games.join(', ') || '—' },
      { label: 'Member', value: b.customer, tag: customerType(b) },
      { label: 'Started', value: this.started() },
      { label: 'Ended', value: this.ended() },
      { label: 'Started by', value: b.startedBy ?? '—' },
    );
    return out;
  });
  protected readonly writtenOff = computed(() => writtenOffPaise(this.shown()));
  /** What Edit bill changed the total by, added up (History's bill_adjust entries). */
  protected readonly edited = computed(() =>
    (this.full()?.history ?? [])
      .filter((h) => h.action === 'bill_adjust')
      .reduce(
        (sum, h) =>
          sum + Number(h.after?.['billed_paise'] ?? 0) - Number(h.before?.['billed_paise'] ?? 0),
        0,
      ),
  );
  /** Bill-level cash rounding: the final bill minus the sum of its lines (and any edit). */
  protected readonly rounding = computed(() => {
    const d = this.full();
    if (!d || d.billedPaise == null || !d.lines.length) return 0;
    return (
      d.billedPaise -
      this.edited() -
      d.lines.reduce((sum, l) => sum + l.amountPaise, 0) +
      d.discountPaise
    );
  });
  protected readonly canEdit = computed(() => {
    const d = this.full();
    return (
      !!d && !d.voided && d.paymentStatus !== 'waived' && d.billedPaise != null && this.has('money')
    );
  });
  protected readonly voidNote = computed(() => {
    const d = this.full();
    if (!d) return '';
    const by = d.voidRecord?.by ? ` · by ${d.voidRecord.by}` : '';
    const at = d.voidRecord
      ? `, ${formatDate(d.voidRecord.at)} ${formatTime(d.voidRecord.at)}`
      : '';
    return `Voided · ${d.voidReason ?? 'no reason given'}${by}${at}`;
  });

  /** What this login may do here; the server checks the same permissions. */
  private has(perm: string): boolean {
    const m = this.arena.currentMembership();
    return !!m && m.active && (m.role === 'owner' || m.perms.includes(perm));
  }
  protected readonly actions = computed(() => {
    const d = this.full();
    if (!d) return [];
    const out: { mode: MoneyMode; label: string }[] = [];
    if (!d.voided && duePaise(d) > 0 && this.has('bill')) {
      out.push({ mode: 'payment', label: 'Record payment' });
    }
    if (d.paidPaise > 0 && this.has('bill') && this.has('discount')) {
      out.push({ mode: 'refund', label: 'Refund' });
    }
    if (movable(d).size && this.has('money')) {
      out.push({ mode: 'correct', label: 'Correct method' });
    }
    return out;
  });

  protected lineTitle(line: BillLine): string {
    return line.station;
  }

  protected lineSub(line: BillLine): string {
    const span =
      line.start && line.end ? `${formatTime(line.start)}–${formatTime(line.end)} · ` : '';
    return `${span}${formatMinutes(line.billedMinutes)}`;
  }

  protected extensionLabel(e: BillExtension): string {
    const by = e.by ? ` · ${e.by}` : '';
    return `+${formatMinutes(e.addedMinutes)} · ${formatTime(e.at)}${by}`;
  }

  protected paymentKind(p: BillPayment): string {
    if (p.correction) {
      return `${methodName(p.method)} ${p.refund ? 'corrected out' : 'corrected in'}`;
    }
    return p.refund ? `${methodName(p.method)} refund` : methodName(p.method);
  }

  protected paymentSub(p: BillPayment): string {
    return [this.stamp(p.at), p.by].filter(Boolean).join(' · ');
  }

  /** The reason (a correction's rows carry it in History; the tag already says Added / Edited). */
  protected paymentReason(p: BillPayment): string {
    if (p.correction) return '';
    if (p.reason) return p.reason;
    return p.note && p.note !== ADDED_LATER_NOTE && p.note !== BILL_EDITED_NOTE ? p.note : '';
  }

  protected stamp(at: string): string {
    return `${formatDate(at)}, ${formatTime(at)}`;
  }

  protected historyIcon(h: BillHistoryEntry): string {
    switch (h.action) {
      case 'void':
        return 'block';
      case 'waive':
        return 'money_off';
      case 'bill_adjust':
        return 'edit';
      case 'end_moved':
        return 'schedule';
      case 'payment_correct':
        return 'swap_horiz';
      case 'record':
        return 'history_edu';
      default:
        return 'history';
    }
  }

  protected historyLabel(h: BillHistoryEntry): string {
    const paise = (v: unknown) => formatRupees(Number(v ?? 0));
    switch (h.action) {
      case 'void':
        return 'Voided';
      case 'waive':
        return `Waived · ${paise(h.after?.['written_off_paise'])} written off`;
      case 'bill_adjust':
        return `Bill edited · ${paise(h.before?.['billed_paise'])} → ${paise(h.after?.['billed_paise'])}`;
      case 'record':
        return `Added later · ${paise(h.after?.['billed_paise'])}`;
      case 'end_moved':
        return `End moved earlier · ${formatTime(String(h.before?.['ended_at']))} → ${formatTime(
          String(h.after?.['ended_at']),
        )} · ${paise(h.before?.['billed_paise'])} → ${paise(h.after?.['billed_paise'])}`;
      case 'payment_correct':
        return `Payment moved · ${paise(h.after?.['amount_paise'])} ${methodName(
          String(h.before?.['method'] ?? ''),
        )} → ${methodName(String(h.after?.['method'] ?? ''))}`;
      default:
        return h.action;
    }
  }

  protected historyWho(h: BillHistoryEntry): string {
    return `${h.by ?? 'Unknown'} · ${formatDate(h.at)} ${formatTime(h.at)}`;
  }

  protected signed(paise: number): string {
    return paise < 0 ? '−' + formatRupees(-paise) : formatRupees(paise);
  }

  protected message(error: unknown): string {
    return toAppError(error).message;
  }

  protected share(): void {
    const b = this.shown();
    const paid = paidMethods(b).map(methodName).join(' + ');
    const lines = [
      `${this.arena.current().name} · ${b.ref}`,
      this.when(),
      `${this.stationLine()} · ${formatMinutes(this.played())}`,
      `Total ${formatRupees(b.billedPaise ?? 0)}${paid ? ` · Paid by ${paid}` : ''}`,
    ];
    const copied = this.clipboard.copy(lines.join('\n'));
    this.snack.open(
      copied ? `Receipt for ${b.ref} copied` : 'Could not copy the receipt',
      undefined,
      { duration: 3200 },
    );
  }

  protected voidBill(): void {
    const bill = this.shown();
    this.dialog
      .open<VoidDialog, VoidDialogData, boolean>(VoidDialog, {
        data: { bill },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((voided) => {
        if (voided) this.snack.open(`${bill.ref} voided`, undefined, { duration: 3200 });
      });
  }

  protected editBill(bill: Detail): void {
    this.dialog
      .open<EditBillDialog, EditBillDialogData, boolean>(EditBillDialog, {
        data: { bill },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((saved) => {
        if (saved) this.snack.open(`${bill.ref} updated`, undefined, { duration: 3200 });
      });
  }

  protected money(bill: Detail, mode: MoneyMode): void {
    const done = {
      payment: 'Payment recorded',
      refund: 'Refund recorded',
      correct: 'Payment moved',
    }[mode];
    this.dialog
      .open<MoneyDialog, MoneyDialogData, boolean>(MoneyDialog, {
        data: { bill, mode },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((saved) => {
        if (saved) this.snack.open(`${done} on ${bill.ref}`, undefined, { duration: 3200 });
      });
  }
}
