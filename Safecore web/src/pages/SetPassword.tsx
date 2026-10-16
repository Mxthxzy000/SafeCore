import { useEffect, useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { CheckCircle2, Smartphone } from 'lucide-react';
import { Wordmark } from '../components/Brand';
import { Button, Field, FullScreenLoader, Notice } from '../components/ui';
import { supabase } from '../lib/supabase';
import { useAuth } from '../auth/AuthProvider';

/**
 * Página pública aberta pelos links de convite e de redefinição de senha.
 * Serve tanto para funcionários (que depois usam o app mobile) quanto para
 * administradores. Não dá acesso a nenhum dado administrativo: após definir
 * a senha, contas que não são admin têm a sessão encerrada.
 */
export function SetPassword() {
  const navigate = useNavigate();
  const { refresh } = useAuth();
  const [phase, setPhase] = useState<'checking' | 'form' | 'invalid' | 'done-mobile'>('checking');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const hash = new URLSearchParams(window.location.hash.slice(1));
    const linkError = hash.get('error_description') ?? new URLSearchParams(window.location.search).get('error_description');
    if (linkError) {
      setPhase('invalid');
      return;
    }
    let settled = false;
    const decide = (hasSession: boolean) => {
      if (settled) return;
      settled = true;
      setPhase(hasSession ? 'form' : 'invalid');
    };
    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session) decide(true);
    });
    supabase.auth.getSession().then(({ data }) => {
      if (data.session) decide(true);
      else setTimeout(() => supabase.auth.getSession().then(({ data: d }) => decide(Boolean(d.session))), 1500);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
      setError('A senha deve ter pelo menos 8 caracteres, com letras e números.');
      return;
    }
    if (password !== confirm) {
      setError('As senhas não conferem.');
      return;
    }
    setLoading(true);
    const { error: err } = await supabase.auth.updateUser({ password });
    if (err) {
      setLoading(false);
      setError(err.message.toLowerCase().includes('different')
        ? 'A nova senha precisa ser diferente da anterior.'
        : 'Não foi possível definir a senha. Solicite um novo link.');
      return;
    }

    const { data: userData } = await supabase.auth.getUser();
    const { data: profile } = userData.user
      ? await supabase.from('profiles').select('role, active').eq('id', userData.user.id).maybeSingle()
      : { data: null };

    window.history.replaceState(null, '', '/definir-senha');
    if (profile?.role === 'admin' && profile.active !== false) {
      const result = await refresh();
      setLoading(false);
      if (result.ok) navigate('/painel', { replace: true });
      else navigate('/login', { replace: true });
      return;
    }
    await supabase.auth.signOut();
    setLoading(false);
    setPhase('done-mobile');
  }

  if (phase === 'checking') return <FullScreenLoader label="Validando link…" />;

  return (
    <div className="center-page">
      <div className="login-card">
        <Wordmark size={30} />
        {phase === 'invalid' && (
          <>
            <h2>Link inválido ou expirado</h2>
            <Notice tone="warning">
              Este link de convite ou redefinição não é mais válido. Peça ao administrador um novo envio.
            </Notice>
            <Button variant="secondary" onClick={() => navigate('/login')}>Ir para o login</Button>
          </>
        )}
        {phase === 'done-mobile' && (
          <>
            <div className="success-mark"><CheckCircle2 size={40} /></div>
            <h2>Senha definida com sucesso</h2>
            <Notice tone="info">
              <span className="notice-row">
                <Smartphone size={18} />
                <span>Abra o aplicativo <strong>SafeCore Mobile</strong> e entre com seu e-mail e a nova senha.</span>
              </span>
            </Notice>
          </>
        )}
        {phase === 'form' && (
          <form onSubmit={onSubmit} className="stack" noValidate>
            <div className="login-head">
              <h2>Definir senha</h2>
              <p className="muted">Crie a senha de acesso da sua conta SafeCore.</p>
            </div>
            {error && <Notice tone="critical">{error}</Notice>}
            <Field label="Nova senha" hint="Mínimo de 8 caracteres, com letras e números.">
              <input type="password" autoComplete="new-password" value={password}
                     onChange={(e) => setPassword(e.target.value)} />
            </Field>
            <Field label="Confirmar senha">
              <input type="password" autoComplete="new-password" value={confirm}
                     onChange={(e) => setConfirm(e.target.value)} />
            </Field>
            <Button type="submit" loading={loading} className="btn-block">Salvar senha</Button>
          </form>
        )}
      </div>
    </div>
  );
}
