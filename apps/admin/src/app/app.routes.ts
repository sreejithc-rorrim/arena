import { Routes } from '@angular/router';
import { arenaGuard, noArenaGuard, permGuard } from './core/arena/arena-context';
import { signedInGuard, signedOutGuard } from './core/auth/session';
import { NAV_ITEMS } from './core/layout/nav';
import { capabilityGuard } from './core/venue/venue';
import { Shell } from './core/layout/shell';
import { CONFIG_PROBLEM } from './core/supabase/supabase';
import { MATERIAL_DEFAULTS } from './shared/material/material-defaults';

/** Screens built so far replace their placeholder here with lazy-loaded feature routes. */
const BUILT: Readonly<Record<string, () => Promise<Routes>>> = {
  overview: () => import('./features/overview/overview.routes').then((m) => m.OVERVIEW_ROUTES),
  sales: () => import('./features/sales/sales.routes').then((m) => m.SALES_ROUTES),
  pricing: () => import('./features/pricing/pricing.routes').then((m) => m.PRICING_ROUTES),
  stations: () => import('./features/stations/stations.routes').then((m) => m.STATIONS_ROUTES),
  members: () => import('./features/members/members.routes').then((m) => m.MEMBERS_ROUTES),
  settings: () => import('./features/settings/settings.routes').then((m) => m.SETTINGS_ROUTES),
  'staff/team': () => import('./features/team/team.routes').then((m) => m.TEAM_ROUTES),
};

const APP_ROUTES: Routes = [
  {
    // Opened from the invitation e-mail, signed in or not: the page signs the person in itself.
    path: 'accept-invite',
    title: 'Accept invitation · ARQ',
    loadComponent: () => import('./features/auth/accept-invite').then((m) => m.AcceptInvite),
  },
  {
    // Opened from the password-reset e-mail, signed in or not: the link signs the person in.
    path: 'reset-password',
    title: 'Choose a new password · ARQ',
    loadComponent: () => import('./features/auth/reset-password').then((m) => m.ResetPassword),
  },
  {
    path: 'sign-in',
    title: 'Sign in · ARQ',
    canMatch: [signedOutGuard],
    loadComponent: () => import('./features/auth/sign-in').then((m) => m.SignIn),
  },
  {
    path: 'register',
    title: 'Create account · ARQ',
    canMatch: [signedOutGuard],
    loadComponent: () => import('./features/auth/register').then((m) => m.Register),
  },
  {
    // Only a login with no membership at all (a new owner); everyone else is sent where they belong.
    path: 'create-arena',
    title: 'Create your arena · ARQ',
    canMatch: [signedInGuard, noArenaGuard],
    loadComponent: () => import('./features/auth/create-arena').then((m) => m.CreateArena),
  },
  {
    // A signed-in login the dashboard is not for (floor staff, access turned off), or whose access
    // could not be read: says which, and what to do.
    path: 'account',
    title: 'Your access · ARQ',
    canMatch: [signedInGuard],
    loadComponent: () => import('./features/auth/account-access').then((m) => m.AccountAccess),
  },
  {
    path: '',
    component: Shell,
    canMatch: [signedInGuard, arenaGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'overview' },
      // Self-service setup for a new venue (create-arena lands here); not in the nav.
      {
        path: 'setup',
        title: 'Set up your venue · ARQ',
        providers: [MATERIAL_DEFAULTS],
        loadComponent: () => import('./features/setup/setup-page').then((m) => m.SetupPage),
      },
      // The games library moved into Settings; keep old links working.
      { path: 'games', pathMatch: 'full', redirectTo: 'settings/games' },
      // Accessories moved into Stations; keep old links working.
      { path: 'controllers', pathMatch: 'full', redirectTo: 'stations' },
      // Users was split: employees and their access on Team, owners in Settings.
      { path: 'users', pathMatch: 'full', redirectTo: 'staff/team' },
      // A nav entry without a BUILT screen shows a placeholder.
      ...NAV_ITEMS.map((item) =>
        BUILT[item.path]
          ? {
              path: item.path,
              canMatch: [
                ...(item.requires ? [capabilityGuard(item.requires)] : []),
                ...(item.perm ? [permGuard(item.perm)] : []),
              ],
              loadChildren: BUILT[item.path],
            }
          : {
              path: item.path,
              canMatch: item.perm ? [permGuard(item.perm)] : [],
              title: `${item.label} · ARQ`,
              // Overview is a plain page; every other screen is a list/detail frame.
              data: { heading: item.label, kind: item.path === 'overview' ? 'page' : 'list' },
              loadComponent: () =>
                import('./shared/screen-placeholder').then((m) => m.ScreenPlaceholder),
            },
      ),
    ],
  },
  // Signed out (or no arena yet): the guards above send the visitor where they belong.
  { path: '**', redirectTo: '' },
];

/** A build that cannot be used as configured shows only why (core/supabase configProblem). */
const CONFIG_ERROR_ROUTES: Routes = [
  {
    path: '**',
    title: 'Setup needed · ARQ',
    loadComponent: () => import('./features/auth/config-error').then((m) => m.ConfigError),
  },
];

export const routes: Routes = CONFIG_PROBLEM ? CONFIG_ERROR_ROUTES : APP_ROUTES;
