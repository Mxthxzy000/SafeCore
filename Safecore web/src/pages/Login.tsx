import { useState, type FormEvent } from 'react';
import { Link, Navigate, useLocation } from 'react-router-dom';
import { ArrowLeft, Eye, EyeOff, Lock, Mail, ShieldAlert, Smartphone } from 'lucide-react';
import { useAuth } from '../auth/AuthProvider';
import { IndustrialIllustration, LogoMark, Wordmark } from '../components/Brand';
import { Button, Field, FullScreenLoader, Modal, Notice } from '../components/ui';
import { supabase, isConfigured } from '../lib/supabase';
import { setPasswordUrl } from '../lib/adminApi';

function translateLoginError(message: string): string {
  const m = message.toLowerCase();
  if (m.includes('invalid login credentials')) return 'E-mail ou senha incorretos.';
  if (m.includes('banned')) return 'Esta conta está desativada. Procure o administrador do sistema.';
  if (m.includes('email not confirmed')) return 'E-mail ainda não confirmado.';
  if (m.includes('rate limit') || m.includes('too many')) return 'Muitas tentativas. Aguarde alguns minutos.';
  if (m.includes('fetch')) return 'Falha de conexão com o servidor.';
  return 'Não foi possível entrar. Tente novamente.';
}

export function Login() {
  const { state, refresh } = useAuth();
  const location = useLocation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [show, setShow] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [forgotOpen, setForgotOpen] = useState(false);

  if (state.status === 'loading' && !loading) return <FullScreenLoader label="Verificando sessão…" />;
  if (state.status === 'admin') {
    const from = (location.state as { from?: string } | null)?.from;
    return <Navigate to={from && from !== '/login' && from !== '/' ? from : '/painel'} replace />;
  }

  const denied = error ?? (state.status === 'signedOut' ? state.notice : undefined);
  const isMobileAccount = denied?.includes('SafeCore Mobile');

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (!email.trim() || !password) {
      setError('Informe e-mail e senha.');
      return;
    }
    setLoading(true);
    const { error: signInError } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
    if (signInError) {
      setError(translateLoginError(signInError.message));
      setLoading(false);
      return;
    }
    // Verificação de administrador no servidor (perfil + is_admin). Se falhar,
    // a sessão é encerrada imediatamente e o motivo é exibido.
    const result = await refresh();
    if (!result.ok) setError(result.reason);
    setLoading(false);
  }

  return (
    <div className="login-page">
      <div className="login-hero">
        <div className="login-hero-inner">
          <LogoMark size={64} />
          <h1>SafeCore Web</h1>
          <p>
            Painel administrativo para gestão de funcionários, áreas, permissões e
            acompanhamento da operação da fábrica.
          </p>
          <ul>
            <li>Cadastro de contas para o aplicativo mobile</li>
            <li>Permissões por área industrial</li>
            <li>Sensores, alertas, relatórios e auditoria</li>
          </ul>
        </div>
        <IndustrialIllustration />
      </div>

      <div className="login-panel">
        <form className="login-card" onSubmit={onSubmit} noValidate>
          <Link to="/" className="back-link login-back"><ArrowLeft size={16} /> Voltar ao site</Link>
          <Wordmark size={34} />
          <div className="login-head">
            <h2>Acesso do administrador</h2>
            <p className="muted">Entre com a conta de administrador cadastrada no SafeCore.</p>
          </div>

          {!isConfigured && (
            <Notice tone="critical">
              Supabase não configurado. Preencha VITE_SUPABASE_URL e VITE_SUPABASE_PUBLISHABLE_KEY no arquivo .env.
            </Notice>
          )}

          {denied && (
            <Notice tone={isMobileAccount ? 'info' : 'critical'}>
              <span className="notice-row">
                {isMobileAccount ? <Smartphone size={18} /> : <ShieldAlert size={18} />}
                <span>{denied}</span>
              </span>
            </Notice>
          )}

          <Field label="E-mail">
            <div className="input-icon">
              <Mail size={16} />
              <input type="email" autoComplete="username" value={email}
                     onChange={(e) => setEmail(e.target.value)} placeholder="admin@empresa.com" />
            </div>
          </Field>
          <Field label="Senha">
            <div className="input-icon">
              <Lock size={16} />
              <input type={show ? 'text' : 'password'} autoComplete="current-password" value={password}
                     onChange={(e) => setPassword(e.target.value)} placeholder="Sua senha" />
              <button type="button" className="input-action" onClick={() => setShow((s) => !s)}
                      aria-label={show ? 'Ocultar senha' : 'Mostrar senha'}>
                {show ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </Field>

          <Button type="submit" loading={loading} className="btn-block">Entrar</Button>
          <button type="button" className="link-btn" onClick={() => setForgotOpen(true)}>Esqueci minha senha</button>

          <p className="login-foot muted">
            Não há cadastro público. As contas são criadas pelo administrador.
            Técnicos, supervisores e operadores utilizam o aplicativo SafeCore Mobile.
          </p>
        </form>
      </div>

      <ForgotPassword open={forgotOpen} onClose={() => setForgotOpen(false)} initialEmail={email} />
    </div>
  );
}

function ForgotPassword({ open, onClose, initialEmail }: { open: boolean; onClose: () => void; initialEmail: string }) {
  const [email, setEmail] = useState(initialEmail);
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function send() {
    setError(null);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      setError('Informe um e-mail válido.');
      return;
    }
    setLoading(true);
    const { error: err } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: setPasswordUrl() });
    setLoading(false);
    if (err && err.message.toLowerCase().includes('rate limit')) {
      setError('Limite de envio atingido. Tente novamente mais tarde.');
      return;
    }
    setSent(true); // mensagem neutra: não revela se o e-mail existe
  }

  return (
    <Modal
      open={open}
      title="Redefinir senha"
      onClose={() => { setSent(false); onClose(); }}
      footer={sent ? <Button onClick={() => { setSent(false); onClose(); }}>Fechar</Button> : (
        <>
          <Button variant="secondary" onClick={onClose}>Cancelar</Button>
          <Button onClick={send} loading={loading}>Enviar link</Button>
        </>
      )}
    >
      {sent ? (
        <Notice tone="safe">Se o e-mail estiver cadastrado, você receberá um link para definir uma nova senha.</Notice>
      ) : (
        <Field label="E-mail da conta" error={error}>
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoFocus />
        </Field>
      )}
    </Modal>
  );
}
