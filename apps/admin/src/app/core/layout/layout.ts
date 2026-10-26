import { BreakpointObserver } from '@angular/cdk/layout';
import { Service, effect, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { map } from 'rxjs';

/**
 * Responsive layout state. Breakpoints:
 * - compact (< 900px): a bottom bar of quick links; the full nav is a sheet opened from its More
 * - rail (900–1399px): the nav collapses to an 88px icon rail
 * - full (≥ 1400px): 264px nav with labels and group headings
 * - wideDetail (≥ 1180px): list/detail screens show both panes side by side
 */
@Service()
export class Layout {
  private readonly breakpoints = inject(BreakpointObserver);

  readonly compact = this.matches('(max-width: 899.98px)');
  readonly rail = this.matches('(min-width: 900px) and (max-width: 1399.98px)');
  readonly wideDetail = this.matches('(min-width: 1180px)');

  /** More sheet state; only used while compact (on wider screens the nav is always shown). */
  readonly navOpen = signal(false);

  constructor() {
    // Leaving compact must not leave a stale open drawer behind for the next time.
    effect(() => {
      if (!this.compact()) this.navOpen.set(false);
    });
  }

  toggleNav(): void {
    this.navOpen.update((open) => !open);
  }

  closeNav(): void {
    this.navOpen.set(false);
  }

  private matches(query: string) {
    return toSignal(this.breakpoints.observe(query).pipe(map((state) => state.matches)), {
      initialValue: this.breakpoints.isMatched(query),
    });
  }
}
