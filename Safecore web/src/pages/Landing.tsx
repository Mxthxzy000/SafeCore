import { useEffect, useState, type FormEvent, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { FunctionsHttpError } from '@supabase/supabase-js';
import {
  Activity, Bell, BellRing, CheckCircle2, ClipboardList, Eye, Factory,
  FileBarChart, Fingerprint, Gauge, KeyRound, Lock, Mail, Map as MapIcon, Menu, MonitorSmartphone, Radio,
  ScrollText, Send, ShieldCheck, Smartphone, Timer, UserCog, Users, Wrench, X,
} from 'lucide-react';
import { useAuth } from '../auth/AuthProvider';
import { LogoMark } from '../components/Brand';
import { Hero } from './landing/Hero';
import { FloatingPathsBackground } from '../components/ui/floating-paths';
import AccordionGhost, { type AccordionGhostSection } from '../components/ui/accordion-ghost';
import { supabase } from '../lib/supabase';
import '../landing.css';

const SUPPORT_EMAIL = 'suporte@bitlayerdev.com';

const FAQ: AccordionGhostSection[] = [
  {
    value: 'acesso-web',
    title: 'Quem pode acessar o painel web?',
    body: 'Somente usuários com o cargo de administrador. Supervisores, técnicos e operadores usam o aplicativo SafeCore Mobile, que mostra apenas as áreas e funções autorizadas para cada um.',
  },
  {
    value: 'novo-funcionario',
    title: 'Como um novo funcionário recebe acesso?',
    body: 'O administrador cadastra a conta no painel, definindo uma senha inicial ou enviando um convite por e-mail. Depois, vincula o funcionário às áreas com o nível de acesso adequado.',
  },
  {
    value: 'medicoes',
    title: 'Quais medições o SafeCore acompanha?',
    body: 'Temperatura, pressão, umidade, concentração de gases, fumaça e ventilação, cada sensor com sua faixa segura e seus limites críticos.',
  },
  {
    value: 'desligamento',
    title: 'O que acontece quando um funcionário sai da empresa?',
    body: 'A conta é desativada: o acesso é bloqueado imediatamente e todo o histórico de alertas, ações e ocorrências daquela pessoa é preservado.',
  },
  {
    value: 'sensores',
    title: 'Como funciona a integração com os sensores?',
    body: 'Cada sensor pode ser associado a um dispositivo (como um ESP32). As leituras alimentam o sistema, que atualiza o nível do sensor, abre alertas e recalcula a condição da área automaticamente.',
  },
];

const NAV = [
  { href: '#sobre', label: 'Sobre' },
  { href: '#recursos', label: 'Recursos' },
  { href: '#como-funciona', label: 'Como funciona' },
  { href: '#seguranca', label: 'Segurança' },
  { href: '#contato', label: 'Fale conosco' },
];

export function Landing() {
  const { state } = useAuth();
  const isAdmin = state.status === 'admin';
  const [menuOpen, setMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    document.title = 'SafeCore — Monitoramento e Segurança Industrial';
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      window.removeEventListener('scroll', onScroll);
      document.title = 'SafeCore Web';
    };
  }, []);

  const loginCta = isAdmin
    ? { to: '/painel', label: 'Ir para o painel' }
    : { to: '/login', label: 'Entrar' };

  return (
    <div className="lp">
      {/* ---------------- Navegação ---------------- */}
      <header className={`lp-nav ${scrolled ? 'scrolled' : ''}`}>
        <div className="lp-container lp-nav-inner">
          <a href="#topo" className="lp-brand" aria-label="SafeCore — início">
            <span className="lp-brand-mark"><LogoMark size={30} /></span>
            <span className="lp-brand-name"><span className="wm-safe">Safe</span><span className="wm-core">Core</span></span>
          </a>
          <nav className={`lp-links ${menuOpen ? 'open' : ''}`} aria-label="Seções">
            {NAV.map((n) => <a key={n.href} href={n.href} onClick={() => setMenuOpen(false)}>{n.label}</a>)}
            <Link to={loginCta.to} className="lp-btn lp-btn-primary lp-links-cta">{loginCta.label}</Link>
          </nav>
          <div className="lp-nav-actions">
            <Link to={loginCta.to} className="lp-btn lp-btn-primary lp-nav-login">
              <Lock size={15} /> {loginCta.label}
            </Link>
            <button className="lp-menu-btn" onClick={() => setMenuOpen((o) => !o)} aria-label="Abrir menu" aria-expanded={menuOpen}>
              {menuOpen ? <X size={22} /> : <Menu size={22} />}
            </button>
          </div>
        </div>
      </header>

      <main id="topo">
        {/* ---------------- Hero (interativa) ---------------- */}
        <Hero isAdmin={isAdmin} loginTo={loginCta.to} backdrop={<PathsBackdrop />} />

        {/* ---------------- Fatos do produto ---------------- */}
        <section className="lp-facts" aria-label="O SafeCore em números">
          <div className="lp-container lp-facts-grid">
            <Fact value="6" label="tipos de sensores monitorados" />
            <Fact value="4" label="cargos com permissões próprias" />
            <Fact value="3" label="níveis de acesso por área" />
            <Fact value="24/7" label="detecção automática de alertas" />
          </div>
        </section>

        {/* ---------------- Sobre / objetivo ---------------- */}
        <section id="sobre" className="lp-section">
          <div className="lp-container lp-about">
            <div>
              <span className="lp-kicker">Sobre o SafeCore</span>
              <h2>Nosso objetivo é evitar que um risco vire um acidente.</h2>
              <p>
                Em uma fábrica, os sinais de perigo quase sempre aparecem antes: uma caldeira que esquenta
                além do normal, a pressão que sobe em um tanque, um vazamento de gás no laboratório. O problema
                é que essas informações costumam ficar espalhadas em painéis isolados, planilhas e rádios.
              </p>
              <p>
                O SafeCore nasceu para concentrar tudo isso em um só lugar. Os sensores de cada área enviam
                leituras continuamente, o sistema compara com as faixas seguras e abre alertas automaticamente
                quando algo sai do esperado. A equipe certa é avisada, assume o alerta pelo celular e registra
                cada ação, enquanto a gestão acompanha a operação inteira pelo painel web.
              </p>
            </div>
            <div className="lp-goals">
              <Goal icon={<Eye size={22} />} title="Prevenir"
                    text="Monitoramento contínuo de temperatura, pressão, umidade, gases, fumaça e ventilação, com limites seguros e críticos por sensor." />
              <Goal icon={<Timer size={22} />} title="Responder rápido"
                    text="Alertas automáticos que escalam para crítico, chegam em tempo real ao aplicativo e mostram quem está tratando cada caso." />
              <Goal icon={<ScrollText size={22} />} title="Rastrear"
                    text="Histórico de leituras, ações e ocorrências, além de auditoria das alterações importantes feitas pelos usuários." />
            </div>
          </div>
        </section>

        {/* ---------------- Recursos ---------------- */}
        <section id="recursos" className="lp-section lp-section-muted">
          <div className="lp-container">
            <div className="lp-section-head">
              <span className="lp-kicker">Recursos</span>
              <h2>Tudo o que a segurança da fábrica precisa, conectado.</h2>
              <p>Da leitura do sensor ao relatório de gestão, cada etapa acontece na mesma plataforma.</p>
            </div>
            <div className="lp-features">
              <Feature icon={<Radio />} title="Sensores em tempo real"
                       text="Último valor, nível (normal, atenção, crítico) e status de comunicação de cada sensor, com histórico de leituras." />
              <Feature icon={<BellRing />} title="Alertas automáticos"
                       text="Leituras fora da faixa segura geram alertas na hora. Um alerta em atenção é escalado para crítico se a situação piorar." />
              <Feature icon={<MapIcon />} title="Áreas industriais"
                       text="Produção, caldeira, armazém, laboratório e outros setores, cada um com sua condição: segura, atenção, crítica ou interditada." />
              <Feature icon={<KeyRound />} title="Permissões por área"
                       text="Cada funcionário recebe leitura, operação ou gestão em cada área. Áreas restritas ficam visíveis só para quem tem vínculo." />
              <Feature icon={<Users />} title="Gestão de equipe"
                       text="O administrador cria as contas, define cargos e permissões. Não há cadastro aberto: só entra quem foi autorizado." />
              <Feature icon={<ClipboardList />} title="Ocorrências e avisos"
                       text="Mural para registrar ocorrências e avisos, com prioridade, responsável e acompanhamento do status." />
              <Feature icon={<FileBarChart />} title="Relatórios operacionais"
                       text="Alertas por dia, por área e por categoria de risco, tempo médio de resolução e exportação em CSV." />
              <Feature icon={<ScrollText />} title="Auditoria completa"
                       text="Quem alterou o quê e quando: áreas, alertas, permissões e perfis, com o antes e o depois de cada mudança." />
            </div>
          </div>
        </section>

        {/* ---------------- Como funciona ---------------- */}
        <section id="como-funciona" className="lp-section">
          <div className="lp-container">
            <div className="lp-section-head">
              <span className="lp-kicker">Como funciona</span>
              <h2>Dois aplicativos, uma única base segura.</h2>
              <p>O painel web e o aplicativo mobile usam os mesmos usuários, dados e regras de acesso.</p>
            </div>
            <div className="lp-platforms">
              <div className="lp-platform">
                <div className="lp-platform-icon"><MonitorSmartphone size={26} /></div>
                <h3>SafeCore Web</h3>
                <p className="lp-platform-for">Para administradores</p>
                <ul>
                  <li><CheckCircle2 size={16} /> Cadastro de funcionários e cargos</li>
                  <li><CheckCircle2 size={16} /> Áreas, sensores e permissões</li>
                  <li><CheckCircle2 size={16} /> Painel com indicadores e gráficos</li>
                  <li><CheckCircle2 size={16} /> Relatórios e logs de auditoria</li>
                </ul>
              </div>
              <div className="lp-platform lp-platform-mobile">
                <div className="lp-platform-icon"><Smartphone size={26} /></div>
                <h3>SafeCore Mobile</h3>
                <p className="lp-platform-for">Para supervisores, técnicos e operadores</p>
                <ul>
                  <li><CheckCircle2 size={16} /> Áreas autorizadas e mapa da planta</li>
                  <li><CheckCircle2 size={16} /> Sensores e alertas em tempo real</li>
                  <li><CheckCircle2 size={16} /> Assumir, comentar e resolver alertas</li>
                  <li><CheckCircle2 size={16} /> Registro de ocorrências em campo</li>
                </ul>
              </div>
            </div>
            <ol className="lp-steps">
              <Step n={1} title="Cadastro" text="O administrador cria a conta do funcionário no painel web e define o cargo." />
              <Step n={2} title="Permissões" text="Vincula o funcionário às áreas com o nível de acesso adequado." />
              <Step n={3} title="Acesso" text="O funcionário recebe as credenciais ou um convite seguro e entra no aplicativo." />
              <Step n={4} title="Operação" text="Cada pessoa vê apenas as áreas e ações que pode executar, com tudo registrado." />
            </ol>
          </div>
        </section>

        {/* ---------------- Cargos ---------------- */}
        <section className="lp-section lp-section-muted">
          <div className="lp-container">
            <div className="lp-section-head">
              <span className="lp-kicker">Para cada função</span>
              <h2>Cada pessoa com o acesso certo.</h2>
            </div>
            <div className="lp-roles">
              <Role icon={<UserCog size={20} />} title="Administrador" where="Painel web"
                    text="Gerencia a empresa: contas, cargos, áreas, permissões, relatórios e auditoria." />
              <Role icon={<Factory size={20} />} title="Supervisor" where="App mobile"
                    text="Acompanha e gerencia todas as áreas, sensores e o tratamento dos alertas." />
              <Role icon={<Wrench size={20} />} title="Técnico" where="App mobile"
                    text="Trata alertas, executa ações nas áreas e acompanha ocorrências gerais." />
              <Role icon={<Activity size={20} />} title="Operador" where="App mobile"
                    text="Consulta e opera nas áreas em que foi vinculado, registrando ocorrências." />
            </div>
          </div>
        </section>

        {/* ---------------- Segurança ---------------- */}
        <section id="seguranca" className="lp-section lp-security">
          <PathsBackdrop />
          <div className="lp-container lp-security-grid">
            <div>
              <span className="lp-kicker lp-kicker-light">Segurança</span>
              <h2>Proteção em várias camadas, não apenas na tela.</h2>
              <p>
                As regras de acesso ficam no banco de dados. Mesmo que alguém tente acessar uma página pelo
                endereço ou chamar o sistema diretamente, só consegue o que o seu cargo e as suas áreas permitem.
              </p>
            </div>
            <ul className="lp-security-list">
              <li><Fingerprint size={20} /><span><strong>Sem cadastro aberto</strong> Somente o administrador cria contas, e um funcionário não consegue se promover.</span></li>
              <li><Lock size={20} /><span><strong>Regras no banco de dados</strong> Políticas de acesso por linha (RLS) e por área valem para o web e para o app.</span></li>
              <li><ShieldCheck size={20} /><span><strong>Painel exclusivo</strong> O painel web aceita apenas administradores, com verificação no servidor.</span></li>
              <li><Gauge size={20} /><span><strong>Histórico preservado</strong> Áreas com histórico são arquivadas, não apagadas, e contas são desativadas sem perder registros.</span></li>
            </ul>
          </div>
        </section>

        {/* ---------------- FAQ ---------------- */}
        <section className="lp-section">
          <div className="lp-container lp-faq-wrap">
            <div className="lp-section-head">
              <span className="lp-kicker">Perguntas frequentes</span>
              <h2>Dúvidas comuns</h2>
            </div>
            <AccordionGhost sections={FAQ} className="lp-faq" />
          </div>
        </section>

        {/* ---------------- Contato ---------------- */}
        <section id="contato" className="lp-section lp-section-muted">
          <div className="lp-container lp-contact">
            <div className="lp-contact-info">
              <span className="lp-kicker">Fale conosco</span>
              <h2>Vamos conversar sobre a segurança da sua operação.</h2>
              <p>
                Quer conhecer o SafeCore, agendar uma demonstração ou precisa de suporte? Envie sua mensagem
                e nossa equipe retorna pelo e-mail informado.
              </p>
              <div className="lp-contact-card">
                <span className="lp-contact-icon"><Mail size={20} /></span>
                <div>
                  <span className="lp-muted-small">E-mail de suporte</span>
                  <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>
                </div>
              </div>
              <div className="lp-contact-card">
                <span className="lp-contact-icon"><Bell size={20} /></span>
                <div>
                  <span className="lp-muted-small">Já é cliente?</span>
                  <Link to={loginCta.to}>{isAdmin ? 'Ir para o painel administrativo' : 'Entrar no painel administrativo'}</Link>
                </div>
              </div>
            </div>
            <ContactForm />
          </div>
        </section>
      </main>

      {/* ---------------- Rodapé ---------------- */}
      <footer className="lp-footer">
        <div className="lp-container lp-footer-grid">
          <div className="lp-footer-brand">
            <div className="lp-brand">
              <span className="lp-brand-mark"><LogoMark size={30} /></span>
              <span className="lp-brand-name light"><span>Safe</span><span className="wm-core">Core</span></span>
            </div>
            <p>Monitoramento e segurança industrial: sensores, alertas e equipes conectados em uma única plataforma.</p>
          </div>
          <div>
            <h4>Navegação</h4>
            {NAV.map((n) => <a key={n.href} href={n.href}>{n.label}</a>)}
          </div>
          <div>
            <h4>Acesso</h4>
            <Link to={loginCta.to}>Painel administrativo</Link>
            <span className="lp-footer-note">Equipe de campo: aplicativo SafeCore Mobile</span>
          </div>
          <div>
            <h4>Contato</h4>
            <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>
          </div>
        </div>
        <div className="lp-container lp-footer-bottom">
          <span>© {new Date().getFullYear()} SafeCore. Todos os direitos reservados.</span>
        </div>
      </footer>
    </div>
  );
}

