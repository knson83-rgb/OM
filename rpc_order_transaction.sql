-- 주문 트랜잭션 RPC 후보안
--
-- 안전 원칙
-- 1) 이 파일은 기존 행을 읽거나 수정하지 않습니다. 함수 정의만 추가/교체합니다.
-- 2) 실제 적용 전 아래 사전 점검 SELECT를 실행하고 결과를 보관합니다.
-- 3) SQL Editor에서 실행한 뒤, 테스트용 데이터로 RPC를 검증하기 전에는
--    index.html의 기존 저장 로직을 RPC 호출로 교체하지 않습니다.
-- 4) 실패하면 PostgreSQL 트랜잭션 전체가 롤백됩니다.

-- 사전 점검: 읽기 전용. 결과를 적용 전 백업 기록과 비교하세요.
select table_name, count(*) as row_count
from (
  select 'recipes' as table_name from public.recipes
  union all select 'recipe_ingredients' from public.recipe_ingredients
  union all select 'inventory' from public.inventory
  union all select 'draft_orders' from public.draft_orders
  union all select 'final_orders' from public.final_orders
  union all select 'meal_plans' from public.meal_plans
  union all select 'audit_logs' from public.audit_logs
) rows
group by table_name
order by table_name;

select table_name, column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in ('inventory', 'draft_orders', 'final_orders')
order by table_name, ordinal_position;

-- 메뉴 반영: 재고 차감과 임시 발주 upsert를 하나의 트랜잭션으로 처리합니다.
create or replace function public.apply_menu_to_draft_transaction(
  p_items jsonb,
  p_menu_memo text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  inventory_row public.inventory%rowtype;
  v_item_name text;
  v_item_unit text;
  v_ingredient_type text;
  v_use_qty numeric;
  v_order_qty numeric;
  v_order_amount numeric;
  applied_count integer := 0;
  ordered_count integer := 0;
begin
  if jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a JSON array';
  end if;

  for item in select value from jsonb_array_elements(p_items)
  loop
    v_item_name := nullif(trim(item->>'item_name'), '');
    v_item_unit := nullif(trim(item->>'unit'), '');
    v_ingredient_type := coalesce(nullif(item->>'ingredient_type', ''), 'main');
    v_use_qty := coalesce((item->>'use_qty')::numeric, 0);
    v_order_qty := coalesce((item->>'order_qty')::numeric, 0);
    v_order_amount := coalesce((item->>'order_amount')::numeric, 0);

    if v_item_name is null or v_item_unit is null then
      raise exception 'item_name and unit are required';
    end if;
    if v_ingredient_type not in ('main', 'seasoning') then
      raise exception 'invalid ingredient_type: %', v_ingredient_type;
    end if;
    if v_use_qty < 0 or v_order_qty < 0 or v_order_amount < 0 then
      raise exception 'quantities and amount must be non-negative';
    end if;

    if v_use_qty > 0 then
      select * into inventory_row
      from public.inventory
      where lower(regexp_replace(public.inventory.name, '\\s+', '', 'g')) = lower(regexp_replace(v_item_name, '\\s+', '', 'g'))
        and public.inventory.unit = v_item_unit
      for update;

      if not found then
        raise exception 'inventory not found: % (%)', v_item_name, v_item_unit;
      end if;
      if inventory_row.qty < v_use_qty then
        raise exception 'insufficient inventory: % (%)', v_item_name, v_item_unit;
      end if;

      update public.inventory
      set qty = public.inventory.qty - v_use_qty
      where id = inventory_row.id;
      applied_count := applied_count + 1;
    end if;

    if v_order_qty > 0 then
      insert into public.draft_orders
        (item_name, qty, unit, ingredient_type, order_amount, memo)
      values
        (v_item_name, v_order_qty, v_item_unit, v_ingredient_type, v_order_amount, coalesce(p_menu_memo, ''))
      on conflict (item_name, unit, ingredient_type)
      do update set
        qty = public.draft_orders.qty + excluded.qty,
        order_amount = public.draft_orders.order_amount + excluded.order_amount,
        memo = case
          when public.draft_orders.memo = '' then excluded.memo
          when excluded.memo = '' then public.draft_orders.memo
          when position(excluded.memo in public.draft_orders.memo) > 0 then public.draft_orders.memo
          else public.draft_orders.memo || ' | ' || excluded.memo
        end;
      ordered_count := ordered_count + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'inventory_items_updated', applied_count,
    'draft_items_updated', ordered_count
  );
end;
$$;

-- 최종 확정: 현재 임시 발주 전체를 잠근 뒤 최종 발주로 옮기고 임시 발주를 비웁니다.
-- advisory lock으로 동시 확정을 직렬화합니다.
create or replace function public.finalize_draft_order_transaction(
  p_order_no text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  order_no_value text := coalesce(nullif(trim(p_order_no), ''), 'PO-' || to_char(clock_timestamp(), 'YYYYMMDD-HH24MISS') || '-' || substr(md5(random()::text), 1, 6));
  item_count integer;
  total_amount numeric;
begin
  perform pg_advisory_xact_lock(hashtextextended('order-management-finalize', 0));

  select count(*), coalesce(sum(order_amount), 0)
  into item_count, total_amount
  from public.draft_orders;

  if item_count = 0 then
    raise exception 'draft_orders is empty';
  end if;

  insert into public.final_orders
    (order_no, order_date, total_amount, item_name, qty, unit, order_amount,
     status, memo, ordered_at, updated_at, ingredient_type)
  select
    order_no_value,
    current_date,
    total_amount,
    item_name,
    qty,
    unit,
    order_amount,
    'ordered',
    memo,
    now(),
    now(),
    ingredient_type
  from public.draft_orders
  order by id;

  delete from public.draft_orders;

  return jsonb_build_object(
    'order_no', order_no_value,
    'item_count', item_count,
    'total_amount', total_amount
  );
end;
$$;

revoke all on function public.apply_menu_to_draft_transaction(jsonb, text) from public;
revoke all on function public.finalize_draft_order_transaction(text) from public;
grant execute on function public.apply_menu_to_draft_transaction(jsonb, text) to anon;
grant execute on function public.finalize_draft_order_transaction(text) to anon;

-- 적용 후 검증용 읽기 쿼리. 이 쿼리 역시 데이터를 변경하지 않습니다.
select routine_name, routine_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name in ('apply_menu_to_draft_transaction', 'finalize_draft_order_transaction')
order by routine_name;
