import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { ArrowLeft, CheckCircle2, Hand, MessageSquare, Pencil } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { must, useQuery } from '../lib/useQuery';
import { fetchAreas } from '../lib/data';
import { ACTION_TYPE, ALERT_CATEGORY, ALERT_ORIGIN, ALERT_SEVERITY, ALERT_STATUS } from '../lib/labels';
import { errorMessage, fmtDateTime, fmtNumber } from '../lib/format';
import type { ActionLog, Alert, Profile, Sensor } from '../lib/types';
import {
  Badge, Button, Card, EmptyState, Field, InfoRow, Modal, Notice, QueryState, useToast,
} from '../components/ui';
import { ManualAlertModal } from './Alerts';

async function loadAlert(id: string) {
  const alert = must(await supabase.from('alerts').select('*').eq('id', id).maybeSingle()) as Alert | null;
  if (!alert) return null;
  const [areas, logs, sensor, resolver] = await Promise.all([
    fetchAreas(true),
    supabase.from('action_logs').select('*').eq('alert_id', id).order('created_at', { ascending: false }).then(must),
    alert.sensor_id
      ? supabase.from('sensors').select('*').eq('id', alert.sensor_id).maybeSingle().then(must)
      : Promise.resolve(null),
    alert.resolved_by
      ? supabase.from('profiles').select('id, full_name, email').eq('id', alert.resolved_by).maybeSingle().then(must)
      : Promise.resolve(null),
  ]);
  return {
    alert, areas, logs: logs as ActionLog[], sensor: sensor as Sensor | null,
    resolver: resolver as Pick<Profile, 'id' | 'full_name' | 'email'> | null,
  };
}

