import { Component, computed, inject, resource, signal } from '@angular/core';
import { MatButton, MatIconButton } from '@angular/material/button';
import {
  MatDialog,
  MatDialogActions,
  MatDialogContent,
  MatDialogRef,
  MatDialogTitle,
} from '@angular/material/dialog';
import { MatFormField, MatLabel } from '@angular/material/form-field';
import { MatIcon } from '@angular/material/icon';
import { MatInput } from '@angular/material/input';
import { MatMenu, MatMenuItem, MatMenuTrigger } from '@angular/material/menu';
import { toAppError } from '../../../core/auth/auth-api';
import { ConfirmDialog, ConfirmDialogData } from '../../../shared/confirm/confirm-dialog';
import { MATERIAL_DEFAULTS } from '../../../shared/material/material-defaults';
import { StatusPill } from '../../../shared/status-pill/status-pill';
import { ExpensesStore } from '../data/expenses-store';
import {
  ExpenseCategory,
  MAX_CATEGORY_NAME,
  categoryIcon,
  missingStandard,
  nextSortOrder,
} from '../data/expense.models';

/**
 * The arena's expense categories: picked from the standard list (Rent, Electricity, Internet…)
 * or the owner's own, renamed, turned off and on. Removing one deletes it when no expense uses
 * it, otherwise turns it off: its expenses keep it, new ones cannot pick it.
 */
@Component({
  selector: 'app-categories-dialog',
  providers: [MATERIAL_DEFAULTS],
  imports: [
    StatusPill,
    MatButton,
    MatIconButton,
    MatIcon,
    MatMenu,
    MatMenuItem,
    MatMenuTrigger,
    MatDialogTitle,
    MatDialogContent,
    MatDialogActions,
    MatFormField,
    MatLabel,
    MatInput,
  ],
  template: `
    <h2 mat-dialog-title>Expense categories</h2>
    <mat-dialog-content>
      <div class="flex flex-col gap-4 pt-1">
        <div class="flex flex-wrap gap-2">
          <button
            mat-stroked-button
            type="button"
            [disabled]="busy() || !offered().length"
            [matMenuTriggerFor]="catalogMenu"
          >
            <mat-icon aria-hidden="true">library_add</mat-icon>From the standard list
          </button>
          <mat-menu #catalogMenu="matMenu">
            @if (offered().length > 1) {
              <button mat-menu-item type="button" (click)="adopt(offered())">
                <mat-icon aria-hidden="true">done_all</mat-icon>All standard categories
              </button>
            }
            @for (name of offered(); track name) {
              <button mat-menu-item type="button" (click)="adopt([name])">
                <mat-icon aria-hidden="true">{{ icon(name) }}</mat-icon
                >{{ name }}
              </button>
            }
          </mat-menu>
        </div>
        @if (store.metaError(); as e) {
          <p role="alert" class="text-[13px] leading-[1.45] text-danger">
            Categories couldn't load: {{ e }}
          </p>
        } @else if (!categories()) {
          <p class="text-[13px] leading-[1.45] text-muted">Loading…</p>
        } @else {
          <ul class="-mx-2 flex flex-col gap-0.5" aria-label="Categories">
            @for (c of categories(); track c.id) {
              <li class="flex min-h-14 items-center gap-3 px-2">
                <span class="icon text-xl text-muted" aria-hidden="true">{{ icon(c.name) }}</span>
                @if (editing() === c.id) {
                  <form
                    novalidate
                    class="flex min-w-0 flex-1 items-center gap-2"
                    (submit)="rename($event, c)"
                  >
                    <mat-form-field class="arena-compact min-w-0 flex-1">
                      <mat-label>Name</mat-label>
                      <input
                        matInput
                        autocomplete="off"
                        required
                        [value]="draft()"
                        (input)="draft.set($any($event.target).value)"
                      />
                    </mat-form-field>
                    <button
                      mat-button
                      type="button"
                      [disabled]="busy()"
                      (click)="editing.set(null)"
                    >
                      Cancel
                    </button>
                    <button mat-flat-button type="submit" [disabled]="busy()">Save</button>
                  </form>
                } @else {
                  <span class="min-w-0 flex-1 truncate text-sm leading-[1.2] font-medium">{{
                    c.name
                  }}</span>
                  @if (!c.active) {
                    <app-status-pill tone="info">Off</app-status-pill>
                    <button
                      mat-button
                      type="button"
                      [disabled]="busy()"
                      (click)="setActive(c, true)"
                    >
                      Turn on
                    </button>
                  }
                  <button
                    mat-icon-button
                    type="button"
                    [disabled]="busy()"
                    [attr.aria-label]="'Rename ' + c.name"
                    (click)="startEdit(c)"
                  >
                    <mat-icon aria-hidden="true">edit</mat-icon>
                  </button>
                  <button
                    mat-icon-button
                    type="button"
                    [disabled]="busy() || !c.active"
                    [attr.aria-label]="'Remove ' + c.name"
                    (click)="remove(c)"
                  >
                    <mat-icon aria-hidden="true">delete</mat-icon>
                  </button>
                }
              </li>
            } @empty {
              <li class="px-2 text-[13px] leading-[1.45] text-muted">
                No categories yet. Pick the standard ones (Rent, Electricity, Internet, Repairs…) or
                add your own.
              </li>
            }
          </ul>
          <form novalidate class="flex items-start gap-2" (submit)="addCustom($event)">
            <mat-form-field class="min-w-0 flex-1">
              <mat-label>New category</mat-label>
              <input
                matInput
                autocomplete="off"
                [value]="newName()"
                (input)="newName.set($any($event.target).value)"
              />
            </mat-form-field>
            <button mat-stroked-button type="submit" class="mt-2" [disabled]="busy()">
              <mat-icon aria-hidden="true">add</mat-icon>Add
            </button>
          </form>
        }
        @if (error()) {
          <p role="alert" class="text-sm leading-[1.3] font-medium text-danger">{{ error() }}</p>
        }
      </div>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-flat-button type="button" (click)="ref.close()">Done</button>
    </mat-dialog-actions>
  `,
})
export class CategoriesDialog {
  protected readonly ref = inject<MatDialogRef<CategoriesDialog>>(MatDialogRef);
  protected readonly store = inject(ExpensesStore);
  private readonly dialog = inject(MatDialog);

