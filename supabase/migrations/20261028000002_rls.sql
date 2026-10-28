-- Skyltstudio: access rules.
-- All authorization lives here, in the database, so a bug in the UI can never
-- expose another customer's data.

-- ---------------------------------------------------------------------------
-- Helper functions (security definer so they can read profiles without
-- tripping over profiles' own RLS policies)
-- ---------------------------------------------------------------------------

create function public.auth_role() returns public.user_role
language sql stable security definer set search_path = '' as $$
  select p.role from public.profiles p where p.id = auth.uid()
$$;

create function public.is_superadmin() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select p.role = 'superadmin' from public.profiles p where p.id = auth.uid()), false)
$$;

-- The caller's organization, or null if they have none or it is deactivated.
create function public.auth_org_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select p.organization_id
  from public.profiles p
  join public.organizations o on o.id = p.organization_id
  where p.id = auth.uid() and o.is_active
$$;

create function public.is_org_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select public.auth_org_id() is not null and public.auth_role() = 'org_admin'
$$;

-- ---------------------------------------------------------------------------
-- New users: the profile is created from app_metadata, which only the server
-- (service role) can set. user_metadata is ignored because users control it.
-- ---------------------------------------------------------------------------

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  meta jsonb := coalesce(new.raw_app_meta_data, '{}'::jsonb);
  wanted_role public.user_role := coalesce(nullif(meta ->> 'role', ''), 'editor')::public.user_role;
  org uuid := nullif(meta ->> 'organization_id', '')::uuid;
begin
  -- an account without organization that isn't superadmin gets no profile, hence no access
  if wanted_role <> 'superadmin' and org is null then
    return new;
  end if;
  insert into public.profiles (id, organization_id, role, email)
  values (new.id, case when wanted_role = 'superadmin' then null else org end, wanted_role, new.email);
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Guards that RLS alone cannot express (comparing old and new values)
-- ---------------------------------------------------------------------------

-- Only superadmin may move people between organizations or make superadmins.
create function public.guard_profiles() returns trigger
language plpgsql set search_path = '' as $$
begin
  if auth.uid() is null or public.is_superadmin() then
    return new;
  end if;
  if new.organization_id is distinct from old.organization_id then
    raise exception 'Du kan inte flytta en användare till en annan organisation';
  end if;
  if new.role = 'superadmin' then
    raise exception 'Otillåten roll';
  end if;
  if new.id = auth.uid() and new.role is distinct from old.role then
    raise exception 'Du kan inte ändra din egen roll';
  end if;
  return new;
end $$;

create trigger profiles_guard before update on public.profiles
  for each row execute function public.guard_profiles();

-- Template and theme in a screen's content must be ones the organization has.
create function public.assert_content_allowed(org uuid, content jsonb) returns void
language plpgsql stable security definer set search_path = '' as $$
declare
  tpl text := content ->> 'template';
  thm text := nullif(content ->> 'theme', '');
begin
  if tpl is not null and not exists (
    select 1 from public.entitlements e join public.templates t on t.id = e.template_id
    where e.organization_id = org and t.key = tpl
  ) then
    raise exception 'Mallen "%" ingår inte i ert paket', tpl;
  end if;
  if thm is not null and not exists (
    select 1 from public.entitlements e join public.themes t on t.id = e.theme_id
    where e.organization_id = org and t.key = thm
  ) then
    raise exception 'Temat "%" ingår inte i ert paket', thm;
  end if;
end $$;

create function public.guard_screens() returns trigger
language plpgsql set search_path = '' as $$
declare
  n int;
