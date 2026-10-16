import { useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Copy, KeyRound, Mail, RefreshCw, Search, UserPlus } from 'lucide-react';
import { useQuery } from '../lib/useQuery';
import { fetchProfiles } from '../lib/data';
import { supabase } from '../lib/supabase';
import { ROLE_LABEL, ROLES } from '../lib/labels';
import { fmtDate, generatePassword } from '../lib/format';
import { adminApi, type NewEmployee } from '../lib/adminApi';
import type { AreaMember, Role } from '../lib/types';
import {
  Avatar, Badge, Button, Card, EmptyState, Field, Modal, Notice, PageHeader, QueryState, useToast,
} from '../components/ui';

export function Employees() {
  const { data, error, loading, reload } = useQuery(async () => {
    const [profiles, members] = await Promise.all([
      fetchProfiles(),
      supabase.from('area_members').select('user_id, area_id, access_level'),
    ]);
    if (members.error) throw members.error;
    return { profiles, members: (members.data ?? []) as Pick<AreaMember, 'user_id'>[] };
  });
  const [search, setSearch] = useState('');
  const [role, setRole] = useState<'' | Role>('');
  const [status, setStatus] = useState<'ativos' | 'inativos' | 'todos'>('ativos');
  const [createOpen, setCreateOpen] = useState(false);

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (data?.profiles ?? []).filter((p) => {
      if (role && p.role !== role) return false;
      if (status === 'ativos' && p.active === false) return false;
      if (status === 'inativos' && p.active !== false) return false;
      if (!q) return true;
      return [p.full_name, p.email, p.job_title, p.phone].some((v) => v?.toLowerCase().includes(q));
    });
  }, [data, search, role, status]);

  const memberCount = (id: string) => data?.members.filter((m) => m.user_id === id).length ?? 0;

  return (
    <>
      <PageHeader
        title="Funcionários"
        subtitle="Contas utilizadas no aplicativo SafeCore Mobile. Somente o administrador cria e gerencia contas."
        actions={<Button icon={<UserPlus size={16} />} onClick={() => setCreateOpen(true)}>Novo funcionário</Button>}
      />
      <Card padded={false}>
        <div className="toolbar">
          <div className="input-icon toolbar-search">
            <Search size={16} />
            <input placeholder="Buscar por nome, e-mail, função ou telefone" value={search}
                   onChange={(e) => setSearch(e.target.value)} />
          </div>
          <select value={role} onChange={(e) => setRole(e.target.value as Role | '')} aria-label="Cargo">
            <option value="">Todos os cargos</option>
            {ROLES.map((r) => <option key={r} value={r}>{ROLE_LABEL[r]}</option>)}
          </select>
          <select value={status} onChange={(e) => setStatus(e.target.value as typeof status)} aria-label="Status">
            <option value="ativos">Ativos</option>
            <option value="inativos">Desativados</option>
            <option value="todos">Todos</option>
          </select>
          <Button variant="ghost" icon={<RefreshCw size={16} />} onClick={reload} aria-label="Atualizar" />
        </div>
        <QueryState loading={loading && !data} error={error} onRetry={reload}>
          {rows.length === 0 ? <EmptyState title="Nenhum funcionário encontrado" /> : (
            <div className="table-wrap">
              <table className="table">
                <thead>
                  <tr>
                    <th>Funcionário</th><th>Cargo</th><th>Telefone</th><th>Áreas vinculadas</th>
                    <th>Status</th><th>Cadastro</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((p) => (
                    <tr key={p.id} className="clickable">
                      <td>
                        <Link to={`/funcionarios/${p.id}`} className="person">
                          <Avatar name={p.full_name || p.email} />
                          <span>
                            <strong>{p.full_name || '(sem nome)'}</strong>
                            <span className="muted small">{p.email}{p.job_title ? ` · ${p.job_title}` : ''}</span>
                          </span>
                        </Link>
                      </td>
                      <td><Badge tone={p.role === 'admin' ? 'info' : 'neutral'}>{ROLE_LABEL[p.role]}</Badge></td>
                      <td>{p.phone || '—'}</td>
                      <td>
                        {p.role === 'admin' || p.role === 'supervisor'
                          ? <span className="muted small">Todas (pelo cargo)</span>
                          : memberCount(p.id)}
                      </td>
                      <td>{p.active === false ? <Badge tone="offline">Desativado</Badge> : <Badge tone="safe">Ativo</Badge>}</td>
                      <td>{fmtDate(p.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </QueryState>
      </Card>
      <CreateEmployeeModal open={createOpen} onClose={() => setCreateOpen(false)} />
    </>
  );
}

const EMPTY: NewEmployee = {
  full_name: '', email: '', phone: '', job_title: '', role: 'operador', mode: 'password', password: '',
};

function CreateEmployeeModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const navigate = useNavigate();
  const toast = useToast();
  const [form, setForm] = useState<NewEmployee>({ ...EMPTY, password: generatePassword() });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [created, setCreated] = useState<{ id: string; email: string; password?: string } | null>(null);

  const set = <K extends keyof NewEmployee>(k: K, v: NewEmployee[K]) => setForm((f) => ({ ...f, [k]: v }));

  function close() {
    setForm({ ...EMPTY, password: generatePassword() });
    setErrors({});
    setFailure(null);
    setCreated(null);
    onClose();
  }

  function validate() {
    const e: Record<string, string> = {};
    if (form.full_name.trim().length < 3) e.full_name = 'Informe o nome completo.';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())) e.email = 'E-mail inválido.';
    if (form.phone && form.phone.length > 30) e.phone = 'Telefone muito longo.';
    if (form.mode === 'password') {
      const p = form.password ?? '';
      if (p.length < 8 || !/[A-Za-z]/.test(p) || !/\d/.test(p)) e.password = 'Mínimo de 8 caracteres, com letras e números.';
    }
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  async function submit() {
    setFailure(null);
    if (!validate()) return;
    setSaving(true);
    try {
      const payload: NewEmployee = {
        ...form,
        full_name: form.full_name.trim(),
        email: form.email.trim().toLowerCase(),
        password: form.mode === 'password' ? form.password : undefined,
      };
      const res = await adminApi.createEmployee(payload);
      toast(form.mode === 'invite' ? 'Convite enviado por e-mail.' : 'Funcionário cadastrado.');
      setCreated({ id: res.user_id, email: payload.email, password: payload.password });
    } catch (e) {
      setFailure(e instanceof Error ? e.message : String(e));
    } finally {
      setSaving(false);
    }
  }

  if (created) {
    return (
      <Modal open={open} title="Funcionário cadastrado" onClose={close}
             footer={
               <>
                 <Button variant="secondary" onClick={close}>Fechar</Button>
                 <Button onClick={() => { const id = created.id; close(); navigate(`/funcionarios/${id}`); }}>
                   Definir áreas e permissões
                 </Button>
               </>
             }>
        <div className="stack">
          {created.password ? (
            <>
              <Notice tone="safe">A conta foi criada e já pode ser usada no aplicativo SafeCore Mobile.</Notice>
              <p>Entregue as credenciais ao funcionário por um canal seguro. <strong>A senha não será exibida novamente.</strong></p>
              <div className="credentials">
                <div><span className="muted small">E-mail</span><code>{created.email}</code></div>
                <div><span className="muted small">Senha inicial</span><code>{created.password}</code></div>
                <Button variant="secondary" size="sm" icon={<Copy size={14} />}
                        onClick={() => navigator.clipboard.writeText(`E-mail: ${created.email}\nSenha: ${created.password}`)
                          .then(() => toast('Credenciais copiadas.'))}>
                  Copiar
                </Button>
              </div>
              <p className="muted small">Recomende ao funcionário trocar a senha no primeiro acesso (Perfil → Alterar senha no app).</p>
            </>
          ) : (
            <Notice tone="safe">
              Convite enviado para <strong>{created.email}</strong>. O funcionário definirá a própria senha pelo link
              recebido e depois entrará no aplicativo SafeCore Mobile.
            </Notice>
          )}
        </div>
      </Modal>
    );
  }

  return (
    <Modal open={open} title="Novo funcionário" onClose={close} wide
           footer={
             <>
               <Button variant="secondary" onClick={close} disabled={saving}>Cancelar</Button>
               <Button onClick={submit} loading={saving} icon={<UserPlus size={16} />}>Cadastrar</Button>
             </>
           }>
      <div className="stack">
        {failure && <Notice tone="critical">{failure}</Notice>}
        <div className="form-grid">
          <Field label="Nome completo *" error={errors.full_name}>
            <input value={form.full_name} maxLength={120} onChange={(e) => set('full_name', e.target.value)} autoFocus />
          </Field>
          <Field label="E-mail *" error={errors.email}>
            <input type="email" value={form.email} maxLength={254} onChange={(e) => set('email', e.target.value)} />
          </Field>
          <Field label="Telefone" error={errors.phone}>
            <input value={form.phone} maxLength={30} placeholder="(11) 99999-9999" onChange={(e) => set('phone', e.target.value)} />
          </Field>
          <Field label="Função / cargo na empresa">
            <input value={form.job_title} maxLength={80} placeholder="Ex.: Operador de Produção"
                   onChange={(e) => set('job_title', e.target.value)} />
          </Field>
          <Field label="Cargo no sistema *" hint="Define as permissões no app e no banco.">
            <select value={form.role} onChange={(e) => set('role', e.target.value as Role)}>
              {ROLES.map((r) => <option key={r} value={r}>{ROLE_LABEL[r]}</option>)}
            </select>
          </Field>
        </div>
        {form.role === 'admin' && (
          <Notice tone="warning">Administradores têm acesso total ao SafeCore Web e a todas as áreas.</Notice>
        )}

        <div className="segmented" role="radiogroup" aria-label="Forma de acesso">
          <button type="button" className={form.mode === 'password' ? 'active' : ''} onClick={() => set('mode', 'password')}>
            <KeyRound size={16} /> Definir senha inicial
          </button>
          <button type="button" className={form.mode === 'invite' ? 'active' : ''} onClick={() => set('mode', 'invite')}>
            <Mail size={16} /> Enviar convite por e-mail
          </button>
        </div>

        {form.mode === 'password' ? (
          <Field label="Senha inicial *" error={errors.password} hint="Gerada automaticamente; você pode alterá-la.">
            <div className="input-group">
              <input value={form.password} onChange={(e) => set('password', e.target.value)} autoComplete="new-password" />
              <Button type="button" variant="secondary" icon={<RefreshCw size={14} />}
                      onClick={() => set('password', generatePassword())}>Gerar</Button>
            </div>
          </Field>
        ) : (
          <Notice tone="info">
            O funcionário receberá um e-mail com um link seguro para criar a própria senha.
            O endereço <code>{window.location.origin}/definir-senha</code> precisa estar nas Redirect URLs do Supabase.
          </Notice>
        )}
      </div>
    </Modal>
  );
}
