import { useMemo, useState } from 'react';
import { RefreshCw, Search } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { must, useQuery } from '../lib/useQuery';
import { byId, fetchAreas } from '../lib/data';
import { OCC_KIND, OCC_STATUS, PRIORITY } from '../lib/labels';
import { errorMessage, fmtDateTime } from '../lib/format';
import type { Occurrence } from '../lib/types';
import {
  Badge, Button, Card, EmptyState, InfoRow, Modal, Notice, PageHeader, QueryState, useToast,
} from '../components/ui';

export function Occurrences() {
  const [status, setStatus] = useState('abertas');
  const [kind, setKind] = useState('');
  const [priority, setPriority] = useState('');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<Occurrence | null>(null);

  const { data, error, loading, reload } = useQuery(async () => {
    let q = supabase.from('occurrences').select('*').order('created_at', { ascending: false }).limit(300);
    if (status === 'abertas') q = q.neq('status', 'resolvida');
    else if (status) q = q.eq('status', status);
    if (kind) q = q.eq('kind', kind);
    if (priority) q = q.eq('priority', priority);
    const [rows, areas] = await Promise.all([q.then(must), fetchAreas(true)]);
    return { rows: rows as Occurrence[], areas };
  }, [status, kind, priority]);

  const areaMap = byId(data?.areas);
  const rows = useMemo(() => {
    const s = search.trim().toLowerCase();
    return (data?.rows ?? []).filter((o) => !s || o.title.toLowerCase().includes(s)
      || o.reported_by_name.toLowerCase().includes(s));
  }, [data, search]);

  return (
    <>
      <PageHeader title="Ocorrências" subtitle="Mural de avisos e ocorrências registradas pela equipe no aplicativo" />
      <Card padded={false}>
        <div className="toolbar">
          <div className="input-icon toolbar-search">
            <Search size={16} />
            <input placeholder="Buscar por título ou autor" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <select value={status} onChange={(e) => setStatus(e.target.value)} aria-label="Status">
            <option value="abertas">Abertas e em análise</option>
            <option value="aberta">Abertas</option>
            <option value="em_analise">Em análise</option>
            <option value="resolvida">Resolvidas</option>
            <option value="">Todas</option>
          </select>
          <select value={kind} onChange={(e) => setKind(e.target.value)} aria-label="Tipo">
            <option value="">Avisos e ocorrências</option>
            <option value="ocorrencia">Ocorrências</option>
            <option value="aviso">Avisos</option>
          </select>
          <select value={priority} onChange={(e) => setPriority(e.target.value)} aria-label="Prioridade">
            <option value="">Todas as prioridades</option>
            {Object.entries(PRIORITY).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
          </select>
          <Button variant="ghost" icon={<RefreshCw size={16} />} onClick={reload} aria-label="Atualizar" />
        </div>
        <QueryState loading={loading && !data} error={error} onRetry={reload}>
          {rows.length === 0 ? <EmptyState title="Nenhuma ocorrência encontrada" /> : (
            <div className="table-wrap">
              <table className="table">
                <thead><tr><th>Título</th><th>Tipo</th><th>Área</th><th>Prioridade</th><th>Status</th><th>Autor</th><th>Registrada</th></tr></thead>
                <tbody>
                  {rows.map((o) => (
                    <tr key={o.id} className="clickable" onClick={() => setSelected(o)}>
                      <td><button className="cell-link link-btn-plain"><strong>{o.title}</strong></button></td>
                      <td>{OCC_KIND[o.kind]}</td>
                      <td>{o.area_id ? areaMap.get(o.area_id)?.name ?? '—' : <span className="muted small">Geral</span>}</td>
                      <td><Badge tone={PRIORITY[o.priority].tone}>{PRIORITY[o.priority].label}</Badge></td>
                      <td><Badge tone={OCC_STATUS[o.status].tone}>{OCC_STATUS[o.status].label}</Badge></td>
                      <td>{o.reported_by_name || '—'}</td>
                      <td>{fmtDateTime(o.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </QueryState>
      </Card>
      {selected && (
        <OccurrenceModal occurrence={selected} areaName={selected.area_id ? areaMap.get(selected.area_id)?.name : undefined}
                         onClose={() => setSelected(null)} onChanged={() => { setSelected(null); reload(); }} />
      )}
    </>
  );
}

function OccurrenceModal({ occurrence: o, areaName, onClose, onChanged }: {
  occurrence: Occurrence; areaName?: string; onClose: () => void; onChanged: () => void;
}) {
  const toast = useToast();
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  async function setStatus(status: Occurrence['status']) {
    setBusy(status);
    setErr(null);
    try {
      must(await supabase.rpc('update_occurrence_status', { p_id: o.id, p_status: status }));
      toast(`Status alterado para ${OCC_STATUS[status].label}.`);
      onChanged();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(null);
    }
  }

  return (
    <Modal open wide title={o.title} onClose={onClose}
           footer={
             <>
               {(['aberta', 'em_analise', 'resolvida'] as const).filter((s) => s !== o.status).map((s) => (
                 <Button key={s} variant={s === 'resolvida' ? 'success' : 'secondary'} loading={busy === s}
                         disabled={busy !== null} onClick={() => setStatus(s)}>
                   {s === 'aberta' ? 'Reabrir' : s === 'em_analise' ? 'Colocar em análise' : 'Marcar como resolvida'}
                 </Button>
               ))}
             </>
           }>
      <div className="stack">
        {err && <Notice tone="critical">{err}</Notice>}
        <div className="row-gap">
          <Badge tone={OCC_STATUS[o.status].tone}>{OCC_STATUS[o.status].label}</Badge>
          <Badge tone={PRIORITY[o.priority].tone}>Prioridade {PRIORITY[o.priority].label.toLowerCase()}</Badge>
          <span className="muted small">{OCC_KIND[o.kind]}</span>
        </div>
        <div className="desc">{o.description}</div>
        <InfoRow label="Área">{areaName ?? 'Geral'}</InfoRow>
        <InfoRow label="Registrada por">{o.reported_by_name || '—'}</InfoRow>
        <InfoRow label="Responsável">{o.responsible_name || '—'}</InfoRow>
        <InfoRow label="Registrada em">{fmtDateTime(o.created_at)}</InfoRow>
        <InfoRow label="Atualizada em">{fmtDateTime(o.updated_at)}</InfoRow>
      </div>
    </Modal>
  );
}