begin
  if tg_op = 'INSERT' then
    select count(*) into n from public.screens where organization_id = new.organization_id;
    if n >= (select max_screens from public.organizations where id = new.organization_id) then
      raise exception 'Ert paket tillåter inte fler skärmar';
    end if;
    perform public.assert_content_allowed(new.organization_id, new.draft_content);
    return new;
  end if;

  if new.organization_id is distinct from old.organization_id and auth.uid() is not null and not public.is_superadmin() then
    raise exception 'En skärm kan inte flyttas till en annan organisation';
  end if;

  if new.draft_content is distinct from old.draft_content then
    perform public.assert_content_allowed(new.organization_id, new.draft_content);
  end if;

  -- Editors change content (products, prices, campaigns) and nothing else.
  if public.auth_role() = 'editor' then
    if new.name is distinct from old.name
       or new.location_id is distinct from old.location_id
       or new.layout is distinct from old.layout
       or new.sort_order is distinct from old.sort_order
       or (new.draft_content ->> 'template') is distinct from (old.draft_content ->> 'template')
       or (new.draft_content ->> 'theme') is distinct from (old.draft_content ->> 'theme') then
      raise exception 'Din roll får bara ändra innehåll, priser och kampanjer';
    end if;
  end if;
  return new;
end $$;

create trigger screens_guard before insert or update on public.screens
  for each row execute function public.guard_screens();

-- ---------------------------------------------------------------------------
-- Publishing: copies draft to published. published_content cannot be written
-- directly by users (see column grants below), only through this function.
-- ---------------------------------------------------------------------------

create function public.publish_screens(screen_ids uuid[]) returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if auth.uid() is null then
    raise exception 'Inte inloggad';
  end if;
  if exists (
    select 1 from public.screens s
    where s.id = any (screen_ids)
      and not (public.is_superadmin() or s.organization_id = public.auth_org_id())
  ) then
    raise exception 'Du har inte behörighet till alla valda skärmar';
  end if;

  update public.screens s
  set published_content = s.draft_content, published_at = now()
  where s.id = any (screen_ids)
    and s.published_content is distinct from s.draft_content;
  get diagnostics n = row_count;
  return n;
end $$;

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------

-- Anonymous visitors (the players) never read tables directly; they go through
-- server functions that check a device token.
revoke all on all tables in schema public from anon;
revoke all on all functions in schema public from anon, public;

grant execute on function public.auth_role(), public.is_superadmin(), public.auth_org_id(),
  public.is_org_admin(), public.assert_content_allowed(uuid, jsonb),
  public.publish_screens(uuid[]) to authenticated;

-- Screens: users may change these columns only. published_content and
-- last_seen_at are written by publish_screens() and the server.
revoke insert, update on public.screens from authenticated;
grant insert (organization_id, location_id, name, orientation, draft_content, layout, sort_order)
  on public.screens to authenticated;
grant update (location_id, name, draft_content, layout, sort_order)
  on public.screens to authenticated;

revoke all on public.screen_devices from authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.packages enable row level security;
alter table public.organizations enable row level security;
alter table public.templates enable row level security;
alter table public.themes enable row level security;
alter table public.entitlements enable row level security;
alter table public.profiles enable row level security;
alter table public.locations enable row level security;
alter table public.products enable row level security;
alter table public.screens enable row level security;
alter table public.screen_devices enable row level security;
alter table public.schedules enable row level security;

-- packages: your own organization's package
create policy packages_select on public.packages for select to authenticated
  using ((select public.is_superadmin())
         or id = (select o.package_id from public.organizations o where o.id = (select public.auth_org_id())));
create policy packages_admin on public.packages for all to authenticated
  using ((select public.is_superadmin())) with check ((select public.is_superadmin()));

-- organizations: read your own; only superadmin changes them (max_screens etc.)
create policy organizations_select on public.organizations for select to authenticated
  using ((select public.is_superadmin()) or id = (select public.auth_org_id()));
create policy organizations_admin on public.organizations for all to authenticated
  using ((select public.is_superadmin())) with check ((select public.is_superadmin()));

-- templates and themes: only those your organization is entitled to
create policy templates_select on public.templates for select to authenticated
  using ((select public.is_superadmin()) or exists (
    select 1 from public.entitlements e
    where e.template_id = templates.id and e.organization_id = (select public.auth_org_id())));
create policy templates_admin on public.templates for all to authenticated
  using ((select public.is_superadmin())) with check ((select public.is_superadmin()));