// ---------------------------------------------------------------------
// Componentes de seção
// ---------------------------------------------------------------------
/** Fundo animado de linhas flutuantes (duas camadas espelhadas). */
function PathsBackdrop() {
  return (
    <div className="lp-paths" aria-hidden>
      <FloatingPathsBackground position={1} className="lp-paths-layer" />
      <FloatingPathsBackground position={-1} className="lp-paths-layer" />
    </div>
  );
}

// ---------------------------------------------------------------------
function Fact({ value, label }: { value: string; label: string }) {
  return <div className="lp-fact"><strong>{value}</strong><span>{label}</span></div>;
}

function Goal({ icon, title, text }: { icon: ReactNode; title: string; text: string }) {
  return (
    <div className="lp-goal">
      <span className="lp-goal-icon">{icon}</span>
      <div><h3>{title}</h3><p>{text}</p></div>
    </div>
  );
}

function Feature({ icon, title, text }: { icon: ReactNode; title: string; text: string }) {
  return (
    <article className="lp-feature">
      <span className="lp-feature-icon">{icon}</span>
      <h3>{title}</h3>
      <p>{text}</p>
    </article>
  );
}

function Step({ n, title, text }: { n: number; title: string; text: string }) {
  return (
    <li className="lp-step">
      <span className="lp-step-n">{n}</span>
      <h3>{title}</h3>
      <p>{text}</p>
    </li>
  );
}

