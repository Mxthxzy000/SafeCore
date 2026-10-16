import { Fragment, useState } from 'react';
import { ChevronDown, ChevronRight, Download, RefreshCw } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { must, useQuery } from '../lib/useQuery';
import { AUDIT_ACTION, AUDIT_ENTITY } from '../lib/labels';
import { downloadCsv, fmtDateTime } from '../lib/format';
import type { AuditLog } from '../lib/types';
import { Badge, Button, Card, EmptyState, PageHeader, QueryState } from '../components/ui';

const PAGE_SIZE = 50;

export function Audit() {
  const [entity, setEntity] = useState('');
  const [action, setAction] = useState('');
  const [user, setUser] = useState('');
  const [page, setPage] = useState(0);
  const [expanded, setExpanded] = useState<number | null>(null);

  const { data, error, loading, reload } = useQuery(async () => {
    let q = supabase.from('audit_logs').select('*', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1);
    if (entity) q = q.eq('entity', entity);
    if (action) q = q.eq('action', action);
    if (user.trim()) q = q.ilike('user_name', `%${user.trim()}%`);
    const res = await q;
    return { rows: must(res) as AuditLog[], count: res.count ?? 0 };
  }, [entity, action, user, page]);

  const pages = Math.max(1, Math.ceil((data?.count ?? 0) / PAGE_SIZE));
  const resetPage = <T,>(fn: (v: T) => void) => (v: T) => { setPage(0); fn(v); };

  return (
    <>
      <PageHeader
        title="Logs de auditoria"
        subtitle="Registro das operações importantes feitas pelos usuários (somente leitura)"
        actions={data && data.rows.length > 0 && (
          <Button variant="secondary" icon={<Download size={16} />} onClick={() => downloadCsv('safecore-auditoria.csv', [
            ['Data', 'Usuário', 'Ação', 'Entidade', 'ID', 'Detalhes'],
            ...data.rows.map((l) => [fmtDateTime(l.created_at), l.user_name, AUDIT_ACTION[l.action]?.label, AUDIT_ENTITY[l.entity] ?? l.entity, l.entity_id, JSON.stringify(l.details)]),
          ])}>Exportar página (CSV)</Button>
        )}
      />
      <Card padded={false}>
        <div className="toolbar">
          <input className="toolbar-search plain" placeholder="Filtrar por usuário" value={user}
                 onChange={(e) => resetPage(setUser)(e.target.value)} />
          <select value={entity} onChange={(e) => resetPage(setEntity)(e.target.value)} aria-label="Entidade">
            <option value="">Todas as entidades</option>
            {Object.entries(AUDIT_ENTITY).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
          <select value={action} onChange={(e) => resetPage(setAction)(e.target.value)} aria-label="Ação">
            <option value="">Todas as ações</option>
            {Object.entries(AUDIT_ACTION).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
          </select>
          <Button variant="ghost" icon={<RefreshCw size={16} />} onClick={reload} aria-label="Atualizar" />
        </div>
        <QueryState loading={loading && !data} error={error} onRetry={reload}>
          {!data || data.rows.length === 0 ? <EmptyState title="Nenhum registro encontrado" /> : (
            <div className="table-wrap">
              <table className="table">
                <thead><tr><th /><th>Data</th><th>Usuário</th><th>Ação</th><th>Entidade</th><th>Registro</th></tr></thead>
                <tbody>
                  {data.rows.map((l) => (
                    <Fragment key={l.id}>
                      <tr className="clickable" onClick={() => setExpanded(expanded === l.id ? null : l.id)}>
                        <td className="icon-cell">{expanded === l.id ? <ChevronDown size={16} /> : <ChevronRight size={16} />}</td>
                        <td>{fmtDateTime(l.created_at)}</td>
                        <td>{l.user_name}</td>
                        <td><Badge tone={AUDIT_ACTION[l.action]?.tone ?? 'neutral'}>{AUDIT_ACTION[l.action]?.label ?? l.action}</Badge></td>
                        <td>{AUDIT_ENTITY[l.entity] ?? l.entity}</td>
                        <td className="muted small mono">{summarize(l)}</td>
                      </tr>
                      {expanded === l.id && (
                        <tr className="expanded-row">
                          <td colSpan={6}><AuditDetails log={l} /></td>
                        </tr>
                      )}
                    </Fragment>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {data && data.count > PAGE_SIZE && (
            <div className="pager">
              <Button variant="secondary" size="sm" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>Anterior</Button>
              <span className="muted small">Página {page + 1} de {pages} · {data.count} registros</span>
              <Button variant="secondary" size="sm" disabled={page + 1 >= pages} onClick={() => setPage((p) => p + 1)}>Próxima</Button>
            </div>
          )}
        </QueryState>
      </Card>
    </>
  );
}

function rowOf(l: AuditLog): Record<string, unknown> {
  const d = l.details ?? {};
  return ((d as Record<string, unknown>).depois as Record<string, unknown>) ?? d;
}

function summarize(l: AuditLog): string {
  const r = rowOf(l);
  const label = r.title ?? r.name ?? r.full_name ?? r.email ?? r.access_level;
  return label ? String(label) : (l.entity_id ?? '').slice(0, 18);
}

const HIDDEN = new Set(['updated_at', 'created_at']);

function AuditDetails({ log }: { log: AuditLog }) {
  const d = (log.details ?? {}) as Record<string, unknown>;
  if (log.action === 'update' && d.antes && d.depois) {
    const before = d.antes as Record<string, unknown>;
    const after = d.depois as Record<string, unknown>;
    const changed = Object.keys(after).filter((k) => !HIDDEN.has(k) && JSON.stringify(before[k]) !== JSON.stringify(after[k]));
    if (changed.length === 0) return <span className="muted small">Sem alterações relevantes.</span>;
    return (
      <table className="diff">
        <thead><tr><th>Campo</th><th>Antes</th><th>Depois</th></tr></thead>
        <tbody>
          {changed.map((k) => (
            <tr key={k}><td className="mono">{k}</td><td className="mono">{fmt(before[k])}</td><td className="mono">{fmt(after[k])}</td></tr>
          ))}
        </tbody>
      </table>
    );
  }
  return <pre className="json">{JSON.stringify(d, null, 2)}</pre>;
}

const fmt = (v: unknown) => (v === null || v === undefined ? '—' : typeof v === 'object' ? JSON.stringify(v) : String(v));
