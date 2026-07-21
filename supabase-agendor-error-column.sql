-- =====================================================================
-- IGProspect SaaS — Guarda o motivo de falha ao enviar um lead ao Agendor
-- Execute no Supabase SQL Editor.
--
-- Causa raiz: leads.agendor_status já registra 'ok'/'failed'/'pending', mas
-- não existia nenhuma coluna com o TEXTO do erro — então quando o envio
-- falhava (token errado, CORS, mapeamento sem etapa, etc.) o sistema não
-- tinha como mostrar pra equipe o que deu errado, só um toast que passa
-- rápido e não fica registrado em lugar nenhum.
-- =====================================================================

alter table public.leads add column if not exists agendor_error text;