function Role({ icon, title, where, text }: { icon: ReactNode; title: string; where: string; text: string }) {
  return (
    <div className="lp-role">
      <div className="lp-role-top">
        <span className="lp-role-icon">{icon}</span>
        <span className={`lp-role-tag ${where === 'Painel web' ? 'web' : ''}`}>{where}</span>
      </div>
      <h3>{title}</h3>
      <p>{text}</p>
    </div>
  );
}


// ---------------------------------------------------------------------
// Fale conosco
// ---------------------------------------------------------------------
const SUBJECTS = ['Conhecer o SafeCore', 'Demonstração', 'Suporte técnico', 'Parcerias', 'Outro'];
const EMPTY = { name: '', email: '', company: '', phone: '', subject: SUBJECTS[0], message: '', website: '' };

function ContactForm() {
  const [form, setForm] = useState(EMPTY);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle');
  const [failure, setFailure] = useState('');

  const set = (k: keyof typeof EMPTY, v: string) => setForm((f) => ({ ...f, [k]: v }));

  function validate() {
    const e: Record<string, string> = {};
    if (form.name.trim().length < 2) e.name = 'Informe seu nome.';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())) e.email = 'Informe um e-mail válido.';
    if (form.message.trim().length < 10) e.message = 'Escreva pelo menos 10 caracteres.';
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  async function onSubmit(ev: FormEvent) {
    ev.preventDefault();
    if (!validate()) return;
    setStatus('sending');
    setFailure('');
    const { error } = await supabase.functions.invoke('contact', { body: form });
    if (!error) {
      setStatus('sent');
      setForm(EMPTY);
      return;
    }
    let message = 'Não foi possível enviar sua mensagem agora.';
    if (error instanceof FunctionsHttpError) {
      const payload = await error.context.json().catch(() => null);
      if (payload?.error) message = payload.error;
    }
    setFailure(message);
    setStatus('error');
  }

  if (status === 'sent') {
    return (
      <div className="lp-form lp-form-sent">
        <span className="lp-sent-icon"><CheckCircle2 size={44} /></span>
        <h3>Mensagem enviada!</h3>
        <p>Obrigado pelo contato. Nossa equipe vai responder no e-mail informado.</p>
        <button className="lp-btn lp-btn-outline" onClick={() => setStatus('idle')}>Enviar outra mensagem</button>
      </div>
    );
  }

  return (
    <form className="lp-form" onSubmit={onSubmit} noValidate>
      <h3>Envie sua mensagem</h3>
      {status === 'error' && (
        <div className="lp-form-error" role="alert">
          {failure} Se preferir, escreva diretamente para <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
        </div>
      )}
      <div className="lp-form-grid">
        <LpField label="Nome *" error={errors.name}>
          <input value={form.name} maxLength={120} autoComplete="name" onChange={(e) => set('name', e.target.value)} />
        </LpField>
        <LpField label="E-mail *" error={errors.email}>
          <input type="email" value={form.email} maxLength={254} autoComplete="email" onChange={(e) => set('email', e.target.value)} />
        </LpField>
        <LpField label="Empresa">
          <input value={form.company} maxLength={120} autoComplete="organization" onChange={(e) => set('company', e.target.value)} />
        </LpField>
        <LpField label="Telefone">
          <input value={form.phone} maxLength={30} autoComplete="tel" placeholder="(11) 99999-9999" onChange={(e) => set('phone', e.target.value)} />
        </LpField>
      </div>
      <LpField label="Assunto">
        <select value={form.subject} onChange={(e) => set('subject', e.target.value)}>
          {SUBJECTS.map((s) => <option key={s}>{s}</option>)}
        </select>
      </LpField>
      <LpField label="Mensagem *" error={errors.message}>
        <textarea rows={5} value={form.message} maxLength={4000} onChange={(e) => set('message', e.target.value)}
                  placeholder="Conte um pouco sobre sua empresa e o que você precisa." />
      </LpField>
      {/* Campo-isca anti-spam: invisível para pessoas */}
      <input className="lp-hp" tabIndex={-1} autoComplete="off" aria-hidden value={form.website}
             onChange={(e) => set('website', e.target.value)} name="website" />
      <button type="submit" className="lp-btn lp-btn-primary lp-btn-lg lp-btn-block" disabled={status === 'sending'}>
        {status === 'sending' ? 'Enviando…' : <>Enviar mensagem <Send size={16} /></>}
      </button>
      <p className="lp-muted-small lp-form-note">
        Seus dados são usados apenas para responder a este contato.
      </p>
    </form>
  );
}

function LpField({ label, error, children }: { label: string; error?: string; children: ReactNode }) {
  return (
    <label className="lp-field">
      <span>{label}</span>
      {children}
      {error && <em>{error}</em>}
    </label>
  );
}
