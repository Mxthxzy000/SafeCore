import { useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
  AlertOctagon, Bell, Factory, Radio, ShieldCheck, Users, Wrench, WifiOff,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { must, useQuery } from '../lib/useQuery';
import { byId, fetchAreas, fetchProfiles, fetchSensors } from '../lib/data';
import {
  ALERT_SEVERITY, ALERT_STATUS, AREA_STATUS, AREA_STATUS_PRIORITY, AUDIT_ACTION, AUDIT_ENTITY,
  ROLE_LABEL, ROLES,
} from '../lib/labels';
import { fmtNumber, fmtRelative } from '../lib/format';
import type { Alert, AuditLog } from '../lib/types';
import { Badge, Card, EmptyState, PageHeader, QueryState, StatTile, StatusDot } from '../components/ui';
import { AlertsByDayChart, MeasureLineChart } from '../components/charts';

const DAY = 86400000;
const ymd = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

export function dayBuckets(days: number) {
  const out: { key: string; label: string }[] = [];
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(today.getTime() - i * DAY);
    out.push({
      key: ymd(d),
      label: d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' }),
    });
  }
  return out;
}
export const localKey = (iso: string) => ymd(new Date(iso));

async function loadDashboard() {
  const since14 = new Date(Date.now() - 14 * DAY).toISOString();
  const since7 = new Date(Date.now() - 7 * DAY).toISOString();
  const [profiles, areas, sensors, openAlerts, recentAlerts, audit, series] = await Promise.all([
    fetchProfiles(),
    fetchAreas(false),
    fetchSensors(),
    supabase.from('alerts').select('*').neq('status', 'resolvido').order('detected_at', { ascending: false }).then(must),
    supabase.from('alerts').select('detected_at, severity').gte('detected_at', since14).then(must),
    supabase.from('audit_logs').select('*').order('created_at', { ascending: false }).limit(8).then(must),
    supabase.rpc('report_series', { p_from: since7, p_to: new Date().toISOString(), p_bucket: 'day' }).then(must),
  ]);
  return {
    profiles, areas, sensors,
    openAlerts: openAlerts as Alert[],
    recentAlerts: recentAlerts as Pick<Alert, 'detected_at' | 'severity'>[],
    audit: audit as AuditLog[],
    series: (series ?? []) as { bucket: string; sensor_type: string; avg_value: number }[],
  };
}

export function Dashboard() {
  const { data, error, loading, reload } = useQuery(loadDashboard);

  // Atualiza o painel quando um alerta é criado ou alterado (Realtime)
  useEffect(() => {
    let t: number | undefined;
    const channel = supabase
      .channel('dashboard-alerts')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'alerts' }, () => {
        window.clearTimeout(t);
        t = window.setTimeout(reload, 800);
      })
      .subscribe();
    return () => {
      window.clearTimeout(t);
      supabase.removeChannel(channel);
    };
  }, [reload]);

  return (
    <>
      <PageHeader title="Painel administrativo" subtitle="Visão geral da equipe e das condições operacionais da fábrica" />
      <QueryState loading={loading && !data} error={error} onRetry={reload}>
        {data && <DashboardContent data={data} />}
      </QueryState>
    </>
  );
}

