import { Routes } from '@angular/router';
import { MATERIAL_DEFAULTS } from '../../shared/material/material-defaults';

export const SETTINGS_ROUTES: Routes = [
  {
    path: '',
    providers: [MATERIAL_DEFAULTS],
    title: 'Settings · ARQ',
    loadComponent: () => import('./settings-page').then((m) => m.SettingsPage),
    // The selection, read by the page (childParams): /settings/games/<game>.
    children: [
      { path: ':section', children: [] },
      { path: ':section/:tab', children: [] },
      { path: ':section/:tab/:item', children: [] },
    ],
  },
];
