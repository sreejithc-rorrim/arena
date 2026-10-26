import { Routes } from '@angular/router';
import { MATERIAL_DEFAULTS } from '../../shared/material/material-defaults';

/** Expenses (money permission, from the nav entry): the list, salaries and reports tabs. */
export const EXPENSES_ROUTES: Routes = [
  {
    path: '',
    providers: [MATERIAL_DEFAULTS],
    title: 'Expenses · ARQ',
    loadComponent: () => import('./expenses-page').then((m) => m.ExpensesPage),
  },
  {
    path: 'salaries',
    providers: [MATERIAL_DEFAULTS],
    title: 'Salaries · Expenses · ARQ',
    loadComponent: () => import('./salaries-page').then((m) => m.SalariesPage),
  },
  {
    path: 'reports',
    providers: [MATERIAL_DEFAULTS],
    title: 'Expense reports · ARQ',
    loadComponent: () => import('./reports-page').then((m) => m.ReportsPage),
  },
];
