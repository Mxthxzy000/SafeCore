-- =====================================================================
-- SafeCore — INSTALAÇÃO COMPLETA UNIFICADA (cole tudo no Supabase SQL Editor e clique em Run)
--
-- Este arquivo único junta TODOS os scripts do projeto (App Mobile, Painel Web e IoT MQTT)
-- na ordem exata de execução:
--   1. schema.sql                             (estrutura, regras e funções)
--   2. policies.sql                           (segurança RLS inicial)
--   3. migration_002_permissoes_crud.sql      (permissões por área, CRUD, auditoria, usuários demo)
--   4. 003_painel_web_admin.sql               (suporte ao painel web administrativo)
--   5. 004_fale_conosco.sql                   (tabela de mensagens do Fale Conosco da web)
--   6. seed.sql                               (cadastro das áreas da Quimex, sensores e histórico)
--   7. migration_003_mqtt_quimex_caldeira.sql (desativa simulação, desconecta outros setores e ativa Caldeira no MQTT)
--
-- Usuários de demonstração (senha de exemplo: Safecore@2026 — altere pelo app):
--   admin@safecore.com    -> Administrador (todas as áreas)
--   demo@safecore.com     -> Técnico de Segurança (gestão: Caldeira, Produção, Armazém)
--   operador@safecore.com -> Operador (somente Produção; Laboratório é restrito)
--
-- Pode ser executado novamente sem erros (idempotente).
-- =====================================================================


-- #####################################################################
-- 1. SCHEMA
-- #####################################################################

