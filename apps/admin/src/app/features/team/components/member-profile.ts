import { Component, computed, effect, inject, input, linkedSignal, signal } from '@angular/core';
import { MatButton } from '@angular/material/button';
import { MatFormField, MatHint, MatLabel } from '@angular/material/form-field';
import { MatInput } from '@angular/material/input';
import { MatOption, MatSelect } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { isOwnerLevel } from '../../../core/arena/arena-api';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { Clock } from '../../../core/time/clock';
import { DetailRow } from '../../../shared/list-detail/detail-row';
import { DetailSection } from '../../../shared/list-detail/detail-section';
import { formatDayYear } from '../../../shared/staff/staff-format';
import { formatIsoDate, formatTime } from '../../../shared/time/ist';
import { TermsStore } from '../../settings/data/staff-terms';
import {
  BLOOD_GROUPS,
  DetailField,
  DetailsDraft,
  EMPTY_DETAILS,
  PersonalDetailsStore,
  detailsProblems,
  sameDetails,
} from '../data/personal-details';
import { TeamStore } from '../data/team-store';
import { TeamMember } from '../data/team.models';

/** "5 Oct 2026, 9:42 pm" (IST). */
function dateTime(at: string): string {
  return `${formatDayYear(formatIsoDate(at))}, ${formatTime(at)}`;
}

/**
 * An employee's Profile tab on Team: their personal details (contact, date of birth, blood
 * group, address, emergency contact; all optional), editable by owner level, and which version
 * of the staff terms they accepted. Only the changed fields are sent (staff_details.save).
 */
