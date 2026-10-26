import { A11yModule } from '@angular/cdk/a11y';
import { CdkMenu, CdkMenuItemRadio, CdkMenuTrigger } from '@angular/cdk/menu';
import { NgOptimizedImage } from '@angular/common';
import { Component, computed, effect, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter, map } from 'rxjs';
import { ACCESS_HOME, ArenaContext } from '../arena/arena-context';
import { Session } from '../auth/session';
import { RealtimeSync } from '../sync/realtime-sync';
import { Layout } from './layout';
import { VenueStore } from '../venue/venue';
import { NAV_GROUPS } from './nav';

/**
 * App frame from the design: side nav (88px rail / 264px full) + routed page; when compact, a
 * bottom bar of quick links with the full nav in a More sheet.
 */
@Component({
  selector: 'app-shell',
  imports: [
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    A11yModule,
    CdkMenuTrigger,
    CdkMenu,
    CdkMenuItemRadio,
    NgOptimizedImage,
  ],
  templateUrl: './shell.html',
  host: {
    class: 'flex h-dvh overflow-hidden bg-bg text-fg',
    // Panes (h-app) end above the compact quick links bar.
    '[style.--app-bottom-bar]': "layout.compact() ? 'var(--spacing-bottom-bar)' : null",
  },
})
export class Shell {
  protected readonly layout = inject(Layout);
  protected readonly arenaContext = inject(ArenaContext);
  protected readonly session = inject(Session);
  /** Injected so live updates run while the dashboard is open (it follows user and arena). */
  private readonly realtime = inject(RealtimeSync);
  private readonly router = inject(Router);

  private readonly venue = inject(VenueStore);
  /**
   * The nav for this venue and member: capability-gated entries hidden, permission-gated ones
   * shown only to holders (the owner holds every permission), Stations named by its noun.
   */
  protected readonly navGroups = computed(() => {
    const caps = this.venue.capabilities();
    const many = this.venue.words().many;
    return NAV_GROUPS.map((group) => ({
      ...group,
      items: group.items
        .filter((item) => !item.requires || !caps || caps.has(item.requires))
        .filter((item) => !item.perm || this.arenaContext.hasPerm(item.perm))
        .map((item) => (item.venueNoun ? { ...item, label: many } : item)),
    })).filter((group) => group.items.length);
  });
  /** The compact bottom bar's links (this member's quick destinations). */
  protected readonly quickLinks = computed(() =>
    this.navGroups()
      .flatMap((group) => group.items)
      .filter((item) => item.quick),
  );
  private readonly url = toSignal(
    this.router.events.pipe(
      filter((e) => e instanceof NavigationEnd),
      map(() => this.router.url),
    ),
    { initialValue: this.router.url },
  );
  /** More is highlighted while the page open is not one of the quick links. */
  protected readonly moreActive = computed(() => {
    const path = this.url().split(/[?#]/)[0];
    return !this.quickLinks().some(
      (item) => path === '/' + item.path || path.startsWith('/' + item.path + '/'),
    );
  });
  protected readonly rail = computed(() => !this.layout.compact() && this.layout.rail());
  protected readonly navShown = computed(() => !this.layout.compact() || this.layout.navOpen());
  /** The name this arena knows the owner by, else the login's own name or e-mail. */
  protected readonly ownerName = computed(
    () => this.arenaContext.currentMembership()?.name || this.session.user()?.name || '',
  );
  protected readonly ownerInitials = computed(() =>
    this.ownerName()
      .split(/[\s@.]+/)
      .filter(Boolean)
      .map((word) => word[0])
      .slice(0, 2)
      .join('')
      .toUpperCase(),
  );

  constructor() {
    // The selected arena's capabilities and noun, for the nav and every screen.
    effect(() => {
      if (this.arenaContext.current().id) void this.venue.load();
    });
    effect(() => {
      // Signed out from elsewhere (another tab, or the refresh token was rejected): leave the
      // dashboard instead of keeping the previous login's figures on screen.
      if (!this.session.user()) {
        void this.router.navigate(['/sign-in']);
      } else if (!this.arenaContext.loaded()) {
        // Another login signed in (in another tab): open the dashboard for it, through the guards.
        void this.router.navigateByUrl('/');
      } else if (this.arenaContext.access() !== 'owner') {
        // Access to every arena it managed was turned off or narrowed to floor work (live staff
        // change): leave, as the arena guard would on a reload (never to Create Arena for staff).
        void this.router.navigateByUrl(ACCESS_HOME[this.arenaContext.access()]);
      }
    });
  }
}
