-- =====================================================================
-- IGProspect SaaS — Atribuição de prospector nos leads da extensão
-- Execute no Supabase SQL Editor, APÓS supabase-extension-direct-sync.sql.
--
-- Causa raiz: leads gravados direto pela extensão (extension_add_lead)
-- não têm sessão logada, então leads.created_by ficava sempre nulo —
-- e é created_by que o trigger ensure_deal_for_lead usa pra preencher
-- "prospectado por" na negociação (relatórios/comissão por pessoa).
--
-- Correção: a extensão pergunta "quem é você" (escolhe entre os membros
-- reais da equipe, resolvidos pelo mesmo código de convite) na hora de
-- conectar, e passa esse user_id em todo lead que grava — created_by
-- fica certo, e o resto (prospector_name no relatório) já funciona
-- sozinho, é o mesmo trigger que já existia pros leads criados no painel.
-- =====================================================================

create or replace function public.org_members_by_join_code(p_code text)
returns table(user_id uuid, name text, email text)
language sql stable security definer set search_path = public as $$
  select p.id, coalesce(p.name, p.email), p.email
  from public.orgs o
  join public.profiles p on p.org_id = o.id and p.status = 'active'
  where o.join_code = upper(trim(p_code))
  order by coalesce(p.name, p.email);
$$;
grant execute on function public.org_members_by_join_code(text) to anon, authenticated;

create or replace function public.extension_add_lead(
  p_code text, p_ext_id text, p_name text, p_username text default '',
  p_phone text default '', p_niche text default '', p_notes text default '',
  p_status text default 'novo', p_added_at timestamptz default now(),
  p_created_by uuid default null
) returns void
language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_pipeline uuid; v_created_by uuid;
begin
  select id into v_org from public.orgs where join_code = upper(trim(p_code));
  if v_org is null then raise exception 'Código de equipe inválido'; end if;

  -- só aceita created_by se for de fato um membro ATIVO dessa equipe —
  -- não dá pra confiar cegamente num uuid vindo do navegador.
  select p.id into v_created_by from public.profiles p
    where p.id = p_created_by and p.org_id = v_org and p.status = 'active';

  select id into v_pipeline from public.org_pipelines
    where org_id = v_org and is_default limit 1;

  insert into public.leads(org_id, name, username, phone, niche, notes, status, tipo, pipeline_id, source, ext_id, added_at, created_by)
  values (v_org, nullif(p_name,''), nullif(lower(p_username),''), nullif(p_phone,''), nullif(p_niche,''), nullif(p_notes,''),
          coalesce(nullif(p_status,''),'novo'), 'comum', v_pipeline, 'extensao', p_ext_id, coalesce(p_added_at, now()), v_created_by)
  on conflict (org_id, ext_id) where ext_id is not null and ext_id <> '' do nothing;
end; $$;
grant execute on function public.extension_add_lead(text,text,text,text,text,text,text,text,timestamptz,uuid) to anon, authenticated;
