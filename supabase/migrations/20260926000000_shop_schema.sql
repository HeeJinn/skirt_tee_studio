-- Cloud copy of the desktop app's SQLite schema (v7), for PowerSync.
--
-- Conventions:
-- * Every shop table is keyed by (shop_id, id). `id` is the text id the app
--   already generates; shop_id is filled in server-side by apply_changes().
-- * Columns are snake_case here; the PowerSync sync rules alias them back to
--   the app's camelCase names (unit_price -> "unitPrice").
-- * Dates stay ISO-8601 text exactly as the app writes them (local shop time,
--   no zone). The app sorts on these strings, so a timestamp column that
--   round-trips in a different format would break ordering.
-- * Money is double precision, matching the app's REAL columns.

-- ---------------------------------------------------------------------------
-- Shops and who belongs to them
-- ---------------------------------------------------------------------------

create table public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.shop_members (
  shop_id uuid not null references public.shops (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  -- 'owner' for now; 'device' is reserved for a shop-PC login later.
  role text not null check (role in ('owner', 'device')),
  created_at timestamptz not null default now(),
  primary key (shop_id, user_id)
);

create index shop_members_user_id_idx on public.shop_members (user_id);

-- Shops the signed-in user belongs to. Security definer so RLS policies can
-- call it without recursing into shop_members' own policy.
create function public.my_shop_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select shop_id from public.shop_members where user_id = (select auth.uid())
$$;

-- ---------------------------------------------------------------------------
-- Shop data (mirrors the desktop schema)
-- ---------------------------------------------------------------------------

create table public.items (
  shop_id uuid not null references public.shops (id) on delete cascade,
  id text not null,
  name text not null,
  category text not null,
  unit_price double precision not null,
  qty_on_hand integer not null,
  is_bargain integer not null default 0,
  -- File name inside the item-images bucket folder, not a local path.
  image_key text,
  unit_cost double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shop_id, id)
);

create table public.sales (
  shop_id uuid not null references public.shops (id) on delete cascade,
  id text not null,
  date_time text not null,
  payment_method text,
  amount_tendered double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shop_id, id)
);

create table public.sale_line_items (
  shop_id uuid not null,
  id text not null,
  sale_id text not null,
  -- Snapshot, not a foreign key: a line survives its item being deleted.
  item_id text not null,
  item_name text not null,
  unit_price double precision not null,
  qty integer not null,
  unit_cost double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shop_id, id),
  foreign key (shop_id, sale_id) references public.sales (shop_id, id) on delete cascade
);

create index sale_line_items_sale_idx on public.sale_line_items (shop_id, sale_id);

create table public.reservations (
  shop_id uuid not null references public.shops (id) on delete cascade,
  id text not null,
  customer_name text not null,
  contact text not null,
  item_id text not null,
  item_name text not null,
  pickup_date text not null,
  status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shop_id, id)
);

-- Shop-wide settings only (low-stock threshold, when the books started).
-- Per-PC preferences like the theme never leave the PC.
create table public.shop_settings (
  shop_id uuid not null references public.shops (id) on delete cascade,
  id text not null,
  value text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shop_id, id)
);

create table public.money_entries (
  shop_id uuid not null references public.shops (id) on delete cascade,
  id text not null,
  at text not null,
  kind text not null,
  amount double precision not null,
  category text,
  paid_from text not null,
  person text,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shop_id, id)
);

create table public.stock_lots (
  shop_id uuid not null references public.shops (id) on delete cascade,
  id text not null,
  at text not null,
  supplier text not null,
  items_cost double precision not null,
  fees double precision not null default 0,
  paid_from text not null,
  person text,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shop_id, id)
);

create table public.stock_movements (
  shop_id uuid not null references public.shops (id) on delete cascade,
  id text not null,
  at text not null,
  item_id text not null,
  item_name text not null,
  type text not null,
  qty integer not null,
  unit_cost double precision not null,
  reason text,
  lot_id text,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shop_id, id)
);

