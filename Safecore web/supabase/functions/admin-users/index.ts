// SafeCore — Edge Function "admin-users"
//
// Operações de conta que exigem privilégios do Supabase Auth (service_role):
//   create          cria a conta (senha inicial ou convite por e-mail) e o perfil
//   update_email    altera o e-mail de login
//   set_password    define uma nova senha
//   send_recovery   envia e-mail de redefinição de senha
//   set_active      desativa (bloqueia o login) ou reativa a conta
//   delete          exclui a conta SOMENTE se não houver histórico vinculado
//
// Segurança:
//   * A chave service_role existe apenas aqui (variável de ambiente do Supabase).
//   * Toda chamada valida o token do usuário e exige perfil com role = 'admin'
//     e conta ativa, consultados no banco (nunca confia no que o navegador envia).
//   * O administrador não pode desativar, excluir ou alterar a própria conta aqui.
//   * Alterações de cargo continuam passando pela função admin_set_role do banco.

import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ALLOWED_ORIGINS = (Deno.env.get('ALLOWED_ORIGINS') ?? '*')
  .split(',').map((o) => o.trim()).filter(Boolean);

const ROLES = ['operador', 'tecnico', 'supervisor', 'admin'] as const;
const BAN_FOREVER = '876000h'; // ~100 anos

function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('Origin') ?? '';
  const allow = ALLOWED_ORIGINS.includes('*') ? '*'
    : ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0] ?? '';
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    Vary: 'Origin',
  };
}

class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

const isUuid = (v: unknown): v is string =>
  typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const isEmail = (v: unknown): v is string =>
  typeof v === 'string' && v.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
const clean = (v: unknown, max: number): string | null => {
  if (typeof v !== 'string') return null;
  const t = v.trim();
  return t ? t.slice(0, max) : null;
};
function checkPassword(p: unknown): string {
  if (typeof p !== 'string' || p.length < 8 || p.length > 72
      || !/[A-Za-z]/.test(p) || !/\d/.test(p)) {
    throw new HttpError(400, 'A senha deve ter de 8 a 72 caracteres, com letras e números.');
  }
  return p;
}

interface Caller { id: string; name: string }

async function authorize(req: Request, admin: SupabaseClient): Promise<Caller> {
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) throw new HttpError(401, 'Sessão não informada.');

  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, 'Sessão inválida ou expirada.');

  const { data: profile } = await admin
    .from('profiles')
    .select('id, role, active, full_name, email')
    .eq('id', data.user.id)
    .maybeSingle();
  if (!profile || profile.role !== 'admin' || profile.active === false) {
    throw new HttpError(403, 'Acesso restrito a administradores.');
  }
  return { id: profile.id, name: profile.full_name || profile.email || 'Administrador' };
}

async function audit(admin: SupabaseClient, caller: Caller, action: 'insert' | 'update' | 'delete',
                     entityId: string, details: Record<string, unknown>) {
  await admin.from('audit_logs').insert({
    user_id: caller.id, user_name: caller.name, action,
    entity: 'funcionario', entity_id: entityId, details,
  });
}

async function targetProfile(admin: SupabaseClient, caller: Caller, userId: unknown) {
  if (!isUuid(userId)) throw new HttpError(400, 'Funcionário inválido.');
  if (userId === caller.id) {
    throw new HttpError(400, 'Esta operação não pode ser feita na sua própria conta.');
  }
  const { data } = await admin.from('profiles')
    .select('id, email, full_name, role, active').eq('id', userId).maybeSingle();
  if (!data) throw new HttpError(404, 'Funcionário não encontrado.');
  return data;
}

// ---------------------------------------------------------------------
// Ações
// ---------------------------------------------------------------------
async function createEmployee(admin: SupabaseClient, caller: Caller, body: any) {
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  if (!isEmail(email)) throw new HttpError(400, 'Informe um e-mail válido.');
  const fullName = clean(body.full_name, 120);
  if (!fullName || fullName.length < 3) throw new HttpError(400, 'Informe o nome completo.');
  const phone = clean(body.phone, 30);
  const jobTitle = clean(body.job_title, 80);
  const role = body.role;
  if (!ROLES.includes(role)) throw new HttpError(400, 'Cargo inválido.');
  const mode = body.mode === 'invite' ? 'invite' : 'password';

  let userId: string;
  if (mode === 'invite') {
    const redirectTo = typeof body.redirect_to === 'string' ? body.redirect_to : undefined;
    const { data, error } = await admin.auth.admin.inviteUserByEmail(email, {
      data: { full_name: fullName }, redirectTo,
    });
    if (error) throw new HttpError(400, translateAuthError(error.message));
    userId = data.user.id;
  } else {
    const password = checkPassword(body.password);
    const { data, error } = await admin.auth.admin.createUser({
      email, password, email_confirm: true, user_metadata: { full_name: fullName },
    });
    if (error) throw new HttpError(400, translateAuthError(error.message));
    userId = data.user.id;
  }

  // O trigger handle_new_user cria o perfil; o upsert garante os dados e o cargo.
  const { error: profileError } = await admin.from('profiles').upsert({
    id: userId, email, full_name: fullName, phone, job_title: jobTitle, role, active: true,
  }, { onConflict: 'id' });
  if (profileError) {
    await admin.auth.admin.deleteUser(userId); // não deixa conta sem perfil válido
    throw new HttpError(500, 'Não foi possível criar o perfil do funcionário.');
  }
  await admin.from('notification_preferences')
    .upsert({ user_id: userId }, { onConflict: 'user_id', ignoreDuplicates: true });

  await audit(admin, caller, 'insert', userId, { email, full_name: fullName, role, modo: mode });
  return { user_id: userId, mode };
}

