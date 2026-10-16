import { Navigate, useLocation } from 'react-router-dom';
import type { ReactNode } from 'react';
import { useAuth } from './AuthProvider';
import { FullScreenLoader } from '../components/ui';

/**
 * Guarda das rotas administrativas: só renderiza quando a sessão foi validada no
 * servidor e o perfil confirmado como admin ativo (ver verifyAdmin). Qualquer
 * outro estado redireciona para o login — inclusive acesso direto por URL.
 */
export function RequireAdmin({ children }: { children: ReactNode }) {
  const { state } = useAuth();
  const location = useLocation();

  if (state.status === 'loading') return <FullScreenLoader label="Verificando acesso…" />;
  if (state.status !== 'admin') {
    return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />;
  }
  return <>{children}</>;
}
