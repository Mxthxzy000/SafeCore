import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Archive, Lock, Plus, Search } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { must, useQuery } from '../lib/useQuery';
import { fetchAreas, fetchSensors } from '../lib/data';
import { AREA_STATUS, AREA_STATUS_PRIORITY, AREA_TYPES } from '../lib/labels';
import { errorMessage } from '../lib/format';
import type { Area } from '../lib/types';
import {
  Badge, Button, Card, EmptyState, Field, Modal, Notice, PageHeader, QueryState, useToast,
} from '../components/ui';

export function Areas() {
  const { data, error, loading, reload } = useQuery(async () => {
    const [areas, sensors, members, alerts] = await Promise.all([
      fetchAreas(true),
      fetchSensors(),
      supabase.from('area_members').select('area_id').then(must),
      supabase.from('alerts').select('area_id').neq('status', 'resolvido').then(must),
    ]);
    return { areas, sensors, members: members as { area_id: string }[], alerts: alerts as { area_id: string }[] };
  });
  const [showArchived, setShowArchived] = useState(false);
  const [search, setSearch] = useState('');
  const [formOpen, setFormOpen] = useState(false);

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (data?.areas ?? [])
      .filter((a) => (showArchived ? a.archived_at : !a.archived_at))
      .filter((a) => !q || a.name.toLowerCase().includes(q) || a.code.toLowerCase().includes(q))
      .sort((a, b) => (AREA_STATUS_PRIORITY[a.status] ?? 9) - (AREA_STATUS_PRIORITY[b.status] ?? 9) || a.name.localeCompare(b.name));
  }, [data, showArchived, search]);

  const count = (list: { area_id: string }[] | undefined, id: string) => list?.filter((x) => x.area_id === id).length ?? 0;

  return (
    <>
      <PageHeader
        title="Áreas e permissões"
        subtitle="Setores industriais, restrição de acesso e funcionários vinculados"
        actions={<Button icon={<Plus size={16} />} onClick={() => setFormOpen(true)}>Nova área</Button>}
      />
      <Card padded={false}>
        <div className="toolbar">
          <div className="input-icon toolbar-search">
            <Search size={16} />
            <input placeholder="Buscar por nome ou código" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <div className="segmented small">
            <button className={!showArchived ? 'active' : ''} onClick={() => setShowArchived(false)}>Ativas</button>
            <button className={showArchived ? 'active' : ''} onClick={() => setShowArchived(true)}>
              <Archive size={14} /> Arquivadas
            </button>
          </div>
        </div>
        <QueryState loading={loading && !data} error={error} onRetry={reload}>
          {rows.length === 0 ? (
            <EmptyState title={showArchived ? 'Nenhuma área arquivada' : 'Nenhuma área encontrada'} />
          ) : (
            <div className="table-wrap">
              <table className="table">
                <thead>
                  <tr><th>Área</th><th>Tipo</th><th>Condição</th><th>Acesso</th><th>Sensores</th><th>Vinculados</th><th>Alertas abertos</th></tr>
                </thead>
                <tbody>
                  {rows.map((a) => {
                    const st = AREA_STATUS[a.status] ?? AREA_STATUS.segura;
                    const open = count(data?.alerts, a.id);
                    return (
                      <tr key={a.id}>
                        <td>
                          <Link to={`/areas/${a.id}`} className="cell-link">
                            <strong>{a.name}</strong>
                            <span className="muted small">{a.code}</span>
                          </Link>
                        </td>
                        <td>{AREA_TYPES[a.area_type] ?? a.area_type}</td>
                        <td>{a.archived_at ? <Badge tone="offline">Arquivada</Badge> : <Badge tone={st.tone}>{st.label}</Badge>}</td>
                        <td>{a.restricted ? <Badge tone="blocked" icon={<Lock size={12} />}>Restrita</Badge> : <span className="muted small">Pública</span>}</td>
                        <td>{data?.sensors.filter((s) => s.area_id === a.id).length ?? 0}</td>
                        <td>{count(data?.members, a.id)}</td>
                        <td>{open > 0 ? <Badge tone="warning">{open}</Badge> : <span className="muted small">0</span>}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </QueryState>
      </Card>
      <AreaFormModal open={formOpen} onClose={() => setFormOpen(false)} onSaved={reload} />
    </>
  );
}

type AreaForm = Pick<Area, 'code' | 'name' | 'description' | 'area_type' | 'restricted'>;

export function AreaFormModal({ open, area, onClose, onSaved }: {
  open: boolean; area?: Area; onClose: () => void; onSaved: (a: Area) => void;
}) {
  const toast = useToast();
  const initial: AreaForm = {
    code: area?.code ?? '', name: area?.name ?? '', description: area?.description ?? '',
    area_type: area?.area_type ?? 'producao', restricted: area?.restricted ?? false,
  };
  const [form, setForm] = useState<AreaForm>(initial);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setForm(initial);
      setErr(null);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, area]);

  async function save() {
    setErr(null);
    const code = form.code.trim().toUpperCase();
    const name = form.name.trim();
    if (code.length < 2 || code.length > 20) return setErr('O código deve ter de 2 a 20 caracteres.');
    if (name.length < 2 || name.length > 80) return setErr('O nome deve ter de 2 a 80 caracteres.');
    setSaving(true);
    try {
      const payload = { code, name, description: form.description?.trim() || null, area_type: form.area_type, restricted: form.restricted };
      const saved = area
        ? must(await supabase.from('areas').update(payload).eq('id', area.id).select().single())
        : must(await supabase.from('areas').insert(payload).select().single());
      toast(area ? 'Área atualizada.' : 'Área cadastrada.');
      onSaved(saved as unknown as Area);
      onClose();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open={open} title={area ? 'Editar área' : 'Nova área'} onClose={onClose}
           footer={<><Button variant="secondary" onClick={onClose}>Cancelar</Button><Button onClick={save} loading={saving}>Salvar</Button></>}>
      <div className="stack">
        {err && <Notice tone="critical">{err}</Notice>}
        <div className="form-grid">
          <Field label="Código *" hint="Ex.: PRD, CLD">
            <input value={form.code} maxLength={20} onChange={(e) => setForm({ ...form, code: e.target.value })} autoFocus />
          </Field>
          <Field label="Tipo">
            <select value={form.area_type} onChange={(e) => setForm({ ...form, area_type: e.target.value })}>
              {Object.entries(AREA_TYPES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
            </select>
          </Field>
        </div>
        <Field label="Nome *">
          <input value={form.name} maxLength={80} onChange={(e) => setForm({ ...form, name: e.target.value })} />
        </Field>
        <Field label="Descrição">
          <textarea rows={3} value={form.description ?? ''} onChange={(e) => setForm({ ...form, description: e.target.value })} />
        </Field>
        <label className="checkbox">
          <input type="checkbox" checked={form.restricted} onChange={(e) => setForm({ ...form, restricted: e.target.checked })} />
          <span>
            <strong>Área restrita</strong>
            <span className="muted small">Visível apenas para funcionários vinculados (além de supervisores e administradores).</span>
          </span>
        </label>
      </div>
    </Modal>
  );
}