async function updateEmail(admin: SupabaseClient, caller: Caller, body: any) {
  const target = await targetProfile(admin, caller, body.user_id);
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  if (!isEmail(email)) throw new HttpError(400, 'Informe um e-mail válido.');
  const { error } = await admin.auth.admin.updateUserById(target.id, { email, email_confirm: true });
  if (error) throw new HttpError(400, translateAuthError(error.message));
  // O trigger on_auth_user_email_changed sincroniza profiles.email; reforça aqui.
  await admin.from('profiles').update({ email }).eq('id', target.id);
  await audit(admin, caller, 'update', target.id, { campo: 'email', antes: target.email, depois: email });
  return { ok: true };
}

async function setPassword(admin: SupabaseClient, caller: Caller, body: any) {
  const target = await targetProfile(admin, caller, body.user_id);
  const password = checkPassword(body.password);
  const { error } = await admin.auth.admin.updateUserById(target.id, { password });
  if (error) throw new HttpError(400, translateAuthError(error.message));
  await audit(admin, caller, 'update', target.id, { campo: 'senha', observacao: 'Senha redefinida pelo administrador.' });
  return { ok: true };
}

async function sendRecovery(admin: SupabaseClient, caller: Caller, body: any) {
  const target = await targetProfile(admin, caller, body.user_id);
  const redirectTo = typeof body.redirect_to === 'string' ? body.redirect_to : undefined;
  const { error } = await admin.auth.resetPasswordForEmail(target.email, { redirectTo });
  if (error) throw new HttpError(400, translateAuthError(error.message));
  await audit(admin, caller, 'update', target.id, { campo: 'senha', observacao: 'E-mail de redefinição enviado.' });
  return { ok: true };
}

async function setActive(admin: SupabaseClient, caller: Caller, body: any) {
  const target = await targetProfile(admin, caller, body.user_id);
  const active = body.active === true;
  const { error } = await admin.auth.admin.updateUserById(target.id, {
    ban_duration: active ? 'none' : BAN_FOREVER,
  });
  if (error) throw new HttpError(400, translateAuthError(error.message));
  const { error: pErr } = await admin.from('profiles').update({ active }).eq('id', target.id);
  if (pErr) throw new HttpError(500, 'Não foi possível atualizar o status do perfil.');
  await audit(admin, caller, 'update', target.id, {
    campo: 'active', antes: target.active, depois: active, email: target.email,
  });
  return { ok: true, active };
}

async function deleteEmployee(admin: SupabaseClient, caller: Caller, body: any) {
  const target = await targetProfile(admin, caller, body.user_id);

  // Registros históricos que perderiam a autoria se a conta fosse excluída
  const checks = await Promise.all([
    admin.from('alerts').select('id', { count: 'exact', head: true }).eq('resolved_by', target.id),
    admin.from('action_logs').select('id', { count: 'exact', head: true }).eq('user_id', target.id),
    admin.from('occurrences').select('id', { count: 'exact', head: true }).eq('reported_by', target.id),
    admin.from('audit_logs').select('id', { count: 'exact', head: true }).eq('user_id', target.id),
  ]);
  const history = checks.reduce((sum, r) => sum + (r.count ?? 0), 0);
  if (checks.some((r) => r.error)) throw new HttpError(500, 'Não foi possível verificar o histórico.');
  if (history > 0) {
    throw new HttpError(409,
      `Este funcionário possui ${history} registro(s) no histórico (alertas, ações, ocorrências ou auditoria). ` +
      'Para preservar a integridade dos dados, desative a conta em vez de excluí-la.');
  }

  const { error } = await admin.auth.admin.deleteUser(target.id); // perfil e vínculos: on delete cascade
  if (error) throw new HttpError(400, translateAuthError(error.message));
  await audit(admin, caller, 'delete', target.id, {
    email: target.email, full_name: target.full_name, role: target.role,
  });
  return { ok: true };
}

function translateAuthError(message: string): string {
  const m = message.toLowerCase();
  if (m.includes('already') && (m.includes('registered') || m.includes('exists'))) {
    return 'Já existe uma conta com este e-mail.';
  }
  if (m.includes('rate limit')) return 'Limite de envio de e-mails atingido. Tente novamente mais tarde.';
  if (m.includes('password')) return 'A senha não atende aos requisitos de segurança do projeto.';
  if (m.includes('email')) return 'E-mail inválido ou não aceito pelo servidor.';
  return 'Não foi possível concluir a operação no Supabase Auth.';
}

// ---------------------------------------------------------------------
Deno.serve(async (req) => {
  const headers = { ...corsHeaders(req), 'Content-Type': 'application/json' };
  if (req.method === 'OPTIONS') return new Response('ok', { headers });
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Método não permitido.' }), { status: 405, headers });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const caller = await authorize(req, admin);
    const body = await req.json().catch(() => ({}));
    const handlers: Record<string, (a: SupabaseClient, c: Caller, b: any) => Promise<unknown>> = {
      create: createEmployee,
      update_email: updateEmail,
      set_password: setPassword,
      send_recovery: sendRecovery,
      set_active: setActive,
      delete: deleteEmployee,
    };
    const handler = handlers[body?.action];
    if (!handler) throw new HttpError(400, 'Ação inválida.');
    const result = await handler(admin, caller, body);
    return new Response(JSON.stringify(result), { status: 200, headers });
  } catch (e) {
    const status = e instanceof HttpError ? e.status : 500;
    const message = e instanceof HttpError ? e.message : 'Erro interno ao processar a solicitação.';
    if (!(e instanceof HttpError)) console.error(e);
    return new Response(JSON.stringify({ error: message }), { status, headers });
  }
});
