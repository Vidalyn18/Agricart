-- AgriCart schema and policies. Safe to re-run from the Supabase SQL Editor.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('buyer', 'seller')),
  full_name text not null default '',
  email text,
  phone text,
  address text,
  farm_name text,
  pickup_address text,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles (id) on delete restrict,
  seller_name text not null,
  name text not null,
  category text not null check (
    category in ('vegetables', 'fruits', 'rice_grains', 'meat_seafood')
  ),
  subcategory text not null,
  price_per_kg numeric(10, 2) not null check (price_per_kg > 0),
  rating numeric(2, 1) not null default 0 check (rating between 0 and 5),
  stock_kg numeric(10, 2) not null default 0 check (stock_kg >= 0),
  image_url text,
  description text not null default '',
  harvest_date date not null default current_date,
  is_discounted boolean not null default false,
  discount_price numeric(10, 2),
  is_active boolean not null default true,
  unit text not null default 'kg',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_discount_price_check check (
    discount_price is null
    or (discount_price >= 0 and discount_price < price_per_kg)
  ),
  constraint products_seller_name_unique unique (seller_id, name)
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  checkout_id uuid not null,
  buyer_id uuid not null references public.profiles (id) on delete restrict,
  seller_id uuid not null references public.profiles (id) on delete restrict,
  seller_name text not null,
  buyer_name text,
  fulfillment_type text not null
    check (fulfillment_type in ('delivery', 'pickup')),
  delivery_address text,
  contact_name text,
  contact_phone text,
  payment_method text not null
    check (payment_method in ('cod', 'gcash', 'card')),
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  delivery_fee numeric(12, 2) not null check (delivery_fee >= 0),
  total numeric(12, 2) not null check (total >= 0),
  status text not null default 'pending'
    check (status in (
      'pending', 'confirmed', 'preparing', 'out_for_delivery',
      'ready_for_pickup', 'completed', 'cancelled'
    )),
  eta timestamptz,
  rider_name text,
  rider_phone text,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete restrict,
  product_name text not null,
  image_path text,
  price_per_kg numeric(10, 2) not null check (price_per_kg > 0),
  quantity_kg numeric(10, 2) not null check (quantity_kg > 0),
  line_total numeric(12, 2) not null check (line_total >= 0)
);

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  status text not null check (status in (
    'pending', 'confirmed', 'preparing', 'out_for_delivery',
    'ready_for_pickup', 'completed', 'cancelled'
  )),
  created_at timestamptz not null default now()
);

create index if not exists products_category_active_idx
  on public.products (category, is_active);
create index if not exists products_seller_active_idx
  on public.products (seller_id, is_active);
create index if not exists orders_buyer_created_idx
  on public.orders (buyer_id, created_at desc);
create index if not exists orders_seller_created_idx
  on public.orders (seller_id, created_at desc);
create index if not exists orders_checkout_idx
  on public.orders (checkout_id);
create index if not exists order_items_order_idx
  on public.order_items (order_id);
create index if not exists order_items_product_idx
  on public.order_items (product_id);
create index if not exists order_status_history_order_created_idx
  on public.order_status_history (order_id, created_at);

-- New Auth users get their profile from sign-up metadata.
create or replace function public.create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role text := new.raw_user_meta_data ->> 'role';
begin
  if v_role is null or v_role not in ('buyer', 'seller') then
    v_role := 'buyer';
  end if;

  insert into public.profiles (id, role, full_name, email, phone)
  values (
    new.id,
    v_role,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email,
    new.phone
  )
  on conflict (id) do update
  set role = excluded.role,
      full_name = excluded.full_name,
      email = excluded.email,
      phone = excluded.phone;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.create_profile_for_auth_user();

-- User-editable profile fields cannot be used to change account role.
create or replace function public.prevent_profile_role_change()
returns trigger
language plpgsql
as $$
begin
  if new.role is distinct from old.role and auth.role() <> 'service_role' then
    raise exception 'Profile role cannot be changed by the account owner.';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_role_change on public.profiles;
create trigger profiles_prevent_role_change
before update on public.profiles
for each row execute function public.prevent_profile_role_change();

