-- =====================================================================
-- SafeCore — Migração 003: suporte ao painel web administrativo (SafeCore Web)
--
-- Execute DEPOIS da migration_002_permissoes_crud.sql.
-- Cole este arquivo inteiro no SQL Editor e clique em Run.
-- Preserva todos os dados existentes. Pode ser executado mais de uma vez.
--
-- O que muda:
--   * profiles.active / profiles.deactivated_at: desativação de contas sem
--     apagar o histórico (alertas resolvidos, ações, ocorrências, auditoria).
--   * current_role_name() passa a retornar NULL para contas desativadas.
--     Assim um token ainda válido de uma conta desativada perde imediatamente
--     todos os privilégios de cargo (admin, supervisor, técnico) nas políticas
--     RLS e nas funções. Isso só torna as regras mais restritivas.
--   * protect_profile_role(): além do cargo, somente administradores alteram
--     o status ativo/inativo, e ninguém desativa a própria conta.
--   * A Edge Function admin-users registra em audit_logs (entidade
--     'funcionario') a criação, desativação, reativação e exclusão de contas.
--
-- O que NÃO muda:
--   * Nenhuma política RLS é enfraquecida.
--   * is_supervisor(), area_access(), set_area_member() e delete_area()
--     continuam permitindo supervisores (regras do aplicativo mobile).
--     O painel web aplica o próprio controle: só entra quem tem cargo 'admin'.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Estrutura
-- ---------------------------------------------------------------------
alter table public.profiles add column if not exists active boolean not null default true;
alter table public.profiles add column if not exists deactivated_at timestamptz;

create index if not exists idx_profiles_role on public.profiles (role);

-- ---------------------------------------------------------------------
-- 2. Cargo do usuário logado (contas desativadas não têm cargo efetivo)
-- ---------------------------------------------------------------------
create or replace function public.current_role_name()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid() and active;
$$;

-- ---------------------------------------------------------------------
-- 3. Proteção do perfil: cargo, status e e-mail
-- ---------------------------------------------------------------------
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
      new.email := old.email; -- e-mail só muda pelo fluxo do Supabase Auth
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

-- ---------------------------------------------------------------------
-- 4. Conferência
-- ---------------------------------------------------------------------
select email, role, active from public.profiles order by role, email;
