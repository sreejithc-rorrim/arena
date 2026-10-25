/** One staff profile of the arena (inactive ones too), as Team lists it. */
export interface TeamMember {
  readonly id: string;
  readonly userId: string;
  readonly name: string;
  readonly role: 'owner' | 'staff';
  readonly active: boolean;
  readonly createdAt: string;
}

/**
 * Who Team lists: every staff member. Owners are managed in Settings › Owners & access, so
 * owning the venue never makes someone part of Team.
 */
export function isEmployee(s: TeamMember): boolean {
  return s.role !== 'owner';
}
