alter table public.users
  add column if not exists farm_name text,
  add column if not exists pickup_address text,
  add column if not exists phone text;

alter table public.products
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists unit text not null default 'kg';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'products_price_per_kg_check'
      and conrelid = 'public.products'::regclass
  ) then
    alter table public.products
      add constraint products_price_per_kg_check check (price_per_kg >= 0);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'products_stock_kg_check'
      and conrelid = 'public.products'::regclass
  ) then
    alter table public.products
      add constraint products_stock_kg_check check (stock_kg >= 0);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'products_discount_check'
      and conrelid = 'public.products'::regclass
  ) then
    alter table public.products
      add constraint products_discount_check check (
        discount_price is null
        or (discount_price >= 0 and discount_price < price_per_kg)
      );
  end if;
end;
$$;

alter table public.orders
  add column if not exists buyer_name text;

drop policy if exists "Authenticated users can browse products" on public.products;
create policy "Buyers can browse active products"
  on public.products for select to authenticated
  using (
    is_active = true
    or seller_id = auth.uid()
  );

drop policy if exists "Sellers can insert their products" on public.products;
create policy "Sellers can insert their products"
  on public.products for insert to authenticated
  with check (
    seller_id = auth.uid()
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'seller'
    )
  );

drop policy if exists "Sellers can update their products" on public.products;
create policy "Sellers can update their products"
  on public.products for update to authenticated
  using (seller_id = auth.uid())
  with check (seller_id = auth.uid());

drop policy if exists "Sellers can delete their products" on public.products;
create policy "Sellers can delete their products"
  on public.products for delete to authenticated
  using (seller_id = auth.uid());

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

drop policy if exists "Public can read product images" on storage.objects;
create policy "Public can read product images"
  on storage.objects for select
  using (bucket_id = 'product-images');

drop policy if exists "Sellers can upload product images" on storage.objects;
create policy "Sellers can upload product images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Sellers can update product images" on storage.objects;
create policy "Sellers can update product images"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Sellers can delete product images" on storage.objects;
create policy "Sellers can delete product images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create or replace function public.update_order_status(
  p_order_id uuid,
  p_new_status text,
  p_eta timestamptz default null,
  p_rider_name text default null,
  p_rider_phone text default null
)
returns public.orders
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders%rowtype;
  v_caller uuid := auth.uid();
  v_item record;
begin
  if v_caller is null then
    raise exception 'Sign in as a Seller.';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id
  for update;
  if not found then raise exception 'Order not found.'; end if;
  if v_order.seller_id <> v_caller then
    raise exception 'You can only update orders sold by you.';
  end if;
  if v_order.status in ('completed', 'cancelled') then
    raise exception 'This order is already final and cannot be changed.';
  end if;

  if p_new_status = 'cancelled' then
    if v_order.status not in ('pending', 'confirmed', 'preparing') then
      raise exception 'This order can no longer be cancelled.';
    end if;
    for v_item in
      select product_id, sum(quantity_kg) quantity_kg
      from public.order_items
      where order_id = v_order.id
      group by product_id
    loop
      update public.products
      set stock_kg = stock_kg + v_item.quantity_kg,
          updated_at = now()
      where id = v_item.product_id;
    end loop;
  elsif v_order.fulfillment_type = 'delivery' then
    if p_new_status = 'confirmed' and v_order.status <> 'pending'
      then raise exception 'Invalid status jump for this delivery order.'; end if;
    if p_new_status = 'preparing' and v_order.status <> 'confirmed'
      then raise exception 'Confirm this delivery before preparing it.'; end if;
    if p_new_status = 'out_for_delivery' then
      if v_order.status <> 'preparing'
        then raise exception 'Preparing must be completed before out for delivery.'; end if;
      if coalesce(trim(p_rider_name), '') = ''
        then raise exception 'Rider name is required.'; end if;
      if coalesce(p_rider_phone, '') !~ '^(09[0-9]{9}|\+639[0-9]{9})$'
        then raise exception 'Enter a valid rider phone number.'; end if;
    elsif p_new_status = 'completed' then
      if v_order.status <> 'out_for_delivery'
        then raise exception 'Out for delivery must come before completion.'; end if;
    elsif p_new_status not in ('confirmed', 'preparing')
      then raise exception 'Invalid status for this delivery order.'; end if;
  else
    if p_new_status = 'confirmed' and v_order.status <> 'pending'
      then raise exception 'Invalid status jump for this pickup order.'; end if;
    if p_new_status = 'preparing' and v_order.status <> 'confirmed'
      then raise exception 'Confirm this pickup before preparing it.'; end if;
    if p_new_status = 'ready_for_pickup' and v_order.status <> 'preparing'
      then raise exception 'Preparing must be completed before ready for pickup.'; end if;
    if p_new_status = 'completed' and v_order.status <> 'ready_for_pickup'
      then raise exception 'Ready for pickup must come before completion.'; end if;
    if p_new_status not in ('confirmed', 'preparing', 'ready_for_pickup', 'completed')
      then raise exception 'Invalid status for this pickup order.'; end if;
  end if;

  update public.orders
  set status = p_new_status,
      eta = case
        when p_eta is not null then p_eta
        else eta
      end,
      rider_name = case
        when p_rider_name is not null then trim(p_rider_name)
        else rider_name
      end,
      rider_phone = case
        when p_rider_phone is not null then trim(p_rider_phone)
        else rider_phone
      end
  where id = v_order.id
  returning * into v_order;
  return v_order;
end;
$$;

revoke all on function public.update_order_status(uuid, text, timestamptz, text, text) from public;
grant execute on function public.update_order_status(uuid, text, timestamptz, text, text) to authenticated;

create or replace function public.get_seller_sales(p_from_date timestamptz, p_to_date timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_seller uuid := auth.uid();
  v_total numeric;
  v_count bigint;
  v_units numeric;
  v_per_day jsonb;
  v_top jsonb;
begin
  select coalesce(sum(subtotal), 0), count(*)
  into v_total, v_count
  from public.orders
  where seller_id = v_seller
    and status = 'completed'
    and created_at >= p_from_date
    and created_at < p_to_date;

  select coalesce(sum(quantity_kg), 0)
  into v_units
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  where o.seller_id = v_seller
    and o.status = 'completed'
    and o.created_at >= p_from_date
    and o.created_at < p_to_date;

  select coalesce(jsonb_agg(row_to_json(d) order by d.day), '[]'::jsonb)
  into v_per_day
  from (
    select date(created_at) as day, coalesce(sum(subtotal), 0) as revenue
    from public.orders
    where seller_id = v_seller
      and status = 'completed'
      and created_at >= p_from_date
      and created_at < p_to_date
    group by date(created_at)
  ) d;

  select coalesce(jsonb_agg(row_to_json(p) order by p.revenue desc), '[]'::jsonb)
  into v_top
  from (
    select oi.product_name as name,
           sum(oi.quantity_kg) as kg,
           sum(oi.line_total) as revenue
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where o.seller_id = v_seller
      and o.status = 'completed'
      and o.created_at >= p_from_date
      and o.created_at < p_to_date
    group by oi.product_name
  ) p;

  return jsonb_build_object(
    'total_revenue', v_total,
    'completed_orders', v_count,
    'units_kg', v_units,
    'revenue_per_day', v_per_day,
    'top_products', v_top
  );
end;
$$;

revoke all on function public.get_seller_sales(timestamptz, timestamptz) from public;
grant execute on function public.get_seller_sales(timestamptz, timestamptz) to authenticated;
