-- Smoke test for the shop schema, safe to run against the live project:
--
--     npx supabase db query --linked -f supabase/tests/smoke_test.sql
--
-- Everything runs in one DO block that always ends by raising an exception,
-- so every row it creates (test users, shops, items) is rolled back. Success
-- is the message "SMOKE TEST PASSED"; anything else is a failed check.
do $$
declare
  owner_a uuid := gen_random_uuid();
  owner_b uuid := gen_random_uuid();
  shop_a uuid;
  shop_b uuid;
  n int;
  v text;
  failed boolean;

  -- Pretend to be a signed-in app user, as PostgREST does for each request.
  procedure_sql text := $sql$
    select set_config('role', 'authenticated', true),
           set_config('request.jwt.claims', json_build_object('sub', %L, 'role', 'authenticated')::text, true)
  $sql$;
begin
  insert into auth.users (id, email, aud, role)
  values (owner_a, 'smoke-a@example.test', 'authenticated', 'authenticated'),
         (owner_b, 'smoke-b@example.test', 'authenticated', 'authenticated');

  -- ---- Owner A creates a shop and uploads ----------------------------------
  execute format(procedure_sql, owner_a);

  shop_a := public.ensure_shop('Smoke Shop A');
  if public.ensure_shop('ignored') <> shop_a then
    raise exception 'FAIL: ensure_shop made a second shop for the same owner';
  end if;

  -- One local transaction: a new item, a sale with its line, stock deducted,
  -- and the books' start date.
  perform public.apply_changes($j$[
    {"op": "PUT", "type": "items", "id": "tee",
     "data": {"name": "Basic Tee", "category": "T-Shirt", "unitPrice": 150, "qtyOnHand": 10, "isBargain": 0, "imageKey": "abc.png"}},
    {"op": "PUT", "type": "sales", "id": "sale-1",
     "data": {"dateTime": "2026-09-26T10:00:00.000", "paymentMethod": "cash", "amountTendered": 500}},
    {"op": "PUT", "type": "sale_line_items", "id": "line-1",
     "data": {"saleId": "sale-1", "itemId": "tee", "itemName": "Basic Tee", "unitPrice": 150, "qty": 2, "unitCost": 90}},
    {"op": "PATCH", "type": "items", "id": "tee", "data": {"qtyOnHand": 8}},
    {"op": "PUT", "type": "shop_settings", "id": "booksStartedAt", "data": {"value": "2026-03-01T09:00:00.000"}}
  ]$j$::jsonb);

  select qty_on_hand, image_key into n, v from public.items where id = 'tee';
  if n <> 8 or v <> 'abc.png' then
    raise exception 'FAIL: item should have 8 on hand and image_key abc.png, got % / %', n, v;
  end if;

  select count(*) into n from public.sale_line_items where sale_id = 'sale-1';
  if n <> 1 then raise exception 'FAIL: expected 1 line item, got %', n; end if;

  -- A fresh install stamping "today" must not move when the books started.
  perform public.apply_changes($j$[
    {"op": "PUT", "type": "shop_settings", "id": "booksStartedAt", "data": {"value": "2026-09-26T08:00:00.000"}},
    {"op": "PATCH", "type": "shop_settings", "id": "booksStartedAt", "data": {"value": "2026-09-27T08:00:00.000"}},
    {"op": "DELETE", "type": "shop_settings", "id": "booksStartedAt"}
  ]$j$::jsonb);
  select value into v from public.shop_settings where id = 'booksStartedAt';
  if v is distinct from '2026-03-01T09:00:00.000' then
    raise exception 'FAIL: booksStartedAt changed to %', v;
  end if;

  -- PUT replaces the whole row, so a column the app cleared becomes null.
  perform public.apply_changes($j$[
    {"op": "PUT", "type": "items", "id": "tee",
     "data": {"name": "Basic Tee", "category": "T-Shirt", "unitPrice": 150, "qtyOnHand": 8, "isBargain": 0}}
  ]$j$::jsonb);
  select image_key into v from public.items where id = 'tee';
  if v is not null then raise exception 'FAIL: PUT should clear image_key, got %', v; end if;

  -- Voiding deletes the sale; its lines go with it.
  perform public.apply_changes($j$[
    {"op": "DELETE", "type": "sale_line_items", "id": "line-1"},
    {"op": "DELETE", "type": "sales", "id": "sale-1"}
  ]$j$::jsonb);
  select count(*) into n from public.sales;
  if n <> 0 then raise exception 'FAIL: sale not deleted'; end if;

  -- Bad uploads are refused, not half-applied.
  failed := false;
  begin
    perform public.apply_changes('[{"op": "PUT", "type": "items", "id": "x", "data": {"name": "X", "colour": "red"}}]');
  exception when invalid_parameter_value then failed := true;
  end;
  if not failed then raise exception 'FAIL: unknown column was accepted'; end if;

  failed := false;
  begin
    perform public.apply_changes('[{"op": "PUT", "type": "staff", "id": "x", "data": {"name": "X"}}]');
  exception when invalid_parameter_value then failed := true;
  end;
  if not failed then raise exception 'FAIL: staff (local-only) upload was accepted'; end if;

  -- ---- Owner B: no shop yet, then a separate shop ---------------------------
  execute format(procedure_sql, owner_b);

  failed := false;
  begin
    perform public.apply_changes('[{"op": "PUT", "type": "items", "id": "y", "data": {"name": "Y"}}]');
  exception when insufficient_privilege then failed := true;
  end;
  if not failed then raise exception 'FAIL: a user with no shop could upload'; end if;

  shop_b := public.ensure_shop('Smoke Shop B');
  if shop_b = shop_a then raise exception 'FAIL: owner B joined owner A''s shop'; end if;

  select count(*) into n from public.items;
  if n <> 0 then raise exception 'FAIL: owner B can see % of shop A''s items', n; end if;
  select count(*) into n from public.shops;
  if n <> 1 then raise exception 'FAIL: owner B can see % shops', n; end if;

  -- The same ids in another shop don't collide with shop A's rows.
  perform public.apply_changes($j$[
    {"op": "PUT", "type": "items", "id": "tee",
     "data": {"name": "B's Tee", "category": "T-Shirt", "unitPrice": 99, "qtyOnHand": 1, "isBargain": 0}}
  ]$j$::jsonb);
  select count(*) into n from public.items;
  if n <> 1 then raise exception 'FAIL: owner B should see exactly their 1 item, got %', n; end if;

  raise exception 'SMOKE TEST PASSED (rolled back)';
end;
$$;
