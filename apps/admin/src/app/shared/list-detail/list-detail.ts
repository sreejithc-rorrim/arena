import { A11yModule } from '@angular/cdk/a11y';
import { NgTemplateOutlet } from '@angular/common';
import { Component, inject, input, output } from '@angular/core';
import { Layout } from '../../core/layout/layout';

/**
 * The design's list/detail frame (`isList` block, `renderVals` else-branch):
 * - wide (≥ 1180px): 380px list beside the detail; with nothing selected the detail shows
 *   `emptyText`;
 * - narrower: the list fills the page and the detail slides over it (min(560px, 92vw), full
 *   width when compact) behind a scrim, closed by the scrim, Escape or its close button.
 *
 * Project the list with `[list]` and the detail with `[detail]`.
 */
@Component({
  selector: 'app-list-detail',
  imports: [A11yModule, NgTemplateOutlet],
  host: { class: 'flex h-app min-w-0' },
  template: `
    <!-- Projected once: it is shown beside the list (wide) or over it (narrow). -->
    <ng-template #detail><ng-content select="[detail]" /></ng-template>

    <section
      class="flex h-app min-w-0 flex-col bg-bg"
      [class.w-[380px]]="layout.wideDetail()"
      [class.flex-none]="layout.wideDetail()"
      [class.border-r]="layout.wideDetail()"
      [class.border-border]="layout.wideDetail()"
      [class.flex-1]="!layout.wideDetail()"
      [attr.aria-label]="listLabel()"
    >
      <ng-content select="[list]" />
    </section>

    @if (layout.wideDetail()) {
      <section class="flex h-app min-w-0 flex-1 flex-col overflow-y-auto bg-bg" aria-live="polite">
        @if (open()) {
          <ng-container [ngTemplateOutlet]="detail" />
        } @else {
          <div class="flex flex-1 flex-col items-center justify-center gap-3 text-muted">
            <span class="icon text-[40px] text-subtle" aria-hidden="true">arrow_back</span>
            <span class="text-sm leading-none">{{ emptyText() }}</span>
          </div>
        }
      </section>
    } @else if (open()) {
      @if (!layout.compact()) {
        <div
          class="fixed inset-0 z-[44] animate-fade bg-overlay"
          aria-hidden="true"
          (click)="closed.emit()"
        ></div>
      }
      <section
        role="dialog"
        aria-modal="true"
        [attr.aria-label]="detailLabel()"
        class="fixed inset-y-0 right-0 z-[45] flex flex-col overflow-y-auto border-l border-border bg-bg shadow-raised"
        [class.w-screen]="layout.compact()"
        [class.w-[min(560px,92vw)]]="!layout.compact()"
        cdkTrapFocus
        [cdkTrapFocusAutoCapture]="true"
        (keydown.escape)="closed.emit()"
      >
        <ng-container [ngTemplateOutlet]="detail" />
      </section>
    }
  `,
})
export class ListDetail {
  protected readonly layout = inject(Layout);

  /** Something is selected (wide: shown beside the list; narrow: slid over it). */
  readonly open = input.required<boolean>();
  readonly listLabel = input.required<string>();
  readonly detailLabel = input('Details');
  readonly emptyText = input('Select an item to see details');
  /** Scrim, Escape or the detail's close button: the page clears the selection. */
  readonly closed = output<void>();
}
