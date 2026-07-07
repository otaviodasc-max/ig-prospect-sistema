-- =====================================================================
-- IGProspect SaaS — Migração: "Venda paga" (comissão paga) nas negociações
-- Execute no Supabase SQL Editor (depois do supabase-deals.sql).
-- =====================================================================
alter table public.deals add column if not exists commission_paid boolean not null default false;