-- Product seller fields are derived from the signed-in seller profile.
create or replace function public.set_product_seller_fields()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile public.profiles%rowtype;
begin
  if tg_op = 'UPDATE' and new.seller_id <> old.seller_id then
    raise exception 'A product cannot be transferred to another seller.';
  end if;
  if tg_op = 'INSERT' and auth.uid() is not null then
    new.seller_id := auth.uid();
  end if;
  select * into v_profile from public.profiles where id = new.seller_id;
  if not found or v_profile.role <> 'seller' then
    raise exception 'Products must belong to a Seller account.';
  end if;
  new.seller_name := coalesce(
    nullif(trim(v_profile.farm_name), ''),
    nullif(trim(v_profile.full_name), ''),
    'Local Seller'
  );
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists products_set_seller_fields on public.products;
create trigger products_set_seller_fields
before insert or update on public.products
for each row execute function public.set_product_seller_fields();

create or replace function public.prevent_deleting_product_with_active_orders()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.is_active and not new.is_active and exists (
    select 1
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.product_id = old.id
      and o.status not in ('completed', 'cancelled')
  ) then
    raise exception 'This product has an order that is not completed or cancelled.';
  end if;
  return new;
end;
$$;

drop trigger if exists products_block_active_order_soft_delete
  on public.products;
create trigger products_block_active_order_soft_delete
before update of is_active on public.products
for each row execute function public.prevent_deleting_product_with_active_orders();

-- Orders automatically receive a history record on creation and status changes.
create or replace function public.record_order_status_history()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.order_status_history (order_id, status)
    values (new.id, new.status);
  elsif new.status is distinct from old.status then
    insert into public.order_status_history (order_id, status)
    values (new.id, new.status);
  end if;
  return new;
end;
$$;

drop trigger if exists orders_record_status_history on public.orders;
create trigger orders_record_status_history
after insert or update on public.orders
for each row execute function public.record_order_status_history();

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;

drop policy if exists "Profiles: read own" on public.profiles;
create policy "Profiles: read own"
  on public.profiles for select to authenticated
  using (id = auth.uid());
drop policy if exists "Profiles: update own" on public.profiles;
create policy "Profiles: update own"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- This view exposes only public seller identity fields to signed-in users.
create or replace view public.seller_public_profiles as
select
  id,
  coalesce(nullif(trim(farm_name), ''), full_name) as seller_name,
  farm_name
from public.profiles
where role = 'seller';
drop policy if exists "Products: read active or own" on public.products;
create policy "Products: read active or own"
  on public.products for select to authenticated
  using (is_active or seller_id = auth.uid());
drop policy if exists "Products: seller insert own" on public.products;
create policy "Products: seller insert own"
  on public.products for insert to authenticated
  with check (
    seller_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'seller'
    )
  );
drop policy if exists "Products: seller update own" on public.products;
create policy "Products: seller update own"
  on public.products for update to authenticated
  using (
    seller_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'seller'
    )
  )
  with check (
    seller_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'seller'
    )
  );

drop policy if exists "Orders: buyer and seller read own" on public.orders;
create policy "Orders: buyer and seller read own"
  on public.orders for select to authenticated
  using (buyer_id = auth.uid() or seller_id = auth.uid());

drop policy if exists "Order items: buyer and seller read own" on public.order_items;
create policy "Order items: buyer and seller read own"
  on public.order_items for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.buyer_id = auth.uid() or o.seller_id = auth.uid())
    )
  );

drop policy if exists "Order history: buyer and seller read own"
  on public.order_status_history;
create policy "Order history: buyer and seller read own"
  on public.order_status_history for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.buyer_id = auth.uid() or o.seller_id = auth.uid())
    )
  );

revoke all on public.profiles, public.products, public.orders,
  public.order_items, public.order_status_history
  from anon, authenticated;
revoke all on public.seller_public_profiles from anon, authenticated;
grant select on public.seller_public_profiles to authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update on public.products to authenticated;
grant select on public.orders, public.order_items,
  public.order_status_history to authenticated;

-- Public-read image bucket; writes are scoped to a user's own top-level folder.
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

drop policy if exists "Product images: public read" on storage.objects;
create policy "Product images: public read"
  on storage.objects for select
  using (bucket_id = 'product-images');
drop policy if exists "Product images: owner upload" on storage.objects;
create policy "Product images: owner upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
drop policy if exists "Product images: owner update" on storage.objects;
create policy "Product images: owner update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
drop policy if exists "Product images: owner delete" on storage.objects;
create policy "Product images: owner delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create or replace function public.place_order(
  p_checkout_id uuid,
  p_items jsonb,
  p_fulfillment_type text,
  p_delivery_address text,
  p_contact_name text,
  p_contact_phone text,
  p_payment_method text
)
returns setof public.orders
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_buyer uuid := auth.uid();
  v_item record;
  v_product public.products%rowtype;
  v_seller record;
  v_order public.orders%rowtype;
  v_order_number text;
  v_delivery_fee numeric(12, 2);
  v_attempt integer;
  v_actual_price numeric(10, 2);
  v_buyer_name text;
  v_inserted boolean;
