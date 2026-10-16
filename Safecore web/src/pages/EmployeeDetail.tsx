import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import {
  ArrowLeft, Ban, KeyRound, Mail, RefreshCw, Save, ShieldCheck, Trash2, UserCheck,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { must, useQuery } from '../lib/useQuery';
import { fetchAreas } from '../lib/data';
import { useAdmin, useAuth } from '../auth/AuthProvider';
import {
  ACCESS_HINT, ACCESS_LABEL, AREA_STATUS, AUDIT_ACTION, AUDIT_ENTITY, ROLE_LABEL, ROLES,
} from '../lib/labels';
import { errorMessage, fmtDateTime, generatePassword } from '../lib/format';
import { adminApi } from '../lib/adminApi';
import type { AccessLevel, AreaMember, AuditLog, Profile, Role } from '../lib/types';
import {
  Avatar, Badge, Button, Card, ConfirmDialog, EmptyState, Field, InfoRow, Modal, Notice,
  QueryState, useToast,
} from '../components/ui';

async function loadEmployee(id: string) {
  const [profile, areas, members, audit] = await Promise.all([
    supabase.from('profiles').select('*').eq('id', id).maybeSingle().then(must),
    fetchAreas(false),
    supabase.from('area_members').select('*').eq('user_id', id).then(must),
    supabase.from('audit_logs').select('*')
      .or(`entity_id.eq.${id},entity_id.like.${id}:*`)
      .order('created_at', { ascending: false }).limit(15).then(must),
  ]);
  return {
    profile: profile as Profile | null,
    areas,
    members: (members ?? []) as AreaMember[],
    audit: (audit ?? []) as AuditLog[],
  };
}

export function EmployeeDetail() {
  const { id = '' } = useParams();
  const { data, error, loading, reload, setData } = useQuery(() => loadEmployee(id), [id]);

  return (
    <>
      <Link to="/funcionarios" className="back-link"><ArrowLeft size={16} /> Funcionários</Link>
      <QueryState loading={loading && !data} error={error} onRetry={reload}>
        {data && !data.profile && <EmptyState title="Funcionário não encontrado" />}
        {data?.profile && (
          <EmployeeContent
            data={{ ...data, profile: data.profile }}
            reload={reload}
            setProfile={(p) => setData({ ...data, profile: p })}
          />
        )}
      </QueryState>
    </>
  );
}

function EmployeeContent({ data, reload, setProfile }: {
  data: Awaited<ReturnType<typeof loadEmployee>> & { profile: Profile };
  reload: () => void;
  setProfile: (p: Profile) => void;
}) {
  const { profile, areas, members, audit } = data;
  const admin = useAdmin();
  const isSelf = admin.profile.id === profile.id;
  const inactive = profile.active === false;

  return (
    <div className="stack-lg">
      <div className="detail-head">
        <Avatar name={profile.full_name || profile.email} size={56} />
        <div>
          <h1>{profile.full_name || '(sem nome)'}</h1>
          <div className="row-gap">
            <Badge tone={profile.role === 'admin' ? 'info' : 'neutral'}>{ROLE_LABEL[profile.role]}</Badge>
            {inactive ? <Badge tone="offline">Desativado</Badge> : <Badge tone="safe">Ativo</Badge>}
            {isSelf && <Badge tone="info">Você</Badge>}
            <span className="muted small">{profile.email}</span>
          </div>
        </div>
      </div>

      {inactive && (
        <Notice tone="warning">
          Conta desativada em {fmtDateTime(profile.deactivated_at)}. O login no aplicativo e no painel está bloqueado;
          o histórico do funcionário foi preservado.
        </Notice>
      )}

      <div className="grid-2">
        <PersonalCard profile={profile} isSelf={isSelf} onSaved={setProfile} />
        <RoleCard profile={profile} isSelf={isSelf} onSaved={reload} />
      </div>

      <AreaPermissionsCard profile={profile} areas={areas} members={members} onChanged={reload} />

      <div className="grid-2">
        <SecurityCard profile={profile} isSelf={isSelf} onChanged={reload} />
        <Card title="Histórico de alterações">
          {audit.length === 0 ? <EmptyState title="Nenhuma alteração registrada" /> : (
            <ul className="list">
              {audit.map((l) => (
                <li key={l.id} className="list-row">
                  <div>
                    <strong>{AUDIT_ACTION[l.action]?.label} · {AUDIT_ENTITY[l.entity] ?? l.entity}</strong>
                    <span className="muted small">por {l.user_name}</span>
                  </div>
                  <span className="muted small">{fmtDateTime(l.created_at)}</span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------
function PersonalCard({ profile, isSelf, onSaved }: { profile: Profile; isSelf: boolean; onSaved: (p: Profile) => void }) {
  const toast = useToast();
  const { setProfile: setAdminProfile } = useAuth();
  const [form, setForm] = useState({ full_name: profile.full_name, phone: profile.phone ?? '', job_title: profile.job_title ?? '' });
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [emailOpen, setEmailOpen] = useState(false);

  useEffect(() => {
    setForm({ full_name: profile.full_name, phone: profile.phone ?? '', job_title: profile.job_title ?? '' });
  }, [profile]);

  const dirty = form.full_name !== profile.full_name || form.phone !== (profile.phone ?? '')
    || form.job_title !== (profile.job_title ?? '');

  async function save() {
    setErr(null);
    if (form.full_name.trim().length < 3) {
      setErr('Informe o nome completo.');
      return;
    }
    setSaving(true);
    try {
      // Atualização direta sob RLS (política profiles_admin_update) — auditada no banco
      const updated = must(await supabase.from('profiles').update({
        full_name: form.full_name.trim(),
        phone: form.phone.trim() || null,
        job_title: form.job_title.trim() || null,
      }).eq('id', profile.id).select().single()) as Profile;
      onSaved(updated);
      if (isSelf) setAdminProfile(updated);
      toast('Dados atualizados.');
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Card title="Dados do funcionário">
      <div className="stack">
        {err && <Notice tone="critical">{err}</Notice>}
        <Field label="Nome completo">
          <input value={form.full_name} maxLength={120} onChange={(e) => setForm({ ...form, full_name: e.target.value })} />
        </Field>
        <div className="form-grid">
          <Field label="Telefone">
            <input value={form.phone} maxLength={30} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
          </Field>
          <Field label="Função na empresa">
            <input value={form.job_title} maxLength={80} onChange={(e) => setForm({ ...form, job_title: e.target.value })} />
          </Field>
        </div>
        <InfoRow label="E-mail de acesso">
          <span className="row-gap">
            {profile.email}
            {!isSelf && <Button variant="ghost" size="sm" icon={<Mail size={14} />} onClick={() => setEmailOpen(true)}>Alterar</Button>}
          </span>
        </InfoRow>
        <InfoRow label="Cadastrado em">{fmtDateTime(profile.created_at)}</InfoRow>
        <div className="actions-end">
          <Button icon={<Save size={16} />} onClick={save} loading={saving} disabled={!dirty}>Salvar</Button>
        </div>
      </div>
      <ChangeEmailModal open={emailOpen} profile={profile} onClose={() => setEmailOpen(false)}
                        onSaved={(email) => onSaved({ ...profile, email })} />
    </Card>
  );
}

function ChangeEmailModal({ open, profile, onClose, onSaved }: {
  open: boolean; profile: Profile; onClose: () => void; onSaved: (email: string) => void;
}) {
  const toast = useToast();
  const [email, setEmail] = useState(profile.email);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function save() {
    setErr(null);
    const v = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)) {
      setErr('E-mail inválido.');
      return;
    }
    setSaving(true);
    try {
      await adminApi.updateEmail(profile.id, v);
      onSaved(v);
      toast('E-mail de acesso alterado.');
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open={open} title="Alterar e-mail de acesso" onClose={onClose}
           footer={<><Button variant="secondary" onClick={onClose}>Cancelar</Button><Button onClick={save} loading={saving}>Salvar</Button></>}>
      <div className="stack">
        {err && <Notice tone="critical">{err}</Notice>}
        <Field label="Novo e-mail" hint="O funcionário passará a entrar no aplicativo com este e-mail.">
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoFocus />
        </Field>
      </div>
    </Modal>
  );
}

// ---------------------------------------------------------------------
function RoleCard({ profile, isSelf, onSaved }: { profile: Profile; isSelf: boolean; onSaved: () => void }) {
  const toast = useToast();
  const [role, setRole] = useState<Role>(profile.role);
  const [confirm, setConfirm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => setRole(profile.role), [profile.role]);

  async function save() {
    setSaving(true);
    setErr(null);
    try {
      // admin_set_role valida no banco: somente admin, nunca a própria conta
      must(await supabase.rpc('admin_set_role', { p_user_id: profile.id, p_role: role }));
      toast(`Cargo alterado para ${ROLE_LABEL[role]}.`);
      setConfirm(false);
      onSaved();
    } catch (e) {
      setErr(errorMessage(e));
      setConfirm(false);
    } finally {
      setSaving(false);
    }
  }

  return (
    <Card title="Cargo no sistema">
      <div className="stack">
        {err && <Notice tone="critical">{err}</Notice>}
        {isSelf ? (
          <Notice tone="info">Por segurança, você não pode alterar o seu próprio cargo.</Notice>
        ) : null}
        <div className="role-options">
          {ROLES.map((r) => (
            <label key={r} className={`role-option ${role === r ? 'selected' : ''} ${isSelf ? 'disabled' : ''}`}>
              <input type="radio" name="role" value={r} checked={role === r} disabled={isSelf}
                     onChange={() => setRole(r)} />
              <span>
                <strong>{ROLE_LABEL[r]}</strong>
                <span className="muted small">{ROLE_HINT[r]}</span>
              </span>
            </label>
          ))}
        </div>
        <div className="actions-end">
          <Button icon={<ShieldCheck size={16} />} disabled={isSelf || role === profile.role}
                  onClick={() => setConfirm(true)}>Alterar cargo</Button>
        </div>
      </div>
      <ConfirmDialog
        open={confirm}
        title="Confirmar alteração de cargo"
        message={
          <>
            Alterar o cargo de <strong>{profile.full_name || profile.email}</strong> de{' '}
            <strong>{ROLE_LABEL[profile.role]}</strong> para <strong>{ROLE_LABEL[role]}</strong>?
            {role === 'operador' && <p className="muted small">Acessos de gestão em áreas serão reduzidos para operação.</p>}
            {role === 'admin' && <p className="muted small">O funcionário terá acesso total ao SafeCore Web.</p>}
            <p className="muted small">A mudança vale imediatamente nas políticas do banco e no próximo carregamento do app.</p>
          </>
        }
        loading={saving}
        onConfirm={save}
        onClose={() => setConfirm(false)}
      />
    </Card>
  );
}

const ROLE_HINT: Record<Role, string> = {
  admin: 'Acesso total: SafeCore Web, funcionários, cargos e todas as áreas.',
  supervisor: 'App mobile: gestão de todas as áreas, sensores e permissões.',
  tecnico: 'App mobile: trata alertas e ocorrências gerais conforme as áreas.',
  operador: 'App mobile: consulta e operação nas áreas vinculadas (sem gestão).',
};

// ---------------------------------------------------------------------
function AreaPermissionsCard({ profile, areas, members, onChanged }: {
  profile: Profile; areas: Awaited<ReturnType<typeof fetchAreas>>; members: AreaMember[]; onChanged: () => void;
}) {
  const toast = useToast();
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const allByRole = profile.role === 'admin' || profile.role === 'supervisor';
  const levelOf = (areaId: string) => members.find((m) => m.area_id === areaId)?.access_level ?? '';

  async function change(areaId: string, level: AccessLevel | '') {
    setBusy(areaId);
    setErr(null);
    try {
      // set_area_member valida permissões e regras (ex.: operador sem gestão)
      must(await supabase.rpc('set_area_member', { p_user_id: profile.id, p_area_id: areaId, p_level: level || null }));
      toast(level ? `Acesso definido: ${ACCESS_LABEL[level]}.` : 'Acesso removido.');
      onChanged();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(null);
    }
  }

  return (
    <Card title="Áreas e permissões">
      <div className="stack">
        {allByRole && (
          <Notice tone="info">
            Pelo cargo de {ROLE_LABEL[profile.role]}, este funcionário já tem acesso de gestão a todas as áreas.
            Os vínculos abaixo ficam registrados e passam a valer se o cargo mudar.
          </Notice>
        )}
        {err && <Notice tone="critical">{err}</Notice>}
        <div className="level-legend">
          {(Object.keys(ACCESS_LABEL) as AccessLevel[]).map((l) => (
            <span key={l}><strong>{ACCESS_LABEL[l]}:</strong> {ACCESS_HINT[l]}</span>
          ))}
        </div>
        {areas.length === 0 ? <EmptyState title="Nenhuma área ativa cadastrada" /> : (
          <div className="table-wrap">
            <table className="table">
              <thead><tr><th>Área</th><th>Condição</th><th>Visibilidade</th><th>Nível de acesso</th></tr></thead>
              <tbody>
                {areas.map((a) => {
                  const st = AREA_STATUS[a.status] ?? AREA_STATUS.segura;
                  return (
                    <tr key={a.id}>
                      <td><Link to={`/areas/${a.id}`}><strong>{a.name}</strong></Link> <span className="muted small">{a.code}</span></td>
                      <td><Badge tone={st.tone}>{st.label}</Badge></td>
                      <td>{a.restricted ? <Badge tone="blocked">Restrita</Badge> : <span className="muted small">Pública (leitura)</span>}</td>
                      <td>
                        <select value={levelOf(a.id)} disabled={busy === a.id}
                                onChange={(e) => change(a.id, e.target.value as AccessLevel | '')}>
                          <option value="">{a.restricted ? 'Sem acesso' : 'Sem vínculo (leitura padrão)'}</option>
                          <option value="leitura">Leitura</option>
                          <option value="operacao">Operação</option>
                          <option value="gestao" disabled={profile.role === 'operador'}>
                            Gestão{profile.role === 'operador' ? ' (indisponível p/ operador)' : ''}
                          </option>
                        </select>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </Card>
  );
}

// ---------------------------------------------------------------------
function SecurityCard({ profile, isSelf, onChanged }: { profile: Profile; isSelf: boolean; onChanged: () => void }) {
  const toast = useToast();
  const navigate = useNavigate();
  const inactive = profile.active === false;
  const [dialog, setDialog] = useState<null | 'password' | 'recovery' | 'active' | 'delete'>(null);
  const [password, setPassword] = useState(generatePassword());
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [shownPassword, setShownPassword] = useState<string | null>(null);

  async function run(fn: () => Promise<unknown>, success: string, after?: () => void) {
    setBusy(true);
    setErr(null);
    try {
      await fn();
      toast(success);
      setDialog(null);
      after?.();
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
      setDialog(null);
    } finally {
      setBusy(false);
    }
  }

  if (isSelf) {
    return (
      <Card title="Acesso e segurança">
        <Notice tone="info">
          Operações de bloqueio, exclusão e redefinição de senha não podem ser aplicadas à sua própria conta.
          Para trocar a sua senha, use "Esqueci minha senha" na tela de login.
        </Notice>
      </Card>
    );
  }

  return (
    <Card title="Acesso e segurança">
      <div className="stack">
        {err && <Notice tone="critical">{err}</Notice>}
        {shownPassword && (
          <Notice tone="safe">
            Nova senha definida: <code>{shownPassword}</code> — entregue ao funcionário por um canal seguro.
          </Notice>
        )}
        <div className="security-actions">
          <Button variant="secondary" icon={<KeyRound size={16} />} onClick={() => { setPassword(generatePassword()); setDialog('password'); }}
                  disabled={inactive}>Definir nova senha</Button>
          <Button variant="secondary" icon={<Mail size={16} />} onClick={() => setDialog('recovery')} disabled={inactive}>
            Enviar link de redefinição
          </Button>
          {inactive ? (
            <Button variant="success" icon={<UserCheck size={16} />} onClick={() => setDialog('active')}>Reativar conta</Button>
          ) : (
            <Button variant="secondary" icon={<Ban size={16} />} onClick={() => setDialog('active')}>Desativar conta</Button>
          )}
          <Button variant="danger" icon={<Trash2 size={16} />} onClick={() => setDialog('delete')}>Excluir conta</Button>
        </div>
        <p className="muted small">
          A desativação bloqueia o login no app e no painel e preserva todo o histórico. A exclusão só é permitida
          para contas sem registros históricos.
        </p>
      </div>

      <Modal open={dialog === 'password'} title="Definir nova senha" onClose={() => setDialog(null)}
             footer={
               <>
                 <Button variant="secondary" onClick={() => setDialog(null)}>Cancelar</Button>
                 <Button loading={busy} onClick={() => {
                   if (password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
                     setErr('A senha deve ter pelo menos 8 caracteres, com letras e números.');
                     setDialog(null);
                     return;
                   }
                   const p = password;
                   run(() => adminApi.setPassword(profile.id, p), 'Senha redefinida.', () => setShownPassword(p));
                 }}>Salvar senha</Button>
               </>
             }>
        <Field label="Nova senha" hint="Mínimo de 8 caracteres, com letras e números.">
          <div className="input-group">
            <input value={password} onChange={(e) => setPassword(e.target.value)} />
            <Button type="button" variant="secondary" icon={<RefreshCw size={14} />} onClick={() => setPassword(generatePassword())}>Gerar</Button>
          </div>
        </Field>
      </Modal>

      <ConfirmDialog open={dialog === 'recovery'} title="Enviar link de redefinição"
                     message={<>Um e-mail com link para criar uma nova senha será enviado para <strong>{profile.email}</strong>.</>}
                     confirmLabel="Enviar" loading={busy} onClose={() => setDialog(null)}
                     onConfirm={() => run(() => adminApi.sendRecovery(profile.id), 'E-mail de redefinição enviado.')} />

      <ConfirmDialog open={dialog === 'active'} title={inactive ? 'Reativar conta' : 'Desativar conta'}
                     danger={!inactive}
                     message={inactive
                       ? <>A conta de <strong>{profile.full_name || profile.email}</strong> voltará a ter acesso ao aplicativo.</>
                       : <>O funcionário <strong>{profile.full_name || profile.email}</strong> não conseguirá mais entrar no aplicativo.
                           Sessões abertas perdem os privilégios imediatamente. O histórico será preservado.</>}
                     confirmLabel={inactive ? 'Reativar' : 'Desativar'} loading={busy} onClose={() => setDialog(null)}
                     onConfirm={() => run(() => adminApi.setActive(profile.id, inactive),
                       inactive ? 'Conta reativada.' : 'Conta desativada.', onChanged)} />

      <ConfirmDialog open={dialog === 'delete'} title="Excluir conta" danger
                     message={<>Excluir definitivamente a conta de <strong>{profile.full_name || profile.email}</strong>?
                       <p className="muted small">Se houver histórico (alertas resolvidos, ações, ocorrências ou auditoria), a exclusão
                       será recusada e você deverá desativar a conta.</p></>}
                     confirmLabel="Excluir" loading={busy} onClose={() => setDialog(null)}
                     onConfirm={() => run(() => adminApi.deleteEmployee(profile.id), 'Conta excluída.',
                       () => navigate('/funcionarios', { replace: true }))} />
    </Card>
  );
}
