import { Component, computed, inject, input, output } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatIcon } from '@angular/material/icon';
import { MatSlideToggle, MatSlideToggleChange } from '@angular/material/slide-toggle';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { Session } from '../../../core/auth/session';
import { ConfirmDialog, ConfirmDialogData } from '../../../shared/confirm/confirm-dialog';
import { DetailPane } from '../../../shared/list-detail/detail-pane';
import { DetailSection } from '../../../shared/list-detail/detail-section';
import { formatRupees } from '../../../shared/money/rupees.pipe';
import { StatTile } from '../../../shared/stat-tile/stat-tile';
import { StatusPill } from '../../../shared/status-pill/status-pill';
import { UsersStore } from '../data/users-store';
import { ArenaUser, FLOOR_PERMS, OWNER_ONLY_PERMS } from '../data/user.models';
import { UserDialog, UserDialogData, UserDialogResult } from '../dialogs/user-dialog';
import { initials, statusTone } from './user-format';

/**
 * Design: `if (p === 'staff')` detail. Staff: 30-day stats, floor permissions, Edit /
 * Deactivate. Owners: every permission, Edit only — removing an owner is an operator action.
 */
@Component({
  selector: 'app-user-detail',
  imports: [DetailPane, DetailSection, StatTile, StatusPill, MatButton, MatIcon, MatSlideToggle],
  template: `
    @let u = user();
    <app-detail-pane
      [crumb]="(u.role === 'owner' ? 'Users / Owners / ' : 'Users / Staff / ') + u.name"
      [heading]="u.name"
      [subtitle]="u.email"
      [initials]="initials(u.name)"
      (closed)="closed.emit()"
    >
      <div actions class="arena-compact flex gap-2">
        <button mat-stroked-button type="button" [disabled]="busy() || !canEdit()" (click)="edit()">
          <mat-icon aria-hidden="true">edit</mat-icon>Edit
        </button>
        @if (u.role === 'staff') {
          @if (u.active) {
            <button
              mat-button
              type="button"
              class="danger-action"
              [disabled]="busy() || !canChangeAccess()"
              (click)="deactivate()"
            >
              <mat-icon aria-hidden="true">person_off</mat-icon>Deactivate
            </button>
          } @else {
            <button
              mat-stroked-button
              type="button"
              [disabled]="busy() || !canChangeAccess()"
              (click)="setActive(true)"
            >
              <mat-icon aria-hidden="true">person</mat-icon>Reactivate
            </button>
          }
        }
      </div>
      <app-status-pill chip [tone]="tone()">{{ status() }}</app-status-pill>

      @if (u.role === 'staff') {
        <div stats class="grid grid-cols-[repeat(auto-fit,minmax(130px,1fr))] gap-3">
          <app-stat-tile label="Bills · 30 days" [value]="u.bills30d.toString()" />
          <app-stat-tile label="Takings · 30 days" [value]="rupees(u.takings30dPaise)" />
          <app-stat-tile label="Refunds · 30 days" [value]="rupees(u.refunds30dPaise)" />
          <app-stat-tile
            label="Discounts · 30 days"
            value="—"
            title="Discounts aren't recorded on bills yet"
          />
        </div>
      }
      @if (u.role === 'staff') {
        <app-detail-section
          heading="Permissions"
          subtitle="Applies next time they sign in on the floor app."
        >
          @if (accessNote(); as note) {
            <p role="note" class="text-[13px] leading-[1.45] text-muted">{{ note }}</p>
          } @else if (!isOwner()) {
            <p role="note" class="text-[13px] leading-[1.45] text-muted">
              Only an owner can give or take away Edit own bills and Add missed bills.
            </p>
          }
          @for (p of perms; track p.code) {
            <div class="flex items-center justify-between gap-4">
              <span class="flex flex-col gap-1">
                <span class="text-[15px] leading-[1.3]" [id]="'perm-' + p.code">{{ p.label }}</span>
                <span class="text-[13px] leading-[1.3] text-muted" [id]="'perm-sub-' + p.code">{{
                  p.sub
                }}</span>
              </span>
              <mat-slide-toggle
                hideIcon
                [checked]="u.perms.includes(p.code)"
                [disabled]="busy() || !u.active || !canChangeAccess() || ownerOnlyLocked(p.code)"
                [aria-labelledby]="'perm-' + p.code"
                [aria-describedby]="'perm-sub-' + p.code"
                (change)="togglePerm(p.code, $event)"
              />
            </div>
          }
        </app-detail-section>
      } @else {
        <app-detail-section heading="Owner account">
          <p class="text-[13px] leading-[1.45] text-muted">
            Owners have every permission and manage this arena on this dashboard. They can also sign
            in on the floor app. Removing an owner is done by the operator.
          </p>
        </app-detail-section>
      }
      @if (u.invited && u.active) {
        <app-detail-section>
          <p class="text-[13px] leading-[1.45] text-muted">
            {{ u.email }} has not signed in yet. They sign in with this email and the password they
            chose.
          </p>
        </app-detail-section>
      }
    </app-detail-pane>
  `,
})
export class UserDetail {
  private readonly arena = inject(ArenaContext);
  private readonly session = inject(Session);
  /** Without the Settings permission the server refuses every change here. */
  protected readonly canEdit = this.arena.canEdit;
  private readonly store = inject(UsersStore);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);

  readonly user = input.required<ArenaUser>();
  readonly closed = output<void>();

  protected readonly perms = FLOOR_PERMS;
  protected readonly initials = initials;
  protected readonly rupees = formatRupees;
  protected readonly status = computed(() => statusTone(this.user()).label);
  protected readonly tone = computed(() => statusTone(this.user()).tone);
  protected readonly busy = computed(() => this.store.saving() === this.user().userId);
  /**
   * Why this member's access cannot be changed from here (staff.update refuses it): it is your
   * own, or it is owner level (money or reports) and you are not an owner. Empty when it can.
   */
  protected readonly accessNote = computed(() => {
    const u = this.user();
    if (u.userId === this.session.user()?.id) {
      return 'This is you: someone else with Settings changes your own access.';
    }
    const ownerLevel = u.perms.includes('money') || u.perms.includes('reports');
    if (ownerLevel && this.arena.currentRole() !== 'owner') {
      return 'They have Money or Reports access, so only an owner can change their access.';
    }
    return '';
  });
  protected readonly canChangeAccess = computed(() => this.canEdit() && !this.accessNote());
  /** The signed-in login is an owner here (owner-only permissions are theirs to grant). */
  protected readonly isOwner = computed(() => this.arena.currentRole() === 'owner');

  /** Edit own bills and Add missed bills: only an owner may switch them (staff.update refuses others). */
  protected ownerOnlyLocked(code: string): boolean {
    return OWNER_ONLY_PERMS.includes(code) && !this.isOwner();
  }

  protected edit(): void {
    this.dialog
      .open<UserDialog, UserDialogData, UserDialogResult>(UserDialog, {
        data: { user: this.user() },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((result) => {
        if (result) this.say(result.snack);
      });
  }

  /** Deactivating signs them out of the floor app: confirm first. */
  protected deactivate(): void {
    const u = this.user();
    this.dialog
      .open<ConfirmDialog, ConfirmDialogData, boolean>(ConfirmDialog, {
        data: {
          title: `Deactivate ${u.name}?`,
          message:
            'They are signed out of the floor app and cannot sign in to this arena until you reactivate them. Their past bills stay as they are.',
          confirm: 'Deactivate',
          danger: true,
        },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((yes) => {
        if (yes) void this.setActive(false);
      });
  }

  protected async setActive(active: boolean): Promise<void> {
    const u = this.user();
    try {
      await this.store.change(u, { active });
      this.say(
        active ? `${u.name} reactivated` : `${u.name} deactivated · signed out of the floor app`,
      );
    } catch (e) {
      this.say(toAppError(e).message);
    }
  }

  protected async togglePerm(code: string, event: MatSlideToggleChange): Promise<void> {
    const u = this.user();
    const perms = event.checked ? [...u.perms, code] : u.perms.filter((p) => p !== code);
    try {
      await this.store.change(u, { perms });
      // The server may have saved something else (an adjusted change): show what it holds.
      const saved = this.store.byId().get(u.userId);
      if (saved) event.source.checked = saved.perms.includes(code);
      this.say(`${u.name}'s access updated`);
    } catch (e) {
      // Refused: put the switch back where the server left it.
      event.source.checked = !event.checked;
      this.say(toAppError(e).message);
    }
  }

  private say(message: string): void {
    this.snack.open(message, undefined, { duration: 3200 });
  }
}
