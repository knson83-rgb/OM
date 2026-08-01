-- 발주 목록에서 주재료/양념 구분을 저장하기 위한 DB 패치입니다.
-- Supabase SQL Editor에서 전체 실행하거나 supabase db query로 실행하세요.

alter table public.draft_orders
add column if not exists ingredient_type text not null default 'main';

alter table public.final_orders
add column if not exists ingredient_type text not null default 'main';

alter table public.final_orders
drop constraint if exists final_orders_order_no_key;

update public.draft_orders
set ingredient_type = 'main'
where ingredient_type is null
   or ingredient_type not in ('main', 'seasoning');

update public.final_orders
set ingredient_type = 'main'
where ingredient_type is null
   or ingredient_type not in ('main', 'seasoning');

alter table public.draft_orders
drop constraint if exists draft_orders_ingredient_type_check;

alter table public.draft_orders
add constraint draft_orders_ingredient_type_check
check (ingredient_type in ('main', 'seasoning'));

alter table public.final_orders
drop constraint if exists final_orders_ingredient_type_check;

alter table public.final_orders
add constraint final_orders_ingredient_type_check
check (ingredient_type in ('main', 'seasoning'));

drop index if exists public.draft_orders_item_name_unit_key;

create unique index if not exists draft_orders_item_name_unit_type_key
on public.draft_orders (item_name, unit, ingredient_type);

grant all on public.draft_orders to anon;
grant all on public.final_orders to anon;

select
  'draft_orders.ingredient_type' as check_item,
  count(*) as row_count
from information_schema.columns
where table_schema = 'public'
  and table_name = 'draft_orders'
  and column_name = 'ingredient_type'
union all
select
  'final_orders.ingredient_type' as check_item,
  count(*) as row_count
from information_schema.columns
where table_schema = 'public'
  and table_name = 'final_orders'
  and column_name = 'ingredient_type';
