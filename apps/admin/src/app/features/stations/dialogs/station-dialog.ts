import { Component, computed, inject, signal } from '@angular/core';
import { MatButton } from '@angular/material/button';
import {
  MAT_DIALOG_DATA,
  MatDialogActions,
  MatDialogContent,
  MatDialogRef,
  MatDialogTitle,
} from '@angular/material/dialog';
import { MatFormField, MatLabel } from '@angular/material/form-field';
import { MatInput } from '@angular/material/input';
import { MatOption, MatSelect } from '@angular/material/select';
import { toAppError } from '../../../core/auth/auth-api';
import { FloorStore } from '../../../core/floor/floor-store';
import { Station } from '../../../core/floor/floor.models';
import { ResourceNoun, VenueStore } from '../../../core/venue/venue';
import { MATERIAL_DEFAULTS } from '../../../shared/material/material-defaults';
import { PricingStore } from '../../pricing/data/pricing-store';
import { headlinePrice } from '../../pricing/data/pricing.models';

export interface StationDialogData {
  /** The type picked in the list's filter, if any. */
  readonly code?: string;
}

/** Closes with the new station's id and the snackbar text; undefined when cancelled. */
export interface StationDialogResult {
  readonly id: string;
  readonly snack: string;
}

/**
 * Design: dialog `d.k === 'station'`. Adds a station of one type; a blank name becomes the next
 * free "<CODE>-<n>". Staff see it on the floor after their next sync.
 */
/** Tables and rooms get their own floor zone in the app; everything else is a station. */
function stationKind(noun: ResourceNoun): Station['kind'] {
  return noun === 'table' || noun === 'room' ? noun : 'station';
}

@Component({
  selector: 'app-station-dialog',
  providers: [MATERIAL_DEFAULTS],
  imports: [
    MatDialogTitle,
    MatDialogContent,
    MatDialogActions,
    MatFormField,
    MatLabel,
    MatInput,
    MatSelect,
    MatOption,
    MatButton,
  ],
  template: `
    <h2 mat-dialog-title>Add station</h2>
    <form novalidate (submit)="save($event)">
      <mat-dialog-content>
        <div class="flex flex-col gap-5 pt-1">
          <p class="text-sm leading-[1.4] text-muted">{{ sub() }}</p>
          <mat-form-field>
            <mat-label>Type</mat-label>
            <mat-select [value]="code()" (selectionChange)="code.set($event.value)">
              @for (t of types(); track t.id) {
                <mat-option [value]="t.code">{{ t.name }}</mat-option>
              }
            </mat-select>
          </mat-form-field>
          <mat-form-field>
            <mat-label>Name</mat-label>
            <input
              matInput
              autocomplete="off"
              maxlength="40"
              [placeholder]="auto()"
              [value]="name()"
              (input)="name.set($any($event.target).value)"
            />
          </mat-form-field>
          @if (error()) {
            <p role="alert" class="text-sm leading-[1.3] font-medium text-danger">{{ error() }}</p>
          }
        </div>
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" [disabled]="busy()" (click)="ref.close()">Cancel</button>
        <button mat-flat-button type="submit" [disabled]="busy() || !code()">Add</button>
      </mat-dialog-actions>
    </form>
  `,
})
export class StationDialog {
  private readonly data = inject<StationDialogData>(MAT_DIALOG_DATA);
  protected readonly ref = inject<MatDialogRef<StationDialog, StationDialogResult>>(MatDialogRef);
  private readonly floor = inject(FloorStore);
  private readonly pricing = inject(PricingStore);
  private readonly venue = inject(VenueStore);

  protected readonly types = computed(() => this.pricing.types().filter((t) => t.active));
  protected readonly code = signal(
    this.data.code ?? this.pricing.types().find((t) => t.active)?.code ?? '',
  );
  protected readonly name = signal('');
  protected readonly error = signal('');
  protected readonly busy = signal(false);

  /** The next free "<CODE>-<n>" (a removed station's name is free again). */
  protected readonly auto = computed(() => {
    const prefix = this.code() || this.venue.words().one;
    const onFloor = this.floor.stations().filter((s) => s.status !== 'disabled');
    const taken = new Set(onFloor.map((s) => s.name.toLowerCase()));
    let n = onFloor.filter((s) => s.activityCodes.includes(this.code())).length + 1;
    while (taken.has(`${prefix}-${n}`.toLowerCase())) n++;
    return `${prefix}-${n}`;
  });

  protected readonly sub = computed(() => {
    const failed = this.pricing.loadError();
    if (failed) return `Station types couldn't load, so a station can't be added yet: ${failed}`;
    const type = this.pricing.types().find((t) => t.code === this.code());
    const price = type ? headlinePrice(type, this.pricing.rates()) : null;
    const charged = price
      ? `Charged at ${price.price} ${price.per === 'per hour' ? 'an hour' : price.per}.`
      : 'This type has no price yet · set it under Pricing.';
    return `${charged} Staff see it on the floor straight away.`;
  });

  protected async save(event: Event): Promise<void> {
    event.preventDefault();
    const name = this.name().trim() || this.auto();
    if (name.length > 40) {
      this.error.set('Use up to 40 characters');
      return;
    }
    // A removed station frees its name (its past bills keep it); only stations still on the floor
    // count.
    const taken = this.floor
      .stations()
      .some((s) => s.status !== 'disabled' && s.name.toLowerCase() === name.toLowerCase());
    if (taken) {
      this.error.set(`${name} already exists`);
      return;
    }
    const id = crypto.randomUUID();
    this.busy.set(true);
    this.error.set('');
    try {
      await this.floor.saveStation({
        id,
        name,
        kind: stationKind(this.venue.noun()),
        status: 'available',
        sortOrder: Math.max(-1, ...this.floor.stations().map((s) => s.sortOrder)) + 1,
        activityCodes: [this.code()],
      });
      this.ref.close({ id, snack: `${name} added` });
    } catch (e) {
      this.error.set(toAppError(e).message);
    } finally {
      this.busy.set(false);
    }
  }
}
