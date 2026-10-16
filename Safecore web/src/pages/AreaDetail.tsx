import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Archive, ArchiveRestore, ArrowLeft, Lock, Pencil, Trash2, UserPlus, X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { must, useQuery } from '../lib/useQuery';
import { fetchProfiles } from '../lib/data';
import {
  ACCESS_LABEL, ALERT_SEVERITY, ALERT_STATUS, AREA_STATUS, AREA_TYPES, ROLE_LABEL,
  SENSOR_LEVEL, SENSOR_STATUS, SENSOR_TYPES,
} from '../lib/labels';
import { errorMessage, fmtDateTime, fmtNumber, fmtRelative } from '../lib/format';
import type { AccessLevel, Alert, Area, AreaMember, Sensor } from '../lib/types';
import {
  Avatar, Badge, Button, Card, ConfirmDialog, EmptyState, InfoRow, Notice, QueryState, useToast,
} from '../components/ui';
import { AreaFormModal } from './Areas';

async function loadArea(id: string) {
  const [area, sensors, members, alerts, profiles] = await Promise.all([
    supabase.from('areas').select('*').eq('id', id).maybeSingle().then(must),
    supabase.from('sensors').select('*').eq('area_id', id).order('code').then(must),
    supabase.from('area_members').select('*').eq('area_id', id).then(must),
    supabase.from('alerts').select('*').eq('area_id', id).neq('status', 'resolvido')
      .order('detected_at', { ascending: false }).then(must),
    fetchProfiles(),
  ]);
  return {
    area: area as Area | null,
    sensors: sensors as Sensor[],
    members: members as AreaMember[],
    alerts: alerts as Alert[],
    profiles,
  };
}

