-- =====================================================================
-- IGProspect SaaS — Impede leads duplicados vindos da extensão
-- Execute no Supabase SQL Editor.
--
-- Causa raiz: a checagem de "esse lead já existe?" era feita só no
-- navegador (comparando com os leads já carregados na tela) antes de
-- inserir. Se duas sincronizações rodassem quase ao mesmo tempo — duas
-- abas do painel abertas, dois aparelhos, ou só um reload no meio do
-- sync — as duas liam o banco ANTES de qualquer uma inserir, as duas
-- achavam que o lead era novo, e as duas inseriam. Nada no banco
-- impedia duas linhas com o mesmo lead da extensão (mesmo ext_id).
--
-- Correção: um índice ÚNICO por (org_id, ext_id) — o próprio Postgres
-- passa a recusar a segunda inserção, então mesmo sincronizações
-- simultâneas não conseguem mais duplicar. O client já foi trocado de
-- insert() para upsert(...,{ignoreDuplicates:true}) pra usar essa trava.
-- =====================================================================

-- 1) Remove as duplicatas que já existem hoje (mantém a linha mais
--    antiga de cada grupo org_id+ext_id; negociações/ligações ligadas
--    às linhas removidas são preservadas — deals é recriado automático,
--    calls só perde o vínculo mas continua existindo).
delete from public.leads a
using public.leads b
where a.org_id = b.org_id
  and a.ext_id = b.ext_id
  and a.ext_id is not null and a.ext_id <> ''
  and (a.created_at, a.id) > (b.created_at, b.id);

-- 2) Trava daqui pra frente.
create unique index if not exists leads_org_extid_uniq
  on public.leads(org_id, ext_id)
  where ext_id is not null and ext_id <> '';
