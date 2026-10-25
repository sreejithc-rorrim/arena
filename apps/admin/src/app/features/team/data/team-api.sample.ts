import { TeamApi } from './team-api';
import { TeamMember } from './team.models';

/** The sample arena's staff profiles (owner first; Kavya's access is off). */
export const SAMPLE_TEAM: readonly TeamMember[] = [
  { id: 'st0', userId: 'u0', name: 'Arjun Mehra', role: 'owner', active: true },
  { id: 'st1', userId: 'u1', name: 'Ravi Kumar', role: 'staff', active: true },
  { id: 'st2', userId: 'u2', name: 'Priya Nair', role: 'staff', active: true },
  { id: 'st3', userId: 'u3', name: 'Arjun Rao', role: 'staff', active: true },
  { id: 'st4', userId: 'u4', name: 'Kavya Iyer', role: 'staff', active: false },
].map((p) => ({ ...p, role: p.role as TeamMember['role'], createdAt: '2026-01-05T06:00:00Z' }));

/** Deterministic in-memory TeamApi for tests. */
export class SampleTeamApi extends TeamApi {
  staff: TeamMember[] = [...SAMPLE_TEAM];

  async load(): Promise<readonly TeamMember[]> {
    return this.staff;
  }
}
