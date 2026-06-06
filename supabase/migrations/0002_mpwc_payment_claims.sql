-- ============================================================================
-- Payment claims: capture EXACTLY what the client selected at the moment they
-- click "Pay with Venmo", so the admin can confirm the Venmo transfer and grant
-- the matching access with one click.
-- ============================================================================
create table if not exists public.mpwc_payment_claims (
  id           bigint generated always as identity primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  plan         text not null check (plan in ('alacarte','weekly','bundle')),
  week         int,            -- for 'weekly'   (2 | 3 | 4)
  days         int[],          -- for 'alacarte' (e.g. {8,9,15})
  amount_cents int  not null default 0,
  method       text,           -- 'venmo' | 'paypal'
  note         text,
  status       text not null default 'pending' check (status in ('pending','granted','rejected')),
  created_at   timestamptz not null default now()
);

alter table public.mpwc_payment_claims enable row level security;

-- user creates/reads own claims; admin reads + updates all (approve/reject)
create policy mpwc_claims_self_read on public.mpwc_payment_claims
  for select using (user_id = auth.uid() or public.mpwc_is_admin());
create policy mpwc_claims_self_insert on public.mpwc_payment_claims
  for insert with check (user_id = auth.uid());
create policy mpwc_claims_admin_update on public.mpwc_payment_claims
  for update using (public.mpwc_is_admin()) with check (public.mpwc_is_admin());

create index if not exists mpwc_payment_claims_status_idx
  on public.mpwc_payment_claims (status, created_at desc);
