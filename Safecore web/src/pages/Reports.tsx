import { useState } from 'react';
import { Download } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { must, useQuery } from '../lib/useQuery';
import { byId, fetchAreas } from '../lib/data';
import { ALERT_CATEGORY, ALERT_ORIGIN, ALERT_SEVERITY, ALERT_STATUS, OCC_STATUS } from '../lib/labels';
import { downloadCsv, fmtDateTime, fmtDuration, fmtNumber } from '../lib/format';
import type { Alert, Occurrence } from '../lib/types';
import { Button, Card, EmptyState, PageHeader, QueryState, StatTile } from '../components/ui';
import { AlertsByDayChart, HBarChart, MeasureLineChart } from '../components/charts';
import { dayBuckets, localKey } from './Dashboard';

const PERIODS = { 7: '7 dias', 30: '30 dias', 90: '90 dias' } as const;
type Period = keyof typeof PERIODS;

interface SeriesRow { bucket: string; sensor_type: string; avg_value: number; min_value: number; max_value: number; samples: number }

export function Reports() {
  const [days, setDays] = useState<Period>(30);
  const { data, error, loading, reload } = useQuery(async () => {
    const from = new Date(Date.now() - days * 86400000).toISOString();
    const to = new Date().toISOString();
    const [alerts, occurrences, areas, series, actions] = await Promise.all([
      supabase.from('alerts').select('*').gte('detected_at', from).order('detected_at').limit(5000).then(must),
      supabase.from('occurrences').select('*').gte('created_at', from).limit(5000).then(must),
      fetchAreas(true),
      supabase.rpc('report_series', { p_from: from, p_to: to, p_bucket: 'day' }).then(must),
      supabase.from('action_logs').select('id', { count: 'exact', head: true })
        .eq('is_simulation', true).gte('created_at', from),
    ]);
    return {
      alerts: alerts as Alert[], occurrences: occurrences as Occurrence[], areas,
      series: (series ?? []) as SeriesRow[], simulations: actions.count ?? 0,
    };
  }, [days]);

  return (
    <>
      <PageHeader
        title="Relatórios operacionais"
        subtitle="Indicadores de alertas, ocorrências e medições no período selecionado"
        actions={
          <div className="segmented">
            {(Object.keys(PERIODS) as unknown as Period[]).map((k) => (
              <button key={k} className={Number(days) === Number(k) ? 'active' : ''} onClick={() => setDays(Number(k) as Period)}>
                {PERIODS[k]}
              </button>
            ))}
          </div>
        }
      />
      <QueryState loading={loading && !data} error={error} onRetry={reload}>
        {data && <ReportContent data={data} days={days} />}
      </QueryState>
    </>
  );
}

