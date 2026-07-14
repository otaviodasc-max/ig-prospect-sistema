-- =====================================================================
-- IGProspect SaaS — Aprovação de cadastro + exclusão de espaços (admin)
-- Execute no Supabase SQL Editor UMA vez (cole tudo > Run).
--
-- A partir daqui, TODO cadastro novo nasce com status = 'pending' e fica
-- retido: não acessa a criação de espaço nem os dados de nenhuma org até
-- que o admin da plataforma (paraclaude81@gmail.com) o aprove pelo
-- painel Admin (botão "Aprovar", que troca o status para 'active').
--
-- O is_active() já barra leads/calls no RLS (seção 6 do schema), então um
-- usuário 'pending' também fica bloqueado dos dados no nível do banco. Mas
-- as RPCs create_org/join_org NÃO checavam is_active() — um pending podia
-- criar/entrar num espaço antes de ser aprovado. Por isso este arquivo
-- também redefine essas duas funções adicionando a checagem de is_active()
-- (mesmo corpo de supabase-schema.sql, só com a trava no topo).
--
-- Novidade no painel Admin: admin_delete_org() apaga um espaço inteiro
-- (as FKs on delete cascade levam junto leads/calls/deals/messages/
-- org_members). Só o admin da plataforma pode chamar.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Novo status 'pending' na tabela de perfis
-- ---------------------------------------------------------------------
alter table public.profiles drop constraint if exists profiles_status_check;
alter table public.profiles add constraint profiles_status_check
  check (status in ('active','blocked','pending'));

-- Cadastros novos entram como 'pending' (trava padrão da coluna)
alter table public.profiles alter column status set default 'pending';

-- ---------------------------------------------------------------------
-- 2) Cadastro novo nasce 'pending' (trigger de criação de perfil)
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name, status)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)), 'pending')
  on conflict (id) do nothing;
  return new;
end; $$;

-- ---------------------------------------------------------------------
-- 3) create_org / join_org agora exigem usuário ativo (aprovado)
--    Mesmo corpo do supabase-schema.sql, só com is_active() no topo.
-- ---------------------------------------------------------------------
create or replace function public.create_org(p_name text, p_module_id text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_code text;
begin
  if not public.is_active() then raise exception 'Cadastro em análise: aguarde a aprovação do administrador'; end if;
  v_code := upper(substring(md5(random()::text) from 1 for 6));
  insert into public.orgs(name, join_code, module_id)
    values (coalesce(nullif(trim(p_name),''),'Meu espaço'), v_code, coalesce(p_module_id,'consorcio'))
    returning id into v_org;
  insert into public.org_members(org_id, user_id, role) values (v_org, auth.uid(), 'owner');
  perform set_config('app.allow_org_change','1', true);
  update public.profiles set org_id = v_org, org_role = 'owner' where id = auth.uid();
  return v_org;
end; $$;

create or replace function public.join_org(p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_role text;
begin
  if not public.is_active() then raise exception 'Cadastro em análise: aguarde a aprovação do administrador'; end if;
  select id into v_org from public.orgs where join_code = upper(trim(p_code));
  if v_org is null then raise exception 'Código inválido'; end if;
  insert into public.org_members(org_id, user_id, role) values (v_org, auth.uid(), 'member')
    on conflict (org_id, user_id) do nothing;
  select role into v_role from public.org_members where org_id=v_org and user_id=auth.uid();
  perform set_config('app.allow_org_change','1', true);
  update public.profiles set org_id = v_org, org_role = v_role where id = auth.uid();
  return v_org;
end; $$;

-- ---------------------------------------------------------------------
-- 4) Excluir um espaço inteiro (só admin da plataforma).
--    As FKs on delete cascade removem leads/calls/deals/messages/
--    org_members ligados a este org.
-- ---------------------------------------------------------------------
create or replace function public.admin_delete_org(p_org_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Apenas o administrador da plataforma'; end if;
  delete from public.orgs where id = p_org_id;
end; $$;
grant execute on function public.admin_delete_org(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 5) Promove o dono da plataforma a admin (aplicado ao rodar este arquivo)
-- ---------------------------------------------------------------------
update public.profiles set platform_role = 'admin' where email = 'paraclaude81@gmail.com';
