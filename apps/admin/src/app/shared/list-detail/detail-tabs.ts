import { Component, input } from '@angular/core';
import { MatTabLink, MatTabNav, MatTabNavPanel } from '@angular/material/tabs';
import { RouterLink } from '@angular/router';
import { EMBEDDED_DETAIL } from './detail-pane';

export interface DetailTab {
  readonly key: string;
  readonly label: string;
  /** The tab's own URL: tabs are part of the route path (e.g. `/staff/team/<staff>/access`). */
  readonly link: string | readonly unknown[];
}

/**
 * Routable tabs inside a detail pane: a tab bar of links, then the projected content of the
 * `active` tab (the page picks it from the route). A detail pane projected here renders embedded,
 * as a titled block without its own top bar and hero (DetailPane).
 */
@Component({
  selector: 'app-detail-tabs',
  imports: [MatTabNav, MatTabLink, MatTabNavPanel, RouterLink],
  providers: [{ provide: EMBEDDED_DETAIL, useValue: true }],
  host: { class: 'flex flex-col gap-5' },
  template: `
    <nav
      mat-tab-nav-bar
      mat-stretch-tabs="false"
      mat-align-tabs="start"
      [tabPanel]="panel"
      [attr.aria-label]="label()"
    >
      @for (t of tabs(); track t.key) {
        <a mat-tab-link [routerLink]="t.link" [active]="t.key === active()">{{ t.label }}</a>
      }
    </nav>
    <mat-tab-nav-panel #panel class="flex flex-col gap-5"><ng-content /></mat-tab-nav-panel>
  `,
})
export class DetailTabs {
  readonly tabs = input.required<readonly DetailTab[]>();
  /** Key of the tab shown (from the route). */
  readonly active = input.required<string>();
  readonly label = input.required<string>();
}