@Component({
  selector: 'app-member-profile',
  host: { class: 'flex flex-col gap-5' },
  imports: [
    DetailSection,
    DetailRow,
    MatButton,
    MatFormField,
    MatLabel,
    MatHint,
    MatInput,
    MatSelect,
    MatOption,
  ],
  template: `
    @if (store.loadError(); as error) {
      <app-detail-section>
        <p role="alert" class="text-[13px] leading-[1.45] text-danger">
          Personal details couldn't load: {{ error }}
        </p>
      </app-detail-section>
    } @else if (!store.rows()) {
      <app-detail-section>
        <p class="text-[13px] leading-[1.45] text-muted">Loading…</p>
      </app-detail-section>
    } @else {
      @let d = draft();
      @let p = shownProblems();
      @if (termsText() || row()) {
        <app-detail-section>
          @if (termsText()) {
            <app-detail-row label="Terms" [value]="termsText()" [muted]="termsMuted()" />
          }
          @if (row()) {
            <app-detail-row label="Last updated" [value]="updated()" />
          }
        </app-detail-section>
      }

      <app-detail-section
        heading="Contact"
        subtitle="All optional. Only owners and the person can see these details."
      >
        <div class="grid grid-cols-[repeat(auto-fit,minmax(200px,1fr))] gap-3">
          <mat-form-field>
            <mat-label>Phone</mat-label>
            <input
              matInput
              type="tel"
              autocomplete="off"
              maxlength="20"
              [attr.aria-invalid]="!!p.phone"
              [attr.aria-describedby]="p.phone ? 'pd-phone-error' : null"
              [disabled]="!canEdit()"
              [value]="d.phone"
              (input)="set('phone', $any($event.target).value)"
            />
          </mat-form-field>
          <mat-form-field>
            <mat-label>Personal e-mail</mat-label>
            <input
              matInput
              type="email"
              autocomplete="off"
              maxlength="254"
              [attr.aria-invalid]="!!p.email"
              [attr.aria-describedby]="p.email ? 'pd-email-error' : null"
              [disabled]="!canEdit()"
              [value]="d.email"
              (input)="set('email', $any($event.target).value)"
            />
          </mat-form-field>
          <mat-form-field>
            <mat-label>Date of birth</mat-label>
            <input
              matInput
              type="date"
              min="1900-01-01"
              [max]="today"
              [attr.aria-invalid]="!!p.birthDate"
              [attr.aria-describedby]="p.birthDate ? 'pd-birth-error' : null"
              [disabled]="!canEdit()"
              [value]="d.birthDate"
              (change)="set('birthDate', $any($event.target).value)"
            />
          </mat-form-field>
          <mat-form-field>
            <mat-label>Blood group</mat-label>
            <mat-select
              [value]="d.bloodGroup"
              [disabled]="!canEdit()"
              (selectionChange)="set('bloodGroup', $event.value)"
            >
              <mat-option value="">Not set</mat-option>
              @for (g of bloodGroups; track g) {
                <mat-option [value]="g">{{ g }}</mat-option>
              }
            </mat-select>
          </mat-form-field>
        </div>
        @if (p.phone) {
          <p id="pd-phone-error" role="alert" class="text-[13px] leading-[1.4] text-danger">
            Phone: {{ p.phone }}
          </p>
        }
        @if (p.email) {
          <p id="pd-email-error" role="alert" class="text-[13px] leading-[1.4] text-danger">
            {{ p.email }}
          </p>
        }
        @if (p.birthDate) {
          <p id="pd-birth-error" role="alert" class="text-[13px] leading-[1.4] text-danger">
            {{ p.birthDate }}
          </p>
        }
      </app-detail-section>

      <app-detail-section heading="Address">
        <div class="grid grid-cols-1 gap-3">
          <mat-form-field>
            <mat-label>Address line 1</mat-label>
            <input
              matInput
              autocomplete="off"
              maxlength="200"
              [disabled]="!canEdit()"
              [value]="d.addressLine1"
              (input)="set('addressLine1', $any($event.target).value)"
            />
          </mat-form-field>
          <mat-form-field>
            <mat-label>Address line 2</mat-label>
            <input
              matInput
              autocomplete="off"
              maxlength="200"
              [disabled]="!canEdit()"
              [value]="d.addressLine2"
              (input)="set('addressLine2', $any($event.target).value)"
            />
          </mat-form-field>
        </div>
        <div class="grid grid-cols-[repeat(auto-fit,minmax(180px,1fr))] gap-3">
          <mat-form-field>
            <mat-label>City</mat-label>
            <input
              matInput
              autocomplete="off"
              maxlength="80"
              [disabled]="!canEdit()"
              [value]="d.city"
              (input)="set('city', $any($event.target).value)"
            />
          </mat-form-field>
          <mat-form-field>
            <mat-label>State</mat-label>
            <input
              matInput
              autocomplete="off"
              maxlength="80"
              [disabled]="!canEdit()"
              [value]="d.state"
              (input)="set('state', $any($event.target).value)"
            />
          </mat-form-field>
          <mat-form-field>
            <mat-label>PIN code</mat-label>
            <input
              matInput
              inputmode="numeric"
              autocomplete="off"
              maxlength="6"
              [attr.aria-invalid]="!!p.pinCode"
              [attr.aria-describedby]="p.pinCode ? 'pd-pin-error' : null"
              [disabled]="!canEdit()"
              [value]="d.pinCode"
              (input)="set('pinCode', $any($event.target).value)"
            />
            <mat-hint>Six digits</mat-hint>
          </mat-form-field>
        </div>
        @if (p.pinCode) {
          <p id="pd-pin-error" role="alert" class="text-[13px] leading-[1.4] text-danger">
            PIN code: {{ p.pinCode }}
          </p>
        }
        @for (m of lengthProblems(); track m) {
          <p role="alert" class="text-[13px] leading-[1.4] text-danger">{{ m }}</p>
        }
      </app-detail-section>

      <app-detail-section heading="Emergency contact">
        <div class="grid grid-cols-[repeat(auto-fit,minmax(180px,1fr))] gap-3">
          <mat-form-field>
            <mat-label>Name</mat-label>
            <input
              matInput
              autocomplete="off"
              maxlength="80"
              [disabled]="!canEdit()"
              [value]="d.emergencyName"
              (input)="set('emergencyName', $any($event.target).value)"
            />
          </mat-form-field>
          <mat-form-field>
            <mat-label>Relation</mat-label>
            <input
              matInput
              autocomplete="off"
              maxlength="40"
              [disabled]="!canEdit()"
              [value]="d.emergencyRelation"
              (input)="set('emergencyRelation', $any($event.target).value)"
            />
            <mat-hint>e.g. Mother, Spouse</mat-hint>
          </mat-form-field>
          <mat-form-field>
            <mat-label>Phone</mat-label>
            <input
              matInput
              type="tel"
              autocomplete="off"
              maxlength="20"
              [attr.aria-invalid]="!!p.emergencyPhone"
              [attr.aria-describedby]="p.emergencyPhone ? 'pd-ephone-error' : null"
              [disabled]="!canEdit()"
              [value]="d.emergencyPhone"
              (input)="set('emergencyPhone', $any($event.target).value)"
            />
          </mat-form-field>
        </div>
        @if (p.emergencyPhone) {
          <p id="pd-ephone-error" role="alert" class="text-[13px] leading-[1.4] text-danger">
            Emergency phone: {{ p.emergencyPhone }}
          </p>
        }
        @if (error()) {
          <p role="alert" class="text-sm font-medium text-danger">{{ error() }}</p>
        }
        @if (canEdit() && dirty()) {
          <div class="flex gap-2">
            <button mat-flat-button type="button" [disabled]="busy()" (click)="save()">
              Save details
            </button>
            <button mat-button type="button" [disabled]="busy()" (click)="discard()">
              Discard
            </button>
          </div>
        }
      </app-detail-section>
    }
  `,
})
export class MemberProfile {
  protected readonly store = inject(PersonalDetailsStore);
  private readonly terms = inject(TermsStore);
  private readonly team = inject(TeamStore);
  private readonly arena = inject(ArenaContext);
  private readonly snack = inject(MatSnackBar);
  protected readonly today = formatIsoDate(inject(Clock).now());

