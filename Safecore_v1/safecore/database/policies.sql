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
