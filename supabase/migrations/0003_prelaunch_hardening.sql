-- ============================================================================
-- 0003: pre-launch hardening (defense-in-depth; no behavior change for users)
-- ============================================================================

-- Progress: only accept valid day numbers (1..30). Stops garbage rows; access
-- is read from entitlements, not progress, so this is data-integrity only.
alter table public.mpwc_progress
  drop constraint if exists mpwc_progress_day_range;
alter table public.mpwc_progress
  add constraint mpwc_progress_day_range check (day between 1 and 30);

-- Payment claims: a member may only self-insert a PENDING claim. Blocks forged
-- status='granted'/junk rows at the DB (entitlements are independently
-- admin-gated, so this was inert, but tighten anyway).
drop policy if exists mpwc_claims_self_insert on public.mpwc_payment_claims;
create policy mpwc_claims_self_insert on public.mpwc_payment_claims
  for insert with check (user_id = auth.uid() and status = 'pending');
