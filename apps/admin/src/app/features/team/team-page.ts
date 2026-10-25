import { Component, computed, effect, inject } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatIcon } from '@angular/material/icon';
import { MatProgressBar } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Router } from '@angular/router';
import { isOwnerLevel } from '../../core/arena/arena-api';
import { ArenaContext } from '../../core/arena/arena-context';
import { ListDetail } from '../../shared/list-detail/list-detail';
import { ListPaneHeader } from '../../shared/list-detail/list-pane-header';
import { ListRow } from '../../shared/list-detail/list-row';
import { childParams } from '../../shared/routing/child-params';
import { StatusPill } from '../../shared/status-pill/status-pill';
import { InviteList } from '../users/components/invite-list';
import { initials } from '../users/components/user-format';
import { UsersStore } from '../users/data/users-store';
import { UserDialog, UserDialogData, UserDialogResult } from '../users/dialogs/user-dialog';
import { MemberDetail } from './components/member-detail';
import { TeamStore } from './data/team-store';
import { TeamMember, isEmployee } from './data/team.models';

/**
 * Staff › Team: the venue's staff with their role and status, and Add staff (an e-mailed staff
 * invitation; never owner access, which is Settings › Owners & access). Pending staff
 * invitations follow the list. A member opens in routable tabs; the selection is in the URL path
 * (`/staff/team/<staff>/access`).
 */
@Component({
  selector: 'app-team-page',
  imports: [
    ListDetail,
    ListPaneHeader,
    ListRow,
    StatusPill,
    InviteList,
    MemberDetail,
    MatButton,
    MatIcon,
    MatProgressBar,
  ],
  template: `
    <app-list-detail
      listLabel="Team"
      detailLabel="Employee"
      emptyText="Pick someone to see their details and access"
      [open]="!!selected()"
      (closed)="close()"
    >
      <ng-container list>
        <app-list-pane-header title="Team">
          <button
            actions
            mat-flat-button
            type="button"
            [disabled]="!arena.canEdit()"
            (click)="add()"
          >
            <mat-icon aria-hidden="true">person_add</mat-icon>Add staff
          </button>
          @if (summary()) {
            <p class="text-[13px] leading-[1.3] text-muted" aria-live="polite">{{ summary() }}</p>
          }
        </app-list-pane-header>
        @if (team.loading()) {
          <mat-progress-bar mode="indeterminate" aria-label="Loading the team" />
        }
        <div class="flex min-h-0 flex-1 flex-col overflow-y-auto p-2">
          @if (team.loadError(); as error) {
            <div class="flex flex-col items-center gap-3 px-4 py-12 text-center">
              <p role="alert" class="text-sm text-danger">{{ error }}</p>
              <button mat-stroked-button type="button" (click)="reload()">Try again</button>
            </div>
          } @else if (team.staff()) {
            <ul class="flex flex-col gap-0.5" aria-label="Employees">
              @for (s of people(); track s.id) {
                <li>
                  <app-list-row
                    [title]="s.name"
                    [subtitle]="rowSub(s)"
                    [initials]="initialsOf(s.name)"
                    [selected]="s.id === selected()?.id"
                    [link]="['/staff/team', s.id]"
                  >
                    @if (!s.active) {
                      <app-status-pill tone="danger">Access off</app-status-pill>
                    } @else if (users.byId().get(s.userId)?.invited) {
                      <app-status-pill tone="warning">Invited</app-status-pill>
                    }
                  </app-list-row>
                </li>
              } @empty {
                <li class="px-4 py-12 text-center text-sm leading-[1.4] text-muted">
                  No staff yet. Add the people who work at the venue: they get an e-mail to join
                  and use the floor app.
                </li>
              }
            </ul>
            @if (showInvites()) {
              <app-invite-list role="staff" heading="Invited, not joined yet" />
            }
          }
        </div>
      </ng-container>
      <ng-container detail>
        @if (selected(); as s) {
          <app-member-detail
            [staff]="s"
            [user]="users.byId().get(s.userId)"
            [tab]="params()['tab']"
            (closed)="close()"
          />
        }
      </ng-container>
    </app-list-detail>
  `,
})
export class TeamPage {
  protected readonly team = inject(TeamStore);
  protected readonly users = inject(UsersStore);
  protected readonly arena = inject(ArenaContext);
  private readonly router = inject(Router);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);

  /** `/staff/team/:id[/:tab]` — a staff profile id and the employee section open. */
  protected readonly params = childParams();

  protected readonly initialsOf = initials;
  /** Staff only, active first, each group by name. */
  protected readonly people = computed(() =>
    (this.team.staff() ?? [])
      .filter(isEmployee)
      .sort((a, b) => Number(b.active) - Number(a.active) || a.name.localeCompare(b.name)),
  );
  protected readonly selected = computed(() => {
    const id = this.params()['id'];
    return id ? this.people().find((s) => s.id === id) : undefined;
  });
  /** Staff invitations still open, for owner-level logins (arena_invites). */
  protected readonly showInvites = computed(() => {
    const me = this.arena.currentMembership();
    return (
      !!me &&
      isOwnerLevel(me) &&
      (this.users.invites().some((i) => i.role === 'staff') || !!this.users.invitesError())
    );
  });
  protected readonly summary = computed(() => {
    const active = this.people().filter((s) => s.active).length;
    return active ? `${active} ${active === 1 ? 'employee' : 'employees'}` : '';
  });

  constructor() {
    effect(() => {
      if (!this.arena.current().id) return;
      void this.team.load();
      void this.users.load();
    });
  }

  /** "Staff", "Staff · admin". */
  protected rowSub(s: TeamMember): string {
    const perms = this.users.byId().get(s.userId)?.perms ?? [];
    return perms.includes('money') || perms.includes('reports') ? 'Staff · admin' : 'Staff';
  }

  protected reload(): void {
    void this.team.load(true);
  }

  /** Add staff: an e-mailed staff invitation (the staff role only, the default permissions). */
  protected add(): void {
    this.dialog
      .open<UserDialog, UserDialogData, UserDialogResult>(UserDialog, {
        data: { role: 'staff' },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((result) => {
        if (!result) return;
        this.snack.open(result.snack, undefined, { duration: 3200 });
        // They join once they accept the e-mailed invitation; then they appear here.
        void this.users.load(true);
        void this.team.load(true);
      });
  }

  protected close(): void {
    void this.router.navigate(['/staff/team']);
  }
}
