import { useCallback, useEffect, useRef, useState, type MouseEvent, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import {
  AnimatePresence, animate, motion, useMotionValue, useReducedMotion, useSpring, useTransform,
  type MotionValue, type Variants,
} from 'motion/react';
import { ArrowRight, CheckCircle2, Lock, MousePointerClick, ShieldCheck } from 'lucide-react';
import { LogoMark } from '../../components/Brand';

// Hero interativa da landing page. Os dados do mockup são ILUSTRATIVOS (simulação
// local no navegador), não vêm do banco.

const RISKS = ['temperatura alta', 'sobrepressão', 'vazamento de gás', 'fumaça', 'falha de ventilação'];

type Severity = 'crit' | 'warn';
const ALERT_POOL: { title: string; where: string; sev: Severity }[] = [
  { title: 'Temperatura acima do limite', where: 'Caldeira · 96,4 °C', sev: 'crit' },
  { title: 'Pressão acima do limite', where: 'Produção · 7,8 bar', sev: 'warn' },
  { title: 'Concentração de gás elevada', where: 'Laboratório · 38 ppm', sev: 'crit' },
  { title: 'Umidade abaixo do limite', where: 'Armazém · 28 %', sev: 'warn' },
  { title: 'Fumaça detectada', where: 'Expedição · 12 ppm', sev: 'crit' },
  { title: 'Ventilação abaixo do limite', where: 'Tanques · 0,4 m/s', sev: 'warn' },
];

interface LiveAlert { id: number; pool: number; status: 'ativo' | 'andamento' }

const container: Variants = { hidden: {}, show: { transition: { staggerChildren: 0.09, delayChildren: 0.05 } } };
const item: Variants = {
  hidden: { opacity: 0, y: 18 },
  show: { opacity: 1, y: 0, transition: { duration: 0.55, ease: [0.22, 1, 0.36, 1] } },
};

export function Hero({ isAdmin, loginTo, backdrop }: { isAdmin: boolean; loginTo: string; backdrop: ReactNode }) {
  const reduce = useReducedMotion() ?? false;
  const sectionRef = useRef<HTMLElement>(null);

  // Posição do mouse normalizada (-0.5 a 0.5) para o efeito 3D e o brilho
  const mx = useMotionValue(0);
  const my = useMotionValue(0);
  const spring = { stiffness: 110, damping: 18, mass: 0.6 };
  const rotateY = useSpring(useTransform(mx, [-0.5, 0.5], [-15, 3]), spring);
  const rotateX = useSpring(useTransform(my, [-0.5, 0.5], [9, -5]), spring);
  const phoneX = useSpring(useTransform(mx, [-0.5, 0.5], [18, -18]), spring);
  const phoneY = useSpring(useTransform(my, [-0.5, 0.5], [12, -12]), spring);

  const onMove = useCallback((e: MouseEvent<HTMLElement>) => {
    const el = sectionRef.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width;
    const y = (e.clientY - r.top) / r.height;
    el.style.setProperty('--mx', `${x * 100}%`);
    el.style.setProperty('--my', `${y * 100}%`);
    if (!reduce) {
      mx.set(x - 0.5);
      my.set(y - 0.5);
    }
  }, [mx, my, reduce]);

  const onLeave = useCallback(() => {
    mx.set(0);
    my.set(0);
  }, [mx, my]);

  return (
    <section ref={sectionRef} className="lp-hero" onMouseMove={onMove} onMouseLeave={onLeave}>
      <div className="lp-hero-spotlight" aria-hidden />
      <div className="lp-container lp-hero-grid">
        <motion.div className="lp-hero-text" variants={container} initial={reduce ? false : 'hidden'} animate="show">
          <motion.span variants={item} className="lp-eyebrow">
            <span className="lp-live-dot" /> <ShieldCheck size={15} /> Monitoramento e segurança industrial
          </motion.span>
          <motion.h1 variants={item}>Segurança industrial em tempo real, do chão de fábrica à gestão.</motion.h1>
          <motion.p variants={item} className="lp-rotator">
            Detecte <RotatingWord words={RISKS} reduce={reduce} /> antes que vire acidente.
          </motion.p>
          <motion.p variants={item} className="lp-lead">
            O SafeCore une sensores, alertas e equipes em uma única plataforma. Os riscos são detectados na hora,
            e cada pessoa sabe exatamente o que fazer e onde pode atuar.
          </motion.p>
          <motion.div variants={item} className="lp-hero-ctas">
            <a href="#contato" className="lp-btn lp-btn-green lp-btn-lg lp-btn-shine">
              Fale conosco <ArrowRight size={18} className="lp-arrow" />
            </a>
            <Link to={loginTo} className="lp-btn lp-btn-ghost-light lp-btn-lg">
              <Lock size={16} /> {isAdmin ? 'Ir para o painel' : 'Acessar o painel'}
            </Link>
          </motion.div>
          <motion.ul variants={item} className="lp-hero-checks">
            <li><CheckCircle2 size={16} /> Painel web para administradores</li>
            <li><CheckCircle2 size={16} /> Aplicativo mobile para a equipe</li>
            <li><CheckCircle2 size={16} /> Permissões por área industrial</li>
          </motion.ul>
        </motion.div>

        <motion.div
          initial={reduce ? false : { opacity: 0, y: 30, scale: 0.97 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ duration: 0.8, delay: 0.25, ease: [0.22, 1, 0.36, 1] }}
        >
          <LiveMockup reduce={reduce} rotateX={rotateX} rotateY={rotateY} phoneX={phoneX} phoneY={phoneY} />
        </motion.div>
      </div>
      {backdrop}
    </section>
  );
}

// ---------------------------------------------------------------------
function RotatingWord({ words, reduce }: { words: string[]; reduce: boolean }) {
  const [i, setI] = useState(0);
  useEffect(() => {
    if (reduce) return;
    const t = window.setInterval(() => setI((n) => (n + 1) % words.length), 2400);
    return () => window.clearInterval(t);
  }, [words.length, reduce]);

  return (
    <span className="lp-rotator-word" aria-live="polite">
      <AnimatePresence mode="wait" initial={false}>
        <motion.span
          key={words[i]}
          initial={{ y: '0.6em', opacity: 0, filter: 'blur(4px)' }}
          animate={{ y: 0, opacity: 1, filter: 'blur(0px)' }}
          exit={{ y: '-0.6em', opacity: 0, filter: 'blur(4px)' }}
          transition={{ duration: 0.35, ease: 'easeOut' }}
        >
          {words[i]}
        </motion.span>
      </AnimatePresence>
    </span>
  );
}

function CountUp({ to, reduce }: { to: number; reduce: boolean }) {
  const [value, setValue] = useState(reduce ? to : 0);
  useEffect(() => {
    if (reduce) {
      setValue(to);
      return;
    }
    const controls = animate(0, to, { duration: 1.4, delay: 0.5, ease: 'easeOut', onUpdate: (v) => setValue(Math.round(v)) });
    return () => controls.stop();
  }, [to, reduce]);
  return <>{value}</>;
}

/** Número que "pula" ao mudar. */
function Pop({ value }: { value: number }) {
  return (
    <AnimatePresence mode="popLayout" initial={false}>
      <motion.b key={value} initial={{ y: -8, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 8, opacity: 0 }}
                transition={{ duration: 0.25 }}>
        {value}
      </motion.b>
    </AnimatePresence>
  );
}

// ---------------------------------------------------------------------
function LiveMockup({ reduce, rotateX, rotateY, phoneX, phoneY }: {
  reduce: boolean;
  rotateX: MotionValue<number>; rotateY: MotionValue<number>;
  phoneX: MotionValue<number>; phoneY: MotionValue<number>;
}) {
  const [bars, setBars] = useState([3, 5, 2, 6, 4, 7, 3, 5, 8, 4, 6, 3]);
  const [alerts, setAlerts] = useState<LiveAlert[]>([
    { id: 1, pool: 0, status: 'ativo' },
    { id: 2, pool: 1, status: 'ativo' },
  ]);
  const [resolved, setResolved] = useState(0);
  const [flash, setFlash] = useState<string | null>(null);
  const nextId = useRef(3);
  const nextPool = useRef(2);

  // Leituras "ao vivo" no gráfico
  useEffect(() => {
    if (reduce) return;
    const t = window.setInterval(() => {
      setBars((b) => [...b.slice(1), 2 + Math.round(Math.random() * 6)]);
    }, 2200);
    return () => window.clearInterval(t);
  }, [reduce]);

  // Novos alertas chegam sozinhos enquanto houver espaço
  useEffect(() => {
    if (reduce || alerts.length >= 3) return;
    const t = window.setTimeout(() => {
      setAlerts((a) => [{ id: nextId.current++, pool: nextPool.current++ % ALERT_POOL.length, status: 'ativo' }, ...a]);
    }, alerts.length === 0 ? 2500 : 6500);
    return () => window.clearTimeout(t);
  }, [alerts.length, reduce]);

  useEffect(() => {
    if (!flash) return;
    const t = window.setTimeout(() => setFlash(null), 1800);
    return () => window.clearTimeout(t);
  }, [flash]);

  const top = alerts[0];
  function act() {
    if (!top) return;
    if (top.status === 'ativo') {
      setAlerts((a) => a.map((x) => (x.id === top.id ? { ...x, status: 'andamento' } : x)));
      setFlash('Alerta assumido por você');
    } else {
      setAlerts((a) => a.filter((x) => x.id !== top.id));
      setResolved((n) => n + 1);
      setFlash('Alerta resolvido');
    }
  }

  const critical = alerts.filter((a) => ALERT_POOL[a.pool].sev === 'crit').length;
  const areaStatus = (name: string): [string, string] => {
    const hit = alerts.find((a) => ALERT_POOL[a.pool].where.startsWith(name));
    if (!hit) return ['safe', 'Segura'];
    return ALERT_POOL[hit.pool].sev === 'crit' ? ['crit', 'Crítica'] : ['warn', 'Atenção'];
  };

  return (
    <div className="lp-mockup">
      <motion.div className="lp-browser" style={{ rotateX, rotateY, transformPerspective: 1400 }} aria-hidden>
        <div className="lp-browser-bar">
          <i /><i /><i /><span>SafeCore Web · Painel</span>
          <em className="lp-live"><span className="lp-live-dot" /> ao vivo</em>
        </div>
        <div className="lp-browser-body">
          <div className="lp-mini-side">
            <LogoMark size={22} />
            {[0, 1, 2, 3, 4].map((i) => <span key={i} className={i === 0 ? 'on' : ''} />)}
          </div>
          <div className="lp-mini-main">
            <div className="lp-mini-stats">
              <div><small>Funcionários</small><b><CountUp to={48} reduce={reduce} /></b></div>
              <div className="warn"><small>Alertas ativos</small><Pop value={alerts.length} /></div>
              <div className="crit"><small>Críticos</small><Pop value={critical} /></div>
            </div>
            <div className="lp-mini-chart">
              <small>Leituras fora da faixa · últimos minutos</small>
              <div className="lp-mini-bars">
                {bars.map((h, i) => (
                  <span key={i} style={{ height: `${h * 11}%` }} className={h >= 7 ? 'crit' : ''} />
                ))}
              </div>
            </div>
            <div className="lp-mini-areas">
              {['Caldeira', 'Produção', 'Laboratório'].map((n) => {
                const [tone, label] = areaStatus(n);
                return (
                  <div key={n}>
                    <i className={`${tone} ${tone === 'crit' ? 'pulse' : ''}`} />
                    <span>{n}</span>
                    <em className={tone}>{label}</em>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </motion.div>

      <motion.div className="lp-phone" style={{ x: phoneX, y: phoneY }}>
        <div className="lp-phone-notch" />
        <div className="lp-phone-head">Alertas <span>{resolved > 0 ? `${resolved} resolvido(s)` : 'SafeCore Mobile'}</span></div>
        <div className="lp-phone-list">
          <AnimatePresence initial={false}>
            {alerts.slice(0, 2).map((a) => {
              const p = ALERT_POOL[a.pool];
              return (
                <motion.div
                  key={a.id}
                  layout
                  initial={{ opacity: 0, x: 40, scale: 0.95 }}
                  animate={{ opacity: 1, x: 0, scale: 1 }}
                  exit={{ opacity: 0, x: -40, scale: 0.95, transition: { duration: 0.25 } }}
                  transition={{ type: 'spring', stiffness: 260, damping: 24 }}
                  className={`lp-phone-alert ${p.sev}`}
                >
                  <b>{p.title}</b>
                  <span>{p.where}</span>
                  <em className={a.status === 'andamento' ? 'prog' : ''}>
                    {a.status === 'andamento' ? 'Em andamento' : p.sev === 'crit' ? 'Crítico' : 'Atenção'}
                  </em>
                </motion.div>
              );
            })}
          </AnimatePresence>
          {alerts.length === 0 && (
            <motion.div className="lp-phone-empty" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
              <CheckCircle2 size={22} /> Nenhum alerta ativo
            </motion.div>
          )}
        </div>
        <AnimatePresence>
          {flash && (
            <motion.div className="lp-phone-flash" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
              <CheckCircle2 size={12} /> {flash}
            </motion.div>
          )}
        </AnimatePresence>
        <motion.button
          type="button"
          className={`lp-phone-btn ${top?.status === 'andamento' ? 'resolve' : ''}`}
          onClick={act}
          disabled={!top}
          whileTap={{ scale: 0.94 }}
          whileHover={{ scale: 1.03 }}
        >
          {!top ? 'Aguardando alertas' : top.status === 'ativo' ? 'Assumir alerta' : 'Resolver alerta'}
        </motion.button>
        <span className="lp-phone-hint"><MousePointerClick size={12} /> Experimente: toque no botão</span>
      </motion.div>
    </div>
  );
}
