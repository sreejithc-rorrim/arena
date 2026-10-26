import { Capability } from '../venue/venue';

/**
 * Side-nav destinations (when compact: a bottom bar of the quick ones, the full list under More). Accessories (controllers, headsets…) live inside Stations, and station
 * types, accessory types and the games library inside Settings, so none has its own entry.
 */
export interface NavItem {
  /** Top-level route path. */
  readonly path: string;
  readonly label: string;
  /** Material Symbols name. */
  readonly icon: string;
  /** Shown (and routable) only for venues using this capability (core/venue). */
  readonly requires?: Capability;
  /**
   * Shown (and routable) only for members holding this permission in the current arena; the
   * owner holds every permission (ArenaContext.hasPerm).
   */
  readonly perm?: string;
  /** Labelled with the venue's own noun ("Tables", "Grounds") instead of `label`. */
  readonly venueNoun?: true;
  /** A quick link in the compact bottom bar (the rest are under More). */
  readonly quick?: true;
}

export interface NavGroup {
  readonly heading: string;
  readonly items: readonly NavItem[];
}

export const NAV_GROUPS: readonly NavGroup[] = [
  {
    heading: 'Reports',
    items: [
      { path: 'overview', label: 'Overview', icon: 'dashboard', quick: true },
      { path: 'sales', label: 'Sales', icon: 'receipt_long', quick: true },
      { path: 'expenses', label: 'Expenses', icon: 'account_balance_wallet', perm: 'money' },
    ],
  },
  {
    heading: 'Configure',
    items: [
      { path: 'stations', label: 'Stations', icon: 'grid_view', venueNoun: true, quick: true },
      { path: 'pricing', label: 'Pricing', icon: 'sell' },
    ],
  },
  {
    heading: 'People',
    items: [
      { path: 'members', label: 'Members', icon: 'group', quick: true },
    ],
  },
  {
    // Staff and their access on Team; the staff terms in Settings › Staff.
    heading: 'Staff',
    items: [
      // Everyone who can open the dashboard sees the team; each tab checks its permission.
      { path: 'staff/team', label: 'Team', icon: 'badge' },
    ],
  },
  { heading: 'Arena', items: [{ path: 'settings', label: 'Settings', icon: 'settings' }] },
];

export const NAV_ITEMS: readonly NavItem[] = NAV_GROUPS.flatMap((group) => group.items);
