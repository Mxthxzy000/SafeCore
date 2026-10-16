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
