-- =====================================================================
-- IGProspect SaaS — Sigla customizável por funil (org_pipelines)
-- Execute no Supabase SQL Editor APÓS supabase-pipelines.sql.
-- Sem isso a sigla do rail do CRM/Negociações é sempre derivada
-- automaticamente do nome do funil; com a coluna, o dono pode
-- sobrescrever (ex.: "Instagram" → "IG" em vez de "INS").
-- =====================================================================

alter table public.org_pipelines add column if not exists sigla text;
