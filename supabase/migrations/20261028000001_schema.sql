-- Skyltstudio: core schema.
-- Content of a screen (draft and published) is stored as JSON:
--   { "template": "menu-8", "theme": "halloween" | null, "fields": { ...per field_schema... } }
-- so that changing template or theme is also a draft until it is published.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Catalog (managed by superadmin)
-- ---------------------------------------------------------------------------

create table public.packages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  colors jsonb not null default '{}'::jsonb,   -- e.g. {"primary":"#1f3d33","accent":"#e3b45c","paper":"#f6efe3"}
  fonts jsonb not null default '{}'::jsonb,    -- e.g. {"heading":"Young Serif","body":"DM Sans"}
  logo_url text,
  created_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  package_id uuid references public.packages (id) on delete set null,
  max_screens int not null default 3 check (max_screens >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.templates (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  -- 'any' = the template has both a landscape and a portrait layout
  orientation text not null default 'any' check (orientation in ('landscape', 'portrait', 'any')),
  field_schema jsonb not null default '{"fields":[]}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.themes (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  default_start text check (default_start ~ '^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'),
  default_end text check (default_end ~ '^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'),
  created_at timestamptz not null default now()
);

create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  template_id uuid references public.templates (id) on delete cascade,
  theme_id uuid references public.themes (id) on delete cascade,
  created_at timestamptz not null default now(),
  check (num_nonnulls(template_id, theme_id) = 1)
);
create unique index entitlements_template_uq on public.entitlements (organization_id, template_id) where template_id is not null;
create unique index entitlements_theme_uq on public.entitlements (organization_id, theme_id) where theme_id is not null;

-- ---------------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------------

create type public.user_role as enum ('superadmin', 'org_admin', 'editor');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  organization_id uuid references public.organizations (id) on delete cascade,
  role public.user_role not null default 'editor',
  email text,
  created_at timestamptz not null default now(),
  -- everyone except superadmin belongs to exactly one organization
  check (role = 'superadmin' or organization_id is not null)
);
create index profiles_org_idx on public.profiles (organization_id);

-- ---------------------------------------------------------------------------
-- Customer data
-- ---------------------------------------------------------------------------

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);
create index locations_org_idx on public.locations (organization_id);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  price numeric(10, 2) not null check (price >= 0),
  campaign_price numeric(10, 2) check (campaign_price >= 0),
  image_url text,
  category text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index products_org_idx on public.products (organization_id, sort_order);

create table public.screens (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  location_id uuid references public.locations (id) on delete set null,
  name text not null check (char_length(name) between 1 and 40),
  orientation text not null default 'landscape' check (orientation in ('landscape', 'portrait')),
  draft_content jsonb not null default '{}'::jsonb,
  published_content jsonb,
  layout jsonb not null default '{"x":0,"y":0}'::jsonb,
  sort_order int not null default 0,
  last_seen_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index screens_org_idx on public.screens (organization_id, sort_order);

-- Device secrets live in their own table that no logged-in user can read
-- (RLS on, no policies). Only server code with the service role touches it.
create table public.screen_devices (
  screen_id uuid primary key references public.screens (id) on delete cascade,
  device_token_hash text not null unique,
  paired_at timestamptz not null default now()
);

create table public.schedules (
  id uuid primary key default gen_random_uuid(),
  screen_id uuid not null references public.screens (id) on delete cascade,
  template_id uuid references public.templates (id) on delete cascade,
  theme_id uuid references public.themes (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  weekdays int[] not null default '{1,2,3,4,5,6,7}',  -- ISO weekdays, 1 = Monday
  created_at timestamptz not null default now(),
  check (num_nonnulls(template_id, theme_id) = 1),
  check (ends_at > starts_at),
  check (weekdays <@ '{1,2,3,4,5,6,7}'::int[])
);
create index schedules_screen_idx on public.schedules (screen_id);

-- keep updated_at fresh
create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger products_touch before update on public.products
  for each row execute function public.touch_updated_at();
create trigger screens_touch before update on public.screens
  for each row execute function public.touch_updated_at();
