import { Component, computed, effect, inject, input, output, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { MatAnchor, MatButton } from '@angular/material/button';
import { MatChipListbox, MatChipListboxChange, MatChipOption } from '@angular/material/chips';
import { MatDialog } from '@angular/material/dialog';
import { MatFormField, MatPrefix } from '@angular/material/form-field';
import { MatIcon } from '@angular/material/icon';
import { MatInput } from '@angular/material/input';
import { MatProgressBar } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { map } from 'rxjs';
import { ArenaContext } from '../../../core/arena/arena-context';
import { FloorRead, FloorStore } from '../../../core/floor/floor-store';
import { Game } from '../../../core/floor/floor.models';
import { injectNow } from '../../../core/time/ticker';
import { VenueStore } from '../../../core/venue/venue';
import { DetailPane, EmbeddedDetail } from '../../../shared/list-detail/detail-pane';
import { StatusPill } from '../../../shared/status-pill/status-pill';
import { formatMinutes } from '../../../shared/time/ist';
import { PricingStore } from '../../pricing/data/pricing-store';
import {
  ageTone,
  gameIcon,
  gameStations,
  knownPlatforms,
  libraryOrder,
  platformLabel,
  playableCount,
  playModesShort,
} from '../data/game-view';
import { GameDialog, GameDialogData, GameDialogResult } from '../dialogs/game-dialog';
import { GameDetail } from './game-detail';

const GAMES = '/settings/games';

/**
 * Settings › Games: the catalog staff pick from, as a table (platform, play modes, players per
 * station, age, 30-day play, status), searchable and filtered by platform (`?platform=PS5`). Shown in the Settings detail pane beside the Settings
 * list; a game opens in its place at `/settings/games/<game>`.
 */
@Component({
  selector: 'app-games-library',
  imports: [
    DetailPane,
    EmbeddedDetail,
    GameDetail,
    StatusPill,
    MatAnchor,
    MatButton,
    MatChipListbox,
    MatChipOption,
    MatFormField,
    MatPrefix,
    MatIcon,
    MatInput,
    MatProgressBar,
    RouterLink,
  ],
  template: `
    <app-detail-pane
      crumb="Settings / Games"
      icon="stadia_controller"
      heading="Games"
      [subtitle]="subtitleLine()"
      (closed)="closed.emit()"
    >
      <button actions mat-flat-button type="button" [disabled]="!arena.canEdit()" (click)="add()">
        <mat-icon aria-hidden="true">add</mat-icon>Add
      </button>

      @if (gameId()) {
        <div>
          <a mat-button [routerLink]="games" queryParamsHandling="preserve" class="-ml-3">
            <mat-icon aria-hidden="true">arrow_back</mat-icon>All games
          </a>
        </div>
        @if (selected(); as g) {
          <app-game-detail
            appEmbeddedDetail
            [game]="g"
            [stats]="stats().get(g.id)"
            [now]="now()"
            (closed)="toList()"
            (edit)="edit(g)"
            (deleted)="toList()"
          />
        } @else if (floor.errorOf(reads); as error) {
          <p role="alert" class="text-sm text-danger">{{ error }}</p>
        } @else if (loading()) {
          <mat-progress-bar mode="indeterminate" aria-label="Loading game" />
        } @else {
          <p class="text-sm leading-[1.4] text-muted">This game no longer exists.</p>
        }
      } @else {
        <div class="flex flex-col gap-3">
          <mat-form-field class="arena-search">
            <mat-icon matPrefix aria-hidden="true">search</mat-icon>
            <input
              matInput
              type="search"
              aria-label="Search games"
              placeholder="Search games"
              [value]="query()"
              (input)="query.set($any($event.target).value)"
            />
          </mat-form-field>
          @if (chips().length > 1) {
            <mat-chip-listbox aria-label="Platform" [value]="platform()" (change)="pick($event)">
              @for (c of chips(); track c.key) {
                <mat-chip-option [value]="c.key" [selectable]="c.key !== platform()">{{
                  c.label
                }}</mat-chip-option>
              }
            </mat-chip-listbox>
          }
        </div>
        @if (loading()) {
          <mat-progress-bar mode="indeterminate" aria-label="Loading games" />
        }
        @if (floor.errorOf(reads); as error) {
          <div class="flex flex-col items-center gap-3 px-4 py-12 text-center">
            <p role="alert" class="text-sm text-danger">{{ error }}</p>
            <button mat-stroked-button type="button" (click)="load(true)">Try again</button>
          </div>
        } @else if (!loading() || floor.games().length) {
          @if (filtered().length) {
            <div class="-mx-2 overflow-x-auto">
              <table class="w-full min-w-[720px] border-collapse text-left text-[13px] leading-[1.3]">
                <caption class="sr-only">
                  Games
                </caption>
                <thead>
                  <tr class="border-b border-border text-xs text-muted">
                    <th scope="col" class="px-2 py-2 font-medium">Game</th>
                    <th scope="col" class="px-2 py-2 font-medium">Platform</th>
                    <th scope="col" class="px-2 py-2 font-medium">Modes</th>
                    <th scope="col" class="px-2 py-2 text-right font-medium">Players</th>
                    <th scope="col" class="px-2 py-2 font-medium">Age</th>
                    <th scope="col" class="px-2 py-2 text-right font-medium">30 days</th>
                    <th scope="col" class="px-2 py-2 font-medium">Status</th>
                  </tr>
                </thead>
                <tbody>
                  @for (g of filtered(); track g.id) {
                    <tr
                      class="border-b border-border last:border-b-0 hover:bg-info-soft"
                      [class.text-muted]="!g.active"
                    >
                      <th scope="row" class="px-2 py-2 font-medium">
                        <a
                          [routerLink]="[games, g.id]"
                          queryParamsHandling="preserve"
                          class="flex items-center gap-2 text-fg no-underline underline-offset-2 hover:underline"
                        >
                          <span class="icon text-lg text-muted" aria-hidden="true">{{
                            icon(g)
                          }}</span>
                          <span class="min-w-0 [overflow-wrap:anywhere]">{{ g.name }}</span>
                        </a>
                      </th>
                      <td class="px-2 py-2 whitespace-nowrap">{{ platformOf(g) }}</td>
                      <td class="px-2 py-2">{{ modesOf(g) }}</td>
                      <td class="px-2 py-2 text-right tabular-nums">{{ g.maxLocalPlayers }}</td>
                      <td class="px-2 py-2">
                        @if (g.ageRating) {
                          <app-status-pill [tone]="ageTone(g.ageRating)"
                            >{{ g.ageRating }}+</app-status-pill
                          >
                        } @else {
                          <span class="text-subtle">—</span>
                        }
                      </td>
                      <td class="px-2 py-2 text-right whitespace-nowrap tabular-nums">
                        {{ played(g) }}
                      </td>
                      <td class="px-2 py-2">
                        <div class="flex flex-wrap gap-1">
                          @if (!g.active) {
                            <app-status-pill tone="info">Archived</app-status-pill>
                          } @else if (unplayable().has(g.id)) {
                            <app-status-pill
                              tone="warning"
                              title="Staff can't start this game anywhere yet"
                              >No station</app-status-pill
                            >
                          } @else {
                            <app-status-pill tone="primary">Available</app-status-pill>
                          }
                        </div>
                      </td>
                    </tr>
                  }
                </tbody>
              </table>
            </div>
          }
          @if (!filtered().length) {
            <p class="px-4 py-12 text-center text-sm leading-[1.4] text-muted">
              {{ floor.games().length ? 'No games match.' : 'No games yet. Add the first one.' }}
            </p>
          }
        }
      }
    </app-detail-pane>
  `,
})
export class GamesLibrary {
  protected readonly floor = inject(FloorStore);
  private readonly pricing = inject(PricingStore);
  private readonly venue = inject(VenueStore);
  protected readonly arena = inject(ArenaContext);
  private readonly router = inject(Router);
  private readonly dialog = inject(MatDialog);
  private readonly snack = inject(MatSnackBar);

  /** The game open (`/settings/games/<game>`), if any. */
  readonly gameId = input<string | undefined>(undefined);
  readonly closed = output<void>();

  protected readonly games = GAMES;
  /**
   * What this section reads (and reports errors for): the catalog, where each game is installed
   * and its 30-day figures aggregated on the server. A game's top players are read when opened.
   */
  protected readonly reads: readonly FloorRead[] = [
    'games',
    'stations',
    'gameResources',
    'gameFigures',
  ];
  protected readonly now = injectNow(60_000);
  protected readonly loading = computed(() => this.floor.loading());
  protected readonly query = signal('');
  /** `?platform=` — a platform code, or all. */
  private readonly platformParam = toSignal(
    inject(ActivatedRoute).queryParamMap.pipe(map((p) => p.get('platform'))),
  );

  protected readonly stats = computed(() => this.floor.gameFigures());
  protected readonly platforms = computed(() => knownPlatforms(this.floor.games()));
  protected readonly platform = computed(() => {
    const p = this.platformParam();
    return p && this.platforms().includes(p) ? p : 'all';
  });
  protected readonly chips = computed(() => [
    { key: 'all', label: 'All' },
    ...this.platforms().map((p) => ({ key: p, label: p })),
  ]);
  protected readonly filtered = computed(() => {
    const p = this.platform();
    const q = this.query().trim().toLowerCase();
    return libraryOrder(this.floor.games()).filter(
      (g) =>
        (p === 'all' || g.platforms.includes(p)) &&
        (!q || [g.name, ...g.aliases].some((x) => x.toLowerCase().includes(q))),
    );
  });
  /** Games staff could pick but no station lets them start (warned in the list). */
  protected readonly unplayable = computed(() => {
    if (!this.floor.gameResourcesReady() || !this.floor.stationsReady()) return new Set<string>();
    const stations = gameStations(this.floor.stations(), this.venue.gameTypeCodes());
    const byGame = this.floor.compatByGame();
    return new Set(
      this.floor
        .games()
        .filter((g) => g.active && playableCount(byGame.get(g.id), stations) === 0)
        .map((g) => g.id),
    );
  });
  protected readonly selected = computed<Game | undefined>(() => {
    const id = this.gameId();
    return id ? this.floor.gameById().get(id) : undefined;
  });
  protected readonly subtitleLine = computed(() => {
    const all = this.floor.games();
    const archived = all.filter((g) => !g.active).length;
    if (!all.length) return 'What staff pick from when starting a session';
    return [`${all.length - archived} available`, archived ? `${archived} archived` : '']
      .filter(Boolean)
      .join(' · ');
  });

  constructor() {
    effect(() => {
      if (this.arena.current().id) void this.load();
    });
  }

  protected load(force = false): void {
    void this.floor.load(this.reads, force);
    void this.pricing.load(force);
  }

  protected played(g: Game): string {
    return formatMinutes(this.stats().get(g.id)?.minutes30 ?? 0);
  }

  protected readonly platformOf = platformLabel;
  protected readonly modesOf = playModesShort;

  protected readonly ageTone = ageTone;

  protected icon(g: Game): string {
    return gameIcon(g);
  }

  protected pick(event: MatChipListboxChange): void {
    if (!event.value) return;
    void this.router.navigate([GAMES], {
      queryParams: { platform: event.value === 'all' ? null : event.value },
      queryParamsHandling: 'merge',
    });
  }

  protected toList(): void {
    void this.router.navigate([GAMES], { queryParamsHandling: 'preserve' });
  }

  protected add(): void {
    const platform = this.platform();
    this.open({
      platforms: this.platformChoices(),
      platform: platform === 'all' ? undefined : platform,
      stations: gameStations(this.floor.stations(), this.venue.gameTypeCodes()).map((s) => ({
        id: s.id,
        name: s.name,
      })),
    });
  }

  protected edit(game: Game): void {
    this.open({ platforms: this.platformChoices(), stations: [], game });
  }

  /** Platforms in use plus the game-based station types (what a game can be marked for). */
  private platformChoices(): string[] {
    const fromTypes = this.pricing
      .types()
      .filter((t) => t.usesGames && t.active)
      .map((t) => t.code);
    return knownPlatforms(this.floor.games(), fromTypes);
  }

  private open(data: GameDialogData): void {
    this.dialog
      .open<GameDialog, GameDialogData, GameDialogResult>(GameDialog, {
        data,
        width: '520px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((result) => {
        if (!result) return;
        this.snack.open(result.snack, undefined, { duration: 3200 });
        if (data.game) return;
        this.query.set('');
        void this.router.navigate([GAMES, result.id]);
      });
  }
}
