-- =====================================================================
-- Realtime na tabela leads — sem isso, o painel só percebia uma mudança
-- feita pela extensão (ou por outra pessoa da equipe, em outro aparelho)
-- depois de recarregar a página inteira. O client (app.js subscribeLeads)
-- já assina o canal; falta só publicar a tabela pro Supabase entregar os
-- eventos. Roda uma vez, idempotente (mesmo padrão de supabase-messages.sql).
-- =====================================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='leads'
  ) then
    alter publication supabase_realtime add table public.leads;
  end if;
end $$;