function ReportContent({ data, days }: {
  data: { alerts: Alert[]; occurrences: Occurrence[]; areas: Awaited<ReturnType<typeof fetchAreas>>; series: SeriesRow[]; simulations: number };
  days: number;
}) {
  const { alerts, occurrences, areas, series, simulations } = data;
  const areaMap = byId(areas);
  const resolved = alerts.filter((a) => a.status === 'resolvido' && a.resolved_at);
  const mttr = resolved.length
    ? resolved.reduce((s, a) => s + (new Date(a.resolved_at!).getTime() - new Date(a.detected_at).getTime()), 0) / resolved.length
    : 0;
  const critical = alerts.filter((a) => a.severity === 'critico').length;

  const buckets = dayBuckets(days);
  const idx = new Map(buckets.map((b, i) => [b.key, i]));
  const byDay = buckets.map((b) => ({ label: b.label, atencao: 0, critico: 0 }));
  alerts.forEach((a) => {
    const i = idx.get(localKey(a.detected_at));
    if (i !== undefined) byDay[i][a.severity] += 1;
  });

  const countBy = (key: (a: Alert) => string) => {
    const m = new Map<string, number>();
    alerts.forEach((a) => m.set(key(a), (m.get(key(a)) ?? 0) + 1));
    return [...m.entries()].map(([label, value]) => ({ label, value })).sort((a, b) => b.value - a.value);
  };
  const byArea = countBy((a) => areaMap.get(a.area_id)?.name ?? 'Área removida').slice(0, 10);
  const byCategory = countBy((a) => ALERT_CATEGORY[a.category] ?? a.category);

  const seriesFor = (type: string) => buckets.map((b) => {
    const row = series.find((r) => r.sensor_type === type && r.bucket.slice(0, 10) === b.key);
    return { label: b.label, value: row ? Number(row.avg_value) : null };
  });
  const temp = seriesFor('temperatura');
  const press = seriesFor('pressao');

  const occOpen = occurrences.filter((o) => o.status !== 'resolvida').length;

  function exportAlerts() {
    downloadCsv(`safecore-alertas-${days}d.csv`, [
      ['Detectado em', 'Título', 'Área', 'Categoria', 'Severidade', 'Status', 'Origem', 'Valor', 'Unidade', 'Resolvido em', 'Nota'],
      ...alerts.map((a) => [
        fmtDateTime(a.detected_at), a.title, areaMap.get(a.area_id)?.name ?? '', ALERT_CATEGORY[a.category] ?? a.category,
        ALERT_SEVERITY[a.severity].label, ALERT_STATUS[a.status].label, ALERT_ORIGIN[a.origin],
        a.detected_value, a.unit, fmtDateTime(a.resolved_at), a.resolution_note,
      ]),
    ]);
  }
  function exportOccurrences() {
    downloadCsv(`safecore-ocorrencias-${days}d.csv`, [
      ['Registrada em', 'Título', 'Tipo', 'Área', 'Prioridade', 'Status', 'Autor', 'Responsável'],
      ...occurrences.map((o) => [
        fmtDateTime(o.created_at), o.title, o.kind, o.area_id ? areaMap.get(o.area_id)?.name ?? '' : 'Geral',
        o.priority, OCC_STATUS[o.status].label, o.reported_by_name, o.responsible_name,
      ]),
    ]);
  }
  function exportSeries() {
    downloadCsv(`safecore-medicoes-${days}d.csv`, [
      ['Dia', 'Tipo', 'Média', 'Mínimo', 'Máximo', 'Amostras'],
      ...series.map((r) => [r.bucket.slice(0, 10), r.sensor_type, r.avg_value, r.min_value, r.max_value, r.samples]),
    ]);
  }

  return (
    <div className="stack-lg">
      <div className="stats-grid">
        <StatTile label="Alertas no período" value={fmtNumber(alerts.length)} hint={`${critical} crítico(s)`} tone={critical ? 'critical' : 'neutral'} />
        <StatTile label="Alertas resolvidos" value={fmtNumber(resolved.length)}
                  hint={alerts.length ? `${Math.round((resolved.length / alerts.length) * 100)}% do total` : '—'} tone="safe" />
        <StatTile label="Tempo médio de resolução" value={fmtDuration(mttr)} hint="da detecção à resolução" />
        <StatTile label="Ocorrências" value={fmtNumber(occurrences.length)} hint={`${occOpen} em aberto · ${simulations} ação(ões) simulada(s)`} />
      </div>

      <Card title="Alertas por dia" actions={<Button variant="secondary" size="sm" icon={<Download size={14} />} onClick={exportAlerts}>Exportar alertas (CSV)</Button>}>
        <AlertsByDayChart data={byDay} height={260} />
      </Card>

      <div className="grid-2">
        <Card title="Alertas por área (top 10)">
          {byArea.length ? <HBarChart data={byArea} name="Alertas" /> : <EmptyState title="Sem alertas no período" />}
        </Card>
        <Card title="Alertas por categoria de risco">
          {byCategory.length ? <HBarChart data={byCategory} name="Alertas" /> : <EmptyState title="Sem alertas no período" />}
        </Card>
      </div>

      <div className="grid-2">
        <Card title="Temperatura média diária (°C)" actions={<Button variant="secondary" size="sm" icon={<Download size={14} />} onClick={exportSeries}>Medições (CSV)</Button>}>
          {temp.some((p) => p.value !== null) ? <MeasureLineChart data={temp} name="Temperatura média" unit="°C" /> : <EmptyState title="Sem leituras" />}
        </Card>
        <Card title="Pressão média diária (bar)">
          {press.some((p) => p.value !== null) ? <MeasureLineChart data={press} name="Pressão média" unit="bar" /> : <EmptyState title="Sem leituras" />}
        </Card>
      </div>

      <Card title="Ocorrências por status" actions={<Button variant="secondary" size="sm" icon={<Download size={14} />} onClick={exportOccurrences}>Exportar ocorrências (CSV)</Button>}>
        <div className="sensor-status-grid">
          {Object.entries(OCC_STATUS).map(([k, v]) => (
            <div key={k} className="mini-stat">
              <strong>{occurrences.filter((o) => o.status === k).length}</strong>
              <span>{v.label}</span>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
