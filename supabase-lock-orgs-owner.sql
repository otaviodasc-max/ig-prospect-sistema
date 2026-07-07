-- =====================================================================
-- IGProspect SaaS — Trava a edição da organização (token do Agendor,
-- module_id, join_code, settings) para o DONO apenas.
--
-- ATENÇÃO: só rode este arquivo depois de confirmar que o client novo
-- (que já esconde token/mapeamento do Agendor e mostra o card de
-- Personalização apenas para o dono) está publicado em produção.
-- Rodar antes disso quebra o salvamento de Agendor para membros que
-- ainda estejam com o client antigo em cache.
-- =====================================================================

drop policy if exists orgs_update on public.orgs;
create policy orgs_update on public.orgs
  for update using ((id = public.my_org() and public.is_org_owner()) or public.is_platform_admin());
