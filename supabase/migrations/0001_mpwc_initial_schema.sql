-- ============================================================================
-- Mat Pilates with Caroline — initial schema (Caroline's OWN Supabase project)
-- Wave A of the membership backend. Videos stay in PXE's public bucket;
-- THIS project holds only accounts + entitlements + progress + admin.
-- Prefix everything `mpwc_` so the project stays clean if ever reused.
-- ============================================================================

-- 1) Profiles: one row per auth user, auto-created on signup --------------
create table if not exists public.mpwc_profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  full_name   text,
  created_at  timestamptz not null default now()
);

-- 2) Entitlements: what each user has paid/been granted access to ---------
--    kind = 'week' | 'day' | 'bundle';  ref = week number / day number / null
create table if not exists public.mpwc_entitlements (
  id           bigint generated always as identity primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  kind         text not null check (kind in ('week','day','bundle')),
  ref          int,
  amount_cents int  not null default 0,
  granted_by   text,                 -- admin email who granted (Venmo manual)
  created_at   timestamptz not null default now()
);
-- one entitlement per (user, kind, ref); coalesce(ref,-1) so NULL is unique
create unique index if not exists mpwc_entitlements_unique
  on public.mpwc_entitlements (user_id, kind, coalesce(ref, -1));

-- 3) Progress: which days a user has completed ---------------------------
create table if not exists public.mpwc_progress (
  user_id      uuid not null references auth.users(id) on delete cascade,
  day          int  not null,
  completed_at timestamptz not null default now(),
  primary key (user_id, day)
);

-- 4) Admin check: read email from the JWT (NO table lookup -> no RLS recursion)
create or replace function public.mpwc_is_admin()
returns boolean
language sql stable
as $$
  select coalesce(
    (auth.jwt() ->> 'email') in (
      'andresescobedolara@gmail.com'
      -- , 'caroline@...'   <-- add Caroline's login email here
    ),
    false
  );
$$;

-- 5) Auto-create profile on new auth user --------------------------------
--    SECURITY DEFINER + swallow errors (shared auth pool best practice)
create or replace function public.mpwc_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.mpwc_profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
exception when others then
  return new;  -- never block signup
end;
$$;

drop trigger if exists mpwc_on_auth_user_created on auth.users;
create trigger mpwc_on_auth_user_created
  after insert on auth.users
  for each row execute function public.mpwc_handle_new_user();

-- 6) Row Level Security --------------------------------------------------
alter table public.mpwc_profiles     enable row level security;
alter table public.mpwc_entitlements enable row level security;
alter table public.mpwc_progress     enable row level security;

-- profiles: a user sees/edits own row; admin sees all
create policy mpwc_profiles_self on public.mpwc_profiles
  for select using (id = auth.uid() or public.mpwc_is_admin());
create policy mpwc_profiles_self_upd on public.mpwc_profiles
  for update using (id = auth.uid());

-- entitlements: user reads own; ONLY admin writes (grant/revoke after Venmo)
create policy mpwc_ent_read on public.mpwc_entitlements
  for select using (user_id = auth.uid() or public.mpwc_is_admin());
create policy mpwc_ent_admin_write on public.mpwc_entitlements
  for all using (public.mpwc_is_admin()) with check (public.mpwc_is_admin());

-- progress: user reads/writes own; admin reads all
create policy mpwc_prog_self on public.mpwc_progress
  for select using (user_id = auth.uid() or public.mpwc_is_admin());
create policy mpwc_prog_self_write on public.mpwc_progress
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 7) Admin overview view -- security_invoker so RLS of the caller applies
create or replace view public.mpwc_admin_overview
with (security_invoker = true) as
select
  p.id,
  p.email,
  p.full_name,
  p.created_at,
  count(distinct e.id)                                    as entitlements,
  coalesce(sum(e.amount_cents), 0)                        as revenue_cents,
  count(distinct pr.day)                                  as days_completed
from public.mpwc_profiles p
left join public.mpwc_entitlements e on e.user_id = p.id
left join public.mpwc_progress     pr on pr.user_id = p.id
group by p.id, p.email, p.full_name, p.created_at;
