-- RPC 비파괴 통합 테스트
--
-- 반드시 rpc_order_transaction.sql을 먼저 성공 실행한 뒤 별도로 실행하세요.
-- 이 파일은 테스트 행을 만든 뒤 마지막 ROLLBACK으로 전부 취소합니다.
-- SQL Editor가 전체 문장을 하나의 트랜잭션으로 실행하더라도
-- RPC 함수 정의가 함께 롤백되지 않도록 생성 SQL과 분리되어 있습니다.

begin;
do $$
declare
  test_name constant text := '__rpc_transaction_test__';
  apply_result jsonb;
  finalize_result jsonb;
  remaining_qty numeric;
  test_draft_count integer;
  test_final_count integer;
begin
  insert into public.inventory (name, qty, unit, memo)
  values (test_name, 10, 'g', 'rollback test');

  select public.apply_menu_to_draft_transaction(
    jsonb_build_array(jsonb_build_object(
      'item_name', test_name,
      'unit', 'g',
      'ingredient_type', 'main',
      'use_qty', 2,
      'order_qty', 3,
      'order_amount', 100
    )),
    'rollback test menu'
  ) into apply_result;

  select qty into remaining_qty
  from public.inventory
  where name = test_name and unit = 'g';
  if remaining_qty <> 8 then
    raise exception 'RPC test failed: inventory was not reduced to 8';
  end if;

  select count(*) into test_draft_count
  from public.draft_orders
  where item_name = test_name;
  if test_draft_count <> 1 then
    raise exception 'RPC test failed: expected one draft order';
  end if;

  select public.finalize_draft_order_transaction('PO-RPC-ROLLBACK-TEST') into finalize_result;

  select count(*) into test_final_count
  from public.final_orders
  where order_no = 'PO-RPC-ROLLBACK-TEST' and item_name = test_name;
  if test_final_count <> 1 then
    raise exception 'RPC test failed: expected one final order';
  end if;
end;
$$;
rollback;