-- =====================================================================
-- SafeCore — Estrutura do banco de dados (Supabase / PostgreSQL)
-- Ordem de execução: 1) schema.sql  2) policies.sql  3) seed.sql
-- Script idempotente: pode ser executado novamente sem erros.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Função utilitária: atualiza a coluna updated_at
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 1. Perfis de usuário (1:1 com auth.users)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null default '' check (char_length(full_name) <= 120),
  email       text not null default '',
  phone       text check (phone is null or char_length(phone) <= 30),
  job_title   text check (job_title is null or char_length(job_title) <= 80),
  role        text not null default 'operador'
              check (role in ('operador', 'tecnico', 'supervisor', 'admin')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2. Áreas industriais
-- map_x/map_y/map_w/map_h: posição relativa (0 a 1) no mapa da planta
-- ---------------------------------------------------------------------
create table if not exists public.areas (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique check (char_length(code) between 2 and 20),
  name         text not null check (char_length(name) between 2 and 80),
  description  text,
  area_type    text not null default 'producao'
               check (area_type in ('producao', 'armazem', 'caldeira', 'laboratorio',
                                    'escritorio', 'tanques', 'expedicao', 'tratamento')),
  status       text not null default 'segura'
               check (status in ('segura', 'atencao', 'critica', 'interditada', 'desconectada')),
  status_note  text,
  map_x        numeric(4,3) not null default 0 check (map_x between 0 and 1),
  map_y        numeric(4,3) not null default 0 check (map_y between 0 and 1),
  map_w        numeric(4,3) not null default 0.2 check (map_w > 0 and map_w <= 1),
  map_h        numeric(4,3) not null default 0.2 check (map_h > 0 and map_h <= 1),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. Sensores
-- ref_min/ref_max: faixa segura | critical_min/critical_max: limites críticos
-- device_id: identificador do dispositivo físico (ESP32) para integração futura
-- ---------------------------------------------------------------------
create table if not exists public.sensors (
  id               uuid primary key default gen_random_uuid(),
  area_id          uuid not null references public.areas (id) on delete cascade,
  code             text not null unique check (char_length(code) between 2 and 30),
  name             text not null check (char_length(name) between 2 and 80),
  sensor_type      text not null
                   check (sensor_type in ('temperatura', 'pressao', 'umidade',
                                          'gas', 'fumaca', 'ventilacao')),
  unit             text not null check (char_length(unit) <= 10),
  ref_min          numeric(10,2),
  ref_max          numeric(10,2),
  critical_min     numeric(10,2),
  critical_max     numeric(10,2),
  status           text not null default 'online'
                   check (status in ('online', 'offline', 'manutencao')),
  level            text not null default 'normal'
                   check (level in ('normal', 'atencao', 'critico')),
  last_value       numeric(10,2),
  last_reading_at  timestamptz,
  device_id        text,
  is_simulated     boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 4. Leituras dos sensores (série temporal)
-- source: 'simulado' (esta versão), 'esp32' (integração futura) ou 'manual'
-- ---------------------------------------------------------------------
create table if not exists public.sensor_readings (
  id           bigint generated always as identity primary key,
  sensor_id    uuid not null references public.sensors (id) on delete cascade,
  value        numeric(10,2) not null,
  recorded_at  timestamptz not null default now(),
  source       text not null default 'simulado'
               check (source in ('simulado', 'esp32', 'manual')),
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 5. Alertas
-- ---------------------------------------------------------------------
create table if not exists public.alerts (
  id              uuid primary key default gen_random_uuid(),
  area_id         uuid not null references public.areas (id) on delete cascade,
  sensor_id       uuid references public.sensors (id) on delete set null,
  title           text not null check (char_length(title) between 3 and 120),
  description     text,
  severity        text not null check (severity in ('atencao', 'critico')),
  status          text not null default 'ativo'
                  check (status in ('ativo', 'em_andamento', 'resolvido')),
  detected_value  numeric(10,2),
  unit            text,
  detected_at     timestamptz not null default now(),
  resolved_at     timestamptz,
  resolved_by     uuid references public.profiles (id) on delete set null,
  resolution_note text,
  is_simulated    boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint alerts_resolved_consistency
    check ((status = 'resolvido') = (resolved_at is not null))
);

-- ---------------------------------------------------------------------
-- 6. Histórico de ações (alertas, áreas e simulações de atuadores)
-- ---------------------------------------------------------------------
create table if not exists public.action_logs (
  id             uuid primary key default gen_random_uuid(),
  area_id        uuid references public.areas (id) on delete cascade,
  alert_id       uuid references public.alerts (id) on delete cascade,
  user_id        uuid references public.profiles (id) on delete set null,
  user_name      text not null default 'Sistema',
  action_type    text not null
                 check (action_type in ('comentario', 'reconhecido', 'resolvido', 'reaberto',
                                        'ventilacao', 'isolamento', 'liberacao', 'sistema')),
  description    text not null check (char_length(description) between 1 and 500),
  is_simulation  boolean not null default false,
  created_at     timestamptz not null default now(),
  constraint action_logs_target check (area_id is not null or alert_id is not null)
);

-- ---------------------------------------------------------------------
-- 7. Mural de avisos e ocorrências
-- ---------------------------------------------------------------------
create table if not exists public.occurrences (
  id                uuid primary key default gen_random_uuid(),
  area_id           uuid references public.areas (id) on delete set null,
  kind              text not null default 'ocorrencia' check (kind in ('aviso', 'ocorrencia')),
  title             text not null check (char_length(title) between 3 and 120),
  description       text not null check (char_length(description) between 3 and 1000),
  priority          text not null default 'media' check (priority in ('baixa', 'media', 'alta')),
  status            text not null default 'aberta'
                    check (status in ('aberta', 'em_analise', 'resolvida')),
  reported_by       uuid references public.profiles (id) on delete set null,
  reported_by_name  text not null default '',
  responsible_name  text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 8. Preferências de notificação
-- ---------------------------------------------------------------------
create table if not exists public.notification_preferences (
  user_id          uuid primary key references public.profiles (id) on delete cascade,
  enabled          boolean not null default true,
  critical_alerts  boolean not null default true,
  warning_alerts   boolean not null default true,
  occurrences      boolean not null default true,
  daily_summary    boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Índices
-- ---------------------------------------------------------------------
create index if not exists idx_sensors_area          on public.sensors (area_id);
create index if not exists idx_sensors_type          on public.sensors (sensor_type);
create index if not exists idx_readings_sensor_time  on public.sensor_readings (sensor_id, recorded_at desc);
create index if not exists idx_readings_time         on public.sensor_readings (recorded_at);
create index if not exists idx_alerts_area           on public.alerts (area_id);
create index if not exists idx_alerts_status         on public.alerts (status, severity);
create index if not exists idx_alerts_detected       on public.alerts (detected_at desc);
create index if not exists idx_alerts_sensor_open    on public.alerts (sensor_id) where status <> 'resolvido';
create index if not exists idx_action_logs_alert     on public.action_logs (alert_id, created_at desc);
create index if not exists idx_action_logs_area      on public.action_logs (area_id, created_at desc);
create index if not exists idx_occurrences_area      on public.occurrences (area_id);
create index if not exists idx_occurrences_created   on public.occurrences (created_at desc);

-- ---------------------------------------------------------------------
-- Triggers de updated_at
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['profiles', 'areas', 'sensors', 'alerts',
                           'occurrences', 'notification_preferences']
  loop
    execute format('drop trigger if exists trg_%1$s_updated_at on public.%1$s', t);
    execute format('create trigger trg_%1$s_updated_at before update on public.%1$s
                    for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- Funções auxiliares de permissão
-- ---------------------------------------------------------------------
create or replace function public.current_role_name()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- Técnicos, supervisores e administradores podem tratar alertas e áreas
create or replace function public.can_operate()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_role_name() in ('tecnico', 'supervisor', 'admin'), false);
$$;

create or replace function public.is_supervisor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_role_name() in ('supervisor', 'admin'), false);
$$;

create or replace function public.current_user_name()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(nullif(full_name, ''), email, 'Usuário')
  from public.profiles where id = auth.uid();
$$;

-- ---------------------------------------------------------------------
-- Cria perfil e preferências quando um usuário se cadastra no Auth
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (new.id,
          coalesce(new.raw_user_meta_data ->> 'full_name', ''),
          coalesce(new.email, ''))
  on conflict (id) do nothing;

  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Mantém o e-mail do perfil sincronizado após confirmação de troca de e-mail
create or replace function public.handle_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set email = coalesce(new.email, '') where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_changed on auth.users;
create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.handle_user_email_change();

-- Impede que um usuário altere o próprio papel (role) pelo aplicativo
create or replace function public.protect_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role
     and auth.uid() is not null
     and not coalesce(public.current_role_name() = 'admin', false) then
    raise exception 'Somente administradores podem alterar o papel do usuário.';
  end if;
  if new.email is distinct from old.email and auth.uid() is not null then
    new.email := old.email; -- e-mail só muda pelo fluxo do Supabase Auth
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_protect_role on public.profiles;
create trigger trg_profiles_protect_role
  before update on public.profiles
  for each row execute function public.protect_profile_role();

-- Preenche o nome do autor em ações e ocorrências
create or replace function public.fill_author_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'occurrences' then
    if new.reported_by is null and auth.uid() is not null then
      new.reported_by := auth.uid();
    end if;
    if coalesce(new.reported_by_name, '') = '' then
      new.reported_by_name := coalesce(
        (select coalesce(nullif(full_name, ''), email) from public.profiles where id = new.reported_by),
        'Equipe SafeCore');
    end if;
  elsif tg_table_name = 'action_logs' then
    if new.user_id is null and auth.uid() is not null then
      new.user_id := auth.uid();
    end if;
    if new.user_id is not null and (new.user_name is null or new.user_name = 'Sistema') then
      new.user_name := coalesce(
        (select coalesce(nullif(full_name, ''), email) from public.profiles where id = new.user_id),
        'Usuário');
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_occurrences_author on public.occurrences;
create trigger trg_occurrences_author
  before insert on public.occurrences
  for each row execute function public.fill_author_name();

drop trigger if exists trg_action_logs_author on public.action_logs;
create trigger trg_action_logs_author
  before insert on public.action_logs
  for each row execute function public.fill_author_name();

-- ---------------------------------------------------------------------
-- Regras de negócio: nível do sensor e status da área
-- ---------------------------------------------------------------------
create or replace function public.sensor_level(
  p_value numeric, p_ref_min numeric, p_ref_max numeric,
  p_crit_min numeric, p_crit_max numeric)
returns text
language sql
immutable
as $$
  select case
    when p_value is null then 'normal'
    when (p_crit_max is not null and p_value >= p_crit_max)
      or (p_crit_min is not null and p_value <= p_crit_min) then 'critico'
    when (p_ref_max is not null and p_value > p_ref_max)
      or (p_ref_min is not null and p_value < p_ref_min) then 'atencao'
    else 'normal'
  end;
$$;

-- Recalcula o status de uma área a partir dos sensores.
-- Áreas interditadas mantêm o status até serem liberadas manualmente.
create or replace function public.refresh_area_status(p_area_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current text;
  v_total int;
  v_offline int;
  v_crit int;
  v_warn int;
  v_new text;
begin
  select status into v_current from public.areas where id = p_area_id;
  if v_current is null or v_current = 'interditada' then
    return;
  end if;

  select count(*),
         count(*) filter (where status <> 'online'),
         count(*) filter (where status = 'online' and level = 'critico'),
         count(*) filter (where status = 'online' and level = 'atencao')
    into v_total, v_offline, v_crit, v_warn
  from public.sensors where area_id = p_area_id;

  v_new := case
    when v_total > 0 and v_offline = v_total then 'desconectada'
    when v_crit > 0 then 'critica'
    when v_warn > 0 or v_offline > 0 then 'atencao'
    else 'segura'
  end;

  if v_new is distinct from v_current then
    update public.areas set status = v_new, status_note = null where id = p_area_id;
  end if;
end;
$$;

-- Ao receber uma leitura: atualiza o sensor, gera alertas e atualiza a área.
-- Durante o seed (safecore.seeding = on) os alertas não são gerados automaticamente.
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

  -- Leituras antigas (ex.: histórico importado) não alteram o estado atual
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
                                   detected_value, unit, detected_at, is_simulated)
        values (s.area_id, s.id, v_title,
                format('%s registrou %s %s (faixa segura: %s a %s %s).',
                       s.name, new.value, s.unit,
                       coalesce(s.ref_min::text, '—'), coalesce(s.ref_max::text, '—'), s.unit),
                v_level, new.value, s.unit, new.recorded_at, new.source = 'simulado');
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

drop trigger if exists trg_readings_after_insert on public.sensor_readings;
create trigger trg_readings_after_insert
  after insert on public.sensor_readings
  for each row execute function public.handle_new_reading();

-- ---------------------------------------------------------------------
-- RPCs usadas pelo aplicativo
-- ---------------------------------------------------------------------

-- Gera uma nova leitura SIMULADA para cada sensor simulado online.
-- Substituído por leituras reais (source = 'esp32') na integração IoT.
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
    where se.is_simulated and se.status = 'online' and a.status <> 'interditada'
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

-- Registra um comentário/ação em um alerta
create or replace function public.add_alert_action(p_alert_id uuid, p_action text, p_description text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_area uuid;
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;
  if p_action not in ('comentario', 'reconhecido') then
    raise exception 'Ação inválida.';
  end if;
  if p_action = 'reconhecido' and not public.can_operate() then
    raise exception 'Seu perfil não tem permissão para assumir alertas.';
  end if;

  select area_id into v_area from public.alerts where id = p_alert_id;
  if v_area is null then
    raise exception 'Alerta não encontrado.';
  end if;

  if p_action = 'reconhecido' then
    update public.alerts set status = 'em_andamento' where id = p_alert_id and status = 'ativo';
  end if;

  insert into public.action_logs (area_id, alert_id, user_id, action_type, description)
  values (v_area, p_alert_id, auth.uid(), p_action, left(trim(p_description), 500));
end;
$$;

-- Resolve um alerta registrando a ação
create or replace function public.resolve_alert(p_alert_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_area uuid;
begin
  if not public.can_operate() then
    raise exception 'Seu perfil não tem permissão para resolver alertas.';
  end if;

  update public.alerts
     set status = 'resolvido', resolved_at = now(), resolved_by = auth.uid(),
         resolution_note = nullif(trim(p_note), '')
   where id = p_alert_id and status <> 'resolvido'
  returning area_id into v_area;

  if v_area is null then
    raise exception 'Alerta não encontrado ou já resolvido.';
  end if;

  insert into public.action_logs (area_id, alert_id, user_id, action_type, description)
  values (v_area, p_alert_id, auth.uid(), 'resolvido',
          coalesce(nullif(trim(p_note), ''), 'Alerta marcado como resolvido.'));
end;
$$;

-- Ações SIMULADAS de atuadores: ventilação, isolamento e liberação de área.
-- Nenhum equipamento físico é acionado nesta versão.
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
  if not public.can_operate() then
    raise exception 'Seu perfil não tem permissão para executar ações na área.';
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

-- Atualiza o status de uma ocorrência (técnicos ou o próprio autor)
create or replace function public.update_occurrence_status(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  if p_status not in ('aberta', 'em_analise', 'resolvida') then
    raise exception 'Status inválido.';
  end if;
  select reported_by into v_owner from public.occurrences where id = p_id;
  if not found then
    raise exception 'Ocorrência não encontrada.';
  end if;
  if not public.can_operate() and v_owner is distinct from auth.uid() then
    raise exception 'Seu perfil não tem permissão para alterar esta ocorrência.';
  end if;

  update public.occurrences
     set status = p_status,
         responsible_name = case when p_status = 'em_analise' or responsible_name is null
                                 then public.current_user_name() else responsible_name end
   where id = p_id;
end;
$$;

-- Série agregada para relatórios (média/mín/máx por intervalo e tipo de sensor)
create or replace function public.report_series(
  p_from timestamptz, p_to timestamptz, p_bucket text default 'day')
returns table (bucket timestamptz, sensor_type text, avg_value numeric,
               min_value numeric, max_value numeric, samples bigint)
language sql
stable
security invoker
set search_path = public
as $$
  select date_trunc(case when p_bucket = 'hour' then 'hour' else 'day' end, r.recorded_at) as bucket,
         s.sensor_type,
         round(avg(r.value), 2),
         min(r.value),
         max(r.value),
         count(*)
  from public.sensor_readings r
  join public.sensors s on s.id = r.sensor_id
  where r.recorded_at >= p_from and r.recorded_at < p_to
    and s.sensor_type in ('temperatura', 'pressao')
  group by 1, 2
  order by 1, 2;
$$;

-- ---------------------------------------------------------------------
-- Cria perfis para usuários que já existiam antes deste script
-- ---------------------------------------------------------------------
insert into public.profiles (id, full_name, email)
select u.id, coalesce(u.raw_user_meta_data ->> 'full_name', ''), coalesce(u.email, '')
from auth.users u
on conflict (id) do nothing;

insert into public.notification_preferences (user_id)
select id from public.profiles
on conflict (user_id) do nothing;

-- ---------------------------------------------------------------------
-- Realtime: o app recebe novos alertas em tempo real
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public'
                       and tablename = 'alerts') then
    alter publication supabase_realtime add table public.alerts;
  end if;
end;
$$;


-- #####################################################################
-- 2. POLÍTICAS INICIAIS (RLS)
-- #####################################################################

-- =====================================================================
-- SafeCore — Políticas de segurança (Row Level Security)
-- Execute DEPOIS de schema.sql.
--
-- Papéis (profiles.role):
--   operador   -> consulta dados, comenta alertas e registra ocorrências
--   tecnico    -> + trata/resolve alertas, executa ações simuladas nas áreas
--   supervisor -> + cadastra/edita áreas, sensores e leituras manuais
--   admin      -> + altera o papel de outros usuários
-- =====================================================================

alter table public.profiles                 enable row level security;
alter table public.areas                    enable row level security;
alter table public.sensors                  enable row level security;
alter table public.sensor_readings          enable row level security;
alter table public.alerts                   enable row level security;
alter table public.action_logs              enable row level security;
alter table public.occurrences              enable row level security;
alter table public.notification_preferences enable row level security;

-- Remove políticas antigas (permite reexecutar o script)
do $$
declare p record;
begin
  for p in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('profiles', 'areas', 'sensors', 'sensor_readings', 'alerts',
                        'action_logs', 'occurrences', 'notification_preferences')
  loop
    execute format('drop policy if exists %I on public.%I', p.policyname, p.tablename);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- profiles: cada usuário vê e edita apenas o próprio perfil.
-- Supervisores veem a equipe; somente admin altera papéis (ver trigger).
-- ---------------------------------------------------------------------
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_supervisor());

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy profiles_admin_update on public.profiles
  for update to authenticated
  using (public.current_role_name() = 'admin')
  with check (true);

-- ---------------------------------------------------------------------
-- areas / sensors / sensor_readings: leitura para usuários autenticados,
-- escrita apenas para supervisores.
-- (Dispositivos ESP32 enviarão leituras por uma Edge Function com
--  credencial própria — nunca pelo aplicativo.)
-- ---------------------------------------------------------------------
create policy areas_select on public.areas
  for select to authenticated using (true);
create policy areas_write on public.areas
  for all to authenticated
  using (public.is_supervisor()) with check (public.is_supervisor());

create policy sensors_select on public.sensors
  for select to authenticated using (true);
create policy sensors_write on public.sensors
  for all to authenticated
  using (public.is_supervisor()) with check (public.is_supervisor());

create policy readings_select on public.sensor_readings
  for select to authenticated using (true);
create policy readings_insert on public.sensor_readings
  for insert to authenticated
  with check (public.is_supervisor() and source = 'manual');

-- ---------------------------------------------------------------------
-- alerts: leitura para autenticados; tratamento via RPC (resolve_alert)
-- ---------------------------------------------------------------------
create policy alerts_select on public.alerts
  for select to authenticated using (true);
create policy alerts_update on public.alerts
  for update to authenticated
  using (public.can_operate()) with check (public.can_operate());

-- ---------------------------------------------------------------------
-- action_logs: histórico somente leitura (inserções via RPC);
-- comentários diretos permitidos ao próprio usuário.
-- ---------------------------------------------------------------------
create policy action_logs_select on public.action_logs
  for select to authenticated using (true);
create policy action_logs_insert_comment on public.action_logs
  for insert to authenticated
  with check (user_id = auth.uid() and action_type = 'comentario' and is_simulation = false);

-- ---------------------------------------------------------------------
-- occurrences: todos leem; cada um cria em seu nome;
-- autor ou técnico atualiza; supervisor exclui.
-- ---------------------------------------------------------------------
create policy occurrences_select on public.occurrences
  for select to authenticated using (true);
create policy occurrences_insert on public.occurrences
  for insert to authenticated
  with check (reported_by = auth.uid()
              and (kind = 'ocorrencia' or public.can_operate()));
create policy occurrences_update on public.occurrences
  for update to authenticated
  using (reported_by = auth.uid() or public.can_operate())
  with check (reported_by = auth.uid() or public.can_operate());
create policy occurrences_delete on public.occurrences
  for delete to authenticated
  using (public.is_supervisor());

-- ---------------------------------------------------------------------
-- notification_preferences: somente o próprio usuário
-- ---------------------------------------------------------------------
create policy notif_select_own on public.notification_preferences
  for select to authenticated using (user_id = auth.uid());
create policy notif_insert_own on public.notification_preferences
  for insert to authenticated with check (user_id = auth.uid());
create policy notif_update_own on public.notification_preferences
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- Funções: usuários anônimos não executam RPCs do sistema
-- ---------------------------------------------------------------------
revoke execute on function public.simulate_readings() from public, anon;
revoke execute on function public.add_alert_action(uuid, text, text) from public, anon;
revoke execute on function public.resolve_alert(uuid, text) from public, anon;
revoke execute on function public.simulate_area_action(uuid, text, uuid) from public, anon;
revoke execute on function public.update_occurrence_status(uuid, text) from public, anon;
revoke execute on function public.report_series(timestamptz, timestamptz, text) from public, anon;
revoke execute on function public.refresh_area_status(uuid) from public, anon, authenticated;

grant execute on function public.simulate_readings() to authenticated;
grant execute on function public.add_alert_action(uuid, text, text) to authenticated;
grant execute on function public.resolve_alert(uuid, text) to authenticated;
grant execute on function public.simulate_area_action(uuid, text, uuid) to authenticated;
grant execute on function public.update_occurrence_status(uuid, text) to authenticated;
grant execute on function public.report_series(timestamptz, timestamptz, text) to authenticated;

-- Tabelas: anônimos não têm acesso
revoke all on public.profiles, public.areas, public.sensors, public.sensor_readings,
              public.alerts, public.action_logs, public.occurrences,
              public.notification_preferences from anon;


-- #####################################################################
-- 3. MIGRAÇÃO 002 — PERMISSÕES, CRUD E AUDITORIA
-- #####################################################################

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


-- #####################################################################
-- 4. DADOS FICTÍCIOS (SEED)
-- #####################################################################

-- =====================================================================
-- SafeCore — Dados FICTÍCIOS para demonstração
-- Execute DEPOIS de schema.sql, policies.sql e migration_002_permissoes_crud.sql.
--
-- ATENÇÃO: todos os dados abaixo são SIMULADOS (sensors.is_simulated = true,
-- sensor_readings.source = 'simulado'). Não representam medições reais da
-- Quimex Industrial. As datas são relativas ao momento da execução; execute
-- o script novamente antes de uma apresentação para "atualizar" os horários.
--
-- O script apaga e recria áreas, sensores, leituras, alertas, histórico de
-- ações e ocorrências. Perfis de usuários NÃO são apagados.
-- =====================================================================

-- Desativa a geração automática de alertas enquanto o histórico é inserido
select set_config('safecore.seeding', 'on', false);
select setseed(0.42);

delete from public.occurrences;
delete from public.areas; -- remove em cascata sensores, leituras, alertas e ações

-- ---------------------------------------------------------------------
-- Áreas (posição relativa no mapa da planta)
-- ---------------------------------------------------------------------
insert into public.areas (code, name, description, area_type, status, map_x, map_y, map_w, map_h) values
  ('ESC', 'Escritório',            'Administração, recepção e sala de controle.',          'escritorio',  'segura', 0.05, 0.04, 0.40, 0.16),
  ('LAB', 'Laboratório',           'Controle de qualidade e análises químicas.',           'laboratorio', 'segura', 0.55, 0.04, 0.40, 0.16),
  ('PRD', 'Produção',              'Linha de mistura e envase de produtos químicos.',      'producao',    'segura', 0.05, 0.26, 0.55, 0.26),
  ('CLD', 'Caldeira',              'Geração de vapor para o processo produtivo.',          'caldeira',    'segura', 0.66, 0.26, 0.29, 0.26),
  ('ARM', 'Armazém',               'Estoque de matérias-primas e produtos acabados.',      'armazem',     'segura', 0.05, 0.58, 0.40, 0.18),
  ('TNQ', 'Tanques Químicos',      'Tancagem de solventes e reagentes.',                   'tanques',     'segura', 0.51, 0.58, 0.44, 0.18),
  ('EXP', 'Expedição',             'Carregamento e saída de mercadorias.',                 'expedicao',   'segura', 0.05, 0.82, 0.40, 0.14),
  ('ETE', 'Estação de Tratamento', 'Tratamento de efluentes industriais.',                 'tratamento',  'segura', 0.51, 0.82, 0.44, 0.14);

-- ---------------------------------------------------------------------
-- Sensores (4 por área = 32) e parâmetros da simulação
-- ---------------------------------------------------------------------
drop table if exists seed_specs;
create temporary table seed_specs (
  area_code text, code text, name text, sensor_type text, unit text,
  ref_min numeric, ref_max numeric, crit_min numeric, crit_max numeric,
  base numeric, amp numeric, noise numeric, current_value numeric
);

insert into seed_specs values
  -- Produção
  ('PRD','PRD-TMP-01','Temperatura Produção','temperatura','°C', 15,40,5,55,   26,2,0.8,   26.4),
  ('PRD','PRD-PRS-01','Pressão Produção','pressao','bar',        0.9,1.3,0.7,1.6, 1.05,0.03,0.02, 1.40),
  ('PRD','PRD-UMD-01','Umidade Produção','umidade','%',          35,70,20,85,  48,4,2,     47),
  ('PRD','PRD-VNT-01','Ventilação Produção','ventilacao','m/s',  0.8,3,0.3,4.5, 1.6,0.2,0.1, 1.62),
  -- Armazém
  ('ARM','ARM-TMP-01','Temperatura Armazém','temperatura','°C',  15,40,5,55,   24,2,0.8,   23.8),
  ('ARM','ARM-PRS-01','Pressão Armazém','pressao','bar',         0.9,1.3,0.7,1.6, 0.98,0.02,0.02, 0.98),
  ('ARM','ARM-UMD-01','Umidade Armazém','umidade','%',           35,70,20,85,  50,4,2,     50),
  ('ARM','ARM-FUM-01','Detector de Fumaça Armazém','fumaca','%obs/m', null,1.5,null,4, 0.2,0.05,0.1, 0.18),
  -- Caldeira
  ('CLD','CLD-TMP-01','Temperatura Caldeira','temperatura','°C', 15,50,5,55,   44,3,1,     58.7),
  ('CLD','CLD-PRS-01','Pressão Caldeira','pressao','bar',        0.9,1.3,0.7,1.6, 1.1,0.03,0.02, 1.12),
  ('CLD','CLD-UMD-01','Umidade Caldeira','umidade','%',          35,70,20,85,  42,3,2,     41),
  ('CLD','CLD-GAS-01','Gás Combustível Caldeira','gas','%LEL',   null,10,null,25, 3,0.8,0.6, 3.4),
  -- Laboratório
  ('LAB','LAB-TMP-01','Temperatura Laboratório','temperatura','°C', 15,40,5,55, 22,1,0.5,  22.1),
  ('LAB','LAB-PRS-01','Pressão Laboratório','pressao','bar',     0.9,1.3,0.7,1.6, 0.98,0.02,0.02, 0.98),
  ('LAB','LAB-UMD-01','Umidade Laboratório','umidade','%',       35,70,20,85,  50,3,2,     50),
  ('LAB','LAB-GAS-01','Gás Tóxico Laboratório','gas','%LEL',     null,10,null,25, 2,0.5,0.5, 1.9),
  -- Escritório
  ('ESC','ESC-TMP-01','Temperatura Escritório','temperatura','°C', 15,40,5,55, 22,1,0.5,   21.8),
  ('ESC','ESC-PRS-01','Pressão Escritório','pressao','bar',      0.9,1.3,0.7,1.6, 0.99,0.02,0.02, 0.99),
  ('ESC','ESC-UMD-01','Umidade Escritório','umidade','%',        35,70,20,85,  50,3,2,     50),
  ('ESC','ESC-FUM-01','Detector de Fumaça Escritório','fumaca','%obs/m', null,1.5,null,4, 0.1,0.03,0.05, 0.10),
  -- Tanques Químicos
  ('TNQ','TNQ-TMP-01','Temperatura Tanques','temperatura','°C',  15,40,5,55,   25,2,0.8,   25.3),
  ('TNQ','TNQ-PRS-01','Pressão Tanques','pressao','bar',         0.9,1.3,0.7,1.6, 1.02,0.03,0.02, 1.03),
  ('TNQ','TNQ-UMD-01','Umidade Tanques','umidade','%',           35,70,20,85,  55,4,2,     54),
  ('TNQ','TNQ-GAS-01','Vapores Inflamáveis Tanques','gas','%LEL', null,10,null,25, 4,1,0.8, 4.2),
  -- Expedição (fica desconectada: sem leituras nas últimas 3 horas)
  ('EXP','EXP-TMP-01','Temperatura Expedição','temperatura','°C', 15,40,5,55,  27,2,0.8,   null),
  ('EXP','EXP-PRS-01','Pressão Expedição','pressao','bar',       0.9,1.3,0.7,1.6, 1.0,0.02,0.02, null),
  ('EXP','EXP-UMD-01','Umidade Expedição','umidade','%',         35,70,20,85,  60,4,2,     null),
  ('EXP','EXP-VNT-01','Ventilação Expedição','ventilacao','m/s', 0.8,3,0.3,4.5, 1.4,0.2,0.1, null),
  -- Estação de Tratamento
  ('ETE','ETE-TMP-01','Temperatura ETE','temperatura','°C',      15,40,5,55,   23,2,0.8,   23.4),
  ('ETE','ETE-PRS-01','Pressão ETE','pressao','bar',             0.9,1.3,0.7,1.6, 1.01,0.02,0.02, 1.01),
  ('ETE','ETE-UMD-01','Umidade ETE','umidade','%',               40,80,25,90,  62,4,2,     63),
  ('ETE','ETE-VNT-01','Ventilação ETE','ventilacao','m/s',       0.8,3,0.3,4.5, 1.8,0.2,0.1, 1.79);

insert into public.sensors (area_id, code, name, sensor_type, unit, ref_min, ref_max,
                            critical_min, critical_max, device_id, is_simulated)
select a.id, s.code, s.name, s.sensor_type, s.unit, s.ref_min, s.ref_max, s.crit_min, s.crit_max,
       'SIM-' || s.code, true
from seed_specs s join public.areas a on a.code = s.area_code;

-- ---------------------------------------------------------------------
-- Leituras: histórico de 30 dias a cada 2 horas (ciclo diário + ruído)
-- ---------------------------------------------------------------------
insert into public.sensor_readings (sensor_id, value, recorded_at, source)
select se.id,
       round(greatest(sp.base
             + sp.amp * sin(2 * pi() * (extract(hour from t) - 9) / 24)::numeric
             + sp.noise * (random() - 0.5)::numeric * 2, 0), 2),
       t,
       'simulado'
from seed_specs sp
join public.sensors se on se.code = sp.code
cross join lateral generate_series(
  date_trunc('hour', now()) - interval '30 days',
  date_trunc('hour', now()) - case when sp.area_code = 'EXP' then interval '3 hours'
                                   else interval '2 hours' end,
  interval '2 hours') as t
order by t;

-- Picos históricos (correspondem aos alertas resolvidos abaixo)
insert into public.sensor_readings (sensor_id, value, recorded_at, source)
select se.id, v.value, now() + v.offset_time, 'simulado'
from (values
  ('ARM-FUM-01', 2.10, interval '-20 days -10 minutes'),
  ('ARM-FUM-01', 4.60, interval '-20 days'),
  ('ARM-FUM-01', 1.20, interval '-20 days +40 minutes'),
  ('LAB-GAS-01', 14.80, interval '-12 days -15 minutes'),
  ('LAB-GAS-01', 27.00, interval '-12 days'),
  ('LAB-GAS-01', 6.10, interval '-12 days +50 minutes'),
  ('PRD-TMP-01', 41.50, interval '-8 days'),
  ('PRD-TMP-01', 34.20, interval '-8 days +1 hour'),
  ('CLD-TMP-01', 52.10, interval '-5 days'),
  ('CLD-TMP-01', 47.30, interval '-5 days +1 hour'),
  ('ARM-UMD-01', 33.00, interval '-2 days -1 hour'),
  ('ARM-UMD-01', 28.00, interval '-2 days'),
  ('ARM-UMD-01', 36.50, interval '-2 days +2 hours'),
  ('TNQ-GAS-01', 12.40, interval '-1 day'),
  ('TNQ-GAS-01', 5.20, interval '-1 day +1 hour')
) as v(code, value, offset_time)
join public.sensors se on se.code = v.code;

-- Evolução recente que originou os alertas ativos
insert into public.sensor_readings (sensor_id, value, recorded_at, source)
select se.id, v.value, now() + v.offset_time, 'simulado'
from (values
  ('CLD-TMP-01', 50.80, interval '-90 minutes'),
  ('CLD-TMP-01', 53.90, interval '-60 minutes'),
  ('CLD-TMP-01', 56.20, interval '-35 minutes'),
  ('PRD-PRS-01', 1.27,  interval '-130 minutes'),
  ('PRD-PRS-01', 1.33,  interval '-120 minutes'),
  ('PRD-PRS-01', 1.37,  interval '-60 minutes')
) as v(code, value, offset_time)
join public.sensors se on se.code = v.code;

-- Leitura atual de cada sensor conectado
insert into public.sensor_readings (sensor_id, value, recorded_at, source)
select se.id, sp.current_value,
       now() - make_interval(mins => 5 + (row_number() over (order by sp.code))::int % 7),
       'simulado'
from seed_specs sp
join public.sensors se on se.code = sp.code
where sp.current_value is not null;

-- Expedição: sensores sem comunicação
update public.sensors set status = 'offline'
where area_id = (select id from public.areas where code = 'EXP');

-- ---------------------------------------------------------------------
-- Alertas (coerentes com as leituras acima)
-- ---------------------------------------------------------------------
insert into public.alerts (area_id, sensor_id, title, description, severity, status,
                           detected_value, unit, detected_at, resolved_at, resolution_note,
                           origin, category)
select a.id, se.id, v.title, v.description, v.severity, v.status, v.value, v.unit,
       now() + v.detected, case when v.resolved is null then null else now() + v.resolved end,
       v.note, 'sensor', coalesce(se.sensor_type, 'comunicacao')
from (values
  ('CLD', 'CLD-TMP-01', 'Temperatura Elevada',
   'Temperatura acima do limite seguro (50 °C). Limite crítico de 55 °C ultrapassado.',
   'critico', 'ativo', 58.70, '°C', interval '-90 minutes', null::interval, null),
  ('PRD', 'PRD-PRS-01', 'Pressão Elevada',
   'Pressão acima do limite seguro (1,30 bar) na linha de mistura.',
   'atencao', 'em_andamento', 1.40, 'bar', interval '-120 minutes', null, null),
  ('EXP', null, 'Sensores sem comunicação',
   'Os 4 sensores da Expedição não enviam leituras há mais de 2 horas.',
   'atencao', 'ativo', null, null, interval '-2 hours -50 minutes', null, null),
  ('TNQ', 'TNQ-GAS-01', 'Vapores Inflamáveis',
   'Concentração de vapores acima do limite seguro (10 %LEL).',
   'atencao', 'resolvido', 12.40, '%LEL', interval '-1 day', interval '-23 hours',
   'Vazamento em válvula identificado. Área interditada para manutenção.'),
  ('ARM', 'ARM-UMD-01', 'Umidade abaixo do ideal',
   'Umidade abaixo do ideal para armazenamento de matérias-primas.',
   'atencao', 'resolvido', 28.00, '%', interval '-2 days', interval '-2 days +3 hours',
   'Umidificador do armazém religado.'),
  ('CLD', 'CLD-TMP-01', 'Temperatura Elevada',
   'Temperatura acima do limite seguro durante pico de produção.',
   'atencao', 'resolvido', 52.10, '°C', interval '-5 days', interval '-5 days +2 hours',
   'Carga da caldeira reduzida; temperatura normalizada.'),
  ('PRD', 'PRD-TMP-01', 'Temperatura Elevada',
   'Temperatura acima de 40 °C na linha de produção.',
   'atencao', 'resolvido', 41.50, '°C', interval '-8 days', interval '-8 days +90 minutes',
   'Exaustores adicionais ligados.'),
  ('LAB', 'LAB-GAS-01', 'Concentração de Gás',
   'Concentração de gás tóxico acima do limite crítico (25 %LEL).',
   'critico', 'resolvido', 27.00, '%LEL', interval '-12 days', interval '-12 days +1 hour',
   'Capela de exaustão reparada. Laboratório evacuado preventivamente por 40 minutos.'),
  ('ARM', 'ARM-FUM-01', 'Fumaça Detectada',
   'Detector de fumaça acima do limite crítico no corredor B.',
   'critico', 'resolvido', 4.60, '%obs/m', interval '-20 days', interval '-20 days +45 minutes',
   'Superaquecimento de empilhadeira elétrica. Sem feridos.')
) as v(area_code, sensor_code, title, description, severity, status, value, unit,
       detected, resolved, note)
join public.areas a on a.code = v.area_code
left join public.sensors se on se.code = v.sensor_code;

-- ---------------------------------------------------------------------
-- Histórico de ações
-- ---------------------------------------------------------------------
insert into public.action_logs (area_id, alert_id, user_name, action_type, description,
                                is_simulation, created_at)
select al.area_id, al.id, v.user_name, v.action_type, v.description, v.is_sim, now() + v.at
from (values
  ('Temperatura Elevada', 'ativo', 'Sistema', 'sistema',
   'Alerta gerado: temperatura de 50,8 °C acima da faixa segura.', false, interval '-90 minutes'),
  ('Temperatura Elevada', 'ativo', 'Sistema', 'sistema',
   'Alerta escalonado para crítico: 56,2 °C.', false, interval '-35 minutes'),
  ('Temperatura Elevada', 'ativo', 'Carla Mendes', 'comentario',
   'Equipe de manutenção acionada para inspecionar o queimador.', false, interval '-25 minutes'),
  ('Pressão Elevada', 'em_andamento', 'Sistema', 'sistema',
   'Alerta gerado: pressão de 1,33 bar acima da faixa segura.', false, interval '-120 minutes'),
  ('Pressão Elevada', 'em_andamento', 'Ricardo Alves', 'reconhecido',
   'Alerta assumido. Verificando válvula de alívio da linha 2.', false, interval '-100 minutes'),
  ('Pressão Elevada', 'em_andamento', 'Ricardo Alves', 'ventilacao',
   '[SIMULAÇÃO] Ventilação de emergência acionada na área Produção.', true, interval '-95 minutes'),
  ('Sensores sem comunicação', 'ativo', 'Sistema', 'sistema',
   'Perda de comunicação com o gateway da Expedição.', false, interval '-2 hours -50 minutes'),
  ('Vapores Inflamáveis', 'resolvido', 'Carla Mendes', 'isolamento',
   '[SIMULAÇÃO] Área Tanques Químicos isolada e interditada.', true, interval '-23 hours -30 minutes'),
  ('Vapores Inflamáveis', 'resolvido', 'Carla Mendes', 'resolvido',
   'Vazamento em válvula identificado. Área interditada para manutenção.', false, interval '-23 hours'),
  ('Umidade abaixo do ideal', 'resolvido', 'Ricardo Alves', 'resolvido',
   'Umidificador do armazém religado.', false, interval '-2 days +3 hours'),
  ('Concentração de Gás', 'resolvido', 'Carla Mendes', 'resolvido',
   'Capela de exaustão reparada. Laboratório evacuado preventivamente por 40 minutos.', false,
   interval '-12 days +1 hour'),
  ('Fumaça Detectada', 'resolvido', 'Ricardo Alves', 'resolvido',
   'Superaquecimento de empilhadeira elétrica. Sem feridos.', false, interval '-20 days +45 minutes')
) as v(title, status, user_name, action_type, description, is_sim, at)
join public.alerts al on al.title = v.title and al.status = v.status
where (v.title <> 'Temperatura Elevada' or al.area_id = (select id from public.areas where code = 'CLD'));

-- ---------------------------------------------------------------------
-- Mural de avisos e ocorrências
-- ---------------------------------------------------------------------
insert into public.occurrences (area_id, kind, title, description, priority, status,
                                reported_by_name, responsible_name, created_at)
select a.id, v.kind, v.title, v.description, v.priority, v.status, v.reporter, v.responsible,
       now() + v.at
from (values
  ('TNQ', 'aviso', 'Tanques Químicos interditados',
   'Área interditada para manutenção preventiva das válvulas. Acesso somente com autorização da segurança.',
   'alta', 'em_analise', 'Carla Mendes', 'Equipe de Manutenção', interval '-22 hours'),
  ('CLD', 'aviso', 'Uso obrigatório de EPI térmico',
   'Durante a inspeção do queimador é obrigatório o uso de luvas e avental térmicos na Caldeira.',
   'alta', 'aberta', 'Carla Mendes', null, interval '-20 minutes'),
  (null, 'aviso', 'Simulado de evacuação',
   'Simulado geral de evacuação na próxima sexta-feira às 15h. Ponto de encontro: estacionamento.',
   'media', 'aberta', 'Segurança do Trabalho', null, interval '-3 days'),
  ('EXP', 'ocorrencia', 'Gateway da Expedição sem energia',
   'Tomada do gateway de sensores desligada durante limpeza. Sensores sem comunicação.',
   'media', 'aberta', 'Marcos Silva', null, interval '-2 hours -30 minutes'),
  ('PRD', 'ocorrencia', 'Ruído anormal na bomba 2',
   'Operadores relataram ruído metálico na bomba de recirculação da linha 2.',
   'media', 'em_analise', 'Juliana Rocha', 'Ricardo Alves', interval '-1 day -4 hours'),
  ('ARM', 'ocorrencia', 'Corredor B obstruído',
   'Paletes bloqueando parcialmente a rota de fuga do corredor B.',
   'baixa', 'resolvida', 'Marcos Silva', 'Ricardo Alves', interval '-6 days'),
  ('LAB', 'ocorrencia', 'Capela de exaustão com falha',
   'Capela de exaustão 3 apresentou baixa vazão durante análise de solventes.',
   'alta', 'resolvida', 'Juliana Rocha', 'Carla Mendes', interval '-12 days -30 minutes')
) as v(area_code, kind, title, description, priority, status, reporter, responsible, at)
left join public.areas a on a.code = v.area_code;

-- ---------------------------------------------------------------------
-- Estado final das áreas
-- ---------------------------------------------------------------------
select set_config('safecore.seeding', 'off', false);

select public.refresh_area_status(id) from public.areas;

update public.areas
   set status = 'interditada',
       status_note = 'Manutenção preventiva das válvulas (ver mural de avisos).'
 where code = 'TNQ';

-- ---------------------------------------------------------------------
-- Usuários de demonstração: funções e vínculos com as áreas
-- (os usuários são criados pela migration_002_permissoes_crud.sql)
-- ---------------------------------------------------------------------
select public.apply_demo_permissions();

drop table if exists seed_specs;


-- #####################################################################
-- 5. SUPORTE AO PAINEL WEB ADMINISTRATIVO (003_painel_web_admin.sql)
-- #####################################################################

alter table public.profiles add column if not exists active boolean not null default true;
alter table public.profiles add column if not exists deactivated_at timestamptz;

create index if not exists idx_profiles_role on public.profiles (role);

create or replace function public.current_role_name()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid() and active;
$$;

create or replace function public.protect_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null then
    if new.role is distinct from old.role
       and not coalesce(public.current_role_name() = 'admin', false) then
      raise exception 'Somente administradores podem alterar o papel do usuário.';
    end if;

    if new.active is distinct from old.active then
      if not coalesce(public.current_role_name() = 'admin', false) then
        raise exception 'Somente administradores podem ativar ou desativar contas.';
      end if;
      if new.id = auth.uid() then
        raise exception 'Você não pode desativar a sua própria conta.';
      end if;
    end if;

    if new.email is distinct from old.email then
      new.email := old.email;
    end if;
  end if;

  if new.active is distinct from old.active then
    new.deactivated_at := case when new.active then null else now() end;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_protect_role on public.profiles;
create trigger trg_profiles_protect_role
  before update on public.profiles
  for each row execute function public.protect_profile_role();


-- #####################################################################
-- 6. MENSAGENS DO FALE CONOSCO DA WEB (004_fale_conosco.sql)
-- #####################################################################

create table if not exists public.contact_messages (
  id          bigint generated always as identity primary key,
  name        text not null check (char_length(name) between 2 and 120),
  email       text not null check (char_length(email) between 5 and 254),
  company     text check (company is null or char_length(company) <= 120),
  phone       text check (phone is null or char_length(phone) <= 30),
  subject     text not null check (char_length(subject) between 2 and 80),
  message     text not null check (char_length(message) between 10 and 4000),
  ip_hash     text,
  delivered   boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists idx_contact_messages_created on public.contact_messages (created_at desc);
create index if not exists idx_contact_messages_ip on public.contact_messages (ip_hash, created_at desc);

alter table public.contact_messages enable row level security;

drop policy if exists contact_messages_admin_select on public.contact_messages;
create policy contact_messages_admin_select on public.contact_messages
  for select to authenticated using (public.is_admin());

revoke all on public.contact_messages from anon;
revoke insert, update, delete on public.contact_messages from authenticated;


-- #####################################################################
-- 7. INTEGRAÇÃO IoT MQTT — QUIMEX (SETOR CALDEIRA ATIVO, DEMAIS DESCONECTADOS)
-- #####################################################################

-- Desativa o modo de simulação em todos os sensores
update public.sensors
   set is_simulated = false;

-- Todos os setores exceto Caldeira (CLD) ficam desconectados e sem valores simulados
update public.sensors
   set status = 'offline',
       level = 'normal',
       last_value = null,
       last_reading_at = null
 where area_id <> (select id from public.areas where code = 'CLD');

update public.areas
   set status = 'desconectada',
       status_note = 'Setor desconectado do broker MQTT (safecore/quimex/' || lower(code) || ').'
 where code <> 'CLD';

-- Configura os sensores da Caldeira (CLD) com o device_id do ESP32 da Quimex
update public.sensors
   set device_id = 'quimex-caldeira-01',
       status = 'online',
       is_simulated = false
 where area_id = (select id from public.areas where code = 'CLD');

update public.areas
   set status = 'segura',
       status_note = 'Conectado ao broker MQTT (safecore/quimex/caldeira).'
 where code = 'CLD';

-- Conferência final das áreas e sensores
select a.code, a.name, a.status,
       count(s.*) as total_sensores,
       count(s.*) filter (where s.status = 'online') as sensores_online,
       (select count(*) from public.alerts al where al.area_id = a.id and al.status <> 'resolvido') as alertas_ativos
from public.areas a
left join public.sensors s on s.area_id = a.id
group by a.id
order by a.name;


