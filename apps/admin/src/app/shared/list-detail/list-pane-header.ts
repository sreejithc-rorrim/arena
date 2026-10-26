import { Component, input } from '@angular/core';
import { MatIconAnchor } from '@angular/material/button';
import { MatIcon } from '@angular/material/icon';
import { RouterLink } from '@angular/router';

/**
 * Top of a list pane (design: list header block): 64px title row with a back arrow to `back`
 * (for a screen opened from another; navigation is the side nav or, when compact, the bottom
 * bar) and any projected
 * actions (e.g. the Add button), then projected search / chips / summary rows, all above one
 * hairline.
 */
@Component({
  selector: 'app-list-pane-header',
  imports: [MatIconAnchor, MatIcon, RouterLink],
  host: { class: 'flex flex-none flex-col gap-3 border-b border-border px-4 pb-3' },
  template: `
    <div class="flex h-topbar items-center gap-2">
      @if (back(); as link) {
        <a mat-icon-button class="-ml-1.5" [routerLink]="link" [attr.aria-label]="backLabel()">
          <mat-icon aria-hidden="true">arrow_back</mat-icon>
        </a>
      }
      <h1 class="min-w-0 flex-1 truncate text-xl leading-[1.2] font-semibold">{{ title() }}</h1>
      <ng-content select="[actions]" />
    </div>
    <ng-content />
  `,
})
export class ListPaneHeader {
  readonly title = input.required<string>();
  /** A screen opened from another: the arrow back to it instead of the menu button. */
  readonly back = input<string | null>(null);
  readonly backLabel = input('Back');
}
