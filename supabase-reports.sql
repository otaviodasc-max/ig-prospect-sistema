-- =====================================================================
-- IGProspect SaaS — Migração: Aba Relatórios
-- Execute no Supabase SQL Editor APÓS supabase-deals.sql e supabase-deal-paid.sql.
--
-- Hoje o pagamento semanal é 100% calculado na hora (sempre olhando a
-- semana corrente) e a comissão paga é só um boolean sem data — por isso
-- some assim que a semana vira ou a comissão é marcada como paga. Esta
-- migração adiciona:
--   1) deals.report    — relatório/anotação livre por venda (aba Relatórios)
--   2) deals.paid_at   — quando a comissão foi marcada como paga (permite
--                         agrupar comissões pagas pela semana em que
--                         entraram no pagamento)
--   3) weekly_payments — snapshot permanente de cada pagamento semanal
--                         confirmado, por membro da equipe
-- =====================================================================

alter table public.deals add column if not exists report text;
alter table public.deals add column if not exists paid_at timestamptz;

create table if not exists public.weekly_payments (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null default public.my_org() references public.orgs(id) on delete cascade,
  member_id      uuid not null references auth.users(id) on delete cascade,
  member_name    text,
  week_start     date not null,
  week_end       date not null,
  prospect_leads int not null default 0,
  prospect_pay   numeric not null default 0,
  commission_pay numeric not null default 0,
  total          numeric not null default 0,
  deal_ids       uuid[] not null default '{}',
  created_by     uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  unique (org_id, member_id, week_start)
);
create index if not exists weekly_payments_org_idx on public.weekly_payments(org_id);

alter table public.weekly_payments enable row level security;
drop policy if exists weekly_payments_org on public.weekly_payments;
create policy weekly_payments_org on public.weekly_payments
  for all using (org_id = public.my_org() and public.is_active())
  with check (org_id = public.my_org());
