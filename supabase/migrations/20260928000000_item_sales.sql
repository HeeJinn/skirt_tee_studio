-- Sales on items: the "Bargain" tag becomes "On sale" with a real discount,
-- either a percent off the regular price or a set sale price.
--
-- is_bargain keeps its name and now means "on sale"; an item tagged before
-- this has neither discount and sells at unit_price, as it always did.
--
-- Apply this (and redeploy supabase/powersync/sync-rules.yaml) before the
-- shop computer runs the version that sends these columns: upload_changes
-- refuses columns the table doesn't have.

alter table public.items
  add column sale_percent double precision
    check (sale_percent is null or (sale_percent > 0 and sale_percent < 100)),
  add column sale_price double precision
    check (sale_price is null or sale_price >= 0);
