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
  description text not null default '',
  image_url text not null,
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
alter table public.portfolio add column if not exists description text not null default '';
alter table public.portfolio add column if not exists image_url text not null default 'assets/corte.webp';
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
alter table public.portfolio enable row level security;
alter table public.testimonials enable row level security;

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
drop policy if exists "admins manage portfolio" on public.portfolio;
drop policy if exists "admins manage testimonials" on public.testimonials;
drop policy if exists "users read own profile" on public.profiles;
drop policy if exists "public create pending booking" on public.bookings;
drop policy if exists "public create confirmed booking" on public.bookings;
drop policy if exists "public create client profile" on public.clients;
drop policy if exists "public read client profile" on public.clients;
drop policy if exists "public update client profile" on public.clients;
drop policy if exists "public create pending testimonial" on public.testimonials;

-- Leitura pública somente do conteúdo necessário ao site.
create policy "public read settings" on public.business_settings for select to anon, authenticated using (true);
create policy "public read active services" on public.services for select to anon, authenticated using (active = true or auth.role() = 'authenticated');
create policy "public read availability" on public.availability for select to anon, authenticated using (true);
create policy "public read active portfolio" on public.portfolio for select to anon, authenticated using (active = true or auth.role() = 'authenticated');
create policy "public read active testimonials" on public.testimonials for select to anon, authenticated using (active = true and status = 'approved');

-- Administradores autenticados gerenciam todos os dados.
create policy "admins manage settings" on public.business_settings for all to authenticated using (true) with check (true);
create policy "admins manage services" on public.services for all to authenticated using (true) with check (true);
create policy "admins manage availability" on public.availability for all to authenticated using (true) with check (true);
create policy "admins manage blocks" on public.blocked_slots for all to authenticated using (true) with check (true);
create policy "admins manage bookings" on public.bookings for all to authenticated using (true) with check (true);
create policy "admins manage clients" on public.clients for all to authenticated using (true) with check (true);
create policy "admins manage portfolio" on public.portfolio for all to authenticated using (true) with check (true);
create policy "admins manage testimonials" on public.testimonials for all to authenticated using (true) with check (true);
create policy "users read own profile" on public.profiles for select to authenticated using (auth.uid() = id);

-- Criação pública de agendamentos já confirmados. Em produção, prefira uma Edge Function
-- ou RPC com validação de conflito, limite de requisições e CAPTCHA.
create policy "public create confirmed booking" on public.bookings
for insert to anon
with check (status = 'confirmed' and char_length(phone_digits) between 10 and 13);

create policy "public create client profile" on public.clients
for insert to anon
with check (char_length(phone_digits) between 10 and 13);

create policy "public update client profile" on public.clients
for update to anon
using (char_length(phone_digits) between 10 and 13)
with check (char_length(phone_digits) between 10 and 13);

-- Necessario para o site localizar o perfil existente pelo WhatsApp normalizado
-- antes de atualizar, evitando duplicar clientes anonimos.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'clients' and policyname = 'public read client profile'
  ) then
    create policy "public read client profile" on public.clients
    for select to anon
    using (char_length(phone_digits) between 10 and 13);
  end if;
end $$;

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
grant select on public.business_settings, public.availability, public.services, public.portfolio, public.testimonials to anon, authenticated;
grant insert on public.bookings, public.clients, public.testimonials to anon;
grant select, update on public.clients to anon;
grant all on public.business_settings, public.availability, public.services, public.blocked_slots, public.bookings, public.clients, public.portfolio, public.testimonials to authenticated;

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
      and p.proname in ('booked_intervals', 'booked_intervals_for_professional', 'lookup_booking', 'reserve_booking')
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

-- Consulta segura por telefone e código. Não lista agendamentos de terceiros.
drop function if exists public.lookup_booking(text, text) cascade;

create or replace function public.lookup_booking(p_phone_digits text, p_code text)
returns table (
  id uuid, code text, service_name text, booking_date date, start_time time, end_time time,
  professional text, status text, duration_minutes integer, price_value numeric, notes text
)
language sql security definer set search_path = public
as $$
  select b.id, b.code, b.service_name, b.booking_date, b.start_time, b.end_time,
         b.professional, b.status, b.duration_minutes, b.price_value, b.notes
  from public.bookings b
  where b.phone_digits = regexp_replace(p_phone_digits, '\D', '', 'g')
    and upper(b.code) = upper(p_code)
  limit 1;
$$;
grant execute on function public.lookup_booking(text, text) to anon, authenticated;

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