function DashboardContent({ data }: { data: Awaited<ReturnType<typeof loadDashboard>> }) {
  const { profiles, areas, sensors, openAlerts, recentAlerts, audit, series } = data;
  const activeProfiles = profiles.filter((p) => p.active !== false);
  const areaIds = new Set(areas.map((a) => a.id));
  const liveSensors = sensors.filter((s) => areaIds.has(s.area_id));
  const sensorCount = (st: string) => liveSensors.filter((s) => s.status === st).length;
  const critical = openAlerts.filter((a) => a.severity === 'critico');
  const areaMap = byId(areas);

  const buckets = dayBuckets(14);
  const alertsByDay = buckets.map((b) => ({ label: b.label, atencao: 0, critico: 0 }));
  const idx = new Map(buckets.map((b, i) => [b.key, i]));
  recentAlerts.forEach((a) => {
    const i = idx.get(localKey(a.detected_at));
    if (i !== undefined) alertsByDay[i][a.severity] += 1;
  });

  const days7 = dayBuckets(7);
  const seriesFor = (type: string) =>
    days7.map((d) => {
      const row = series.find((r) => r.sensor_type === type && r.bucket.slice(0, 10) === d.key);
      return { label: d.label, value: row ? Number(row.avg_value) : null };
    });
  const tempSeries = seriesFor('temperatura');
  const pressSeries = seriesFor('pressao');

  const sortedAreas = [...areas].sort(
    (a, b) => (AREA_STATUS_PRIORITY[a.status] ?? 9) - (AREA_STATUS_PRIORITY[b.status] ?? 9) || a.name.localeCompare(b.name),
  );
  const unsafeAreas = areas.filter((a) => a.status !== 'segura').length;

  return (
    <div className="stack-lg">
      <div className="stats-grid">
        <StatTile label="Funcionários" value={fmtNumber(activeProfiles.length)} icon={<Users size={18} />}
                  hint={`${profiles.length - activeProfiles.length} desativado(s)`} />
        <StatTile label="Áreas industriais" value={fmtNumber(areas.length)} icon={<Factory size={18} />}
                  hint={`${unsafeAreas} fora da condição segura`} tone={unsafeAreas ? 'warning' : 'safe'} />
        <StatTile label="Alertas ativos" value={fmtNumber(openAlerts.length)} icon={<Bell size={18} />}
                  tone={openAlerts.length ? 'warning' : 'safe'} hint="ativos ou em andamento" />
        <StatTile label="Alertas críticos" value={fmtNumber(critical.length)} icon={<AlertOctagon size={18} />}
                  tone={critical.length ? 'critical' : 'safe'} hint="exigem ação imediata" />
      </div>

      <div className="grid-2">
        <Card title="Funcionários por cargo" actions={<Link to="/funcionarios" className="link">Gerenciar</Link>}>
          <div className="role-bars">
            {ROLES.map((r) => {
              const n = activeProfiles.filter((p) => p.role === r).length;
              const pct = activeProfiles.length ? (n / activeProfiles.length) * 100 : 0;
              return (
                <div key={r} className="role-bar">
                  <span className="role-bar-label">{ROLE_LABEL[r]}</span>
                  <div className="role-bar-track"><div className="role-bar-fill" style={{ width: `${pct}%` }} /></div>
                  <strong>{n}</strong>
                </div>
              );
            })}
          </div>
        </Card>
        <Card title="Sensores" actions={<Link to="/sensores" className="link">Ver todos</Link>}>
          <div className="sensor-status-grid">
            <div className="mini-stat"><Radio size={18} className="tone-safe" /><strong>{sensorCount('online')}</strong><span>Online</span></div>
            <div className="mini-stat"><WifiOff size={18} className="tone-offline" /><strong>{sensorCount('offline')}</strong><span>Sem comunicação</span></div>
            <div className="mini-stat"><Wrench size={18} className="tone-blocked" /><strong>{sensorCount('manutencao')}</strong><span>Em manutenção</span></div>
          </div>
          <p className="muted small">
            {liveSensors.filter((s) => s.status === 'online' && s.level !== 'normal').length} sensor(es) online fora da faixa segura.
          </p>
        </Card>
      </div>

      <div className="grid-2">
        <Card title="Alertas nos últimos 14 dias">
          <AlertsByDayChart data={alertsByDay} />
        </Card>
        <Card title="Condições operacionais por área" actions={<Link to="/areas" className="link">Áreas</Link>}>
          {sortedAreas.length === 0 ? <EmptyState title="Nenhuma área cadastrada" /> : (
            <ul className="area-status-list">
              {sortedAreas.map((a) => {
                const st = AREA_STATUS[a.status] ?? AREA_STATUS.segura;
                const open = openAlerts.filter((al) => al.area_id === a.id).length;
                return (
                  <li key={a.id}>
                    <Link to={`/areas/${a.id}`}>
                      <StatusDot tone={st.tone} />
                      <span className="area-status-name">{a.name}</span>
                      {open > 0 && <span className="muted small">{open} alerta(s)</span>}
                      <Badge tone={st.tone}>{st.label}</Badge>
                    </Link>
                  </li>
                );
              })}
            </ul>
          )}
        </Card>
      </div>

      <div className="grid-2">
        <Card title="Temperatura média diária (°C) — 7 dias">
          {tempSeries.some((p) => p.value !== null)
            ? <MeasureLineChart data={tempSeries} name="Temperatura média" unit="°C" />
            : <EmptyState title="Sem leituras no período" />}
        </Card>
        <Card title="Pressão média diária (bar) — 7 dias">
          {pressSeries.some((p) => p.value !== null)
            ? <MeasureLineChart data={pressSeries} name="Pressão média" unit="bar" />
            : <EmptyState title="Sem leituras no período" />}
        </Card>
      </div>

      <div className="grid-2">
        <Card title="Alertas críticos em aberto" actions={<Link to="/alertas" className="link">Ver alertas</Link>}>
          {critical.length === 0 ? (
            <EmptyState title="Nenhum alerta crítico" text="A operação está sem ocorrências críticas." icon={<ShieldCheck size={28} />} />
          ) : (
            <ul className="list">
              {critical.slice(0, 6).map((a) => (
                <li key={a.id}>
                  <Link to={`/alertas/${a.id}`} className="list-link">
                    <div>
                      <strong>{a.title}</strong>
                      <span className="muted small">{areaMap.get(a.area_id)?.name ?? 'Área'} · {fmtRelative(a.detected_at)}</span>
                    </div>
                    <div className="row-gap">
                      <Badge tone={ALERT_SEVERITY[a.severity].tone}>{ALERT_SEVERITY[a.severity].label}</Badge>
                      <Badge tone={ALERT_STATUS[a.status].tone}>{ALERT_STATUS[a.status].label}</Badge>
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Card>
        <Card title="Atividades administrativas recentes" actions={<Link to="/auditoria" className="link">Auditoria</Link>}>
          {audit.length === 0 ? <EmptyState title="Nenhuma atividade registrada" /> : (
            <ul className="list">
              {audit.map((l) => (
                <li key={l.id} className="list-row">
                  <div>
                    <strong>{l.user_name}</strong>
                    <span className="muted small">
                      {AUDIT_ACTION[l.action]?.label ?? l.action} · {AUDIT_ENTITY[l.entity] ?? l.entity}
                    </span>
                  </div>
                  <span className="muted small">{fmtRelative(l.created_at)}</span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
}