  protected readonly icon = categoryIcon;
  protected readonly categories = this.store.categories;

  private readonly catalog = resource({ loader: () => this.store.catalog() });
  /** Standard names the arena doesn't have yet (names are unique ignoring case). */
  protected readonly offered = computed(() =>
    this.catalog.hasValue() ? missingStandard(this.catalog.value(), this.categories() ?? []) : [],
  );

  protected readonly editing = signal<string | null>(null);
  protected readonly draft = signal('');
  protected readonly newName = signal('');
  protected readonly error = signal('');
  protected readonly busy = signal(false);

  constructor() {
    void this.store.loadMeta();
  }

  protected adopt(names: readonly string[]): Promise<boolean> {
    const start = nextSortOrder(this.categories() ?? []);
    return this.run(() =>
      this.store.saveCategories(
        names.map((name, i) => ({
          id: crypto.randomUUID(),
          name,
          sortOrder: start + i,
          active: true,
        })),
      ),
    );
  }

  protected async addCustom(event: Event): Promise<void> {
    event.preventDefault();
    const name = this.checked(this.newName());
    if (!name) return;
    const ok = await this.run(() =>
      this.store.saveCategories([
        {
          id: crypto.randomUUID(),
          name,
          sortOrder: nextSortOrder(this.categories() ?? []),
          active: true,
        },
      ]),
    );
    if (ok) this.newName.set('');
  }

  protected startEdit(c: ExpenseCategory): void {
    this.error.set('');
    this.draft.set(c.name);
    this.editing.set(c.id);
  }

  protected async rename(event: Event, c: ExpenseCategory): Promise<void> {
    event.preventDefault();
    const name = this.checked(this.draft());
    if (!name) return;
    if (name === c.name) {
      this.editing.set(null);
      return;
    }
    const ok = await this.run(() => this.store.saveCategories([{ ...c, name }]));
    if (ok) this.editing.set(null);
  }

  protected setActive(c: ExpenseCategory, active: boolean): Promise<boolean> {
    return this.run(() => this.store.saveCategories([{ ...c, active }]));
  }

  protected remove(c: ExpenseCategory): void {
    this.dialog
      .open<ConfirmDialog, ConfirmDialogData, boolean>(ConfirmDialog, {
        data: {
          title: `Remove ${c.name}?`,
          message:
            'If no expense uses it, it is deleted. Otherwise it is turned off: those expenses keep it, but new ones cannot pick it.',
          confirm: 'Remove',
          danger: true,
        },
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((yes) => {
        if (yes) void this.run(() => this.store.removeCategory(c.id));
      });
  }

  /** A trimmed name within the limit; '' (with the error shown) otherwise. */
  private checked(raw: string): string {
    const name = raw.trim();
    if (!name) this.error.set('Enter a name');
    else if (name.length > MAX_CATEGORY_NAME) {
      this.error.set(`Keep the name to ${MAX_CATEGORY_NAME} characters`);
      return '';
    }
    return name;
  }

  /** Runs one change; a refusal stays in the dialog. Resolves with whether it was saved. */
  private async run(change: () => Promise<unknown>): Promise<boolean> {
    this.busy.set(true);
    this.error.set('');
    try {
      await change();
      return true;
    } catch (e) {
      this.error.set(toAppError(e).message);
      return false;
    } finally {
      this.busy.set(false);
    }
  }
}
