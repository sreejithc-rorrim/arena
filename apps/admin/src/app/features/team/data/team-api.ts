import { Service, inject } from '@angular/core';
import { dbError } from '../../../core/supabase/db-error';
import { Supabase } from '../../../core/supabase/supabase';
import { TeamMember } from './team.models';

/**
 * The current arena's staff profiles (inactive ones too), read through RLS. Team only reads:
 * invites, names and access go through the users API.
 */
@Service({ factory: () => new SupabaseTeamApi() })
export abstract class TeamApi {
  abstract load(arenaId: string): Promise<readonly TeamMember[]>;
}

type Row = Record<string, unknown>;

export function toTeamMember(r: Row): TeamMember {
  return {
    id: String(r['id']),
    userId: String(r['user_id'] ?? ''),
    name: String(r['name'] ?? ''),
    role: r['role'] === 'owner' ? 'owner' : 'staff',
    active: r['active'] === true,
    createdAt: String(r['created_at'] ?? ''),
  };
}

class SupabaseTeamApi extends TeamApi {
  private readonly supabase = inject(Supabase);

  async load(arenaId: string): Promise<readonly TeamMember[]> {
    const client = await this.supabase.client();
    const { data, error } = await client
      .from('staff_profiles')
      .select('id, user_id, name, role, active, created_at')
      .eq('arena_id', arenaId);
    if (error) throw dbError(error);
    return ((data as Row[]) ?? []).map(toTeamMember);
  }
}
