import { BreakpointObserver } from '@angular/cdk/layout';
import { TestBed } from '@angular/core/testing';
import { MATERIAL_ANIMATIONS } from '@angular/material/core';
import { Router, provideRouter, withComponentInputBinding } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import { of } from 'rxjs';
import { routes } from '../app.routes';
import { ArenaApi } from '../core/arena/arena-api';
import { SampleArenaApi } from '../core/arena/arena-api.sample';
import { AuthApi } from '../core/auth/auth-api';
import { SampleAuthApi } from '../core/auth/auth-api.sample';
import { FloorApi } from '../core/floor/floor-api';
import { SampleFloorApi } from '../core/floor/floor-api.sample';
import { Clock } from '../core/time/clock';
import { AccessoriesApi } from '../features/accessories/data/accessories-api';
import { SampleAccessoriesApi } from '../features/accessories/data/accessories-api.sample';
import { PricingApi } from '../features/pricing/data/pricing-api';
import { FloorOptionsApi } from '../features/settings/data/floor-options';
import { SampleFloorOptionsApi } from '../features/settings/data/floor-options.sample';
import { SamplePricingApi } from '../features/pricing/data/pricing-api.sample';
import { SalesApi } from '../features/sales/data/sales-api';
import { SampleSalesApi } from '../features/sales/data/sales-api.sample';
import { TeamApi } from '../features/team/data/team-api';
import { SampleTeamApi } from '../features/team/data/team-api.sample';

/** 7:30 pm IST on a Tuesday: the sample floor's "now". */
export const NOW = new Date('2026-10-13T14:00:00Z');

/** Pretend the window is `width` px wide (the Layout service reads the CDK breakpoints). */
function breakpoints(width: number) {
  const matches = (query: string) => {
    const min = /min-width:\s*([\d.]+)px/.exec(query);
    const max = /max-width:\s*([\d.]+)px/.exec(query);
    return (!min || width >= +min[1]) && (!max || width <= +max[1]);
  };
  return {
    isMatched: matches,
    observe: (q: string) => of({ matches: matches(q), breakpoints: {} }),
  };
}

/**
 * Opens a dashboard URL on the sample APIs (floor, pricing, sales, accessories) at NOW, and
 * returns DOM helpers shared by the screen specs.
 */
export async function startPage(
  path: string,
  width = 1440,
  setup: (apis: {
    floor: SampleFloorApi;
    pricing: SamplePricingApi;
    sales: SampleSalesApi;
    accessories: SampleAccessoriesApi;
    arena: SampleArenaApi;
    team: SampleTeamApi;
  }) => void = () => undefined,
) {
  const floor = new SampleFloorApi(NOW);
  const pricing = new SamplePricingApi();
  const sales = new SampleSalesApi(NOW);
  const floorOptions = new SampleFloorOptionsApi();
  const accessories = new SampleAccessoriesApi();
  const arena = new SampleArenaApi();
  const team = new SampleTeamApi();
  setup({
    floor,
    pricing,
    sales,
    accessories,
    arena,
    team,
  });
  TestBed.configureTestingModule({
    providers: [
      provideRouter(routes, withComponentInputBinding()),
      { provide: AuthApi, useValue: new SampleAuthApi() },
      { provide: ArenaApi, useValue: arena },
      { provide: FloorApi, useValue: floor },
      { provide: AccessoriesApi, useValue: accessories },
      { provide: PricingApi, useValue: pricing },
      { provide: SalesApi, useValue: sales },
      { provide: FloorOptionsApi, useValue: floorOptions },
      { provide: TeamApi, useValue: team },
      { provide: Clock, useValue: { now: () => NOW } },
      { provide: BreakpointObserver, useValue: breakpoints(width) },
      { provide: MATERIAL_ANIMATIONS, useValue: { animationsDisabled: true } },
    ],
  });
  const harness = await RouterTestingHarness.create();
  await harness.navigateByUrl(path);

  async function settle() {
    for (let i = 0; i < 3; i++) {
      await harness.fixture.whenStable();
      await new Promise((r) => setTimeout(r));
    }
    await harness.fixture.whenStable();
  }
  await settle();

  const doc = () => harness.routeNativeElement?.ownerDocument as Document;
  /** Visible text with one space between text nodes (spans next to each other stay apart). */
  const text = (el: Element | null | undefined) => {
    if (!el) return undefined;
    const walker = el.ownerDocument.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    const parts: string[] = [];
    for (let n = walker.nextNode(); n; n = walker.nextNode()) {
      const t = n.textContent?.replace(/\s+/g, ' ').trim();
      if (t) parts.push(t);
    }
    return parts.join(' ');
  };
  const button = (label: string, scope: ParentNode = doc()) =>
    [...scope.querySelectorAll('button, a')].find((b) => text(b)?.includes(label)) as
      HTMLButtonElement | undefined;
  const rows = () => [...doc().querySelectorAll('app-list-row a')] as HTMLElement[];
  const rowText = (r: HTMLElement) =>
    [...r.querySelectorAll('span.truncate, app-status-pill')].map((e) => text(e));
  const snack = () => text(doc().querySelector('mat-snack-bar-container'));
  const dialog = () => doc().querySelector('mat-dialog-container') as HTMLElement | null;
  const url = () => TestBed.inject(Router).url;

  function type(label: string, value: string, scope: ParentNode = doc()) {
    const field = [...scope.querySelectorAll('mat-form-field')].find((f) =>
      f.querySelector('mat-label')?.textContent?.includes(label),
    );
    const input = field?.querySelector('input') as HTMLInputElement;
    input.value = value;
    input.dispatchEvent(new Event('input'));
  }

  /** The overlays (dialogs, snackbars) live outside the fixture: clear them between tests. */
  function cleanup() {
    doc()
      ?.querySelectorAll('.cdk-overlay-container')
      .forEach((c) => c.remove());
  }

  return {
    harness,
    floor,
    pricing,
    sales,
    floorOptions,
    accessories,
    arena,
    team,
    settle,
    doc,
    text,
    button,
    rows,
    rowText,
    snack,
    dialog,
    url,
    type,
    cleanup,
  };
}

export type PageTest = Awaited<ReturnType<typeof startPage>>;