begin
  if v_buyer is null or not exists (
    select 1 from public.profiles where id = v_buyer and role = 'buyer'
  ) then
    raise exception 'Sign in as a Buyer before placing an order.';
  end if;
  if p_checkout_id is null then raise exception 'Checkout session is missing.'; end if;
  if p_fulfillment_type is null
     or p_fulfillment_type not in ('delivery', 'pickup') then
    raise exception 'Choose delivery or pickup.';
  end if;
  if p_payment_method is null
     or p_payment_method not in ('cod', 'gcash', 'card') then
    raise exception 'Choose a supported payment method.';
  end if;
  if p_fulfillment_type = 'delivery' then
    if coalesce(trim(p_delivery_address), '') = '' then
      raise exception 'Enter a delivery address.';
    end if;
    if coalesce(trim(p_contact_name), '') = '' then
      raise exception 'Enter a contact name.';
    end if;
    if coalesce(p_contact_phone, '') !~ '^(09[0-9]{9}|\+639[0-9]{9})$' then
      raise exception 'Enter a valid Philippine mobile number.';
    end if;
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'Your cart is empty.';
  end if;
  if jsonb_array_length(p_items) = 0 then
    raise exception 'Your cart is empty.';
  end if;
  if exists (
    select 1
    from jsonb_to_recordset(p_items) as i(
      product_id uuid, quantity_kg numeric, expected_price_per_kg numeric
    )
    where i.product_id is null
       or i.quantity_kg is null or i.quantity_kg <= 0
       or i.expected_price_per_kg is null
  ) then
    raise exception 'Cart contains an invalid item.';
  end if;

  for v_item in
    select i.product_id,
           sum(i.quantity_kg) quantity_kg,
           min(i.expected_price_per_kg) min_price,
           max(i.expected_price_per_kg) max_price
    from jsonb_to_recordset(p_items) as i(
      product_id uuid, quantity_kg numeric, expected_price_per_kg numeric
    )
    group by i.product_id
    order by i.product_id
  loop
    if v_item.min_price <> v_item.max_price then
      raise exception 'Cart has conflicting prices for one product.';
    end if;
    select * into v_product
    from public.products
    where id = v_item.product_id and is_active
    for update;
    if not found then
      raise exception 'A product in your cart is no longer available.';
    end if;
    if v_product.stock_kg < v_item.quantity_kg then
      raise exception 'Not enough stock for %: % kg available, % kg requested.',
        v_product.name, v_product.stock_kg, v_item.quantity_kg;
    end if;
    v_actual_price := case
      when v_product.is_discounted and v_product.discount_price is not null
        then v_product.discount_price
      else v_product.price_per_kg
    end;
    if v_actual_price <> v_item.min_price then
      raise exception 'The price for % changed. Refresh your cart.',
        v_product.name;
    end if;
  end loop;

  for v_item in
    select i.product_id, sum(i.quantity_kg) quantity_kg
    from jsonb_to_recordset(p_items) as i(
      product_id uuid, quantity_kg numeric, expected_price_per_kg numeric
    )
    group by i.product_id
  loop
    update public.products
    set stock_kg = stock_kg - v_item.quantity_kg,
        updated_at = now()
    where id = v_item.product_id;
  end loop;

  select full_name into v_buyer_name from public.profiles where id = v_buyer;
  for v_seller in
    select p.seller_id,
           max(p.seller_name) seller_name,
           sum(round(i.quantity_kg * case
             when p.is_discounted and p.discount_price is not null
               then p.discount_price
             else p.price_per_kg
           end, 2)) subtotal
    from (
      select product_id, sum(quantity_kg) quantity_kg
      from jsonb_to_recordset(p_items) as i(
        product_id uuid, quantity_kg numeric, expected_price_per_kg numeric
      )
      group by product_id
    ) i
    join public.products p on p.id = i.product_id
    group by p.seller_id
    order by p.seller_id
  loop
    v_delivery_fee := case when p_fulfillment_type = 'delivery' then 50 else 0 end;
    v_inserted := false;
    for v_attempt in 1..100 loop
      v_order_number := 'AGC' ||
        lpad(floor(random() * 1000000)::bigint::text, 6, '0');
      insert into public.orders (
        order_number, checkout_id, buyer_id, seller_id, seller_name, buyer_name,
        fulfillment_type, delivery_address, contact_name, contact_phone,
        payment_method, subtotal, delivery_fee, total, status
      ) values (
        v_order_number, p_checkout_id, v_buyer, v_seller.seller_id,
        v_seller.seller_name, v_buyer_name, p_fulfillment_type,
        case when p_fulfillment_type = 'delivery'
          then trim(p_delivery_address) else null end,
        nullif(trim(p_contact_name), ''),
        nullif(trim(p_contact_phone), ''),
        p_payment_method, v_seller.subtotal, v_delivery_fee,
        v_seller.subtotal + v_delivery_fee, 'pending'
      )
      on conflict (order_number) do nothing
      returning * into v_order;
      if found then
        v_inserted := true;
        exit;
      end if;
    end loop;
    if not v_inserted then
      raise exception 'Could not generate an order number. Please try again.';
    end if;

    insert into public.order_items (
      order_id, product_id, product_name, image_path, price_per_kg,
      quantity_kg, line_total
    )
    select v_order.id, p.id, p.name, p.image_url,
      case when p.is_discounted and p.discount_price is not null
        then p.discount_price else p.price_per_kg end,
      i.quantity_kg,
      round(i.quantity_kg * case
        when p.is_discounted and p.discount_price is not null
          then p.discount_price else p.price_per_kg end, 2)
    from (
      select product_id, sum(quantity_kg) quantity_kg
      from jsonb_to_recordset(p_items) as i(
        product_id uuid, quantity_kg numeric, expected_price_per_kg numeric
      )
      group by product_id
    ) i
    join public.products p on p.id = i.product_id
    where p.seller_id = v_seller.seller_id;
    return next v_order;
  end loop;
  return;
