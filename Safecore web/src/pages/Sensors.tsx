import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Plus, RefreshCw, Search } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { must, useQuery } from '../lib/useQuery';
import { byId, fetchAreas, fetchSensors } from '../lib/data';
import { SENSOR_LEVEL, SENSOR_STATUS, SENSOR_TYPES } from '../lib/labels';
import { errorMessage, fmtNumber, fmtRelative } from '../lib/format';
import type { Area, Sensor } from '../lib/types';
import {
  Badge, Button, Card, EmptyState, Field, Modal, Notice, PageHeader, QueryState, useToast,
} from '../components/ui';

export function Sensors() {
  const { data, error, loading, reload } = useQuery(async () => {
    const [sensors, areas] = await Promise.all([fetchSensors(), fetchAreas(true)]);
    return { sensors, areas };
  });
  const [search, setSearch] = useState('');
  const [areaId, setAreaId] = useState('');
  const [type, setType] = useState('');
  const [status, setStatus] = useState('');
  const [level, setLevel] = useState('');
  const [formOpen, setFormOpen] = useState(false);
  const areaMap = byId(data?.areas);

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (data?.sensors ?? []).filter((s) =>
      (!areaId || s.area_id === areaId) && (!type || s.sensor_type === type)
      && (!status || s.status === status) && (!level || s.level === level)
      && (!q || s.name.toLowerCase().includes(q) || s.code.toLowerCase().includes(q)
          || (s.device_id ?? '').toLowerCase().includes(q)));
  }, [data, search, areaId, type, status, level]);

  const summary = (st: string) => data?.sensors.filter((s) => s.status === st).length ?? 0;

  return (
    <>
      <PageHeader
        title="Sensores"
        subtitle={data ? `${summary('online')} online · ${summary('offline')} sem comunicação · ${summary('manutencao')} em manutenção` : undefined}
        actions={<Button icon={<Plus size={16} />} onClick={() => setFormOpen(true)}>Novo sensor</Button>}
      />
      <Card padded={false}>
        <div className="toolbar">
          <div className="input-icon toolbar-search">
            <Search size={16} />
            <input placeholder="Buscar por nome, código ou dispositivo" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <select value={areaId} onChange={(e) => setAreaId(e.target.value)} aria-label="Área">
            <option value="">Todas as áreas</option>
            {data?.areas.map((a) => <option key={a.id} value={a.id}>{a.name}{a.archived_at ? ' (arquivada)' : ''}</option>)}
          </select>
          <select value={type} onChange={(e) => setType(e.target.value)} aria-label="Tipo">
            <option value="">Todos os tipos</option>
            {Object.entries(SENSOR_TYPES).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
          </select>
          <select value={status} onChange={(e) => setStatus(e.target.value)} aria-label="Status">
            <option value="">Todos os status</option>
            {Object.entries(SENSOR_STATUS).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
          </select>
          <select value={level} onChange={(e) => setLevel(e.target.value)} aria-label="Nível">
            <option value="">Todos os níveis</option>
            {Object.entries(SENSOR_LEVEL).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
          </select>
          <Button variant="ghost" icon={<RefreshCw size={16} />} onClick={reload} aria-label="Atualizar" />
        </div>
        <QueryState loading={loading && !data} error={error} onRetry={reload}>
          {rows.length === 0 ? <EmptyState title="Nenhum sensor encontrado" /> : (
            <div className="table-wrap">
              <table className="table">
                <thead>
                  <tr><th>Sensor</th><th>Área</th><th>Tipo</th><th>Último valor</th><th>Faixa segura</th><th>Nível</th><th>Status</th><th>Última leitura</th></tr>
                </thead>
                <tbody>
                  {rows.map((s) => (
                    <tr key={s.id}>
                      <td><Link to={`/sensores/${s.id}`} className="cell-link"><strong>{s.name}</strong><span className="muted small">{s.code}</span></Link></td>
                      <td>{areaMap.get(s.area_id)?.name ?? '—'}</td>
                      <td>{SENSOR_TYPES[s.sensor_type]?.label ?? s.sensor_type}</td>
                      <td className="num">{fmtNumber(s.last_value)} {s.unit}</td>
                      <td className="muted small">{fmtNumber(s.ref_min)} a {fmtNumber(s.ref_max)} {s.unit}</td>
                      <td><Badge tone={SENSOR_LEVEL[s.level].tone}>{SENSOR_LEVEL[s.level].label}</Badge></td>
                      <td><Badge tone={SENSOR_STATUS[s.status].tone}>{SENSOR_STATUS[s.status].label}</Badge></td>
                      <td>{fmtRelative(s.last_reading_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </QueryState>
      </Card>
      <SensorFormModal open={formOpen} areas={data?.areas.filter((a) => !a.archived_at) ?? []}
                       onClose={() => setFormOpen(false)} onSaved={reload} />
    </>
  );
}

type NumField = 'ref_min' | 'ref_max' | 'critical_min' | 'critical_max';
const toNum = (v: string) => (v.trim() === '' ? null : Number(v.replace(',', '.')));

export function SensorFormModal({ open, sensor, areas, onClose, onSaved }: {
  open: boolean; sensor?: Sensor; areas: Area[]; onClose: () => void; onSaved: (s: Sensor) => void;
}) {
  const toast = useToast();
  const init = () => ({
    area_id: sensor?.area_id ?? areas[0]?.id ?? '',
    code: sensor?.code ?? '',
    name: sensor?.name ?? '',
    sensor_type: sensor?.sensor_type ?? 'temperatura',
    unit: sensor?.unit ?? '°C',
    ref_min: sensor?.ref_min?.toString() ?? '',
    ref_max: sensor?.ref_max?.toString() ?? '',
    critical_min: sensor?.critical_min?.toString() ?? '',
    critical_max: sensor?.critical_max?.toString() ?? '',
    status: sensor?.status ?? 'online',
    device_id: sensor?.device_id ?? '',
    is_simulated: sensor?.is_simulated ?? true,
  });
  const [form, setForm] = useState(init);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setForm(init());
      setErr(null);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, sensor]);

  async function save() {
    setErr(null);
    if (!form.area_id) return setErr('Selecione a área.');
    if (form.code.trim().length < 2) return setErr('Informe o código (mínimo 2 caracteres).');
    if (form.name.trim().length < 2) return setErr('Informe o nome do sensor.');
    if (!form.unit.trim()) return setErr('Informe a unidade.');
    const nums = Object.fromEntries((['ref_min', 'ref_max', 'critical_min', 'critical_max'] as NumField[])
      .map((k) => [k, toNum(form[k])])) as Record<NumField, number | null>;
    if (Object.values(nums).some((v) => v !== null && Number.isNaN(v))) return setErr('Limites devem ser números.');
    if (nums.ref_min !== null && nums.ref_max !== null && nums.ref_min > nums.ref_max) {
      return setErr('O mínimo da faixa segura deve ser menor que o máximo.');
    }
    setSaving(true);
    try {
      const payload = {
        area_id: form.area_id, code: form.code.trim().toUpperCase(), name: form.name.trim(),
        sensor_type: form.sensor_type, unit: form.unit.trim(), ...nums, status: form.status,
        device_id: form.device_id.trim() || null, is_simulated: form.is_simulated,
      };
      const saved = sensor
        ? must(await supabase.from('sensors').update(payload).eq('id', sensor.id).select().single())
        : must(await supabase.from('sensors').insert(payload).select().single());
      toast(sensor ? 'Sensor atualizado.' : 'Sensor cadastrado.');
      onSaved(saved as unknown as Sensor);
      onClose();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setSaving(false);
    }
  }

  const set = (k: keyof ReturnType<typeof init>, v: string | boolean) => setForm((f) => ({ ...f, [k]: v }));

  return (
    <Modal open={open} wide title={sensor ? 'Editar sensor' : 'Novo sensor'} onClose={onClose}
           footer={<><Button variant="secondary" onClick={onClose}>Cancelar</Button><Button onClick={save} loading={saving}>Salvar</Button></>}>
      <div className="stack">
        {err && <Notice tone="critical">{err}</Notice>}
        <div className="form-grid">
          <Field label="Área *">
            <select value={form.area_id} onChange={(e) => set('area_id', e.target.value)}>
              {areas.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
            </select>
          </Field>
          <Field label="Código *">
            <input value={form.code} maxLength={30} onChange={(e) => set('code', e.target.value)} />
          </Field>
          <Field label="Nome *">
            <input value={form.name} maxLength={80} onChange={(e) => set('name', e.target.value)} />
          </Field>
          <Field label="Tipo *">
            <select value={form.sensor_type} onChange={(e) => {
              const t = e.target.value;
              setForm((f) => ({ ...f, sensor_type: t, unit: sensor ? f.unit : SENSOR_TYPES[t]?.unit ?? f.unit }));
            }}>
              {Object.entries(SENSOR_TYPES).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
            </select>
          </Field>
          <Field label="Unidade *"><input value={form.unit} maxLength={10} onChange={(e) => set('unit', e.target.value)} /></Field>
          <Field label="Status">
            <select value={form.status} onChange={(e) => set('status', e.target.value)}>
              {Object.entries(SENSOR_STATUS).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
            </select>
          </Field>
          <Field label="Faixa segura — mínimo"><input inputMode="decimal" value={form.ref_min} onChange={(e) => set('ref_min', e.target.value)} /></Field>
          <Field label="Faixa segura — máximo"><input inputMode="decimal" value={form.ref_max} onChange={(e) => set('ref_max', e.target.value)} /></Field>
          <Field label="Limite crítico — mínimo"><input inputMode="decimal" value={form.critical_min} onChange={(e) => set('critical_min', e.target.value)} /></Field>
          <Field label="Limite crítico — máximo"><input inputMode="decimal" value={form.critical_max} onChange={(e) => set('critical_max', e.target.value)} /></Field>
          <Field label="ID do dispositivo (ESP32)"><input value={form.device_id} onChange={(e) => set('device_id', e.target.value)} /></Field>
        </div>
        <label className="checkbox">
          <input type="checkbox" checked={form.is_simulated} onChange={(e) => set('is_simulated', e.target.checked)} />
          <span><strong>Sensor simulado</strong><span className="muted small">Recebe leituras geradas pela simulação do app.</span></span>
        </label>
      </div>
    </Modal>
  );
}