  readonly staff = input.required<TeamMember>();
  /** Owner level (role owner, or money / reports): never asked to accept the terms. */
  readonly exempt = input(false);

  protected readonly bloodGroups = BLOOD_GROUPS;
  /** The server lets owner level change anyone's details. */
  protected readonly canEdit = computed(() => {
    const m = this.arena.currentMembership();
    return !!m && isOwnerLevel(m);
  });

  protected readonly row = computed(() => this.store.byStaff().get(this.staff().id));
  private readonly saved = computed(() => this.row()?.fields ?? EMPTY_DETAILS);
  protected readonly draft = linkedSignal<DetailsDraft>(() => this.saved());
  protected readonly dirty = computed(() => !sameDetails(this.draft(), this.saved()));
  private readonly tried = signal(false);
  protected readonly shownProblems = computed(() =>
    this.tried() ? detailsProblems(this.draft(), this.today) : {},
  );
  /** Too-long text fields (the inputs' maxlength normally prevents them). */
  protected readonly lengthProblems = computed(() => {
    const p = this.shownProblems();
    const labels: Partial<Record<DetailField, string>> = {
      addressLine1: 'Address line 1',
      addressLine2: 'Address line 2',
      city: 'City',
      state: 'State',
      emergencyName: 'Emergency contact name',
      emergencyRelation: 'Relation',
    };
    return (Object.keys(labels) as DetailField[])
      .filter((f) => p[f])
      .map((f) => `${labels[f]}: ${p[f]}`);
  });
  protected readonly busy = signal(false);
  protected readonly error = signal('');

  protected readonly updated = computed(() => {
    const r = this.row();
    if (!r) return '';
    const by = r.updatedBy ? this.team.nameOfUser().get(r.updatedBy) : undefined;
    return by ? `${dateTime(r.updatedAt)} by ${by}` : dateTime(r.updatedAt);
  });

  /** The terms line; empty while no terms are published (or they could not be read). */
  protected readonly termsText = computed(() => {
    const current = this.terms.current();
    if (!current) return '';
    if (this.exempt()) return 'Not required for owners';
    const accepted = this.terms.acceptedOf().get(this.staff().id);
    if (accepted?.version === current.version) {
      return `Version ${accepted.version} accepted ${dateTime(accepted.acceptedAt)}`;
    }
    if (accepted) {
      return `Version ${accepted.version} accepted ${dateTime(accepted.acceptedAt)} · version ${current.version} not accepted yet`;
    }
    return `Not accepted yet (version ${current.version} in force)`;
  });
  protected readonly termsMuted = computed(() => {
    const current = this.terms.current();
    return (
      this.exempt() || this.terms.acceptedOf().get(this.staff().id)?.version !== current?.version
    );
  });

  constructor() {
    effect(() => {
      if (!this.arena.current().id) return;
      void this.store.load();
      void this.terms.load();
    });
  }

  protected set(field: DetailField, value: string): void {
    this.draft.update((d) => ({ ...d, [field]: value }));
    this.error.set('');
  }

  protected discard(): void {
    this.draft.set(this.saved());
    this.tried.set(false);
    this.error.set('');
  }

  protected async save(): Promise<void> {
    this.tried.set(true);
    if (Object.keys(detailsProblems(this.draft(), this.today)).length) {
      this.error.set('Fix the values marked above, then save again');
      return;
    }
    this.busy.set(true);
    this.error.set('');
    try {
      await this.store.save(this.staff().id, this.draft());
      this.tried.set(false);
      this.snack.open(`${this.staff().name}’s details saved`, undefined, { duration: 3200 });
    } catch (e) {
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }
}