export function AlertDetail() {
  const { id = '' } = useParams();
  const toast = useToast();
  const { data, error, loading, reload } = useQuery(() => loadAlert(id), [id]);
  const [dialog, setDialog] = useState<null | 'assume' | 'resolve' | 'comment' | 'edit'>(null);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function run(fn: () => PromiseLike<{ error: unknown }>, success: string) {
    setBusy(true);
    setErr(null);
    try {
      const res = await fn();
      if (res.error) throw res.error;
      toast(success);
      setDialog(null);
      setText('');
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
      <Link to="/alertas" className="back-link"><ArrowLeft size={16} /> Alertas</Link>
      <QueryState loading={loading && !data} error={error} onRetry={reload}>
        {!loading && !data && <EmptyState title="Alerta não encontrado" />}
        {data && (() => {
          const { alert, sensor, logs, resolver } = data;
          const area = data.areas.find((a) => a.id === alert.area_id);
          const open = alert.status !== 'resolvido';
          const isManual = alert.origin === 'manual';
          return (
            <div className="stack-lg">
              <div className="page-header">
                <div>
                  <h1>{alert.title}</h1>
                  <div className="row-gap">
                    <Badge tone={ALERT_SEVERITY[alert.severity].tone}>{ALERT_SEVERITY[alert.severity].label}</Badge>
                    <Badge tone={ALERT_STATUS[alert.status].tone}>{ALERT_STATUS[alert.status].label}</Badge>
                    <span className="muted small">{ALERT_ORIGIN[alert.origin]}</span>
                  </div>
                </div>
                <div className="page-actions">
                  <Button variant="secondary" icon={<MessageSquare size={16} />} onClick={() => setDialog('comment')}>Comentar</Button>
                  {alert.status === 'ativo' && (
                    <Button variant="secondary" icon={<Hand size={16} />} onClick={() => setDialog('assume')}>Assumir</Button>
                  )}
                  {open && <Button variant="success" icon={<CheckCircle2 size={16} />} onClick={() => setDialog('resolve')}>Resolver</Button>}
                  {isManual && <Button variant="secondary" icon={<Pencil size={16} />} onClick={() => setDialog('edit')}>Editar</Button>}
                </div>
              </div>

              {err && <Notice tone="critical">{err}</Notice>}
              {!isManual && (
                <Notice tone="info">
                  Alerta gerado automaticamente por sensor: os dados de medição são preservados e não podem ser editados.
                  É possível comentar, assumir e resolver o alerta.
                </Notice>
              )}

              <div className="grid-2">
                <Card title="Detalhes">
                  <InfoRow label="Área">{area ? <Link to={`/areas/${area.id}`} className="link">{area.name}</Link> : '—'}</InfoRow>
                  <InfoRow label="Categoria">{ALERT_CATEGORY[alert.category] ?? alert.category}</InfoRow>
                  {sensor && <InfoRow label="Sensor"><Link to={`/sensores/${sensor.id}`} className="link">{sensor.name}</Link></InfoRow>}
                  {alert.detected_value !== null && (
                    <InfoRow label="Valor detectado">{fmtNumber(alert.detected_value)} {alert.unit}</InfoRow>
                  )}
                  <InfoRow label="Detectado em">{fmtDateTime(alert.detected_at)}</InfoRow>
                  {alert.is_simulated && <InfoRow label="Simulação">Sim</InfoRow>}
                  {alert.resolved_at && <InfoRow label="Resolvido em">{fmtDateTime(alert.resolved_at)}</InfoRow>}
                  {resolver && <InfoRow label="Resolvido por">{resolver.full_name || resolver.email}</InfoRow>}
                  {alert.resolution_note && <InfoRow label="Nota de resolução">{alert.resolution_note}</InfoRow>}
                  <div className="desc">{alert.description || <span className="muted">Sem descrição.</span>}</div>
                </Card>
                <Card title="Histórico de ações">
                  {logs.length === 0 ? <EmptyState title="Nenhuma ação registrada" /> : (
                    <ol className="timeline">
                      {logs.map((l) => (
                        <li key={l.id}>
                          <div className="timeline-head">
                            <strong>{ACTION_TYPE[l.action_type] ?? l.action_type}</strong>
                            <span className="muted small">{fmtDateTime(l.created_at)}</span>
                          </div>
                          <div>{l.description}</div>
                          <span className="muted small">{l.user_name}</span>
                        </li>
                      ))}
                    </ol>
                  )}
                </Card>
              </div>

              <Modal open={dialog === 'comment' || dialog === 'assume' || dialog === 'resolve'}
                     title={dialog === 'resolve' ? 'Resolver alerta' : dialog === 'assume' ? 'Assumir alerta' : 'Adicionar comentário'}
                     onClose={() => setDialog(null)}
                     footer={
                       <>
                         <Button variant="secondary" onClick={() => setDialog(null)}>Cancelar</Button>
                         <Button loading={busy} variant={dialog === 'resolve' ? 'success' : 'primary'} onClick={() => {
                           if (dialog === 'resolve') {
                             run(() => supabase.rpc('resolve_alert', { p_alert_id: alert.id, p_note: text }), 'Alerta resolvido.');
                           } else {
                             const desc = text.trim() || (dialog === 'assume' ? 'Alerta assumido pelo administrador.' : '');
                             if (!desc) { setErr('Escreva o comentário.'); setDialog(null); return; }
                             run(() => supabase.rpc('add_alert_action', {
                               p_alert_id: alert.id, p_action: dialog === 'assume' ? 'reconhecido' : 'comentario', p_description: desc,
                             }), dialog === 'assume' ? 'Alerta assumido.' : 'Comentário registrado.');
                           }
                         }}>Confirmar</Button>
                       </>
                     }>
                <Field label={dialog === 'resolve' ? 'Nota de resolução (opcional)' : dialog === 'assume' ? 'Observação (opcional)' : 'Comentário'}>
                  <textarea rows={4} maxLength={500} value={text} onChange={(e) => setText(e.target.value)} autoFocus />
                </Field>
              </Modal>

              {dialog === 'edit' && (
                <ManualAlertModal open alert={alert} areas={data.areas.filter((a) => !a.archived_at || a.id === alert.area_id)}
                                  onClose={() => setDialog(null)} onSaved={reload} />
              )}
            </div>
          );
        })()}
      </QueryState>
    </>
  );
}
