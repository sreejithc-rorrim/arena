import { Component, computed, inject, input, output } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatIcon } from '@angular/material/icon';
import { MatSnackBar } from '@angular/material/snack-bar';
import { isOwnerLevel } from '../../../core/arena/arena-api';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { Session } from '../../../core/auth/session';
import { ConfirmDialog, ConfirmDialogData } from '../../../shared/confirm/confirm-dialog';
import { DetailPane } from '../../../shared/list-detail/detail-pane';
import { DetailRow } from '../../../shared/list-detail/detail-row';
import { DetailSection } from '../../../shared/list-detail/detail-section';
import { DetailTab, DetailTabs } from '../../../shared/list-detail/detail-tabs';
import { StatusPill } from '../../../shared/status-pill/status-pill';
import { UserAccess } from '../../users/components/user-access';
import { initials } from '../../users/components/user-format';
import { ArenaUser } from '../../users/data/user.models';
import { UsersStore } from '../../users/data/users-store';
import { UserDialog, UserDialogData, UserDialogResult } from '../../users/dialogs/user-dialog';
import { exemptFromTerms } from '../../settings/data/staff-terms';
import { TeamStore } from '../data/team-store';
import { TeamMember } from '../data/team.models';
import { MemberProfile } from './member-profile';

export type MemberTab = 'overview' | 'profile' | 'access';

/**
 * One employee on Team: Overview (contact, role, status), Profile (personal details and the
 * staff terms they accepted; owner level) and Access (app permissions). Owners' access is not
 * managed here (Settings › Owners & access). The tabs are routable: the tab is in the URL path
 * (`/staff/team/<staff>/access`; Overview is `/staff/team/<staff>`).
 */
