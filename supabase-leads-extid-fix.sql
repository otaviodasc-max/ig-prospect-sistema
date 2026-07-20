-- =====================================================================
-- IGProspect SaaS — Corrige erro ao importar leads: "there is no unique
-- or exclusion constraint matching the ON CONFLICT specification"
-- Execute no Supabase SQL Editor. Requer supabase-leads-dedupe.sql já
-- executado antes (é o índice que este arquivo substitui).
--
-- Causa raiz: supabase-leads-dedupe.sql criou um índice ÚNICO PARCIAL —
-- "unique index ... on leads(org_id, ext_id) where ext_id is not null and
-- ext_id <> ''". Um índice parcial só é usado por um "on conflict" que
-- repete a MESMA cláusula where — e é isso que as funções da extensão
-- (extension_add_lead) fazem, em SQL puro. O problema é o botão
-- "Importar" do painel (e a sincronização em massa), que usa
-- supabase-js: `.upsert(rows, { onConflict:'org_id,ext_id' })` — essa
-- chamada NUNCA consegue expressar o "where" do índice parcial, então
-- sempre falha com esse erro ao tentar importar leads sem ext_id (ex.:
-- leads exportados de outra equipe, ou de planilha).
--
-- Correção: trocar pelo índice único "de verdade" (sem where). No
-- Postgres, duas linhas com ext_id NULO nunca conflitam entre si — então
-- leads sem ext_id (manual, planilha, exportação de outra equipe)
-- continuam podendo coexistir à vontade; só ext_id repetido de verdade
-- (mesmo lead da extensão sincronizado 2x) é barrado, como antes.
-- =====================================================================

-- 0) Normaliza ext_id em branco pra NULL — sem isso, linhas antigas com
--    ext_id='' (que o índice parcial deixava passar de propósito) podem
--    impedir a criação do índice não-parcial se houver mais de uma por
--    equipe.
update public.leads set ext_id = null where ext_id = '';

-- 1) Remove o índice parcial antigo.
drop index if exists public.leads_org_extid_uniq;

-- 2) Cria o índice único sem "where" — compatível com upsert(onConflict)
--    do supabase-js e com o "on conflict" das funções da extensão.
create unique index if not exists leads_org_extid_uniq
  on public.leads(org_id, ext_id);

-- 3) Refaz as duas versões de extension_add_lead (9 e 10 argumentos) sem
--    o "where" no on conflict — o índice já não é mais parcial.
create or replace function public.extension_add_lead(
  p_code text, p_ext_id text, p_name text, p_username text default '',
  p_phone text default '', p_niche text default '', p_notes text default '',
  p_status text default 'novo', p_added_at timestamptz default now()
) returns void
language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_pipeline uuid;
begin
  select id into v_org from public.orgs where join_code = upper(trim(p_code));
  if v_org is null then raise exception 'Código de equipe inválido'; end if;

  select id into v_pipeline from public.org_pipelines
    where org_id = v_org and is_default limit 1;

  insert into public.leads(org_id, name, username, phone, niche, notes, status, tipo, pipeline_id, source, ext_id, added_at)
  values (v_org, nullif(p_name,''), nullif(lower(p_username),''), nullif(p_phone,''), nullif(p_niche,''), nullif(p_notes,''),
          coalesce(nullif(p_status,''),'novo'), 'comum', v_pipeline, 'extensao', nullif(p_ext_id,''), coalesce(p_added_at, now()))
  on conflict (org_id, ext_id) do nothing;
end; $$;
grant execute on function public.extension_add_lead(text,text,text,text,text,text,text,text,timestamptz) to anon, authenticated;

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

  select p.id into v_created_by from public.profiles p
    where p.id = p_created_by and p.org_id = v_org and p.status = 'active';

  select id into v_pipeline from public.org_pipelines
    where org_id = v_org and is_default limit 1;

  insert into public.leads(org_id, name, username, phone, niche, notes, status, tipo, pipeline_id, source, ext_id, added_at, created_by)
  values (v_org, nullif(p_name,''), nullif(lower(p_username),''), nullif(p_phone,''), nullif(p_niche,''), nullif(p_notes,''),
          coalesce(nullif(p_status,''),'novo'), 'comum', v_pipeline, 'extensao', nullif(p_ext_id,''), coalesce(p_added_at, now()), v_created_by)
  on conflict (org_id, ext_id) do nothing;
end; $$;
grant execute on function public.extension_add_lead(text,text,text,text,text,text,text,text,timestamptz,uuid) to anon, authenticated;
