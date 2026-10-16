import { supabase } from './supabase';
import { must } from './useQuery';
import type { Area, Profile, Sensor } from './types';

// Consultas compartilhadas entre as páginas. O administrador enxerga todos os
// registros pelas políticas RLS (area_access = 3 e is_supervisor/is_admin).

export async function fetchAreas(includeArchived = true): Promise<Area[]> {
  let q = supabase.from('areas').select('*').order('name');
  if (!includeArchived) q = q.is('archived_at', null);
  return must(await q) as Area[];
}

export async function fetchProfiles(): Promise<Profile[]> {
  return must(await supabase.from('profiles').select('*').order('full_name')) as Profile[];
}

export async function fetchSensors(): Promise<Sensor[]> {
  return must(await supabase.from('sensors').select('*').order('code')) as Sensor[];
}

export const byId = <T extends { id: string }>(rows: T[] | null | undefined) =>
  new Map((rows ?? []).map((r) => [r.id, r]));