create policy themes_select on public.themes for select to authenticated
  using ((select public.is_superadmin()) or exists (
    select 1 from public.entitlements e
    where e.theme_id = themes.id and e.organization_id = (select public.auth_org_id())));
create policy themes_admin on public.themes for all to authenticated
  using ((select public.is_superadmin())) with check ((select public.is_superadmin()));

create policy entitlements_select on public.entitlements for select to authenticated
  using ((select public.is_superadmin()) or organization_id = (select public.auth_org_id()));
create policy entitlements_admin on public.entitlements for all to authenticated
  using ((select public.is_superadmin())) with check ((select public.is_superadmin()));

-- profiles: yourself and colleagues; org_admin manages colleagues
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid())
         or (select public.is_superadmin())
         or organization_id = (select public.auth_org_id()));
create policy profiles_update on public.profiles for update to authenticated
  using ((select public.is_superadmin())
         or ((select public.is_org_admin()) and organization_id = (select public.auth_org_id())))
  with check ((select public.is_superadmin())
         or ((select public.is_org_admin()) and organization_id = (select public.auth_org_id())));
create policy profiles_delete on public.profiles for delete to authenticated
  using ((select public.is_superadmin())
         or ((select public.is_org_admin()) and organization_id = (select public.auth_org_id())
             and id <> (select auth.uid())));
create policy profiles_insert on public.profiles for insert to authenticated
  with check ((select public.is_superadmin()));

-- locations: read for everyone in the org, changes by org_admin
create policy locations_select on public.locations for select to authenticated
  using ((select public.is_superadmin()) or organization_id = (select public.auth_org_id()));
create policy locations_write on public.locations for all to authenticated
  using ((select public.is_superadmin())
         or ((select public.is_org_admin()) and organization_id = (select public.auth_org_id())))
  with check ((select public.is_superadmin())
         or ((select public.is_org_admin()) and organization_id = (select public.auth_org_id())));

-- products: everyone in the org (editor and org_admin) may manage them
create policy products_select on public.products for select to authenticated
  using ((select public.is_superadmin()) or organization_id = (select public.auth_org_id()));
create policy products_write on public.products for all to authenticated
  using ((select public.is_superadmin()) or organization_id = (select public.auth_org_id()))
  with check ((select public.is_superadmin()) or organization_id = (select public.auth_org_id()));

-- screens: everyone in the org reads and edits content (editor limits enforced
-- by guard_screens); org_admin adds and removes
create policy screens_select on public.screens for select to authenticated
  using ((select public.is_superadmin()) or organization_id = (select public.auth_org_id()));
create policy screens_update on public.screens for update to authenticated
  using ((select public.is_superadmin()) or organization_id = (select public.auth_org_id()))
  with check ((select public.is_superadmin()) or organization_id = (select public.auth_org_id()));
create policy screens_insert on public.screens for insert to authenticated
  with check ((select public.is_superadmin())
         or ((select public.is_org_admin()) and organization_id = (select public.auth_org_id())));
create policy screens_delete on public.screens for delete to authenticated
  using ((select public.is_superadmin())
         or ((select public.is_org_admin()) and organization_id = (select public.auth_org_id())));

-- screen_devices: no policies on purpose = no access for logged-in users

-- schedules: read for the org, changes by org_admin
create policy schedules_select on public.schedules for select to authenticated
  using ((select public.is_superadmin()) or exists (
    select 1 from public.screens s
    where s.id = schedules.screen_id and s.organization_id = (select public.auth_org_id())));
create policy schedules_write on public.schedules for all to authenticated
  using ((select public.is_superadmin()) or ((select public.is_org_admin()) and exists (
    select 1 from public.screens s
    where s.id = schedules.screen_id and s.organization_id = (select public.auth_org_id()))))
  with check ((select public.is_superadmin()) or ((select public.is_org_admin()) and exists (
    select 1 from public.screens s
    where s.id = schedules.screen_id and s.organization_id = (select public.auth_org_id()))));
