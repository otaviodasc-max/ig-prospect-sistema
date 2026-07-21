-- =====================================================================
-- IGProspect SaaS — extensão passa a puxar também o mapeamento de etapas
-- do Agendor (org_pipelines.agendor_map), pra criar o negócio na etapa
-- certa direto do Instagram, em vez de só a pessoa (sem funil/etapa).
-- Execute no Supabase SQL Editor, APÓS supabase-extension-pull-data.sql.
-- =====================================================================

create or replace function public.org_pipeline_by_join_code(p_code text)
returns table(id uuid, name text, stages jsonb, agendor_map jsonb)
language sql stable security definer set search_path = public as $$
  select p.id, p.name, p.stages, p.agendor_map
  from public.orgs o
  join public.org_pipelines p on p.org_id = o.id and p.is_default
  where o.join_code = upper(trim(p_code))
  limit 1;
$$;
grant execute on function public.org_pipeline_by_join_code(text) to anon, authenticated;
