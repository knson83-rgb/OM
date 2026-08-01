-- 로그인 없이 브라우저 관리 화면에서 데이터 저장소를 직접 사용하기 위한 추가 패치입니다.
-- 현재는 schema_v11_patch.sql에 같은 권한 패치가 포함되어 있습니다.
-- 새로 세팅한다면 schema.sql만 실행하면 되고, 기존 DB라면 schema_v11_patch.sql을 실행하세요.
--
-- 주의: 이 설정은 anon publishable key를 가진 화면에서 데이터를 직접 관리할 수 있게 합니다.
-- 내부 관리 도구로 URL/키 접근 범위를 통제할 수 있을 때만 사용하세요.

drop policy if exists "anon users can manage recipes" on public.recipes;
create policy "anon users can manage recipes"
on public.recipes for all
to anon
using (true)
with check (true);

drop policy if exists "anon users can manage recipe ingredients" on public.recipe_ingredients;
create policy "anon users can manage recipe ingredients"
on public.recipe_ingredients for all
to anon
using (true)
with check (true);

drop policy if exists "anon users can manage inventory" on public.inventory;
create policy "anon users can manage inventory"
on public.inventory for all
to anon
using (true)
with check (true);

drop policy if exists "anon users can manage draft orders" on public.draft_orders;
create policy "anon users can manage draft orders"
on public.draft_orders for all
to anon
using (true)
with check (true);

grant usage on schema public to anon;
grant all on public.recipes to anon;
grant all on public.recipe_ingredients to anon;
grant all on public.inventory to anon;
grant all on public.draft_orders to anon;