@Component({
  selector: 'app-member-detail',
  imports: [
    DetailPane,
    DetailSection,
    DetailRow,
    StatusPill,
    UserAccess,
    MemberProfile,
    MatButton,
    DetailTabs,
    MatIcon,
  ],
  template: `
    @let s = staff();
    <app-detail-pane
      [crumb]="'Staff / Team / ' + s.name"
      [heading]="s.name"
      [subtitle]="user()?.email ?? ''"
      [initials]="initialsOf(s.name)"
      (closed)="closed.emit()"
    >
      <app-status-pill chip [tone]="status().tone">{{ status().label }}</app-status-pill>
      <app-detail-tabs label="Employee sections" [tabs]="tabLinks()" [active]="current()">

      @switch (current()) {
        @case ('overview') {
          <app-detail-section>
            <app-detail-row label="E-mail" [value]="user()?.email ?? '—'" [muted]="!user()" />
            <app-detail-row label="Role" [value]="roleText()" />
            <app-detail-row label="Status" [value]="status().label" />
            @if (user(); as u) {
              <div>
                <button
                  mat-stroked-button
                  type="button"
                  [disabled]="!canEdit()"
                  (click)="editName(u)"
                >
                  <mat-icon aria-hidden="true">edit</mat-icon>Edit name
                </button>
              </div>
            }
          </app-detail-section>
          @if (user(); as u) {
            <app-detail-section
              heading="Remove from team"
              subtitle="Erases their name and personal details. Their bills stay, shown as Deleted member."
            >
              @if (removeNote(); as note) {
                <p role="note" class="text-[13px] leading-[1.45] text-muted">{{ note }}</p>
              }
              <div>
                <button
                  mat-button
                  type="button"
                  class="danger-action"
                  [disabled]="removing() || !canRemove()"
                  (click)="remove(u)"
                >
                  <mat-icon aria-hidden="true">person_remove</mat-icon>Remove
                </button>
              </div>
            </app-detail-section>
          }
        }
        @case ('profile') {
          <app-member-profile [staff]="s" [exempt]="termsExempt()" />
        }
        @case ('access') {
          @if (user(); as u) {
            <app-user-access [user]="u" />
          }
        }
      }
      </app-detail-tabs>
    </app-detail-pane>
  `,
})
export class MemberDetail {
  private readonly arena = inject(ArenaContext);
  private readonly team = inject(TeamStore);
  private readonly users = inject(UsersStore);
  private readonly session = inject(Session);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);

  readonly staff = input.required<TeamMember>();
  /** Their login on Users (e-mail, invited or not, permissions), when readable. */
  readonly user = input<ArenaUser | undefined>(undefined);
  /** `/staff/team/<staff>/<tab>`: the section open (Overview when missing or not allowed). */
  readonly tab = input<string | undefined>(undefined);
  readonly closed = output<void>();

  protected readonly initialsOf = initials;

  protected readonly canEdit = this.arena.canEdit;
  /** Personal details and terms acceptances are readable by owner level only. */
  private readonly ownerLevel = computed(() => {
    const m = this.arena.currentMembership();
    return !!m && isOwnerLevel(m);
  });
  /** Owner level (role owner, or money / reports) never accepts the staff terms. */
  protected readonly termsExempt = computed(() =>
    exemptFromTerms({ role: this.staff().role, perms: this.user()?.perms ?? [] }),
  );

  protected readonly tabs = computed(() =>
    [
      { key: 'overview' as const, label: 'Overview', show: true },
      { key: 'profile' as const, label: 'Profile', show: this.ownerLevel() },
      // Owners' access is all permissions, managed in Settings › Owners & access.
      { key: 'access' as const, label: 'Access', show: !!this.user() && this.staff().role === 'staff' },
    ].filter((t) => t.show),
  );
  protected readonly tabLinks = computed<DetailTab[]>(() =>
    this.tabs().map((t) => ({
      ...t,
      link:
        t.key === 'overview'
          ? ['/staff/team', this.staff().id]
          : ['/staff/team', this.staff().id, t.key],
    })),
  );
  protected readonly current = computed<MemberTab>(
    () => this.tabs().find((t) => t.key === this.tab())?.key ?? 'overview',
  );

  protected readonly status = computed(() => {
    if (!this.staff().active) return { label: 'Access off', tone: 'danger' as const };
    if (this.user()?.invited) return { label: 'Invited', tone: 'warning' as const };
    return { label: 'Active', tone: 'success' as const };
  });
  /** Role, never permissions: staff with admin access, or staff. */
  protected readonly roleText = computed(() => {
    const perms = this.user()?.perms ?? [];
    return perms.includes('money') || perms.includes('reports') ? 'Staff · admin access' : 'Staff';
  });

  protected readonly removing = computed(() => this.users.saving() === this.user()?.userId);
  /**
   * Why this member cannot be removed from here (staff.remove refuses it): it is you, or they
   * hold Money, Reports or bill access and you are not an owner. Empty when they can.
   */
  protected readonly removeNote = computed(() => {
    const u = this.user();
    if (!u) return '';
    if (u.userId === this.session.user()?.id) return 'This is you: you cannot remove yourself.';
    const guarded = ['money', 'reports', 'bill_edit', 'bill_record'];
    if (u.perms.some((p) => guarded.includes(p)) && this.arena.currentRole() !== 'owner') {
      return 'They have Money, Reports or bill access, so only an owner can remove them.';
    }
    return '';
  });
  protected readonly canRemove = computed(() => this.canEdit() && !this.removeNote());

  /** Permanent (only a new invitation brings them back): confirm first. */
  protected remove(u: ArenaUser): void {
    this.dialog
      .open<ConfirmDialog, ConfirmDialogData, boolean>(ConfirmDialog, {
        data: {
          title: `Remove ${u.name}?`,
          message:
            'They are signed out and lose access to this venue. Their name, e-mail and personal details are erased here; their bills stay and show "Deleted member". To bring them back later, invite their e-mail again.',
          confirm: 'Remove',
          danger: true,
        },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe(async (yes) => {
        if (!yes) return;
        try {
          await this.users.remove(u);
          await this.team.load(true);
          this.say(`${u.name} removed from the team`);
          this.closed.emit();
        } catch (e) {
          this.say(toAppError(e).message);
        }
      });
  }

  private say(message: string): void {
    this.snack.open(message, undefined, { duration: 3200 });
  }

  protected editName(u: ArenaUser): void {
    this.dialog
      .open<UserDialog, UserDialogData, UserDialogResult>(UserDialog, {
        data: { user: u },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((r) => {
        if (!r) return;
        this.say(r.snack);
        void this.team.load(true);
      });
  }
}
