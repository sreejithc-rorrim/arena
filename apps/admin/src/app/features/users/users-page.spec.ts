import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { PageTest, startPage } from '../../testing/page-test';
import { UsersApi } from './data/users-api';
import { SampleUsersApi, sampleUsers } from './data/users-api.sample';

/**
 * Users was split (app.routes: /users → /staff/team): employees and their app access (staff
 * invitations, permission switches, turning access off) on Team; owners and owner invitations on
 * Settings › Owners & access.
 */
describe('Users › Team and Owners & access', () => {
  let t: PageTest;
  let api: SampleUsersApi;

  /**
   * Opens `url` on the sample APIs, with the Team list (staff_profiles, read by TeamStore)
   * matching the sample logins: s0 Arjun Mehra (owner), s1 Priya Nair, s2 Rohan Das, s3 Kavya
   * Iyer.
   */
  async function start(url: string, width = 1440) {
    api = new SampleUsersApi();
    TestBed.configureTestingModule({ providers: [{ provide: UsersApi, useValue: api }] });
    t = await startPage(url, width, ({ team }) => {
      team.staff = sampleUsers().map((u, i) => ({
        id: `s${i}`,
        userId: u.userId,
        name: u.name,
        role: u.role,
        active: u.active,
        createdAt: '2026-01-05T06:00:00Z',
      }));
    });
  }

  afterEach(() => t?.cleanup());

  const doc = () => t.doc();
  const employees = () =>
    [...doc().querySelectorAll('ul[aria-label="Employees"] app-list-row a')] as HTMLElement[];
  const detail = () => doc().querySelector('app-member-detail') as HTMLElement | null;
  const access = () => doc().querySelector('app-user-access') as HTMLElement | null;
  const owners = () => doc().querySelector('app-owners-access') as HTMLElement | null;
  const toggles = () =>
    [...(access()?.querySelectorAll('mat-slide-toggle button') ?? [])] as HTMLButtonElement[];
  const dialog = () => t.dialog() as HTMLElement;

  /** Becomes an owner-level member who is not an owner (role staff, every permission). */
  async function notAnOwner() {
    t.arena.memberships = t.arena.memberships.map((m) => ({ ...m, role: 'staff' as const }));
    // The memberships were read at start; reload them as the guard would on the next visit.
    const { ArenaContext } = await import('../../core/arena/arena-context');
    await TestBed.inject(ArenaContext).load(true);
    await t.settle();
  }

  const invites = () => doc().querySelector('section[aria-labelledby="users-invites"]');
  const inviteRows = () =>
    [...(invites()?.querySelectorAll('li') ?? [])].map((li) =>
      [...li.querySelectorAll('span.truncate, app-status-pill')].map((e) => t.text(e)),
    );

  it('lists employees on Team and owners on Settings › Owners & access', async () => {
    await start('/users');
    expect(t.url()).toBe('/staff/team');
    // Owners are not employees: only the staff are on Team.
    expect(employees().map(t.rowText)).toEqual([
      ['Kavya Iyer', 'Staff'],
      ['Priya Nair', 'Staff'],
      ['Rohan Das', 'Staff'],
    ]);

    await t.harness.navigateByUrl('/settings/owners');
    await t.settle();
    const ownersSection = owners()!.querySelector('app-detail-section')!;
    expect(
      [...ownersSection.querySelectorAll('span.truncate, app-status-pill')].map((e) => t.text(e)),
    ).toEqual(['Arjun Mehra', 'arjun@404arena.in', 'You']);
  });

  it('wide: says to pick someone until one is picked; the pick is in the URL', async () => {
    await start('/staff/team');
    expect(detail()).toBeNull();
    expect(doc().body.textContent).toContain(
      'Pick someone to see their details and access',
    );
    employees()[1].click();
    await t.settle();
    expect(t.url()).toBe('/staff/team/s1');
    expect(t.text(detail()?.querySelector('h2'))).toBe('Priya Nair');
    expect(detail()?.textContent).toContain('priya@404arena.in');
    expect(employees()[1].getAttribute('aria-current')).toBe('true');
  });

  it('narrow: the detail opens over the list and closes back to it', async () => {
    await start('/staff/team', 1024);
    expect(detail()).toBeNull();
    employees()[2].click();
    await t.settle();
    expect(doc().querySelector('[role="dialog"][aria-label="Employee"]')).not.toBeNull();
    (doc().querySelector('button[aria-label="Close"]') as HTMLButtonElement).click();
    await t.settle();
    expect(detail()).toBeNull();
  });

  it('toggling a staff permission saves it', async () => {
    await start('/staff/team/s2/access');
    expect(toggles().map((b) => b.getAttribute('aria-checked'))).toEqual([
      'true',
      'true',
      'false',
      'false',
      'false',
      'false',
    ]);
    toggles()[2].click(); // Give discounts
    await t.settle();
    expect(api.users.find((u) => u.userId === 'u2')?.perms).toEqual(['start', 'bill', 'discount']);
  });

  it('only an owner may switch Edit own bills and Add missed bills', async () => {
    await start('/staff/team/s2/access');
    await notAnOwner();
    expect(access()!.textContent).toContain(
      'Only an owner can give or take away Edit own bills and Add missed bills.',
    );
    // The floor ones stay a Settings holder's to change.
    expect(toggles().map((b) => b.disabled)).toEqual([false, false, false, false, true, true]);
  });

  it('neither bill permission is in the invite default', async () => {
    const { DEFAULT_STAFF_PERMS } = await import('./data/user.models');
    expect(DEFAULT_STAFF_PERMS).toEqual(['start', 'bill', 'members']);
  });

  it('an owner holding every permission shows as the owner, with no permission toggles', async () => {
    await start('/settings/owners');
    expect(t.text(owners())).toContain('Arjun Mehra');
    expect(access()).toBeNull();
    expect(t.text(owners())).not.toContain('Start sessions');
    expect(owners()!.querySelectorAll('app-toggle-row').length).toBe(0);
    // Not an employee: not on Team, and their Team link opens nothing.
    await t.harness.navigateByUrl('/staff/team/s0');
    await t.settle();
    expect(employees().map((r) => t.rowText(r)[0])).not.toContain('Arjun Mehra');
    expect(detail()).toBeNull();
  });

  it('turning off staff access asks first, then turns it off and says they are signed out', async () => {
    await start('/staff/team/s3/access');
    t.button('Turn off access', access()!)?.click();
    await t.settle();
    expect(dialog().textContent).toContain("Turn off Kavya Iyer's access?");
    expect(dialog().textContent).toContain('They are signed out of the floor app');
    t.button('Cancel', dialog())?.click();
    await t.settle();
    expect(api.users.find((u) => u.userId === 'u3')?.active).toBe(true);

    t.button('Turn off access', access()!)?.click();
    await t.settle();
    t.button('Turn off', dialog().querySelector('mat-dialog-actions')!)?.click();
    await t.settle();
    expect(api.users.find((u) => u.userId === 'u3')?.active).toBe(false);
    expect(t.snack()).toBe("Kavya Iyer's access turned off");
    expect(access()?.textContent).toContain('Turned off: they cannot sign in to this venue.');
    expect(t.button('Turn access back on', access()!)).toBeDefined();
  });

  it('add staff: checks the fields and e-mails a staff invitation, no password', async () => {
    await start('/staff/team');
    t.button('Add staff')?.click();
    await t.settle();
    expect(t.text(dialog().querySelector('h2'))).toContain('Add staff');
    expect(dialog().textContent).toContain('They choose their own password');
    expect(dialog().textContent).toContain('sign in on the staff app');
    expect(dialog().querySelector('input[type="password"]')).toBeNull();
    expect(dialog().textContent).not.toContain('Starting password');
    // Team never invites an owner (Settings › Owners & access does).
    expect(t.button('Owner', dialog())).toBeUndefined();

    t.button('Send invitation', dialog())?.click();
    await t.settle();
    expect(t.text(dialog().querySelector('[role="alert"]'))).toBe('Enter a name');

    t.type('Name', 'Farhan Ali', dialog());
    t.type('Email', 'priya@404arena.in', dialog());
    t.button('Send invitation', dialog())?.click();
    await t.settle();
    expect(t.text(dialog().querySelector('[role="alert"]'))).toBe(
      'That email already has access to this arena',
    );
    expect(api.sent).toEqual([]);

    t.type('Email', 'Farhan@404arena.in', dialog());
    t.button('Send invitation', dialog())?.click();
    await t.settle();
    expect(t.dialog()).toBeNull();
    expect(t.snack()).toBe('Invitation sent to farhan@404arena.in');
    expect(api.sent).toEqual([
      {
        role: 'staff',
        name: 'Farhan Ali',
        email: 'farhan@404arena.in',
        perms: ['start', 'bill', 'members'],
      },
    ]);
    expect('password' in api.sent[0]).toBe(false);
    // Nobody joins until they accept: the team is unchanged, the invitation is pending.
    expect(t.url()).toBe('/staff/team');
    expect(employees()).toHaveLength(3);
    expect(inviteRows()[0]).toEqual([
      'farhan@404arena.in',
      'Farhan Ali · Staff · invited by Arjun Mehra',
      'Expires 20 Oct',
    ]);
  });

  it('an owner can invite another owner from Settings › Owners & access', async () => {
    await start('/settings/owners');
    t.button('Invite an owner', owners()!)?.click();
    await t.settle();
    expect(t.text(dialog().querySelector('h2'))).toContain('Invite an owner');
    expect(dialog().textContent).toContain('manage the arena here with every permission');
    t.type('Name', 'Anand Paul', dialog());
    t.type('Email', 'anand@404arena.in', dialog());
    t.button('Send invitation', dialog())?.click();
    await t.settle();
    expect(t.snack()).toBe('Invitation sent to anand@404arena.in as an owner');
    expect(api.sent.at(-1)?.role).toBe('owner');
    // Still one owner until they accept; the invitation is listed with the owners.
    const ownerNames = owners()!
      .querySelector('app-detail-section')!
      .querySelectorAll('span.truncate.font-semibold');
    expect([...ownerNames].map((e) => t.text(e))).toEqual(['Arjun Mehra']);
    expect(t.text(invites()?.querySelector('h2'))).toBe('Owner invitations · 1');
    expect(inviteRows()[0]?.[1]).toBe('Anand Paul · Owner · invited by Arjun Mehra');
  });

  it('a refused invitation is explained in the dialog', async () => {
    await start('/staff/team');
    t.button('Add staff')?.click();
    await t.settle();
    t.type('Name', 'Farhan Ali', dialog());
    t.type('Email', 'farhan@404arena.in', dialog());
    api.failNext = 'email_rate_limited';
    t.button('Send invitation', dialog())?.click();
    await t.settle();
    expect(t.text(dialog().querySelector('[role="alert"]'))).toBe(
      'Too many e-mails right now. Wait a while, then try again',
    );
  });

  it('lists pending staff invitations with who invited them and until when', async () => {
    await start('/staff/team');
    expect(t.text(invites()?.querySelector('h2'))).toBe('Invited, not joined yet · 2');
    expect(inviteRows()).toEqual([
      ['farah@404arena.in', 'Farah Khan · Staff · invited by Arjun Mehra', 'Expires 19 Oct'],
      ['neha@404arena.in', 'Neha Joshi · Staff', 'Expired'],
    ]);
  });

  it('withdraws an invitation after confirming', async () => {
    await start('/staff/team');
    const withdraw = invites()?.querySelector(
      'button[aria-label="Withdraw the invitation to farah@404arena.in"]',
    ) as HTMLButtonElement;
    withdraw.click();
    await t.settle();
    expect(dialog().querySelector('h2')?.textContent).toContain(
      'Withdraw the invitation to farah@404arena.in?',
    );
    t.button('Withdraw', dialog().querySelector('mat-dialog-actions')!)?.click();
    await t.settle();
    expect(api.invites.map((i) => i.email)).toEqual(['neha@404arena.in']);
    expect(t.snack()).toBe('Invitation to farah@404arena.in withdrawn');
    expect(inviteRows().map((r) => r[0])).toEqual(['neha@404arena.in']);
  });

  it('a permission change the server adjusted reloads the list', async () => {
    await start('/staff/team/s2/access');
    api.adjustNext = true;
    const list = vi.spyOn(api, 'list');
    toggles()[2].click(); // Give discounts
    await t.settle();
    expect(list).toHaveBeenCalledTimes(1);
    expect(api.users.find((u) => u.userId === 'u2')?.perms).toEqual(['start', 'bill']);
    expect(toggles().map((b) => b.getAttribute('aria-checked'))).toEqual([
      'true',
      'true',
      'false',
      'false',
      'false',
      'false',
    ]);
  });

  it('owner-level staff (not an owner) cannot invite an owner', async () => {
    await start('/settings/owners');
    await notAnOwner();
    expect(t.button('Invite an owner', owners()!)).toBeUndefined();
    // Nor through Team: Add staff invites staff only.
    await t.harness.navigateByUrl('/staff/team');
    await t.settle();
    t.button('Add staff')?.click();
    await t.settle();
    expect(t.button('Owner', dialog())).toBeUndefined();
  });
});