end;
$$;

create or replace function public.cancel_order(p_order_id uuid)
returns public.orders
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_buyer uuid := auth.uid();
  v_order public.orders%rowtype;
  v_item record;
begin
  if v_buyer is null or not exists (
    select 1 from public.profiles where id = v_buyer and role = 'buyer'
  ) then
    raise exception 'Sign in as a Buyer to cancel an order.';
  end if;
  select * into v_order from public.orders
  where id = p_order_id and buyer_id = v_buyer for update;
  if not found then raise exception 'Order not found.'; end if;
  if v_order.status <> 'pending' then
    raise exception 'Only pending orders can be cancelled by the buyer.';
  end if;
  for v_item in
    select product_id, sum(quantity_kg) quantity_kg
    from public.order_items where order_id = v_order.id group by product_id
  loop
    update public.products
    set stock_kg = stock_kg + v_item.quantity_kg, updated_at = now()
    where id = v_item.product_id;
  end loop;
  update public.orders set status = 'cancelled'
  where id = v_order.id returning * into v_order;
  return v_order;
end;
$$;

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
  v_seller uuid := auth.uid();
  v_order public.orders%rowtype;
  v_item record;
begin
  if v_seller is null or not exists (
    select 1 from public.profiles where id = v_seller and role = 'seller'
  ) then
    raise exception 'Sign in as a Seller.';
  end if;
  select * into v_order from public.orders
  where id = p_order_id for update;
  if not found then raise exception 'Order not found.'; end if;
  if v_order.seller_id <> v_seller then
    raise exception 'You can only update orders sold by you.';
  end if;
  if v_order.status in ('completed', 'cancelled') then
    raise exception 'Completed and cancelled orders are final.';
  end if;

  if p_new_status = 'cancelled' then
    if v_order.status not in ('pending', 'confirmed', 'preparing') then
      raise exception 'This order can no longer be cancelled.';
    end if;
    for v_item in
      select product_id, sum(quantity_kg) quantity_kg
      from public.order_items where order_id = v_order.id group by product_id
    loop
      update public.products
      set stock_kg = stock_kg + v_item.quantity_kg, updated_at = now()
      where id = v_item.product_id;
    end loop;
  elsif v_order.fulfillment_type = 'delivery' then
    if p_new_status = 'confirmed' and v_order.status <> 'pending' then
      raise exception 'Only pending delivery orders can be confirmed.';
    elsif p_new_status = 'preparing' and v_order.status <> 'confirmed' then
      raise exception 'Confirm the delivery order before preparing it.';
    elsif p_new_status = 'out_for_delivery' then
      if v_order.status <> 'preparing' then
        raise exception 'Preparing must come before out for delivery.';
      end if;
      if coalesce(trim(p_rider_name), '') = '' then
        raise exception 'Rider name is required.';
      end if;
      if coalesce(p_rider_phone, '') !~ '^(09[0-9]{9}|\+639[0-9]{9})$' then
        raise exception 'Enter a valid Philippine rider phone number.';
      end if;
    elsif p_new_status = 'completed' then
      if v_order.status <> 'out_for_delivery' then
        raise exception 'Out for delivery must come before completion.';
      end if;
    else
      raise exception 'Invalid status transition for a delivery order.';
    end if;
  elsif v_order.fulfillment_type = 'pickup' then
    if p_new_status = 'confirmed' and v_order.status <> 'pending' then
      raise exception 'Only pending pickup orders can be confirmed.';
    elsif p_new_status = 'preparing' and v_order.status <> 'confirmed' then
      raise exception 'Confirm the pickup order before preparing it.';
    elsif p_new_status = 'ready_for_pickup' and v_order.status <> 'preparing' then
      raise exception 'Preparing must come before ready for pickup.';
    elsif p_new_status = 'completed' and v_order.status <> 'ready_for_pickup' then
      raise exception 'Ready for pickup must come before completion.';
    else
      if p_new_status not in (
        'confirmed', 'preparing', 'ready_for_pickup', 'completed'
      ) then
        raise exception 'Invalid status transition for a pickup order.';
      end if;
    end if;
  else
    raise exception 'Unknown fulfillment type.';
  end if;

  update public.orders
  set status = p_new_status,
      eta = coalesce(p_eta, eta),
      rider_name = coalesce(nullif(trim(p_rider_name), ''), rider_name),
      rider_phone = coalesce(nullif(trim(p_rider_phone), ''), rider_phone)
  where id = v_order.id
  returning * into v_order;
  return v_order;
