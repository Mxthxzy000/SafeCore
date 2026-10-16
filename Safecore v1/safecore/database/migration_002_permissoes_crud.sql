-- =====================================================================
-- SafeCore — Migração 002: permissões por área, CRUD de áreas/alertas e auditoria
--
-- Para um banco JÁ INSTALADO: cole este arquivo inteiro no SQL Editor e clique em Run.
-- Preserva todos os dados existentes (nenhuma tabela é apagada ou recriada).
-- Pode ser executado mais de uma vez.
--
-- O que muda:
--   * area_members: vínculo funcionário x área com nível de acesso
--       leitura  -> visualiza a área
--       operacao -> + trata alertas, cadastra/edita alertas manuais, ações simuladas
--       gestao   -> + edita a área e exclui alertas manuais
--     Administradores e supervisores têm acesso de gestão a todas as áreas.
--   * areas.restricted: área restrita só é visível para quem tem vínculo.
--   * areas.archived_at: exclusão de área com histórico vira ARQUIVAMENTO
--     (sensores, leituras e alertas são preservados).
--   * alerts.origin ('sensor' | 'manual') e alerts.category (tipo de risco).
--     Alertas de sensores não podem ter medição/área alteradas nem ser excluídos
--     (exceto por administrador).
--   * audit_logs: registro das operações importantes feitas pelos usuários.
--   * Novas políticas RLS baseadas no nível de acesso de cada área.
--   * Usuários de demonstração: admin@safecore.com e operador@safecore.com.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Estrutura (somente adições)
-- ---------------------------------------------------------------------
alter table public.areas add column if not exists restricted  boolean not null default false;
alter table public.areas add column if not exists archived_at timestamptz;

-- Alertas existentes foram gerados pelas leituras (seed/trigger): origem 'sensor'.
-- Depois disso, o padrão passa a ser 'manual' (cadastro pelo app).
alter table public.alerts add column if not exists origin text not null default 'sensor';
alter table public.alerts alter column origin set default 'manual';
alter table public.alerts add column if not exists category text not null default 'outro';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'alerts_origin_check') then
    alter table public.alerts add constraint alerts_origin_check
      check (origin in ('sensor', 'manual'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'alerts_category_check') then
    alter table public.alerts add constraint alerts_category_check
      check (category in ('temperatura', 'pressao', 'umidade', 'gas', 'fumaca', 'ventilacao',
                          'comunicacao', 'eletrico', 'mecanico', 'quimico', 'outro'));
  end if;
end;
$$;

-- Categoria dos alertas antigos a partir do tipo do sensor
update public.alerts al
   set category = s.sensor_type
  from public.sensors s
 where al.sensor_id = s.id and al.category = 'outro';
update public.alerts
   set category = 'comunicacao'
 where sensor_id is null and category = 'outro' and title ilike '%comunica%';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'alerts_manual_without_sensor') then
    alter table public.alerts add constraint alerts_manual_without_sensor
      check (origin <> 'manual' or sensor_id is null);
  end if;
end;
$$;