export function AreaDetail() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const toast = useToast();
  const { data, error, loading, reload } = useQuery(() => loadArea(id), [id]);
  const [editOpen, setEditOpen] = useState(false);
  const [dialog, setDialog] = useState<null | 'delete' | 'restore'>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function removeArea() {
    setBusy(true);
    setErr(null);
    try {
      // delete_area: exclui se não houver histórico; caso contrário arquiva
      const result = must(await supabase.rpc('delete_area', { p_area_id: id })) as string;
      setDialog(null);
      if (result === 'excluida') {
        toast('Área excluída.');
        navigate('/areas', { replace: true });
      } else {
        toast('Área arquivada. Sensores, leituras e alertas foram preservados.');
        reload();
      }
    } catch (e) {
      setErr(errorMessage(e));
      setDialog(null);
    } finally {
      setBusy(false);
    }
  }

  async function restore() {
    setBusy(true);
    setErr(null);
    try {
      must(await supabase.from('areas').update({ archived_at: null, status_note: null }).eq('id', id));
      toast('Área restaurada.');
      setDialog(null);
      reload();
    } catch (e) {
      setErr(errorMessage(e));
      setDialog(null);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <Link to="/areas" className="back-link"><ArrowLeft size={16} /> Áreas</Link>
      <QueryState loading={loading && !data} error={error} onRetry={reload}>
        {data && !data.area && <EmptyState title="Área não encontrada" />}
        {data?.area && (() => {
          const area = data.area;
          const st = AREA_STATUS[area.status] ?? AREA_STATUS.segura;
          return (
            <div className="stack-lg">
              <div className="page-header">
                <div>
                  <h1>{area.name}</h1>
                  <div className="row-gap">
                    <span className="muted">{area.code} · {AREA_TYPES[area.area_type] ?? area.area_type}</span>
                    {area.archived_at ? <Badge tone="offline">Arquivada</Badge> : <Badge tone={st.tone}>{st.label}</Badge>}
                    {area.restricted && <Badge tone="blocked" icon={<Lock size={12} />}>Restrita</Badge>}
                  </div>
                </div>
                <div className="page-actions">
                  <Button variant="secondary" icon={<Pencil size={16} />} onClick={() => setEditOpen(true)}>Editar</Button>
                  {area.archived_at ? (
                    <Button variant="secondary" icon={<ArchiveRestore size={16} />} onClick={() => setDialog('restore')}>Restaurar</Button>
                  ) : (
                    <Button variant="danger" icon={<Trash2 size={16} />} onClick={() => setDialog('delete')}>Excluir / arquivar</Button>
                  )}
                </div>
              </div>

              {err && <Notice tone="critical">{err}</Notice>}
              {area.archived_at && (
                <Notice tone="warning">
                  <span className="notice-row"><Archive size={16} />
                    <span>Área arquivada em {fmtDateTime(area.archived_at)}. O histórico está preservado e ela não recebe leituras simuladas.</span>
                  </span>
                </Notice>
              )}

              <div className="grid-2">
                <Card title="Informações">
                  <InfoRow label="Descrição">{area.description || '—'}</InfoRow>
                  <InfoRow label="Observação de status">{area.status_note || '—'}</InfoRow>
                  <InfoRow label="Sensores">{data.sensors.length}</InfoRow>
                  <InfoRow label="Alertas abertos">{data.alerts.length}</InfoRow>
                  <InfoRow label="Atualizada em">{fmtDateTime(area.updated_at)}</InfoRow>
                </Card>
                <MembersCard area={area} members={data.members} profiles={data.profiles} onChanged={reload} />
              </div>

              <Card title="Sensores da área" padded={false}>
                {data.sensors.length === 0 ? <EmptyState title="Nenhum sensor nesta área" /> : (
                  <div className="table-wrap">
                    <table className="table">
                      <thead><tr><th>Sensor</th><th>Tipo</th><th>Último valor</th><th>Nível</th><th>Status</th><th>Última leitura</th></tr></thead>
                      <tbody>
                        {data.sensors.map((s) => (
                          <tr key={s.id}>
                            <td><Link to={`/sensores/${s.id}`} className="cell-link"><strong>{s.name}</strong><span className="muted small">{s.code}</span></Link></td>
                            <td>{SENSOR_TYPES[s.sensor_type]?.label ?? s.sensor_type}</td>
                            <td>{fmtNumber(s.last_value)} {s.unit}</td>
                            <td><Badge tone={SENSOR_LEVEL[s.level].tone}>{SENSOR_LEVEL[s.level].label}</Badge></td>
                            <td><Badge tone={SENSOR_STATUS[s.status].tone}>{SENSOR_STATUS[s.status].label}</Badge></td>
                            <td>{fmtRelative(s.last_reading_at)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </Card>

              <Card title="Alertas em aberto" padded={false}>
                {data.alerts.length === 0 ? <EmptyState title="Nenhum alerta em aberto" /> : (
                  <ul className="list padded">
                    {data.alerts.map((a) => (
                      <li key={a.id}>
                        <Link to={`/alertas/${a.id}`} className="list-link">
                          <div><strong>{a.title}</strong><span className="muted small">{fmtRelative(a.detected_at)}</span></div>
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

              <AreaFormModal open={editOpen} area={area} onClose={() => setEditOpen(false)} onSaved={() => reload()} />
              <ConfirmDialog open={dialog === 'delete'} danger title="Excluir ou arquivar área" confirmLabel="Confirmar"
                             loading={busy} onClose={() => setDialog(null)} onConfirm={removeArea}
                             message={<>
                               <p>Se a área <strong>{area.name}</strong> tiver histórico (sensores, alertas, ocorrências ou ações), ela será
                               <strong> arquivada</strong> e seus sensores entrarão em manutenção, preservando todos os dados.</p>
                               <p className="muted small">Áreas sem histórico são excluídas definitivamente.</p>
                             </>} />
              <ConfirmDialog open={dialog === 'restore'} title="Restaurar área" confirmLabel="Restaurar"
                             loading={busy} onClose={() => setDialog(null)} onConfirm={restore}
                             message={<>A área voltará a aparecer para os funcionários conforme as permissões. Os sensores permanecem
                               em manutenção até serem reativados na página de cada sensor.</>} />
            </div>
          );
        })()}
      </QueryState>
    </>
  );
}

function MembersCard({ area, members, profiles, onChanged }: {
  area: Area; members: AreaMember[]; profiles: Awaited<ReturnType<typeof fetchProfiles>>; onChanged: () => void;
}) {
  const toast = useToast();
  const [userId, setUserId] = useState('');
  const [level, setLevel] = useState<AccessLevel>('leitura');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const profileMap = new Map(profiles.map((p) => [p.id, p]));
  const memberIds = new Set(members.map((m) => m.user_id));
  const candidates = profiles.filter((p) => !memberIds.has(p.id) && p.active !== false
    && p.role !== 'admin' && p.role !== 'supervisor');
  const selected = profileMap.get(userId);

  async function setMember(uid: string, lvl: AccessLevel | null) {
    setBusy(true);
    setErr(null);
    try {
      must(await supabase.rpc('set_area_member', { p_user_id: uid, p_area_id: area.id, p_level: lvl }));
      toast(lvl ? 'Permissão atualizada.' : 'Vínculo removido.');
      setUserId('');
      onChanged();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card title={`Funcionários vinculados (${members.length})`}>
      <div className="stack">
        {err && <Notice tone="critical">{err}</Notice>}
        <p className="muted small">
          Administradores e supervisores têm gestão de todas as áreas pelo cargo.
          {area.restricted ? ' Por ser restrita, só funcionários vinculados visualizam esta área.' : ' Áreas públicas permitem leitura a todos.'}
        </p>
        {members.length === 0 ? <EmptyState title="Nenhum funcionário vinculado" /> : (
          <ul className="member-list">
            {members.map((m) => {
              const p = profileMap.get(m.user_id);
              return (
                <li key={m.user_id}>
                  <Link to={`/funcionarios/${m.user_id}`} className="person">
                    <Avatar name={p?.full_name || p?.email || '?'} size={30} />
                    <span>
                      <strong>{p?.full_name || p?.email || 'Funcionário'}</strong>
                      <span className="muted small">{p ? ROLE_LABEL[p.role] : ''}{p?.active === false ? ' · desativado' : ''}</span>
                    </span>
                  </Link>
                  <select value={m.access_level} disabled={busy}
                          onChange={(e) => setMember(m.user_id, e.target.value as AccessLevel)}>
                    <option value="leitura">Leitura</option>
                    <option value="operacao">Operação</option>
                    <option value="gestao" disabled={p?.role === 'operador'}>Gestão</option>
                  </select>
                  <button className="icon-btn" disabled={busy} onClick={() => setMember(m.user_id, null)}
                          title="Remover vínculo" aria-label="Remover vínculo"><X size={16} /></button>
                </li>
              );
            })}
          </ul>
        )}
        <div className="add-member">
          <select value={userId} onChange={(e) => setUserId(e.target.value)} aria-label="Funcionário">
            <option value="">Selecionar funcionário…</option>
            {candidates.map((p) => <option key={p.id} value={p.id}>{p.full_name || p.email} — {ROLE_LABEL[p.role]}</option>)}
          </select>
          <select value={level} onChange={(e) => setLevel(e.target.value as AccessLevel)} aria-label="Nível">
            {(Object.keys(ACCESS_LABEL) as AccessLevel[]).map((l) => (
              <option key={l} value={l} disabled={l === 'gestao' && selected?.role === 'operador'}>{ACCESS_LABEL[l]}</option>
            ))}
          </select>
          <Button icon={<UserPlus size={16} />} disabled={!userId} loading={busy}
                  onClick={() => setMember(userId, level === 'gestao' && selected?.role === 'operador' ? 'operacao' : level)}>
            Vincular
          </Button>
        </div>
      </div>
    </Card>
  );
}
