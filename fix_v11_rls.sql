-- v11 화면에서 사용하는 4개 테이블을 프론트 공개키(anon)로 읽기/쓰기 가능하게 맞춥니다.
-- Supabase SQL Editor에서 전체 실행한 뒤 seed_v11_defaults.sql을 다시 전체 실행하세요.

do $$
declare
  p record;
begin
  for p in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('recipes', 'recipe_ingredients', 'inventory', 'draft_orders', 'final_orders')
  loop
    execute format('drop policy if exists %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end $$;

alter table public.recipes enable row level security;
alter table public.recipe_ingredients enable row level security;
alter table public.inventory enable row level security;
alter table public.draft_orders enable row level security;
alter table public.final_orders enable row level security;

create policy recipes_anon_all
on public.recipes
for all
to anon
using (true)
with check (true);

create policy recipe_ingredients_anon_all
on public.recipe_ingredients
for all
to anon
using (true)
with check (true);

create policy inventory_anon_all
on public.inventory
for all
to anon
using (true)
with check (true);

create policy draft_orders_anon_all
on public.draft_orders
for all
to anon
using (true)
with check (true);

create policy final_orders_anon_all
on public.final_orders
for all
to anon
using (true)
with check (true);

grant usage on schema public to anon;
grant all on public.recipes to anon;
grant all on public.recipe_ingredients to anon;
grant all on public.inventory to anon;
grant all on public.draft_orders to anon;
grant all on public.final_orders to anon;
grant usage, select on all sequences in schema public to anon;

select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('recipes', 'recipe_ingredients', 'inventory', 'draft_orders', 'final_orders')
order by tablename, policyname;
