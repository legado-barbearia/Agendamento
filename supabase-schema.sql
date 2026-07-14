-- Legado Barbearia — estrutura inicial para Supabase
-- Execute no SQL Editor do projeto. Revise as políticas antes de publicar em produção.

create extension if not exists pgcrypto;
create extension if not exists btree_gist;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  role text not null default 'admin' check (role in ('owner','admin','barber')),
  created_at timestamptz not null default now()
);

create table if not exists public.business_settings (
  id text primary key default 'main',
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.services (
  id text primary key,
  name text not null,
  description text not null default '',
  duration_minutes integer not null check (duration_minutes >= 5),
  price numeric(10,2) not null default 0,
  icon text not null default 'corte.webp',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.availability (
  id text primary key default 'main',
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.blocked_slots (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  all_day boolean not null default false,
  start_time time,
  end_time time,
  reason text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  service_id text references public.services(id) on delete set null,
  service_name text not null,
  duration_minutes integer not null,
  price_value numeric(10,2) not null default 0,
  booking_date date not null,
  start_time time not null,
  end_time time not null,
  client_name text not null,
  client_phone text not null,
  phone_digits text not null,
  client_photo text not null default '',
  professional text not null,
  notes text not null default '',
  status text not null default 'confirmed' check (status in ('pending','confirmed','completed','cancelled','no_show')),
  source text not null default 'site',
  cancellation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists bookings_schedule_idx on public.bookings (booking_date, start_time, end_time);
create index if not exists bookings_phone_code_idx on public.bookings (phone_digits, code);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  client_name text not null,
  client_phone text not null,
  phone_digits text not null unique,
  profile_photo text not null default '',
  is_existing_customer boolean not null default false,
  notes text not null default '',
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.barbers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  display_name text not null unique,
  phone text not null default '',
  email text not null default '',
  photo_url text not null default '',
  bio text not null default '',
  service_commission numeric(5,2) not null default 0,
  product_commission numeric(5,2) not null default 0,
  active boolean not null default true,
  show_on_site boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  category text not null default 'Geral',
  image_url text not null default '',
  cost_price numeric(10,2) not null default 0,
  sale_price numeric(10,2) not null default 0,
  quantity integer not null default 0 check (quantity >= 0),
  minimum_stock integer not null default 0 check (minimum_stock >= 0),
  internal_code text not null default '',
  barber_commission numeric(5,2) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete set null,
  movement_type text not null check (movement_type in ('entrada','saida','venda','perda','ajuste')),
  quantity integer not null,
  reason text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings(id) on delete set null,
  client_id uuid references public.clients(id) on delete set null,
  barber_id uuid references public.barbers(id) on delete set null,
  gross_amount numeric(10,2) not null default 0,
  discount_amount numeric(10,2) not null default 0,
  fee_amount numeric(10,2) not null default 0,
  net_amount numeric(10,2) not null default 0,
  payment_method text not null default 'pendente',
  status text not null default 'pending' check (status in ('pending','paid','cancelled','refunded')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_sales (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete set null,
  payment_id uuid references public.payments(id) on delete set null,
  product_name text not null default '',
  quantity integer not null check (quantity > 0),
  unit_price numeric(10,2) not null default 0,
  total_amount numeric(10,2) not null default 0,
  payment_method text not null default 'pix',
  notes text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.cash_registers (
  id uuid primary key default gen_random_uuid(),
  register_date date not null default current_date,
  opening_amount numeric(10,2) not null default 0,
  closing_amount numeric(10,2),
  expected_amount numeric(10,2),
  status text not null default 'open' check (status in ('open','closed')),
  opened_by uuid references auth.users(id) on delete set null,
  closed_by uuid references auth.users(id) on delete set null,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  notes text not null default ''
);

create table if not exists public.commissions (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid references public.barbers(id) on delete set null,
  booking_id uuid references public.bookings(id) on delete set null,
  payment_id uuid references public.payments(id) on delete set null,
  base_amount numeric(10,2) not null default 0,
  commission_percent numeric(5,2) not null default 0,
  commission_amount numeric(10,2) not null default 0,
  status text not null default 'pending' check (status in ('pending','paid','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.barber_settlements (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid references public.barbers(id) on delete set null,
  period_start date not null,
  period_end date not null,
  gross_amount numeric(10,2) not null default 0,
  commission_amount numeric(10,2) not null default 0,
  paid_amount numeric(10,2) not null default 0,
  status text not null default 'open' check (status in ('open','closed','paid')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Impede sobreposição de agendamentos ativos do mesmo profissional no banco.
-- Essa é a proteção definitiva quando o site estiver conectado ao Supabase.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'bookings_no_active_overlap'
  ) then
    alter table public.bookings
      add constraint bookings_no_active_overlap
      exclude using gist (
        lower(professional) with =,
        tsrange(booking_date + start_time, booking_date + end_time, '[)') with &&
      )
      where (status in ('pending','confirmed'));
  end if;
end $$;

create table if not exists public.portfolio (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null default 'Cortes',
  summary text not null default '',
  description text not null default '',
  image_url text not null,
  gallery_images jsonb not null default '[]'::jsonb,
  image_position_x numeric(5,2) not null default 50,
  image_position_y numeric(5,2) not null default 50,
  image_zoom numeric(4,2) not null default 1,
  alt_text text not null default '',
  featured boolean not null default false,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.testimonials (
  id uuid primary key default gen_random_uuid(),
  client_name text not null,
  client_phone text not null default '',
  phone_digits text not null default '',
  service_name text not null default 'Atendimento Legado',
  testimonial text not null,
  rating integer not null default 5 check (rating between 1 and 5),
  profile_photo text not null default '',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  active boolean not null default false,
  source text not null default 'admin',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.bookings add column if not exists client_photo text not null default '';
alter table public.bookings add column if not exists service_id text;
alter table public.bookings add column if not exists service_name text not null default 'Atendimento Legado';
alter table public.bookings add column if not exists duration_minutes integer not null default 30;
alter table public.bookings add column if not exists price_value numeric(10,2) not null default 0;
alter table public.bookings add column if not exists booking_date date not null default current_date;
alter table public.bookings add column if not exists start_time time not null default '09:00';
alter table public.bookings add column if not exists end_time time not null default '09:30';
alter table public.bookings add column if not exists client_name text not null default 'Cliente Legado';
alter table public.bookings add column if not exists client_phone text not null default '';
alter table public.bookings add column if not exists phone_digits text not null default '';
alter table public.bookings add column if not exists professional text not null default 'Gilliel Glaydson';
alter table public.bookings add column if not exists notes text not null default '';
alter table public.bookings add column if not exists status text not null default 'confirmed';
alter table public.bookings add column if not exists source text not null default 'site';
alter table public.bookings add column if not exists cancellation_reason text;
alter table public.bookings add column if not exists created_at timestamptz not null default now();
alter table public.bookings add column if not exists updated_at timestamptz not null default now();
alter table public.bookings alter column status set default 'confirmed';
alter table public.clients add column if not exists client_name text not null default 'Cliente Legado';
alter table public.clients add column if not exists client_phone text not null default '';
alter table public.clients add column if not exists phone_digits text not null default '';
alter table public.clients add column if not exists profile_photo text not null default '';
alter table public.clients add column if not exists is_existing_customer boolean not null default false;
alter table public.clients add column if not exists notes text not null default '';
alter table public.clients add column if not exists first_seen_at timestamptz not null default now();
alter table public.clients add column if not exists last_seen_at timestamptz not null default now();
alter table public.clients add column if not exists created_at timestamptz not null default now();
alter table public.clients add column if not exists updated_at timestamptz not null default now();
alter table public.portfolio add column if not exists title text not null default 'Portfolio Legado';
alter table public.portfolio add column if not exists category text not null default 'Cortes';
alter table public.portfolio add column if not exists summary text not null default '';
alter table public.portfolio add column if not exists description text not null default '';
alter table public.portfolio add column if not exists image_url text not null default 'assets/corte.webp';
alter table public.portfolio add column if not exists gallery_images jsonb not null default '[]'::jsonb;
alter table public.portfolio add column if not exists image_position_x numeric(5,2) not null default 50;
alter table public.portfolio add column if not exists image_position_y numeric(5,2) not null default 50;
alter table public.portfolio add column if not exists image_zoom numeric(4,2) not null default 1;
alter table public.portfolio add column if not exists alt_text text not null default '';
alter table public.portfolio add column if not exists featured boolean not null default false;
alter table public.portfolio add column if not exists active boolean not null default true;
alter table public.portfolio add column if not exists sort_order integer not null default 0;
alter table public.portfolio add column if not exists created_at timestamptz not null default now();
alter table public.portfolio add column if not exists updated_at timestamptz not null default now();
alter table public.testimonials add column if not exists client_name text not null default 'Cliente Legado';
alter table public.testimonials add column if not exists client_phone text not null default '';
alter table public.testimonials add column if not exists phone_digits text not null default '';
alter table public.testimonials add column if not exists service_name text not null default 'Atendimento Legado';
alter table public.testimonials add column if not exists testimonial text not null default '';
alter table public.testimonials add column if not exists rating integer not null default 5;
alter table public.testimonials add column if not exists profile_photo text not null default '';
alter table public.testimonials add column if not exists status text not null default 'pending';
alter table public.testimonials add column if not exists active boolean not null default false;
alter table public.testimonials add column if not exists source text not null default 'admin';
alter table public.testimonials add column if not exists sort_order integer not null default 0;
alter table public.testimonials add column if not exists created_at timestamptz not null default now();
alter table public.testimonials add column if not exists updated_at timestamptz not null default now();

alter table public.profiles enable row level security;
alter table public.business_settings enable row level security;
alter table public.services enable row level security;
alter table public.availability enable row level security;
alter table public.blocked_slots enable row level security;
alter table public.bookings enable row level security;
alter table public.clients enable row level security;
alter table public.barbers enable row level security;
alter table public.products enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.payments enable row level security;
alter table public.product_sales enable row level security;
alter table public.cash_registers enable row level security;
alter table public.commissions enable row level security;
alter table public.barber_settlements enable row level security;
alter table public.portfolio enable row level security;
alter table public.testimonials enable row level security;

create or replace function public.is_admin_user()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role in ('owner', 'admin')
  );
$$;
revoke all on function public.is_admin_user() from public;
grant execute on function public.is_admin_user() to anon, authenticated;

drop policy if exists "public read settings" on public.business_settings;
drop policy if exists "public read active services" on public.services;
drop policy if exists "public read availability" on public.availability;
drop policy if exists "public read active portfolio" on public.portfolio;
drop policy if exists "public read active testimonials" on public.testimonials;
drop policy if exists "admins manage settings" on public.business_settings;
drop policy if exists "admins manage services" on public.services;
drop policy if exists "admins manage availability" on public.availability;
drop policy if exists "admins manage blocks" on public.blocked_slots;
drop policy if exists "admins manage bookings" on public.bookings;
drop policy if exists "admins manage clients" on public.clients;
drop policy if exists "barbers read blocks" on public.blocked_slots;
drop policy if exists "barbers read own bookings" on public.bookings;
drop policy if exists "barbers read own clients" on public.clients;
drop policy if exists "public read active barbers" on public.barbers;
drop policy if exists "public read active products" on public.products;
drop policy if exists "admins manage barbers" on public.barbers;
drop policy if exists "admins manage products" on public.products;
drop policy if exists "admins manage inventory" on public.inventory_movements;
drop policy if exists "admins manage payments" on public.payments;
drop policy if exists "admins manage product sales" on public.product_sales;
drop policy if exists "admins manage cash registers" on public.cash_registers;
drop policy if exists "admins manage commissions" on public.commissions;
drop policy if exists "admins manage barber settlements" on public.barber_settlements;
drop policy if exists "barbers read own payments" on public.payments;
drop policy if exists "barbers read own commissions" on public.commissions;
drop policy if exists "barbers read own settlements" on public.barber_settlements;
drop policy if exists "admins manage portfolio" on public.portfolio;
drop policy if exists "admins manage testimonials" on public.testimonials;
drop policy if exists "admins manage profiles" on public.profiles;
drop policy if exists "users read own profile" on public.profiles;
drop policy if exists "public create pending booking" on public.bookings;
drop policy if exists "public create confirmed booking" on public.bookings;
drop policy if exists "public create client profile" on public.clients;
drop policy if exists "public read client profile" on public.clients;
drop policy if exists "public update client profile" on public.clients;
drop policy if exists "public create pending testimonial" on public.testimonials;

-- Leitura pública somente do conteúdo necessário ao site.
create policy "public read settings" on public.business_settings for select to anon, authenticated using (true);
create policy "public read active services" on public.services for select to anon, authenticated using (active = true or public.is_admin_user());
create policy "public read availability" on public.availability for select to anon, authenticated using (true);
create policy "public read active portfolio" on public.portfolio for select to anon, authenticated using (active = true or public.is_admin_user());
create policy "public read active testimonials" on public.testimonials for select to anon, authenticated using (active = true and status = 'approved');
create policy "public read active barbers" on public.barbers for select to anon, authenticated using ((active = true and show_on_site = true) or public.is_admin_user());
create policy "public read active products" on public.products for select to anon, authenticated using (active = true or public.is_admin_user());

-- Administradores autenticados gerenciam os dados da barbearia.
create policy "admins manage settings" on public.business_settings for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage services" on public.services for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage availability" on public.availability for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage blocks" on public.blocked_slots for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage bookings" on public.bookings for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage clients" on public.clients for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage barbers" on public.barbers for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage products" on public.products for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage inventory" on public.inventory_movements for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage payments" on public.payments for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage product sales" on public.product_sales for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage cash registers" on public.cash_registers for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage commissions" on public.commissions for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage barber settlements" on public.barber_settlements for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage portfolio" on public.portfolio for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage testimonials" on public.testimonials for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins manage profiles" on public.profiles for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "users read own profile" on public.profiles for select to authenticated using (auth.uid() = id);

create policy "barbers read blocks" on public.blocked_slots
for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'barber'
  )
);

create policy "barbers read own bookings" on public.bookings
for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'barber'
      and lower(trim(p.name)) = lower(trim(bookings.professional))
  )
);

create policy "barbers read own clients" on public.clients
for select to authenticated
using (
  exists (
    select 1
    from public.profiles p
    join public.bookings b on b.phone_digits = clients.phone_digits
    where p.id = (select auth.uid())
      and p.role = 'barber'
      and lower(trim(p.name)) = lower(trim(b.professional))
  )
);

create policy "barbers read own payments" on public.payments
for select to authenticated
using (
  exists (
    select 1
    from public.profiles p
    join public.bookings b on b.id = payments.booking_id
    where p.id = (select auth.uid())
      and p.role = 'barber'
      and lower(trim(p.name)) = lower(trim(b.professional))
  )
);

create policy "barbers read own commissions" on public.commissions
for select to authenticated
using (
  exists (
    select 1
    from public.profiles p
    join public.bookings b on b.id = commissions.booking_id
    where p.id = (select auth.uid())
      and p.role = 'barber'
      and lower(trim(p.name)) = lower(trim(b.professional))
  )
);

create policy "barbers read own settlements" on public.barber_settlements
for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'barber'
      and lower(coalesce(barber_settlements.notes, '')) like lower('%Barbeiro: ' || trim(p.name) || '%')
  )
);

-- Criação pública de agendamentos já confirmados. Em produção, prefira uma Edge Function
-- ou RPC com validação de conflito, limite de requisições e CAPTCHA.
-- Clientes publicos nao leem nem atualizam a tabela diretamente.
-- Perfil de cliente anonimo passa pelas RPCs lookup_client_profile/save_client_profile.

-- Bucket publico usado para fotos de perfil dos clientes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('client-photos', 'client-photos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'public read client photos'
  ) then
    create policy "public read client photos" on storage.objects
    for select to anon, authenticated
    using (bucket_id = 'client-photos');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'public upload client photos'
  ) then
    create policy "public upload client photos" on storage.objects
    for insert to anon
    with check (bucket_id = 'client-photos');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'public update client photos'
  ) then
    create policy "public update client photos" on storage.objects
    for update to anon
    using (bucket_id = 'client-photos')
    with check (bucket_id = 'client-photos');
  end if;
end $$;

create policy "public create pending testimonial" on public.testimonials
for insert to anon
with check (status = 'pending' and active = false and char_length(phone_digits) between 10 and 13);

grant usage on schema public to anon, authenticated;
grant select on public.business_settings, public.availability, public.services, public.barbers, public.products, public.portfolio, public.testimonials to anon, authenticated;
grant insert on public.testimonials to anon;
revoke insert, update, delete on public.bookings from anon;
revoke select, insert, update, delete on public.clients from anon;
grant select on public.profiles to authenticated;
grant all on public.profiles, public.business_settings, public.availability, public.services, public.blocked_slots, public.bookings, public.clients, public.barbers, public.products, public.inventory_movements, public.payments, public.product_sales, public.cash_registers, public.commissions, public.barber_settlements, public.portfolio, public.testimonials to authenticated;

-- Remove versoes antigas das RPCs, mesmo quando a assinatura/retorno mudou.
-- Isso evita erros como "cannot change return type of existing function".
do $$
declare
  fn record;
begin
  for fn in
    select n.nspname as schema_name, p.proname as function_name, pg_get_function_identity_arguments(p.oid) as arguments
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('booked_intervals', 'booked_intervals_for_professional', 'lookup_booking', 'cancel_booking', 'lookup_client_profile', 'save_client_profile', 'reserve_booking')
  loop
    execute format('drop function if exists %I.%I(%s) cascade', fn.schema_name, fn.function_name, fn.arguments);
  end loop;
end $$;

-- Retorna somente os intervalos ocupados, sem dados pessoais.
drop function if exists public.booked_intervals(date) cascade;

create or replace function public.booked_intervals(p_date date)
returns table (start_time time, end_time time, professional text)
language sql security definer set search_path = public
as $$
  select b.start_time, b.end_time, b.professional
  from public.bookings b
  where b.booking_date = p_date and b.status in ('pending','confirmed');
$$;
grant execute on function public.booked_intervals(date) to anon, authenticated;

-- Retorna somente os intervalos ocupados do profissional escolhido.
drop function if exists public.booked_intervals_for_professional(date, text) cascade;

create or replace function public.booked_intervals_for_professional(p_date date, p_professional text)
returns table (start_time time, end_time time, professional text)
language sql security definer set search_path = public
as $$
  select b.start_time, b.end_time, b.professional
  from public.bookings b
  where b.booking_date = p_date
    and b.status in ('pending','confirmed')
    and lower(b.professional) = lower(coalesce(nullif(trim(p_professional), ''), b.professional));
$$;
grant execute on function public.booked_intervals_for_professional(date, text) to anon, authenticated;

-- Consulta segura de perfil por WhatsApp exato. Nao lista clientes.
drop function if exists public.lookup_client_profile(text) cascade;

create or replace function public.lookup_client_profile(p_phone_digits text)
returns table (
  id uuid,
  client_name text,
  client_phone text,
  phone_digits text,
  profile_photo text,
  is_existing_customer boolean,
  notes text,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone_digits text;
begin
  v_phone_digits := regexp_replace(coalesce(p_phone_digits, ''), '\D', '', 'g');
  while left(v_phone_digits, 2) = '55' and length(v_phone_digits) > 11 loop
    v_phone_digits := substr(v_phone_digits, 3);
  end loop;

  return query
  select c.id, c.client_name, c.client_phone, c.phone_digits, c.profile_photo,
         c.is_existing_customer, c.notes, c.first_seen_at, c.last_seen_at,
         c.created_at, c.updated_at
  from public.clients c
  where c.phone_digits = v_phone_digits
  limit 1;
end;
$$;
revoke all on function public.lookup_client_profile(text) from public;
grant execute on function public.lookup_client_profile(text) to anon, authenticated;

-- Cria ou atualiza perfil publico sem abrir select/update direto na tabela clients.
drop function if exists public.save_client_profile(text, text, text, text, boolean, text) cascade;

create or replace function public.save_client_profile(
  p_client_name text,
  p_client_phone text,
  p_phone_digits text,
  p_profile_photo text default '',
  p_is_existing_customer boolean default false,
  p_notes text default ''
)
returns table (
  id uuid,
  client_name text,
  client_phone text,
  phone_digits text,
  profile_photo text,
  is_existing_customer boolean,
  notes text,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone_digits text;
begin
  v_phone_digits := regexp_replace(coalesce(p_phone_digits, p_client_phone, ''), '\D', '', 'g');
  while left(v_phone_digits, 2) = '55' and length(v_phone_digits) > 11 loop
    v_phone_digits := substr(v_phone_digits, 3);
  end loop;

  if length(v_phone_digits) < 10 or length(v_phone_digits) > 13 then
    raise exception 'invalid_phone' using errcode = 'P0001';
  end if;

  if length(trim(coalesce(p_client_name, ''))) < 2 then
    raise exception 'invalid_name' using errcode = 'P0001';
  end if;

  return query
  insert into public.clients (
    client_name, client_phone, phone_digits, profile_photo, is_existing_customer,
    notes, first_seen_at, last_seen_at, created_at, updated_at
  )
  values (
    trim(p_client_name), coalesce(p_client_phone, ''), v_phone_digits,
    coalesce(p_profile_photo, ''), coalesce(p_is_existing_customer, false),
    coalesce(p_notes, ''), now(), now(), now(), now()
  )
  on conflict (phone_digits) do update
  set client_name = excluded.client_name,
      client_phone = excluded.client_phone,
      profile_photo = coalesce(nullif(excluded.profile_photo, ''), clients.profile_photo),
      is_existing_customer = excluded.is_existing_customer,
      notes = excluded.notes,
      last_seen_at = now(),
      updated_at = now()
  returning public.clients.id, public.clients.client_name, public.clients.client_phone,
            public.clients.phone_digits, public.clients.profile_photo,
            public.clients.is_existing_customer, public.clients.notes,
            public.clients.first_seen_at, public.clients.last_seen_at,
            public.clients.created_at, public.clients.updated_at;
end;
$$;
revoke all on function public.save_client_profile(text, text, text, text, boolean, text) from public;
grant execute on function public.save_client_profile(text, text, text, text, boolean, text) to anon, authenticated;

-- Consulta segura por telefone e código. Não lista agendamentos de terceiros.
drop function if exists public.lookup_booking(text, text) cascade;

create or replace function public.lookup_booking(p_phone_digits text, p_code text)
returns table (
  id uuid,
  code text,
  service_id text,
  service_name text,
  duration_minutes integer,
  price_value numeric,
  booking_date date,
  start_time time,
  end_time time,
  client_name text,
  client_phone text,
  phone_digits text,
  client_photo text,
  professional text,
  notes text,
  status text,
  source text,
  cancellation_reason text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql security definer set search_path = public
as $$
declare
  v_phone_digits text;
begin
  v_phone_digits := regexp_replace(coalesce(p_phone_digits, ''), '\D', '', 'g');
  while left(v_phone_digits, 2) = '55' and length(v_phone_digits) > 11 loop
    v_phone_digits := substr(v_phone_digits, 3);
  end loop;

  return query
  select b.id, b.code, b.service_id, b.service_name, b.duration_minutes, b.price_value,
         b.booking_date, b.start_time, b.end_time, b.client_name, b.client_phone,
         b.phone_digits, b.client_photo, b.professional, b.notes, b.status, b.source,
         b.cancellation_reason, b.created_at, b.updated_at
  from public.bookings b
  where b.phone_digits = v_phone_digits
    and upper(b.code) = upper(p_code)
  limit 1;
end;
$$;
revoke all on function public.lookup_booking(text, text) from public;
grant execute on function public.lookup_booking(text, text) to anon, authenticated;

-- Cancela um agendamento pela mesma chave usada na consulta publica.
-- O registro permanece no historico, mas deixa de bloquear o horario.
drop function if exists public.cancel_booking(text, text, text) cascade;

create or replace function public.cancel_booking(
  p_phone_digits text,
  p_code text,
  p_reason text default 'Cancelado pelo cliente'
)
returns table (
  id uuid,
  code text,
  service_id text,
  service_name text,
  duration_minutes integer,
  price_value numeric,
  booking_date date,
  start_time time,
  end_time time,
  client_name text,
  client_phone text,
  phone_digits text,
  client_photo text,
  professional text,
  notes text,
  status text,
  source text,
  cancellation_reason text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone_digits text;
begin
  v_phone_digits := regexp_replace(coalesce(p_phone_digits, ''), '\D', '', 'g');
  while left(v_phone_digits, 2) = '55' and length(v_phone_digits) > 11 loop
    v_phone_digits := substr(v_phone_digits, 3);
  end loop;

  update public.bookings b
  set status = 'cancelled',
      cancellation_reason = coalesce(nullif(trim(p_reason), ''), 'Cancelado pelo cliente'),
      updated_at = now()
  where b.phone_digits = v_phone_digits
    and upper(b.code) = upper(trim(p_code))
    and b.status in ('pending', 'confirmed')
  returning b.id, b.code, b.service_id, b.service_name, b.duration_minutes, b.price_value,
            b.booking_date, b.start_time, b.end_time, b.client_name, b.client_phone,
            b.phone_digits, b.client_photo, b.professional, b.notes, b.status, b.source,
            b.cancellation_reason, b.created_at, b.updated_at
  into id, code, service_id, service_name, duration_minutes, price_value,
       booking_date, start_time, end_time, client_name, client_phone,
       phone_digits, client_photo, professional, notes, status, source,
       cancellation_reason, created_at, updated_at;

  if id is null then
    raise exception 'booking_not_found_or_inactive' using errcode = 'P0001';
  end if;

  return next;
end;
$$;
revoke all on function public.cancel_booking(text, text, text) from public;
grant execute on function public.cancel_booking(text, text, text) to anon, authenticated;

-- Reserva transacional usada pelo site público e pelo painel.
-- O cliente só recebe confirmação quando este INSERT no Supabase acontece.
-- Valida no banco: serviço, expediente, antecedência, bloqueios, barbeiro e conflitos.
drop function if exists public.reserve_booking(
  uuid, text, text, text, integer, numeric, date, time, text, text, text, text, text, text, text
) cascade;

revoke insert on public.bookings from anon;
drop policy if exists "public create confirmed booking" on public.bookings;

create or replace function public.reserve_booking(
  p_id uuid,
  p_code text,
  p_service_id text,
  p_service_name text,
  p_duration_minutes integer,
  p_price_value numeric,
  p_booking_date date,
  p_start_time time,
  p_client_name text,
  p_client_phone text,
  p_phone_digits text,
  p_client_photo text default '',
  p_professional text default '',
  p_notes text default '',
  p_source text default 'site'
)
returns table (
  id uuid,
  code text,
  service_id text,
  service_name text,
  duration_minutes integer,
  price_value numeric,
  booking_date date,
  start_time time,
  end_time time,
  client_name text,
  client_phone text,
  phone_digits text,
  client_photo text,
  professional text,
  notes text,
  status text,
  source text,
  cancellation_reason text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings jsonb;
  v_availability jsonb;
  v_day_config jsonb;
  v_duration integer;
  v_price numeric(10,2);
  v_service_name text;
  v_professional text;
  v_phone_digits text;
  v_buffer integer;
  v_minimum_lead integer;
  v_start_ts timestamp;
  v_end_ts timestamp;
  v_lock_end_ts timestamp;
  v_end_time time;
  v_dow text;
begin
  select data into v_settings from public.business_settings where id = 'main';
  select data into v_availability from public.availability where id = 'main';

  if v_availability is null then
    raise exception 'not_available: availability_not_configured' using errcode = 'P0001';
  end if;

  v_phone_digits := regexp_replace(coalesce(p_phone_digits, p_client_phone, ''), '\D', '', 'g');
  while left(v_phone_digits, 2) = '55' and length(v_phone_digits) > 11 loop
    v_phone_digits := substr(v_phone_digits, 3);
  end loop;

  if length(trim(coalesce(p_client_name, ''))) < 2 or length(v_phone_digits) < 10 or length(v_phone_digits) > 13 then
    raise exception 'not_available: invalid_client' using errcode = 'P0001';
  end if;

  select s.name, s.duration_minutes, s.price
    into v_service_name, v_duration, v_price
  from public.services s
  where s.id = p_service_id and s.active = true
  limit 1;

  if v_duration is null then
    raise exception 'not_available: service_not_found' using errcode = 'P0001';
  end if;

  v_service_name := coalesce(v_service_name, nullif(trim(p_service_name), ''), 'Atendimento Legado');
  v_duration := greatest(5, coalesce(v_duration, p_duration_minutes, 30));
  v_price := coalesce(v_price, p_price_value, 0);
  v_buffer := greatest(0, coalesce((v_availability->>'bufferMinutes')::integer, 0));
  v_minimum_lead := greatest(0, coalesce((v_availability->>'minimumLeadMinutes')::integer, 0));
  v_professional := nullif(trim(coalesce(p_professional, '')), '');

  if v_professional is null then
    v_professional := coalesce(v_settings->>'professional', 'Gilliel Glaydson');
  end if;

  v_start_ts := p_booking_date + p_start_time;
  v_end_ts := v_start_ts + make_interval(mins => v_duration);
  v_lock_end_ts := v_end_ts + make_interval(mins => v_buffer);
  v_end_time := v_end_ts::time;

  if v_end_ts::date <> p_booking_date then
    raise exception 'not_available: service_outside_day' using errcode = 'P0001';
  end if;

  if v_start_ts < ((now() at time zone 'America/Sao_Paulo') + make_interval(mins => v_minimum_lead)) then
    raise exception 'not_available: minimum_lead_time' using errcode = 'P0001';
  end if;

  v_dow := extract(dow from p_booking_date)::integer::text;
  v_day_config := v_availability->'weekdays'->v_dow;

  if coalesce((v_day_config->>'enabled')::boolean, false) is not true then
    raise exception 'not_available: closed_day' using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(coalesce(v_day_config->'periods', '[]'::jsonb)) as period(value)
    where p_start_time >= (period.value->>'start')::time
      and v_end_time <= (period.value->>'end')::time
  ) then
    raise exception 'not_available: outside_working_hours' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.blocked_slots bs
    where bs.date = p_booking_date
      and (
        bs.all_day = true
        or tsrange(p_booking_date + bs.start_time, p_booking_date + bs.end_time, '[)')
           && tsrange(v_start_ts, v_lock_end_ts, '[)')
      )
  ) then
    raise exception 'slot_conflict: blocked_period' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.booking_date = p_booking_date
      and lower(b.professional) = lower(v_professional)
      and b.status in ('pending', 'confirmed')
      and tsrange(b.booking_date + b.start_time, (b.booking_date + b.end_time) + make_interval(mins => v_buffer), '[)')
          && tsrange(v_start_ts, v_lock_end_ts, '[)')
  ) then
    raise exception 'slot_conflict: booking_overlap' using errcode = 'P0001';
  end if;

  insert into public.bookings (
    id, code, service_id, service_name, duration_minutes, price_value,
    booking_date, start_time, end_time, client_name, client_phone,
    phone_digits, client_photo, professional, notes, status, source,
    created_at, updated_at
  )
  values (
    p_id, upper(trim(p_code)), p_service_id, v_service_name, v_duration, v_price,
    p_booking_date, p_start_time, v_end_time, trim(p_client_name), p_client_phone,
    v_phone_digits, coalesce(p_client_photo, ''), v_professional, coalesce(p_notes, ''),
    'confirmed', coalesce(nullif(p_source, ''), 'site'), now(), now()
  );

  update public.clients
  set client_name = trim(p_client_name),
      client_phone = p_client_phone,
      profile_photo = coalesce(nullif(p_client_photo, ''), profile_photo),
      last_seen_at = now(),
      updated_at = now()
  where phone_digits = v_phone_digits;

  if not found then
    insert into public.clients (
      client_name, client_phone, phone_digits, profile_photo,
      first_seen_at, last_seen_at, created_at, updated_at
    )
    values (
      trim(p_client_name), p_client_phone, v_phone_digits, coalesce(p_client_photo, ''),
      now(), now(), now(), now()
    );
  end if;

  return query
  select b.id, b.code, b.service_id, b.service_name, b.duration_minutes, b.price_value,
         b.booking_date, b.start_time, b.end_time, b.client_name, b.client_phone,
         b.phone_digits, b.client_photo, b.professional, b.notes, b.status, b.source,
         b.cancellation_reason, b.created_at, b.updated_at
  from public.bookings b
  where b.id = p_id;
exception
  when exclusion_violation then
    raise exception 'slot_conflict: booking_overlap' using errcode = 'P0001';
  when unique_violation then
    raise exception 'slot_conflict: duplicate_booking' using errcode = 'P0001';
end;
$$;

revoke all on function public.reserve_booking(
  uuid, text, text, text, integer, numeric, date, time, text, text, text, text, text, text, text
) from public;
grant execute on function public.reserve_booking(
  uuid, text, text, text, integer, numeric, date, time, text, text, text, text, text, text, text
) to anon, authenticated;
