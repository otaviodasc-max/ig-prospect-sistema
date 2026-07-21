-- =====================================================================
-- IGProspect SaaS — extension_update_lead também grava o resultado do
-- envio ao Agendor feito DIRETO pela extensão (ver extension/content.js
-- syncAgendor). Sem isso, o negócio existia de verdade no Agendor mas o
-- painel nunca ficava sabendo — o lead continuava aparecendo com o botão
-- manual "→ Agendor" em vez do ☁ de já sincronizado.
-- Execute no Supabase SQL Editor, APÓS supabase-extension-name-fix.sql.
-- =====================================================================

create or replace function public.extension_update_lead(
  p_code text, p_ext_id text, p_status text default null, p_phone text default null, p_name text default null,
  p_agendor_person_id text default null, p_agendor_deal_id text default null, p_agendor_funnel text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare v_org uuid;
begin
  select id into v_org from public.orgs where join_code = upper(trim(p_code));
  if v_org is null then raise exception 'Código de equipe inválido'; end if;

  update public.leads set
    status            = coalesce(nullif(p_status,''), status),
    phone             = coalesce(nullif(p_phone,''), phone),
    name              = coalesce(nullif(p_name,''), name),
    agendor_person_id = coalesce(nullif(p_agendor_person_id,''), agendor_person_id),
    agendor_deal_id   = coalesce(nullif(p_agendor_deal_id,''), agendor_deal_id),
    agendor_funnel    = coalesce(nullif(p_agendor_funnel,''), agendor_funnel),
    agendor_status    = case when p_agendor_person_id is not null and p_agendor_person_id <> '' then 'ok' else agendor_status end,
    updated_at        = now()
  where org_id = v_org and ext_id = p_ext_id;
end; $$;
grant execute on function public.extension_update_lead(text,text,text,text,text,text,text,text) to anon, authenticated;
