import { Component, computed, inject, input } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatIcon } from '@angular/material/icon';
import { MatSlideToggle, MatSlideToggleChange } from '@angular/material/slide-toggle';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { Session } from '../../../core/auth/session';
import { ConfirmDialog, ConfirmDialogData } from '../../../shared/confirm/confirm-dialog';
import { DetailSection } from '../../../shared/list-detail/detail-section';
import { UsersStore } from '../data/users-store';
import { ArenaUser, FLOOR_PERMS, OWNER_ONLY_PERMS } from '../data/user.models';

/**
 * A staff member's app access (staff.update): the permission switches and turning their access
 * off or back on. Changes need Settings; owner-level members (Money or Reports) and Edit own
 * bills / Add missed bills only an owner may change, and nobody changes their own. Owner accounts are not
 * managed here: they have every permission (Settings › Owners & access).
 */
@Component({
  selector: 'app-user-access',
  imports: [DetailSection, MatButton, MatIcon, MatSlideToggle],
  host: { class: 'flex flex-col gap-5' },
  template: `
    @let u = user();
    <app-detail-section
      heading="Permissions"
      subtitle="What they can do. Applies next time they sign in."
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
    <app-detail-section heading="Sign-in">
      @if (u.invited && u.active) {
        <p class="text-[13px] leading-[1.45] text-muted">
          {{ u.email }} has not signed in yet. They sign in with this e-mail and the password they
          chose.
        </p>
      } @else {
        <p class="text-[13px] leading-[1.45] text-muted">
          {{
            u.active
              ? 'They sign in with ' + u.email + '.'
              : 'Turned off: they cannot sign in to this venue. Their records stay as they are.'
          }}
        </p>
      }
      <div>
        @if (u.active) {
          <button
            mat-button
            type="button"
            class="danger-action"
            [disabled]="busy() || !canChangeAccess()"
            (click)="deactivate()"
          >
            <mat-icon aria-hidden="true">person_off</mat-icon>Turn off access
          </button>
        } @else {
          <button
            mat-stroked-button
            type="button"
            [disabled]="busy() || !canChangeAccess()"
            (click)="setActive(true)"
          >
            <mat-icon aria-hidden="true">person</mat-icon>Turn access back on
          </button>
        }
      </div>
    </app-detail-section>
  `,
})
export class UserAccess {
  private readonly arena = inject(ArenaContext);
  private readonly session = inject(Session);
  private readonly store = inject(UsersStore);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);

  readonly user = input.required<ArenaUser>();

  protected readonly perms = FLOOR_PERMS;
  protected readonly busy = computed(() => this.store.saving() === this.user().userId);
  /** The signed-in login is an owner here (owner-only permissions are theirs to grant). */
  protected readonly isOwner = computed(() => this.arena.currentRole() === 'owner');
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
    if (ownerLevel && !this.isOwner()) {
      return 'They have Money or Reports access, so only an owner can change their access.';
    }
    return '';
  });
  /** Without the Settings permission the server refuses every change here. */
  protected readonly canChangeAccess = computed(() => this.arena.canEdit() && !this.accessNote());

  /** Edit own bills and Add missed bills: only an owner may switch them (staff.update refuses others). */
  protected ownerOnlyLocked(code: string): boolean {
    return OWNER_ONLY_PERMS.includes(code) && !this.isOwner();
  }

  /** Turning access off signs them out of the floor app: confirm first. */
  protected deactivate(): void {
    const u = this.user();
    this.dialog
      .open<ConfirmDialog, ConfirmDialogData, boolean>(ConfirmDialog, {
        data: {
          title: `Turn off ${u.name}'s access?`,
          message:
            'They are signed out of the floor app and cannot sign in to this venue until you turn it back on. Their bills stay as they are.',
          confirm: 'Turn off',
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
      this.say(active ? `${u.name}'s access is back on` : `${u.name}'s access turned off`);
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
