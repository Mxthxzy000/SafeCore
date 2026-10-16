import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import type { User } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import { ROLE_LABEL } from '../lib/labels';
import type { Profile } from '../lib/types';

type AuthState =
  | { status: 'loading' }
  | { status: 'signedOut'; notice?: string }
  | { status: 'admin'; user: User; profile: Profile };

type Verification = { ok: true; user: User; profile: Profile } | { ok: false; reason: string };

interface AuthContextValue {
  state: AuthState;
  /** Revalida a sessão e o cargo no servidor. Encerra a sessão se não for admin. */
  refresh: () => Promise<Verification>;
  signOut: (notice?: string) => Promise<void>;
  /** Atualiza os dados do perfil do administrador logado (ex.: após editar o nome). */
  setProfile: (p: Profile) => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

/** Rotas públicas em que uma sessão de funcionário é legítima (definição de senha). */
const PUBLIC_SESSION_PATHS = ['/definir-senha'];
const isPublicSessionPath = () => PUBLIC_SESSION_PATHS.includes(window.location.pathname);

/**
 * Verificação de administrador. Nunca confia em estado local:
 *   1. getUser() valida o token no servidor do Supabase Auth;
 *   2. o perfil é lido da tabela profiles (sob RLS) e precisa ter role = 'admin' e estar ativo;
 *   3. a função is_admin() do banco precisa confirmar (mesma regra usada pelas políticas RLS).
 */
async function verifyAdmin(): Promise<Verification> {
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) return { ok: false, reason: 'Sessão inválida ou expirada. Entre novamente.' };
  const user = userData.user;

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .maybeSingle<Profile>();
  if (profileError) return { ok: false, reason: 'Não foi possível verificar seu perfil. Acesso negado.' };
  if (!profile) return { ok: false, reason: 'Perfil não encontrado. Acesso negado.' };
  if (profile.active === false) {
    return { ok: false, reason: 'Esta conta está desativada. Procure o administrador do sistema.' };
  }
  if (profile.role !== 'admin') {
    const label = ROLE_LABEL[profile.role] ?? 'funcionário';
    return {
      ok: false,
      reason: `Esta conta (${label}) é destinada ao aplicativo SafeCore Mobile. O SafeCore Web é exclusivo para administradores.`,
    };
  }

  const { data: isAdmin, error: rpcError } = await supabase.rpc('is_admin');
  if (rpcError || isAdmin !== true) {
    return { ok: false, reason: 'O banco de dados não confirmou a permissão de administrador. Acesso negado.' };
  }
  return { ok: true, user, profile };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ status: 'loading' });
  const inFlight = useRef<Promise<Verification> | null>(null);

  const signOut = useCallback(async (notice?: string) => {
    await supabase.auth.signOut().catch(() => undefined);
    setState({ status: 'signedOut', notice });
  }, []);

  const refresh = useCallback((): Promise<Verification> => {
    if (inFlight.current) return inFlight.current;
    const p = (async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) {
        setState((s) => (s.status === 'signedOut' ? s : { status: 'signedOut' }));
        return { ok: false, reason: 'Sessão não encontrada.' } as Verification;
      }
      const result = await verifyAdmin().catch(
        () => ({ ok: false, reason: 'Falha ao verificar a sessão. Tente novamente.' }) as Verification,
      );
      if (result.ok) {
        setState({ status: 'admin', user: result.user, profile: result.profile });
      } else {
        await signOut(result.reason);
      }
      return result;
    })().finally(() => {
      inFlight.current = null;
    });
    inFlight.current = p;
    return p;
  }, [signOut]);

  useEffect(() => {
    if (isPublicSessionPath()) {
      setState({ status: 'signedOut' });
    } else {
      refresh();
    }

    const { data: sub } = supabase.auth.onAuthStateChange((event) => {
      if (isPublicSessionPath()) return;
      if (event === 'SIGNED_OUT') {
        setState((s) => (s.status === 'signedOut' ? s : { status: 'signedOut' }));
      } else if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED' || event === 'USER_UPDATED') {
        // Fora do callback para não bloquear o cliente do Supabase
        setTimeout(() => refresh(), 0);
      }
    });

    // Alterações de cargo/desativação passam a valer sem recarregar a página
    const revalidate = () => {
      if (!isPublicSessionPath() && document.visibilityState === 'visible') refresh();
    };
    const timer = window.setInterval(revalidate, 2 * 60 * 1000);
    document.addEventListener('visibilitychange', revalidate);

    return () => {
      sub.subscription.unsubscribe();
      window.clearInterval(timer);
      document.removeEventListener('visibilitychange', revalidate);
    };
  }, [refresh]);

  const setProfile = useCallback((profile: Profile) => {
    setState((s) => (s.status === 'admin' ? { ...s, profile } : s));
  }, []);

  return (
    <AuthContext.Provider value={{ state, refresh, signOut, setProfile }}>{children}</AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth fora do AuthProvider');
  return ctx;
}

/** Perfil do administrador logado (somente dentro de rotas protegidas). */
export function useAdmin() {
  const { state } = useAuth();
  if (state.status !== 'admin') throw new Error('useAdmin fora de rota protegida');
  return state;
}
