import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { ArrowLeft, Pencil } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { must, useQuery } from '../lib/useQuery';
import { fetchAreas } from '../lib/data';
import { ALERT_SEVERITY, ALERT_STATUS, SENSOR_LEVEL, SENSOR_STATUS, SENSOR_TYPES } from '../lib/labels';
import { fmtDateTime, fmtNumber, fmtRelative } from '../lib/format';
import type { Alert, Reading, Sensor } from '../lib/types';
import { Badge, Button, Card, EmptyState, InfoRow, QueryState, Spinner, StatTile } from '../components/ui';
import { MeasureLineChart } from '../components/charts';
import { SensorFormModal } from './Sensors';

const RANGES = { '24h': 1, '7d': 7, '30d': 30 } as const;
type RangeKey = keyof typeof RANGES;

export function SensorDetail() {
  const { id = '' } = useParams();
  const [range, setRange] = useState<RangeKey>('24h');
  const [editOpen, setEditOpen] = useState(false);

  const base = useQuery(async () => {
    const [sensor, areas, alerts] = await Promise.all([
      supabase.from('sensors').select('*').eq('id', id).maybeSingle().then(must),
      fetchAreas(true),
      supabase.from('alerts').select('*').eq('sensor_id', id).order('detected_at', { ascending: false }).limit(10).then(must),
    ]);
    return { sensor: sensor as Sensor | null, areas, alerts: alerts as Alert[] };
  }, [id]);

  const readings = useQuery(async () => {
    const since = new Date(Date.now() - RANGES[range] * 86400000).toISOString();
    return must(await supabase.from('sensor_readings').select('*').eq('sensor_id', id)
      .gte('recorded_at', since).order('recorded_at', { ascending: false }).limit(3000)) as Reading[];
  }, [id, range]);

  const sensor = base.data?.sensor;
  const area = sensor ? base.data?.areas.find((a) => a.id === sensor.area_id) : undefined;

  // Reduz a série para no máximo ~300 pontos (médias por janela)
  const chartData = (() => {
    const rows = [...(readings.data ?? [])].reverse();
    const step = Math.max(1, Math.ceil(rows.length / 300));
    const out: { label: string; value: number }[] = [];
    for (let i = 0; i < rows.length; i += step) {
      const chunk = rows.slice(i, i + step);
      const avg = chunk.reduce((s, r) => s + Number(r.value), 0) / chunk.length;
      const d = new Date(chunk[0].recorded_at);
      out.push({
        label: range === '24h'
          ? d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
          : d.toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }),
        value: Math.round(avg * 100) / 100,
      });
    }
    return out;
  })();
  const values = (readings.data ?? []).map((r) => Number(r.value));

  return (
    <>
      <Link to="/sensores" className="back-link"><ArrowLeft size={16} /> Sensores</Link>
      <QueryState loading={base.loading && !base.data} error={base.error} onRetry={base.reload}>
        {base.data && !sensor && <EmptyState title="Sensor não encontrado" />}
        {sensor && (
          <div className="stack-lg">
            <div className="page-header">
              <div>
                <h1>{sensor.name}</h1>
                <div className="row-gap">
                  <span className="muted">{sensor.code} · {SENSOR_TYPES[sensor.sensor_type]?.label}</span>
                  {area && <Link to={`/areas/${area.id}`} className="link">{area.name}</Link>}
                  <Badge tone={SENSOR_LEVEL[sensor.level].tone}>{SENSOR_LEVEL[sensor.level].label}</Badge>
                  <Badge tone={SENSOR_STATUS[sensor.status].tone}>{SENSOR_STATUS[sensor.status].label}</Badge>
                </div>
              </div>
              <div className="page-actions">
                <Button variant="secondary" icon={<Pencil size={16} />} onClick={() => setEditOpen(true)}>Editar</Button>
              </div>
            </div>

            <div className="stats-grid">
              <StatTile label="Último valor" value={`${fmtNumber(sensor.last_value)} ${sensor.unit}`}
                        tone={SENSOR_LEVEL[sensor.level].tone} hint={fmtRelative(sensor.last_reading_at)} />
              <StatTile label="Mínimo no período" value={values.length ? `${fmtNumber(Math.min(...values))} ${sensor.unit}` : '—'} />
              <StatTile label="Máximo no período" value={values.length ? `${fmtNumber(Math.max(...values))} ${sensor.unit}` : '—'} />
              <StatTile label="Leituras no período" value={fmtNumber(values.length)} />
            </div>

            <Card
              title={`Histórico de leituras (${sensor.unit})`}
              actions={
                <div className="segmented small">
                  {(Object.keys(RANGES) as RangeKey[]).map((k) => (
                    <button key={k} className={range === k ? 'active' : ''} onClick={() => setRange(k)}>{k}</button>
                  ))}
                </div>
              }
            >
              {readings.loading && !readings.data ? <Spinner /> : chartData.length === 0
                ? <EmptyState title="Sem leituras no período" />
                : <MeasureLineChart data={chartData} name={sensor.name} unit={sensor.unit} height={280}
                                    refMin={sensor.ref_min} refMax={sensor.ref_max} />}
            </Card>

            <div className="grid-2">
              <Card title="Configuração">
                <InfoRow label="Faixa segura">{fmtNumber(sensor.ref_min)} a {fmtNumber(sensor.ref_max)} {sensor.unit}</InfoRow>
                <InfoRow label="Limites críticos">{fmtNumber(sensor.critical_min)} / {fmtNumber(sensor.critical_max)} {sensor.unit}</InfoRow>
                <InfoRow label="Dispositivo">{sensor.device_id || '—'}</InfoRow>
                <InfoRow label="Origem das leituras">{sensor.is_simulated ? 'Simulado' : 'Dispositivo físico'}</InfoRow>
                <InfoRow label="Cadastrado em">{fmtDateTime(sensor.created_at)}</InfoRow>
              </Card>
              <Card title="Últimas leituras">
                {(readings.data ?? []).length === 0 ? <EmptyState title="Sem leituras" /> : (
                  <ul className="list">
                    {(readings.data ?? []).slice(0, 8).map((r) => (
                      <li key={r.id} className="list-row">
                        <span>{fmtDateTime(r.recorded_at)} <span className="muted small">({r.source})</span></span>
                        <strong>{fmtNumber(r.value)} {sensor.unit}</strong>
                      </li>
                    ))}
                  </ul>
                )}
              </Card>
            </div>

            <Card title="Alertas gerados por este sensor" padded={false}>
              {base.data!.alerts.length === 0 ? <EmptyState title="Nenhum alerta" /> : (
                <ul className="list padded">
                  {base.data!.alerts.map((a) => (
                    <li key={a.id}>
                      <Link to={`/alertas/${a.id}`} className="list-link">
                        <div><strong>{a.title}</strong><span className="muted small">{fmtDateTime(a.detected_at)}</span></div>
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

            <SensorFormModal open={editOpen} sensor={sensor} areas={base.data!.areas.filter((a) => !a.archived_at || a.id === sensor.area_id)}
                             onClose={() => setEditOpen(false)} onSaved={() => base.reload()} />
          </div>
        )}
      </QueryState>
    </>
  );
}
