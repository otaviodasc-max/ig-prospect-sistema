-- =====================================================================
-- IGProspect SaaS — Migração: Notificações Push (push_subscriptions)
-- Execute no Supabase SQL Editor APÓS o supabase-schema.sql original.
-- Guarda a "inscrição" de push de cada aparelho da equipe.
-- A Edge Function "notify" lê esta tabela (via service_role) e dispara
-- a notificação para todos os aparelhos do espaço, menos quem gerou o evento.
-- =====================================================================

create table if not exists public.push_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null default public.my_org() references public.orgs(id) on delete cascade,
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  endpoint    text not null unique,          -- URL única do navegador/aparelho
  p256dh      text not null,                 -- chave pública do aparelho
  auth        text not null,                 -- segredo de autenticação do aparelho
  user_agent  text,
  created_at  timestamptz not null default now()
);
create index if not exists push_subs_org_idx  on public.push_subscriptions(org_id);
create index if not exists push_subs_user_idx on public.push_subscriptions(user_id);

-- ---------------------------------------------------------------------
-- RLS — cada pessoa gerencia só as suas inscrições.
-- (O envio é feito pela Edge Function com a service_role, que ignora RLS.)
-- ---------------------------------------------------------------------
alter table public.push_subscriptions enable row level security;

drop policy if exists push_subs_select on public.push_subscriptions;
create policy push_subs_select on public.push_subscriptions
  for select using (user_id = auth.uid() or public.is_platform_admin());

drop policy if exists push_subs_insert on public.push_subscriptions;
create policy push_subs_insert on public.push_subscriptions
  for insert with check (user_id = auth.uid() and org_id = public.my_org() and public.is_active());

drop policy if exists push_subs_update on public.push_subscriptions;
create policy push_subs_update on public.push_subscriptions
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists push_subs_delete on public.push_subscriptions;
create policy push_subs_delete on public.push_subscriptions
  for delete using (user_id = auth.uid() or public.is_platform_admin());
