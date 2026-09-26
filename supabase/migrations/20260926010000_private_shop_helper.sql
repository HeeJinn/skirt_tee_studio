-- Keeps the RLS helper out of the public API: my_shop_ids() is only for
-- policies and apply_changes(), so it moves to a schema PostgREST doesn't
-- expose (the Supabase security advisor flagged it as callable via
-- /rest/v1/rpc). Policies reference the function itself, not its name, so
-- they keep working after the move; apply_changes() names it in its body and
-- is redefined below.

create schema if not exists private;
grant usage on schema private to authenticated;

alter function public.my_shop_ids() set schema private;
revoke execute on function private.my_shop_ids() from public, anon;
grant execute on function private.my_shop_ids() to authenticated;

create or replace function public.apply_changes(ops jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  allowed constant text[] := array[
    'items', 'sales', 'sale_line_items', 'reservations', 'shop_settings',
    'money_entries', 'stock_lots', 'stock_movements', 'audit_log'
  ];
  -- Server-managed columns a client never sets.
  reserved constant text[] := array['shop_id', 'id', 'created_at', 'updated_at'];
  shop uuid;
  op jsonb;
  kind text;
  tbl text;
  row_id text;
  data jsonb;
  cols text[];
  table_cols text[];
  unknown text[];
  col_list text;
  set_list text;
begin
  select s into shop from private.my_shop_ids() s limit 1;
  if shop is null then
    raise exception 'This account is not a member of any shop.' using errcode = '42501';
  end if;

  for op in select * from jsonb_array_elements(ops) loop
    kind := op ->> 'op';
    tbl := op ->> 'type';
    row_id := op ->> 'id';

    if not (tbl = any (allowed)) then
      raise exception 'Unknown table "%".', tbl using errcode = '22023';
    end if;
    if row_id is null then
      raise exception 'Missing id for % on %.', kind, tbl using errcode = '22023';
    end if;

    -- The one first-write-wins value: a fresh install must never move the
    -- date the books started.
    if tbl = 'shop_settings' and row_id = 'booksStartedAt' and kind <> 'PUT' then
      continue;
    end if;

    if kind = 'DELETE' then
      execute format('delete from public.%I where shop_id = $1 and id = $2', tbl)
        using shop, row_id;
      continue;
    end if;

    -- camelCase -> snake_case keys, then add the key columns.
    select coalesce(jsonb_object_agg(lower(regexp_replace(key, '([A-Z])', '_\1', 'g')), value), '{}'::jsonb)
      into data
      from jsonb_each(coalesce(op -> 'data', '{}'::jsonb));

    select array_agg(k) into cols
      from jsonb_object_keys(data) k
      where not (k = any (reserved));
    cols := coalesce(cols, array[]::text[]);

    select array_agg(a.attname::text) into table_cols
      from pg_attribute a
      where a.attrelid = format('public.%I', tbl)::regclass
        and a.attnum > 0 and not a.attisdropped
        and not (a.attname::text = any (reserved));

    select array_agg(c) into unknown from unnest(cols) c where not (c = any (table_cols));
    if unknown is not null then
      raise exception 'Unknown column(s) % on %.', unknown, tbl using errcode = '22023';
    end if;

    data := data || jsonb_build_object('shop_id', shop, 'id', row_id);

    if kind = 'PUT' then
      -- PUT replaces the whole row: columns the client left out become null
      -- (or fail NOT NULL), matching the local row exactly.
      select string_agg(format('%I', c), ', ') into col_list from unnest(table_cols) c;
      select string_agg(format('%1$I = excluded.%1$I', c), ', ') into set_list from unnest(table_cols) c;

      if tbl = 'shop_settings' and row_id = 'booksStartedAt' then
        execute format(
          'insert into public.%1$I (shop_id, id, %2$s)
             select shop_id, id, %2$s from jsonb_populate_record(null::public.%1$I, $1)
           on conflict (shop_id, id) do nothing', tbl, col_list)
          using data;
      else
        execute format(
          'insert into public.%1$I (shop_id, id, %2$s)
             select shop_id, id, %2$s from jsonb_populate_record(null::public.%1$I, $1)
           on conflict (shop_id, id) do update set %3$s', tbl, col_list, set_list)
          using data;
      end if;

    elsif kind = 'PATCH' then
      if array_length(cols, 1) is null then
        continue;
      end if;
      select string_agg(format('%I', c), ', ') into col_list from unnest(cols) c;
      execute format(
        'update public.%1$I t set (%2$s) = (select %2$s from jsonb_populate_record(null::public.%1$I, $1))
           where t.shop_id = $2 and t.id = $3', tbl, col_list)
        using data, shop, row_id;

    else
      raise exception 'Unknown op "%".', kind using errcode = '22023';
    end if;
  end loop;
end;
$$;