create table public.audit_log (
  shop_id uuid not null references public.shops (id) on delete cascade,
  id text not null,
  at text not null,
  staff_name text not null,
  action text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shop_id, id)
);

-- ---------------------------------------------------------------------------
-- updated_at bookkeeping
-- ---------------------------------------------------------------------------

create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'items', 'sales', 'sale_line_items', 'reservations', 'shop_settings',
    'money_entries', 'stock_lots', 'stock_movements', 'audit_log'
  ] loop
    execute format(
      'create trigger touch_updated_at before update on public.%I
         for each row execute function public.touch_updated_at()', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security: members see and change only their own shop's rows
-- ---------------------------------------------------------------------------

alter table public.shops enable row level security;
alter table public.shop_members enable row level security;

create policy "members read their shop" on public.shops
  for select to authenticated
  using (id in (select public.my_shop_ids()));

create policy "members read their memberships" on public.shop_members
  for select to authenticated
  using (user_id = (select auth.uid()));

do $$
declare
  t text;
begin
  foreach t in array array[
    'items', 'sales', 'sale_line_items', 'reservations', 'shop_settings',
    'money_entries', 'stock_lots', 'stock_movements', 'audit_log'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "members manage their shop''s rows" on public.%I
         for all to authenticated
         using (shop_id in (select public.my_shop_ids()))
         with check (shop_id in (select public.my_shop_ids()))', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Creating a shop (first cloud connect)
-- ---------------------------------------------------------------------------

-- Returns the caller's shop, creating it (with the caller as owner) the first
-- time. A second owner is added by hand for now — see "Adding another owner"
-- in the root README.md.
create function public.ensure_shop(shop_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  existing uuid;
  created uuid;
begin
  if uid is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;

  select shop_id into existing from public.shop_members where user_id = uid limit 1;
  if existing is not null then
    return existing;
  end if;

  insert into public.shops (name) values (shop_name) returning id into created;
  insert into public.shop_members (shop_id, user_id, role) values (created, uid, 'owner');
  return created;
end;
$$;

revoke execute on function public.ensure_shop(text) from public, anon;
grant execute on function public.ensure_shop(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Upload endpoint for the PowerSync connector
-- ---------------------------------------------------------------------------

-- Applies one local PowerSync transaction in a single database transaction,
-- so the cloud never holds a sale without its line items.
--
-- ops: [{"op": "PUT"|"PATCH"|"DELETE", "type": "<table>", "id": "<id>",
--        "data": {<camelCase column>: value, ...}}, ...]
--
-- Security invoker: RLS still decides what the caller may write.
create function public.apply_changes(ops jsonb)
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
  select s into shop from public.my_shop_ids() s limit 1;
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

revoke execute on function public.apply_changes(jsonb) from public, anon;
grant execute on function public.apply_changes(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- PowerSync replication
-- ---------------------------------------------------------------------------

create publication powersync for table
  public.shop_members,
  public.items, public.sales, public.sale_line_items, public.reservations,
  public.shop_settings, public.money_entries, public.stock_lots,
  public.stock_movements, public.audit_log;

-- ---------------------------------------------------------------------------
-- Item photos: private bucket, one folder per shop (<shop_id>/<image key>)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('item-images', 'item-images', false)
on conflict (id) do nothing;

create policy "members read their shop's item images" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'item-images'
    and (storage.foldername(name))[1] in (select s::text from public.my_shop_ids() s)
  );

create policy "members add their shop's item images" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'item-images'
    and (storage.foldername(name))[1] in (select s::text from public.my_shop_ids() s)
  );

create policy "members replace their shop's item images" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'item-images'
    and (storage.foldername(name))[1] in (select s::text from public.my_shop_ids() s)
  );

create policy "members delete their shop's item images" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'item-images'
    and (storage.foldername(name))[1] in (select s::text from public.my_shop_ids() s)
  );
