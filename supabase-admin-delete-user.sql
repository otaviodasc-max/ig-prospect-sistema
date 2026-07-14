-- =====================================================================
-- IGProspect SaaS — Excluir usuário (só admin da plataforma)
-- Execute no Supabase SQL Editor UMA vez (cole tudo > Run).
--
-- Apaga a conta de Auth do usuário; as FKs on delete cascade removem
-- junto o profile e a associação em org_members. Leads/ligações/negócios
-- que ele criou ficam (created_by vira null — on delete set null), então
-- o histórico da equipe não é perdido.
--
-- Travas de segurança: não dá pra excluir a si mesmo nem outro admin da
-- plataforma (evita você se trancar pra fora ou apagar um co-admin).
-- =====================================================================
create or replace function public.admin_delete_user(p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Apenas o administrador da plataforma'; end if;
  if p_user_id = auth.uid() then raise exception 'Você não pode excluir a si mesmo'; end if;
  if exists (select 1 from public.profiles where id = p_user_id and platform_role = 'admin') then
    raise exception 'Não é possível excluir outro administrador';
  end if;
  delete from auth.users where id = p_user_id;
end; $$;
grant execute on function public.admin_delete_user(uuid) to authenticated;

notify pgrst, 'reload schema';
