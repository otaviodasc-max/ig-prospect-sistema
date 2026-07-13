-- =====================================================================
-- IGProspect SaaS — Migração: Gestão de equipe pelo dono
-- Execute no Supabase SQL Editor APÓS supabase-org-members.sql.
--
-- Adiciona duas ações que só o dono da equipe ativa pode executar:
--   1) remove_team_member — remove outro usuário da equipe (ele volta pro
--      onboarding se essa era a equipe ativa dele; os dados que ele já
--      cadastrou continuam no espaço, só o acesso dele é removido).
--   2) promote_team_member — promove um membro comum a dono também,
--      permitindo múltiplos donos na mesma equipe.
--
-- Ambas são SECURITY DEFINER e verificam internamente se quem chamou é
-- dono da equipe ativa — não dependem de policy de UPDATE/DELETE direta
-- em profiles/org_members (que continuam sem essas policies para o client).
-- =====================================================================

create or replace function public.remove_team_member(p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_caller_role text;
begin
  select org_id into v_org from public.profiles where id = auth.uid();
  if v_org is null then raise exception 'Você não está em nenhuma equipe'; end if;

  select role into v_caller_role from public.org_members where org_id = v_org and user_id = auth.uid();
  if v_caller_role is distinct from 'owner' then raise exception 'Só o dono pode remover membros da equipe'; end if;
  if p_user_id = auth.uid() then raise exception 'Você não pode remover a si mesmo'; end if;

  delete from public.org_members where org_id = v_org and user_id = p_user_id;

  -- Se essa era a equipe ativa da pessoa removida, tira o ponteiro dela
  -- (ela volta pra tela de onboarding no próximo login/refresh).
  perform set_config('app.allow_org_change', '1', true);
  update public.profiles set org_id = null, org_role = 'member'
    where id = p_user_id and org_id = v_org;
end; $$;
grant execute on function public.remove_team_member(uuid) to authenticated;

create or replace function public.promote_team_member(p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_caller_role text;
begin
  select org_id into v_org from public.profiles where id = auth.uid();
  if v_org is null then raise exception 'Você não está em nenhuma equipe'; end if;

  select role into v_caller_role from public.org_members where org_id = v_org and user_id = auth.uid();
  if v_caller_role is distinct from 'owner' then raise exception 'Só o dono pode promover outros donos'; end if;

  update public.org_members set role = 'owner' where org_id = v_org and user_id = p_user_id;

  perform set_config('app.allow_org_change', '1', true);
  update public.profiles set org_role = 'owner' where id = p_user_id and org_id = v_org;
end; $$;
grant execute on function public.promote_team_member(uuid) to authenticated;
