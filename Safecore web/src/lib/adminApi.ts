import { FunctionsHttpError } from '@supabase/supabase-js';
import { supabase } from './supabase';
import type { Role } from './types';

/** Chama a Edge Function admin-users (operações com privilégio do Supabase Auth). */
async function call<T = { ok: boolean }>(body: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.functions.invoke('admin-users', { body });
  if (error) {
    if (error instanceof FunctionsHttpError) {
      const payload = await error.context.json().catch(() => null);
      throw new Error(payload?.error ?? 'Falha na operação administrativa.');
    }
    throw new Error(
      'Não foi possível contatar a Edge Function admin-users. Verifique se ela foi publicada no Supabase.',
    );
  }
  return data as T;
}

export const setPasswordUrl = () => `${window.location.origin}/definir-senha`;

export interface NewEmployee {
  full_name: string;
  email: string;
  phone: string;
  job_title: string;
  role: Role;
  mode: 'password' | 'invite';
  password?: string;
}

export const adminApi = {
  createEmployee: (e: NewEmployee) =>
    call<{ user_id: string; mode: string }>({ action: 'create', ...e, redirect_to: setPasswordUrl() }),
  updateEmail: (userId: string, email: string) =>
    call({ action: 'update_email', user_id: userId, email }),
  setPassword: (userId: string, password: string) =>
    call({ action: 'set_password', user_id: userId, password }),
  sendRecovery: (userId: string) =>
    call({ action: 'send_recovery', user_id: userId, redirect_to: setPasswordUrl() }),
  setActive: (userId: string, active: boolean) =>
    call({ action: 'set_active', user_id: userId, active }),
  deleteEmployee: (userId: string) => call({ action: 'delete', user_id: userId }),
};
