-- =====================================================================
-- SafeCore — Migração 004: mensagens do "Fale conosco" (landing page)
--
-- Execute DEPOIS da 003_painel_web_admin.sql. Pode ser executado mais de uma vez.
--
-- As mensagens são gravadas SOMENTE pela Edge Function "contact" (service_role),
-- que também envia o e-mail para suporte@bitlayerdev.com. Visitantes não têm
-- acesso direto à tabela; apenas administradores podem consultá-la.
-- =====================================================================

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

-- Sem políticas de insert/update/delete: somente a service_role (Edge Function) grava.
revoke all on public.contact_messages from anon;
revoke insert, update, delete on public.contact_messages from authenticated;
