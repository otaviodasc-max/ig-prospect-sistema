-- =====================================================================
-- IGProspect SaaS — Módulos/abas liberáveis por equipe (controle do admin)
-- Execute no Supabase SQL Editor UMA vez (cole tudo > Run).
--
-- Ideia: cada aba/módulo do sistema é uma "feature" com uma chave (a
-- mesma da rota: dashboard, leads, crm, deals, ...). Cada equipe (org)
-- pode ter a feature ligada ou desligada. Quando NÃO há registro em
-- org_features para aquela equipe, vale o padrão da feature (default_on).
--
-- • As abas que já existem entram com default_on = true (ninguém perde
--   nada; todas as equipes continuam vendo tudo).
-- • Toda feature NOVA que o Claude criar daqui pra frente deve nascer
--   com default_on = false — assim ela fica OCULTA para todas as equipes
--   até o admin da plataforma liberar equipe por equipe.
-- • O admin da plataforma (super admin) SEMPRE enxerga todas as abas,
--   independente do que estiver ligado — isso é resolvido no app.js
--   (nav mostra tudo quando platform_role='admin').
--
-- Fluxo pra você: cria-se algo novo → só você vê → você entra no painel
-- Admin, escolhe a equipe e liga a novidade → aí a equipe passa a ver.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Catálogo de features (abas/módulos) e overrides por equipe
-- ---------------------------------------------------------------------
create table if not exists public.features (
  key        text primary key,          -- mesma chave da rota no app (NAV[].k)
  label      text not null,
  default_on boolean not null default false,  -- novidade nasce oculta
  sort       int not null default 100,
  created_at timestamptz not null default now()
);

create table if not exists public.org_features (
  org_id      uuid not null references public.orgs(id) on delete cascade,
  feature_key text not null references public.features(key) on delete cascade,
  enabled     boolean not null,
  updated_at  timestamptz not null default now(),
  primary key (org_id, feature_key)
);

-- Semente: abas atuais, todas ligadas por padrão
insert into public.features(key,label,default_on,sort) values
  ('dashboard','Dashboard',true,10),
  ('goals','Metas',true,20),
  ('leads','Leads',true,30),
  ('crm','CRM',true,40),
  ('deals','Negociações',true,50),
  ('calls','Ligações',true,60),
  ('relatorios','Relatórios',true,70),
  ('team','Equipe',true,80),
  ('settings','Configurações',true,90)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- 2) RLS — todo mundo lê o catálogo; overrides só o admin escreve
-- ---------------------------------------------------------------------
alter table public.features     enable row level security;
alter table public.org_features enable row level security;

drop policy if exists features_select on public.features;
create policy features_select on public.features
  for select using (true);
drop policy if exists features_admin on public.features;
create policy features_admin on public.features
  for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- Cada equipe lê os próprios overrides; admin lê/escreve todos
drop policy if exists org_features_select on public.org_features;
create policy org_features_select on public.org_features
  for select using (org_id = public.my_org() or public.is_platform_admin());
drop policy if exists org_features_admin on public.org_features;
create policy org_features_admin on public.org_features
  for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- ---------------------------------------------------------------------
-- 3) Funções
-- ---------------------------------------------------------------------
-- Abas efetivamente liberadas para a equipe ativa do usuário logado.
-- (override da equipe quando existe; senão o padrão da feature)
create or replace function public.my_features()
returns table(key text)
language sql stable security definer set search_path = public as $$
  select f.key
  from public.features f
  left join public.org_features ofx
    on ofx.feature_key = f.key and ofx.org_id = public.my_org()
  where coalesce(ofx.enabled, f.default_on) = true;
$$;
grant execute on function public.my_features() to authenticated;

-- Estado de cada feature para UMA equipe (para o painel Admin montar os
-- botões liga/desliga). is_override = true quando há registro explícito.
create or replace function public.admin_org_features(p_org_id uuid)
returns table(key text, label text, enabled boolean, is_override boolean, sort int)
language sql stable security definer set search_path = public as $$
  select f.key, f.label,
         coalesce(ofx.enabled, f.default_on) as enabled,
         (ofx.org_id is not null) as is_override,
         f.sort
  from public.features f
  left join public.org_features ofx
    on ofx.feature_key = f.key and ofx.org_id = p_org_id
  where public.is_platform_admin()
  order by f.sort, f.label;
$$;
grant execute on function public.admin_org_features(uuid) to authenticated;

-- Liga/desliga uma feature para uma equipe (só admin da plataforma).
create or replace function public.admin_set_org_feature(p_org_id uuid, p_key text, p_enabled boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Apenas o administrador da plataforma'; end if;
  insert into public.org_features(org_id, feature_key, enabled)
  values (p_org_id, p_key, p_enabled)
  on conflict (org_id, feature_key) do update set enabled = excluded.enabled, updated_at = now();
end; $$;
grant execute on function public.admin_set_org_feature(uuid, text, boolean) to authenticated;

-- Avisa o PostgREST para recarregar o cache de funções/tabelas
notify pgrst, 'reload schema';