end;
$$;

create or replace function public.get_seller_sales(
  p_from_date timestamptz,
  p_to_date timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_seller uuid := auth.uid();
  v_revenue numeric;
  v_order_count bigint;
  v_units numeric;
  v_days jsonb;
  v_products jsonb;
begin
  if v_seller is null or not exists (
    select 1 from public.profiles where id = v_seller and role = 'seller'
  ) then
    raise exception 'Sign in as a Seller to view sales.';
  end if;
  if p_from_date is null or p_to_date is null or p_from_date >= p_to_date then
    raise exception 'Choose a valid sales date range.';
  end if;
  select coalesce(sum(subtotal), 0), count(*)
  into v_revenue, v_order_count
  from public.orders
  where seller_id = v_seller and status = 'completed'
    and created_at >= p_from_date and created_at < p_to_date;
  select coalesce(sum(oi.quantity_kg), 0)
  into v_units
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  where o.seller_id = v_seller and o.status = 'completed'
    and o.created_at >= p_from_date and o.created_at < p_to_date;
  select coalesce(jsonb_agg(to_jsonb(d) order by d.day), '[]'::jsonb)
  into v_days
  from (
    select created_at::date day, sum(subtotal) revenue
    from public.orders
    where seller_id = v_seller and status = 'completed'
      and created_at >= p_from_date and created_at < p_to_date
    group by created_at::date
  ) d;
  select coalesce(jsonb_agg(to_jsonb(p) order by p.revenue desc), '[]'::jsonb)
  into v_products
  from (
    select oi.product_name name, sum(oi.quantity_kg) kg,
           sum(oi.line_total) revenue
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where o.seller_id = v_seller and o.status = 'completed'
      and o.created_at >= p_from_date and o.created_at < p_to_date
    group by oi.product_name
  ) p;
  return jsonb_build_object(
    'total_revenue', v_revenue,
    'completed_orders', v_order_count,
    'units_kg', v_units,
    'revenue_per_day', v_days,
    'top_products', v_products
  );
end;
$$;

revoke all on function public.place_order(
  uuid, jsonb, text, text, text, text, text
) from public;
grant execute on function public.place_order(
  uuid, jsonb, text, text, text, text, text
) to authenticated;
revoke all on function public.cancel_order(uuid) from public;
grant execute on function public.cancel_order(uuid) to authenticated;
revoke all on function public.update_order_status(
  uuid, text, timestamptz, text, text
) from public;
grant execute on function public.update_order_status(
  uuid, text, timestamptz, text, text
) to authenticated;
revoke all on function public.get_seller_sales(timestamptz, timestamptz)
  from public;
grant execute on function public.get_seller_sales(timestamptz, timestamptz)
  to authenticated;
