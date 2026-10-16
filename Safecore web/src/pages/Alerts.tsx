import { useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { Plus, RefreshCw, Search } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { must, useQuery } from '../lib/useQuery';
import { byId, fetchAreas } from '../lib/data';
import { ALERT_CATEGORY, ALERT_ORIGIN, ALERT_SEVERITY, ALERT_STATUS } from '../lib/labels';
import { errorMessage, fmtDateTime, fmtNumber } from '../lib/format';
import type { Alert, Area } from '../lib/types';
import {
  Badge, Button, Card, EmptyState, Field, Modal, Notice, PageHeader, QueryState, useToast,
} from '../components/ui';

const PAGE = 200;

export function Alerts() {
  const [params, setParams] = useSearchParams();
  const status = params.get('status') ?? 'abertos';
  const severity = params.get('severidade') ?? '';
  const origin = params.get('origem') ?? '';
  const areaId = params.get('area') ?? '';
  const [search, setSearch] = useState('');
  const [formOpen, setFormOpen] = useState(false);

  const setParam = (k: string, v: string) => {
    const next = new URLSearchParams(params);
    if (v) next.set(k, v); else next.delete(k);
    setParams(next, { replace: true });
  };

  const { data, error, loading, reload } = useQuery(async () => {
    let q = supabase.from('alerts').select('*').order('detected_at', { ascending: false }).limit(PAGE);
    if (status === 'abertos') q = q.neq('status', 'resolvido');
    else if (status) q = q.eq('status', status);
    if (severity) q = q.eq('severity', severity);
    if (origin) q = q.eq('origin', origin);
    if (areaId) q = q.eq('area_id', areaId);
    const [alerts, areas] = await Promise.all([q.then(must), fetchAreas(true)]);
    return { alerts: alerts as Alert[], areas };
  }, [status, severity, origin, areaId]);

  const areaMap = byId(data?.areas);
  const rows = useMemo(() => {
    const s = search.trim().toLowerCase();
    return (data?.alerts ?? []).filter((a) => !s || a.title.toLowerCase().includes(s)
      || (areaMap.get(a.area_id)?.name ?? '').toLowerCase().includes(s));
  }, [data, search, areaMap]);

  return (
    <>
      <PageHeader
        title="Alertas"
        subtitle="Alertas gerados por sensores e cadastrados manualmente"
        actions={<Button icon={<Plus size={16} />} onClick={() => setFormOpen(true)}>Alerta manual</Button>}
      />
      <Card padded={false}>
        <div className="toolbar">
          <div className="input-icon toolbar-search">
            <Search size={16} />
            <input placeholder="Buscar por título ou área" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <select value={status} onChange={(e) => setParam('status', e.target.value)} aria-label="Status">
            <option value="abertos">Ativos e em andamento</option>
            <option value="ativo">Ativos</option>
            <option value="em_andamento">Em andamento</option>
            <option value="resolvido">Resolvidos</option>
            <option value="">Todos</option>
          </select>
          <select value={severity} onChange={(e) => setParam('severidade', e.target.value)} aria-label="Severidade">
            <option value="">Todas as severidades</option>
            <option value="critico">Crítico</option>
            <option value="atencao">Atenção</option>
          </select>
          <select value={origin} onChange={(e) => setParam('origem', e.target.value)} aria-label="Origem">
            <option value="">Todas as origens</option>
            <option value="sensor">Sensor</option>
            <option value="manual">Manual</option>
          </select>
          <select value={areaId} onChange={(e) => setParam('area', e.target.value)} aria-label="Área">
            <option value="">Todas as áreas</option>
            {data?.areas.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
          </select>
          <Button variant="ghost" icon={<RefreshCw size={16} />} onClick={reload} aria-label="Atualizar" />
        </div>
        <QueryState loading={loading && !data} error={error} onRetry={reload}>
          {rows.length === 0 ? <EmptyState title="Nenhum alerta encontrado" /> : (
            <div className="table-wrap">
              <table className="table">
                <thead>
                  <tr><th>Alerta</th><th>Área</th><th>Severidade</th><th>Status</th><th>Origem</th><th>Valor</th><th>Detectado</th></tr>
                </thead>
                <tbody>
                  {rows.map((a) => (
                    <tr key={a.id}>
                      <td><Link to={`/alertas/${a.id}`} className="cell-link"><strong>{a.title}</strong>
                        <span className="muted small">{ALERT_CATEGORY[a.category] ?? a.category}</span></Link></td>
                      <td>{areaMap.get(a.area_id)?.name ?? '—'}</td>
                      <td><Badge tone={ALERT_SEVERITY[a.severity].tone}>{ALERT_SEVERITY[a.severity].label}</Badge></td>
                      <td><Badge tone={ALERT_STATUS[a.status].tone}>{ALERT_STATUS[a.status].label}</Badge></td>
                      <td className="muted small">{ALERT_ORIGIN[a.origin] ?? a.origin}</td>
                      <td className="num">{a.detected_value !== null ? `${fmtNumber(a.detected_value)} ${a.unit ?? ''}` : '—'}</td>
                      <td>{fmtDateTime(a.detected_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {data && data.alerts.length === PAGE && (
                <p className="muted small table-foot">Exibindo os {PAGE} alertas mais recentes. Use os filtros para refinar.</p>
              )}
            </div>
          )}
        </QueryState>
      </Card>
      {formOpen && <ManualAlertModal open areas={data?.areas.filter((a) => !a.archived_at) ?? []}
                        onClose={() => setFormOpen(false)} />}
    </>
  );
}

const MANUAL_CATEGORIES = Object.keys(ALERT_CATEGORY);

export function ManualAlertModal({ open, areas, alert, onClose, onSaved }: {
  open: boolean; areas: Area[]; alert?: Alert; onClose: () => void; onSaved?: () => void;
}) {
  const toast = useToast();
  const navigate = useNavigate();
  const [form, setForm] = useState(() => ({
    area_id: alert?.area_id ?? '', title: alert?.title ?? '', description: alert?.description ?? '',
    severity: alert?.severity ?? 'atencao', category: alert?.category ?? 'outro',
  }));
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const areaId = form.area_id || areas[0]?.id || '';

  async function save() {
    setErr(null);
    if (!areaId) return setErr('Selecione a área.');
    if (form.title.trim().length < 3) return setErr('O título deve ter pelo menos 3 caracteres.');
    setSaving(true);
    try {
      const payload = {
        area_id: areaId, title: form.title.trim(), description: form.description.trim() || null,
        severity: form.severity, category: form.category,
      };
      if (alert) {
        must(await supabase.from('alerts').update(payload).eq('id', alert.id));
        toast('Alerta atualizado.');
        onSaved?.();
        onClose();
      } else {
        // O trigger guard_alert_changes força origem 'manual' e sem sensor
        const created = must(await supabase.from('alerts')
          .insert({ ...payload, is_simulated: false }).select('id').single()) as { id: string };
        toast('Alerta manual cadastrado.');
        onClose();
        navigate(`/alertas/${created.id}`);
      }
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open={open} title={alert ? 'Editar alerta manual' : 'Novo alerta manual'} onClose={onClose}
           footer={<><Button variant="secondary" onClick={onClose}>Cancelar</Button><Button onClick={save} loading={saving}>Salvar</Button></>}>
      <div className="stack">
        {err && <Notice tone="critical">{err}</Notice>}
        <Field label="Área *">
          <select value={areaId} onChange={(e) => setForm({ ...form, area_id: e.target.value })}>
            {areas.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
          </select>
        </Field>
        <Field label="Título *">
          <input value={form.title} maxLength={120} onChange={(e) => setForm({ ...form, title: e.target.value })} autoFocus />
        </Field>
        <div className="form-grid">
          <Field label="Severidade">
            <select value={form.severity} onChange={(e) => setForm({ ...form, severity: e.target.value as Alert['severity'] })}>
              <option value="atencao">Atenção</option>
              <option value="critico">Crítico</option>
            </select>
          </Field>
          <Field label="Categoria">
            <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
              {MANUAL_CATEGORIES.map((c) => <option key={c} value={c}>{ALERT_CATEGORY[c]}</option>)}
            </select>
          </Field>
        </div>
        <Field label="Descrição">
          <textarea rows={4} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
        </Field>
      </div>
    </Modal>
  );
}
