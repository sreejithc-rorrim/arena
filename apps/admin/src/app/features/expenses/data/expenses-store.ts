import { Service, computed, inject, signal } from '@angular/core';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { LoginScope } from '../../../core/auth/login-scope';
import { Attempt, writeThenReload } from '../../../core/sync/push-ops';
import {
  CategoryInput,
  ExpenseInput,
  ExpensesApi,
  NewExpense,
  PaymentInput,
  SalaryInput,
} from './expenses-api';
import {
  Expense,
  ExpenseCategory,
  ExpensePayment,
  ExpensePeriod,
  ExpensesData,
  StaffSalary,
} from './expense.models';

/**
 * The current arena's expenses for one period (IST days), with its categories and agreed
 * salaries. Every write goes to the server first; the list, the categories and salaries it may
 * have changed, and any open detail (through `revision`) then reload to show what was recorded.
 */
@Service()
export class ExpensesStore {
  private readonly api = inject(ExpensesApi);
  private readonly arena = inject(ArenaContext);

  readonly data = signal<ExpensesData | null>(null);
  readonly expenses = computed(() => this.data()?.expenses ?? []);
  readonly payments = computed(() => this.data()?.payments ?? []);
  readonly byId = computed(() => new Map(this.expenses().map((e) => [e.id, e])));
  readonly loading = signal(false);
  readonly loadError = signal('');
  /** When the list last came from the server (null before the first load). */
  readonly loadedAt = signal<Date | null>(null);
  /** Bumped after a change so open details and other periods read again. */
  readonly revision = signal(0);

  /** Null until read (once per arena, again after a change to them). */
  readonly categories = signal<readonly ExpenseCategory[] | null>(null);
  /** Every agreed salary (each person's history). */
  readonly salaries = signal<readonly StaffSalary[]>([]);
  readonly metaError = signal('');

  /** Arena + period: another arena or period loads again. */
  private loadedKey: string | null = null;
  private outOfDate = false;
  private current: ExpensePeriod | null = null;
  private latest = 0;
  private metaArena: string | null = null;
  private metaLatest = 0;

  constructor() {
    // Sign-out or another login: the records leave memory; a read in flight does not land.
    inject(LoginScope).onEnd(() => {
      this.latest++;
      this.metaLatest++;
      this.loadedKey = null;
      this.current = null;
      this.metaArena = null;
      this.data.set(null);
      this.loading.set(false);
      this.loadError.set('');
      this.loadedAt.set(null);
      this.categories.set(null);
      this.salaries.set([]);
      this.metaError.set('');
    });
  }

  async load(period: ExpensePeriod, force = false): Promise<void> {
    this.current = period;
    const arenaId = this.arena.current().id;
    if (!arenaId) return;
    const meta = this.loadMeta();
    const key = `${arenaId}|${period.first}|${period.last}`;
    if (!force && !this.outOfDate && key === this.loadedKey) return meta;
    const call = ++this.latest;
    if (this.loadedKey !== key) this.data.set(null);
    this.outOfDate = false;
    this.loadedKey = key;
    this.loading.set(true);
    this.loadError.set('');
    try {
      const data = await this.api.list(arenaId, period.first, period.last);
      if (call === this.latest) {
        this.data.set(data);
        this.loadedAt.set(new Date());
      }
    } catch (e) {
      if (call === this.latest) {
        this.loadError.set(toAppError(e).message);
        this.loadedKey = null;
      }
    } finally {
      if (call === this.latest) this.loading.set(false);
    }
    await meta;
  }

  /** The categories and agreed salaries, once per arena unless `force`. */
  async loadMeta(force = false): Promise<void> {
    const arenaId = this.arena.current().id;
    if (!arenaId || (!force && this.metaArena === arenaId)) return;
    if (this.metaArena !== arenaId) {
      this.categories.set(null);
      this.salaries.set([]);
    }
    const call = ++this.metaLatest;
    this.metaArena = arenaId;
    this.metaError.set('');
    try {
      const [categories, salaries] = await Promise.all([
        this.api.categories(arenaId),
        this.api.salaries(arenaId),
      ]);
      if (call !== this.metaLatest) return;
      this.categories.set(categories);
      this.salaries.set(salaries);
    } catch (e) {
      if (call !== this.metaLatest) return;
      this.metaError.set(toAppError(e).message);
      this.metaArena = null;
    }
  }

  get(id: string) {
    return this.api.get(this.arena.current().id, id);
  }

  /** Another period than the list's (the Salaries month, the Reports trend). */
  list(first: string, last: string) {
    return this.api.list(this.arena.current().id, first, last);
  }

  staffRecord(staffId: string) {
    return this.api.staffSalary(this.arena.current().id, staffId);
  }

  catalog() {
    return this.api.catalog();
  }

  add(entry: NewExpense): Promise<void> {
    return this.write(() => this.api.add(this.arena.current().id, entry), !!entry.agreed);
  }

  update(expense: Expense, change: ExpenseInput, attempt?: Attempt): Promise<void> {
    return this.write(() => this.api.update(this.arena.current().id, expense, change, attempt));
  }

  pay(expense: Expense, payment: PaymentInput, attempt?: Attempt): Promise<void> {
    return this.write(() => this.api.pay(this.arena.current().id, expense, payment, attempt));
  }

  reverse(payment: ExpensePayment, reason: string, attempt?: Attempt): Promise<void> {
    return this.write(() => this.api.reverse(this.arena.current().id, payment, reason, attempt));
  }

  /** Resolves with how many payments were reversed with it. */
  void(expense: Expense, reason: string, reversePayments: boolean, attempt?: Attempt) {
    return this.write(() =>
      this.api.void(this.arena.current().id, expense, reason, reversePayments, attempt),
    );
  }

  setSalary(salary: SalaryInput, attempt?: Attempt): Promise<void> {
    return this.write(() => this.api.setSalary(this.arena.current().id, salary, attempt), true);
  }

  saveCategories(categories: readonly CategoryInput[]): Promise<void> {
    return this.write(() => this.api.saveCategories(this.arena.current().id, categories), true);
  }

  removeCategory(id: string) {
    return this.write(() => this.api.removeCategory(this.arena.current().id, id), true);
  }

  /**
   * Marks the data out of date without reading it (a live update while no screen shows it): the
   * next screen that loads it reads it again, instead of a download nobody looks at.
   */
  stale(): void {
    if (!this.loadedKey && !this.metaArena) return;
    this.outOfDate = true;
    this.metaArena = null;
    this.revision.update((n) => n + 1);
  }

  /**
   * A live update (another device or tab changed an expense), the Refresh button or a
   * reconnect: reloads what is shown and bumps `revision`, so an open detail reads it again.
   */
  async refresh(): Promise<void> {
    if (!this.current || (!this.loadedKey && !this.loadError())) return;
    this.revision.update((n) => n + 1);
    await Promise.all([this.load(this.current, true), this.loadMeta(true)]);
  }

  /**
   * Runs a write, then reloads the list (and the categories and salaries when `meta`), also when
   * part of a batch was applied before a refusal.
   */
  private async write<T>(change: () => Promise<T>, meta = false): Promise<T> {
    let result!: T;
    await writeThenReload(
      async () => {
        result = await change();
      },
      async () => {
        this.revision.update((n) => n + 1);
        await Promise.all([
          this.current ? this.load(this.current, true) : Promise.resolve(),
          meta ? this.loadMeta(true) : Promise.resolve(),
        ]);
      },
    );
    return result;
  }
}