create table if not exists public.area_members (
  user_id       uuid not null references public.profiles (id) on delete cascade,
  area_id       uuid not null references public.areas (id) on delete cascade,
  access_level  text not null default 'leitura'
                check (access_level in ('leitura', 'operacao', 'gestao')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  primary key (user_id, area_id)
);
create index if not exists idx_area_members_area on public.area_members (area_id);

drop trigger if exists trg_area_members_updated_at on public.area_members;
create trigger trg_area_members_updated_at before update on public.area_members
  for each row execute function public.set_updated_at();

create table if not exists public.audit_logs (
  id          bigint generated always as identity primary key,
  user_id     uuid references public.profiles (id) on delete set null,
  user_name   text not null default 'Sistema',
  action      text not null check (action in ('insert', 'update', 'delete')),
  entity      text not null,
  entity_id   text,
  details     jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists idx_audit_logs_created on public.audit_logs (created_at desc);
create index if not exists idx_audit_logs_entity on public.audit_logs (entity, entity_id);

-- ---------------------------------------------------------------------
-- 2. Funções de permissão por área
-- ---------------------------------------------------------------------
-- Nível de acesso do usuário logado: 0 nenhum, 1 leitura, 2 operação, 3 gestão
create or replace function public.area_access(p_area_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case
    when auth.uid() is null then 0
    when public.current_role_name() in ('admin', 'supervisor') then 3
    else coalesce(
      (select case m.access_level when 'gestao' then 3 when 'operacao' then 2 else 1 end
         from public.area_members m
        where m.area_id = p_area_id and m.user_id = auth.uid()),
      (select case when a.restricted then 0 else 1 end
         from public.areas a where a.id = p_area_id),
      0)
  end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_role_name() = 'admin', false);
$$;

-- ---------------------------------------------------------------------
-- 3. Triggers de integridade
-- ---------------------------------------------------------------------
-- Áreas: só administradores/supervisores alteram restrição e arquivamento
create or replace function public.guard_area_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_supervisor() then
    if new.restricted is distinct from old.restricted
       or new.archived_at is distinct from old.archived_at then
      raise exception 'Somente administradores e supervisores alteram a restrição ou o arquivamento da área.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_areas_guard on public.areas;
create trigger trg_areas_guard
  before update on public.areas
  for each row execute function public.guard_area_changes();

-- Alertas: protege os dados de medição dos alertas de sensores e mantém a
-- consistência da resolução. Executado apenas para operações vindas do app.
create or replace function public.guard_alert_changes()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('authenticated', 'anon') then
    if tg_op = 'INSERT' then
      new.origin := 'manual';
      new.sensor_id := null;
      new.is_simulated := false;
    else
      if new.origin is distinct from old.origin then
        raise exception 'A origem do alerta não pode ser alterada.';
      end if;
      if old.origin = 'sensor' and (
           new.area_id is distinct from old.area_id
        or new.sensor_id is distinct from old.sensor_id
        or new.detected_value is distinct from old.detected_value
        or new.unit is distinct from old.unit
        or new.detected_at is distinct from old.detected_at
        or new.severity is distinct from old.severity
        or new.category is distinct from old.category) then
        raise exception 'Alertas gerados por sensores: só é possível editar título, descrição e status.';
      end if;
    end if;
  end if;

  if new.status = 'resolvido' and new.resolved_at is null then
    new.resolved_at := now();
    new.resolved_by := coalesce(new.resolved_by, auth.uid());
  elsif new.status <> 'resolvido' then
    new.resolved_at := null;
    new.resolved_by := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_alerts_guard on public.alerts;
create trigger trg_alerts_guard
  before insert or update on public.alerts
  for each row execute function public.guard_alert_changes();

-- Auditoria das operações feitas por usuários (não registra o seed nem o sistema)
create or replace function public.audit_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  if auth.uid() is null
     or coalesce(current_setting('safecore.seeding', true), 'off') = 'on' then
    return coalesce(new, old);
  end if;
  insert into public.audit_logs (user_id, user_name, action, entity, entity_id, details)
  values (auth.uid(), coalesce(public.current_user_name(), 'Usuário'), lower(tg_op), tg_argv[0],
          coalesce(v_row ->> 'id', (v_row ->> 'user_id') || ':' || (v_row ->> 'area_id')),
          case when tg_op = 'UPDATE'
               then jsonb_build_object('antes', to_jsonb(old), 'depois', to_jsonb(new))
               else v_row end);
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_audit_areas on public.areas;
create trigger trg_audit_areas after insert or update or delete on public.areas
  for each row execute function public.audit_changes('area');
drop trigger if exists trg_audit_alerts on public.alerts;
create trigger trg_audit_alerts after insert or update or delete on public.alerts
  for each row execute function public.audit_changes('alerta');
drop trigger if exists trg_audit_members on public.area_members;
create trigger trg_audit_members after insert or update or delete on public.area_members
  for each row execute function public.audit_changes('permissao_area');
drop trigger if exists trg_audit_profiles on public.profiles;
create trigger trg_audit_profiles after update on public.profiles
  for each row execute function public.audit_changes('perfil');

-- ---------------------------------------------------------------------
-- 4. Funções atualizadas (permissão por área)
-- ---------------------------------------------------------------------
-- Leitura recebida: agora marca origem 'sensor' e a categoria do alerta
create or replace function public.handle_new_reading()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.sensors%rowtype;
  v_level text;
  v_open public.alerts%rowtype;
  v_title text;
  v_label text;
  v_high boolean;
  v_seeding boolean := coalesce(current_setting('safecore.seeding', true), 'off') = 'on';
begin
  select * into s from public.sensors where id = new.sensor_id;

  if s.last_reading_at is not null and new.recorded_at < s.last_reading_at then
    return new;
  end if;

  v_level := public.sensor_level(new.value, s.ref_min, s.ref_max, s.critical_min, s.critical_max);

  update public.sensors
     set last_value = new.value,
         last_reading_at = new.recorded_at,
         level = v_level,
         status = case when status = 'manutencao' then status else 'online' end
   where id = s.id;

  if not v_seeding then
    if v_level in ('atencao', 'critico') then
      select * into v_open from public.alerts
       where sensor_id = s.id and status <> 'resolvido'
       order by detected_at desc limit 1;

      v_label := case s.sensor_type
        when 'temperatura' then 'Temperatura'
        when 'pressao' then 'Pressão'
        when 'umidade' then 'Umidade'
        when 'gas' then 'Concentração de gás'
        when 'fumaca' then 'Fumaça'
        when 'ventilacao' then 'Ventilação'
      end;
      v_high := (s.ref_max is not null and new.value > s.ref_max);
      v_title := v_label || case when v_high then ' acima do limite' else ' abaixo do limite' end;

      if v_open.id is null then
        insert into public.alerts (area_id, sensor_id, title, description, severity,
                                   detected_value, unit, detected_at, is_simulated,
                                   origin, category)
        values (s.area_id, s.id, v_title,
                format('%s registrou %s %s (faixa segura: %s a %s %s).',
                       s.name, new.value, s.unit,
                       coalesce(s.ref_min::text, '—'), coalesce(s.ref_max::text, '—'), s.unit),
                v_level, new.value, s.unit, new.recorded_at, new.source = 'simulado',
                'sensor', s.sensor_type);
      elsif v_open.severity = 'atencao' and v_level = 'critico' then
        update public.alerts
           set severity = 'critico', detected_value = new.value, detected_at = new.recorded_at
         where id = v_open.id;
        insert into public.action_logs (area_id, alert_id, action_type, description)
        values (s.area_id, v_open.id, 'sistema',
                format('Alerta escalonado para crítico: %s %s.', new.value, s.unit));
      else
        update public.alerts set detected_value = new.value where id = v_open.id;
      end if;
    end if;

    perform public.refresh_area_status(s.area_id);
  end if;

  return new;
end;
$$;

-- Leituras simuladas: ignora áreas arquivadas ou interditadas
create or replace function public.simulate_readings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  s record;
  v_target numeric;
  v_span numeric;
  v_value numeric;
  v_count int := 0;
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;

  for s in
    select se.* from public.sensors se
    join public.areas a on a.id = se.area_id
    where se.is_simulated and se.status = 'online'
      and a.status <> 'interditada' and a.archived_at is null
  loop
    v_target := coalesce((coalesce(s.ref_min, 0) + coalesce(s.ref_max, s.ref_min * 2)) / 2, 0);
    v_span := greatest(abs(coalesce(s.ref_max, 1) - coalesce(s.ref_min, 0)), 0.1);
    v_value := coalesce(s.last_value, v_target);
    v_value := v_value + (v_target - v_value) * 0.15 + (random() - 0.5) * v_span * 0.08;
    if s.sensor_type in ('gas', 'fumaca', 'umidade', 'ventilacao') then
      v_value := greatest(v_value, 0);
    end if;
    insert into public.sensor_readings (sensor_id, value, source)
    values (s.id, round(v_value, 2), 'simulado');
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

create or replace function public.add_alert_action(p_alert_id uuid, p_action text, p_description text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_area uuid;
begin
  if p_action not in ('comentario', 'reconhecido') then
    raise exception 'Ação inválida.';
  end if;
  select area_id into v_area from public.alerts where id = p_alert_id;
  if v_area is null or public.area_access(v_area) < 1 then
    raise exception 'Alerta não encontrado.';
  end if;
  if p_action = 'reconhecido' and public.area_access(v_area) < 2 then
    raise exception 'Você não tem permissão para assumir alertas desta área.';
  end if;

  if p_action = 'reconhecido' then
    update public.alerts set status = 'em_andamento' where id = p_alert_id and status = 'ativo';
  end if;

  insert into public.action_logs (area_id, alert_id, user_id, action_type, description)
  values (v_area, p_alert_id, auth.uid(), p_action, left(trim(p_description), 500));
end;
$$;

create or replace function public.resolve_alert(p_alert_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_area uuid;
begin
  select area_id into v_area from public.alerts where id = p_alert_id;
  if v_area is null or public.area_access(v_area) < 2 then
    raise exception 'Você não tem permissão para resolver alertas desta área.';
  end if;

  update public.alerts
     set status = 'resolvido', resolved_at = now(), resolved_by = auth.uid(),
         resolution_note = nullif(trim(p_note), '')
   where id = p_alert_id and status <> 'resolvido';
  if not found then
    raise exception 'Alerta não encontrado ou já resolvido.';
  end if;

  insert into public.action_logs (area_id, alert_id, user_id, action_type, description)
  values (v_area, p_alert_id, auth.uid(), 'resolvido',
          coalesce(nullif(trim(p_note), ''), 'Alerta marcado como resolvido.'));
end;
$$;

create or replace function public.simulate_area_action(p_area_id uuid, p_action text, p_alert_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_desc text;
  v_name text;
begin
  if public.area_access(p_area_id) < 2 then
    raise exception 'Você não tem permissão para executar ações nesta área.';
  end if;
  select name into v_name from public.areas where id = p_area_id;
  if v_name is null then
    raise exception 'Área não encontrada.';
  end if;

  if p_action = 'ventilacao' then
    v_desc := format('[SIMULAÇÃO] Ventilação de emergência acionada na área %s.', v_name);
  elsif p_action = 'isolamento' then
    update public.areas
       set status = 'interditada', status_note = 'Área isolada (simulação) pelo aplicativo.'
     where id = p_area_id;
    v_desc := format('[SIMULAÇÃO] Área %s isolada e interditada.', v_name);
  elsif p_action = 'liberacao' then
    update public.areas set status = 'segura', status_note = null where id = p_area_id;
    perform public.refresh_area_status(p_area_id);
    v_desc := format('[SIMULAÇÃO] Área %s liberada para operação.', v_name);
  else
    raise exception 'Ação inválida.';
  end if;

  insert into public.action_logs (area_id, alert_id, user_id, action_type, description, is_simulation)
  values (p_area_id, p_alert_id, auth.uid(), p_action, v_desc, true);
end;
$$;

create or replace function public.update_occurrence_status(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_area uuid;
begin
  if p_status not in ('aberta', 'em_analise', 'resolvida') then
    raise exception 'Status inválido.';
  end if;
  select reported_by, area_id into v_owner, v_area from public.occurrences where id = p_id;
  if not found then
    raise exception 'Ocorrência não encontrada.';
  end if;
  if v_owner is distinct from auth.uid()
     and not (case when v_area is null then public.can_operate()
                   else public.area_access(v_area) >= 2 end) then
    raise exception 'Você não tem permissão para alterar esta ocorrência.';
  end if;

  update public.occurrences
     set status = p_status,
         responsible_name = case when p_status = 'em_analise' or responsible_name is null
                                 then public.current_user_name() else responsible_name end
   where id = p_id;
end;
$$;

-- Exclui a área. Se houver histórico (sensores, alertas, ocorrências ou ações),
-- a área é ARQUIVADA para preservar os dados. Retorna 'excluida' ou 'arquivada'.
create or replace function public.delete_area(p_area_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_supervisor() then
    raise exception 'Somente administradores e supervisores podem excluir áreas.';
  end if;
  if not exists (select 1 from public.areas where id = p_area_id) then
    raise exception 'Área não encontrada.';
  end if;

  if exists (select 1 from public.sensors where area_id = p_area_id)
     or exists (select 1 from public.alerts where area_id = p_area_id)
     or exists (select 1 from public.occurrences where area_id = p_area_id)
     or exists (select 1 from public.action_logs where area_id = p_area_id) then
    update public.areas
       set archived_at = now(),
           status_note = 'Área arquivada em ' || to_char(now(), 'DD/MM/YYYY') || '. Histórico preservado.'
     where id = p_area_id;
    update public.sensors set status = 'manutencao' where area_id = p_area_id;
    return 'arquivada';
  end if;

  delete from public.areas where id = p_area_id;
  return 'excluida';
end;
$$;

-- Administração de funcionários ---------------------------------------
create or replace function public.admin_set_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Somente administradores podem alterar funções no sistema.';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Você não pode alterar a sua própria função.';
  end if;
  if p_role not in ('operador', 'tecnico', 'supervisor', 'admin') then
    raise exception 'Função inválida.';
  end if;
  update public.profiles set role = p_role where id = p_user_id;
  if not found then
    raise exception 'Funcionário não encontrado.';
  end if;
  -- Operadores não mantêm acesso de gestão
  if p_role = 'operador' then
    update public.area_members set access_level = 'operacao'
     where user_id = p_user_id and access_level = 'gestao';
  end if;
end;
$$;

-- Define (ou remove, com p_level nulo) o acesso de um funcionário a uma área
create or replace function public.set_area_member(p_user_id uuid, p_area_id uuid, p_level text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  if not public.is_supervisor() then
    raise exception 'Somente administradores e supervisores gerenciam permissões.';
  end if;
  select role into v_role from public.profiles where id = p_user_id;
  if v_role is null then
    raise exception 'Funcionário não encontrado.';
  end if;

  if p_level is null then
    delete from public.area_members where user_id = p_user_id and area_id = p_area_id;
    return;
  end if;
  if p_level not in ('leitura', 'operacao', 'gestao') then
    raise exception 'Nível de acesso inválido.';
  end if;
  if v_role = 'operador' and p_level = 'gestao' then
    raise exception 'Operadores podem ter no máximo acesso de operação.';
  end if;

  insert into public.area_members (user_id, area_id, access_level)
  values (p_user_id, p_area_id, p_level)
  on conflict (user_id, area_id) do update set access_level = excluded.access_level;
end;
$$;

-- ---------------------------------------------------------------------
-- 5. Políticas RLS (substituem as da policies.sql)
-- ---------------------------------------------------------------------
alter table public.area_members enable row level security;
alter table public.audit_logs   enable row level security;

do $$
declare p record;
begin
  for p in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('profiles', 'areas', 'sensors', 'sensor_readings', 'alerts',
                        'action_logs', 'occurrences', 'notification_preferences',
                        'area_members', 'audit_logs')
  loop
    execute format('drop policy if exists %I on public.%I', p.policyname, p.tablename);
  end loop;
end;
$$;

-- profiles: próprio perfil; supervisores/administradores veem a equipe
create policy profiles_select on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_supervisor());
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_admin_update on public.profiles
  for update to authenticated using (public.is_admin()) with check (true);

-- areas: visíveis conforme o nível de acesso; criação por supervisores;
-- edição por quem tem gestão; exclusão somente pela função delete_area
create policy areas_select on public.areas
  for select to authenticated using (public.area_access(id) >= 1);
create policy areas_insert on public.areas
  for insert to authenticated with check (public.is_supervisor());
create policy areas_update on public.areas
  for update to authenticated
  using (public.area_access(id) >= 3) with check (public.area_access(id) >= 3);

-- sensors / readings: visíveis conforme a área; sem exclusão pelo app
create policy sensors_select on public.sensors
  for select to authenticated using (public.area_access(area_id) >= 1);
create policy sensors_insert on public.sensors
  for insert to authenticated with check (public.is_supervisor());
create policy sensors_update on public.sensors
  for update to authenticated using (public.is_supervisor()) with check (public.is_supervisor());

create policy readings_select on public.sensor_readings
  for select to authenticated using (sensor_id in (select id from public.sensors));
create policy readings_insert on public.sensor_readings
  for insert to authenticated with check (public.is_supervisor() and source = 'manual');

-- alerts: visíveis conforme a área; cadastro/edição com acesso de operação;
-- exclusão de alertas manuais com acesso de gestão (alertas de sensor: só admin)
create policy alerts_select on public.alerts
  for select to authenticated using (public.area_access(area_id) >= 1);
create policy alerts_insert on public.alerts
  for insert to authenticated
  with check (public.area_access(area_id) >= 2 and origin = 'manual' and sensor_id is null);
create policy alerts_update on public.alerts
  for update to authenticated
  using (public.area_access(area_id) >= 2) with check (public.area_access(area_id) >= 2);
create policy alerts_delete on public.alerts
  for delete to authenticated
  using ((origin = 'manual' and public.area_access(area_id) >= 3) or public.is_admin());

-- action_logs: visíveis conforme a área; comentários próprios
create policy action_logs_select on public.action_logs
  for select to authenticated
  using (public.area_access(coalesce(area_id,
           (select al.area_id from public.alerts al where al.id = alert_id))) >= 1);
create policy action_logs_insert_comment on public.action_logs
  for insert to authenticated
  with check (user_id = auth.uid() and action_type = 'comentario' and is_simulation = false
              and public.area_access(area_id) >= 1);

-- occurrences: gerais (sem área) para todos; por área conforme o acesso
create policy occurrences_select on public.occurrences
  for select to authenticated
  using (area_id is null or public.area_access(area_id) >= 1);
create policy occurrences_insert on public.occurrences
  for insert to authenticated
  with check (
    reported_by = auth.uid()
    and (area_id is null or public.area_access(area_id) >= 1)
    and (kind = 'ocorrencia'
         or (case when area_id is null then public.can_operate()
                  else public.area_access(area_id) >= 2 end)));
create policy occurrences_update on public.occurrences
  for update to authenticated
  using (reported_by = auth.uid()
         or (case when area_id is null then public.can_operate()
                  else public.area_access(area_id) >= 2 end))
  with check (area_id is null or public.area_access(area_id) >= 1);
create policy occurrences_delete on public.occurrences
  for delete to authenticated using (public.is_supervisor());

-- notification_preferences: somente o próprio usuário
create policy notif_select_own on public.notification_preferences
  for select to authenticated using (user_id = auth.uid());
create policy notif_insert_own on public.notification_preferences
  for insert to authenticated with check (user_id = auth.uid());
create policy notif_update_own on public.notification_preferences
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- area_members: cada um vê os próprios vínculos; supervisores veem todos.
-- Alterações somente pela função set_area_member.
create policy area_members_select on public.area_members
  for select to authenticated using (user_id = auth.uid() or public.is_supervisor());

-- audit_logs: somente leitura para supervisores e administradores
create policy audit_logs_select on public.audit_logs
  for select to authenticated using (public.is_supervisor());

-- Permissões de execução
revoke execute on function public.delete_area(uuid) from public, anon;
revoke execute on function public.admin_set_role(uuid, text) from public, anon;
revoke execute on function public.set_area_member(uuid, uuid, text) from public, anon;
revoke execute on function public.audit_changes() from public, anon, authenticated;
grant execute on function public.delete_area(uuid) to authenticated;
grant execute on function public.admin_set_role(uuid, text) to authenticated;
grant execute on function public.set_area_member(uuid, uuid, text) to authenticated;
grant execute on function public.area_access(uuid) to authenticated;

revoke all on public.area_members, public.audit_logs from anon;

-- ---------------------------------------------------------------------
-- 6. Usuários e permissões de demonstração (dados fictícios)
--    admin@safecore.com    -> Administrador
--    demo@safecore.com     -> Técnico de Segurança
--    operador@safecore.com -> Operador (somente Produção)
--    Senha de todos: Safecore@2026 (exemplo; altere pelo app)
-- ---------------------------------------------------------------------
do $$
declare
  u record;
  v_id uuid;
begin
  for u in
    select * from (values
      ('demo@safecore.com', 'Luiz Paulo'),
      ('admin@safecore.com', 'Carla Mendes'),
      ('operador@safecore.com', 'Marcos Silva')
    ) as t(email, full_name)
  loop
    if not exists (select 1 from auth.users where email = u.email) then
      v_id := gen_random_uuid();
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
        confirmation_token, email_change, email_change_token_new, recovery_token)
      values (
        '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
        u.email, extensions.crypt('Safecore@2026', extensions.gen_salt('bf')), now(),
        '{"provider":"email","providers":["email"]}',
        jsonb_build_object('full_name', u.full_name), now(), now(), '', '', '', '');
      insert into auth.identities (
        id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (
        gen_random_uuid(), v_id, v_id::text,
        jsonb_build_object('sub', v_id::text, 'email', u.email, 'email_verified', true),
        'email', now(), now(), now());
    end if;
  end loop;
end;
$$;

-- Aplica funções e vínculos de demonstração (também chamada no fim do seed.sql)
create or replace function public.apply_demo_permissions()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_demo uuid := (select id from public.profiles where email = 'demo@safecore.com');
  v_admin uuid := (select id from public.profiles where email = 'admin@safecore.com');
  v_oper uuid := (select id from public.profiles where email = 'operador@safecore.com');
begin
  -- Laboratório: dados restritos (somente quem tem vínculo)
  update public.areas set restricted = true where code = 'LAB';

  update public.profiles
     set role = 'admin',
         full_name = case when full_name = '' then 'Carla Mendes' else full_name end,
         job_title = coalesce(job_title, 'Coordenadora de Segurança')
   where id = v_admin;
  update public.profiles
     set role = 'tecnico',
         full_name = case when full_name = '' then 'Luiz Paulo' else full_name end,
         job_title = coalesce(job_title, 'Técnico de Segurança'),
         phone = coalesce(phone, '(11) 99765-4321')
   where id = v_demo;
  update public.profiles
     set role = 'operador',
         full_name = case when full_name = '' then 'Marcos Silva' else full_name end,
         job_title = coalesce(job_title, 'Operador de Produção')
   where id = v_oper;

  if v_demo is not null then
    insert into public.area_members (user_id, area_id, access_level)
    select v_demo, a.id,
           case when a.code in ('CLD', 'PRD', 'ARM') then 'gestao'
                when a.code = 'LAB' then 'leitura'
                else 'operacao' end
      from public.areas a
    on conflict (user_id, area_id) do nothing;
  end if;

  if v_oper is not null then
    insert into public.area_members (user_id, area_id, access_level)
    select v_oper, a.id, 'operacao' from public.areas a where a.code = 'PRD'
    on conflict (user_id, area_id) do nothing;
  end if;
end;
$$;

revoke execute on function public.apply_demo_permissions() from public, anon, authenticated;

select public.apply_demo_permissions();

-- Conferência
select p.email, p.role,
       coalesce(string_agg(a.code || ':' || m.access_level, ', ' order by a.code), '—') as areas
from public.profiles p
left join public.area_members m on m.user_id = p.id
left join public.areas a on a.id = m.area_id
group by p.email, p.role
order by p.email;
