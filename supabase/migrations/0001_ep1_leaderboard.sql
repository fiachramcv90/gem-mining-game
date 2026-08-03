-- EP1 leaderboard schema, RLS, and SECURITY DEFINER RPCs (EP1 spec L1/L2,
-- asset 02-leaderboard-data-model.md).
--
-- Trust posture: client-trusted / advisory-social. Anonymous sign-in gives
-- server-enforced per-ROW ownership (RLS), but score VALIDITY is not policed
-- (v1). submit_score is the designated future sanity-cap seam — caps and
-- rate-limits attach in that one function later, touching no client code.
--
-- Identity is dual (asset 02 §1): device_id (durable save-blob anchor, the
-- primary key) + owner = auth.uid() (the write credential). Auth-eviction
-- re-attach crosses the ownership boundary only through claim_row.
--
-- IMPORTANT — this migration is committed but NOT yet applied to a live
-- project. Applying it + wiring the URL/anon-key is the one remaining manual
-- step (EP1 Part IV "Supabase live-verify"). See supabase/README.md.

-- ============================================================================
-- Tables
-- ============================================================================

-- One row per player, globally — the canonical score (asset 02 §4).
create table if not exists public.scores (
  device_id        uuid primary key,                  -- durable anchor (save blob)
  owner            uuid not null,                      -- = auth.uid(); RLS write credential
  nickname         text not null
                     check (char_length(trim(nickname)) between 3 and 16),
  total_banked     bigint not null default 0,          -- gross lifetime banked, monotonic
  best_haul        bigint not null default 0,          -- best single surface-to-surface descent
  total_reached_at timestamptz not null default now(), -- tie-break: when total_banked last rose
  best_reached_at  timestamptz not null default now(), -- tie-break: when best_haul last rose
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()  -- debug only; NOT used for ranking
);
create unique index if not exists scores_owner_idx on public.scores (owner);
create index if not exists scores_best_idx on public.scores (best_haul desc, best_reached_at asc);
create index if not exists scores_total_idx on public.scores (total_banked desc, total_reached_at asc);

-- Friend groups. Codes are system-generated (Crockford base32), permanent.
create table if not exists public.groups (
  id         uuid primary key default gen_random_uuid(),
  join_code  text not null unique
               check (join_code ~ '^[0-9A-HJ-NP-TV-Z]{6}$'),  -- Crockford, minus I L O U
  name       text not null,
  created_by uuid not null,
  created_at timestamptz not null default now()
);

-- Many-to-many membership. Add-only for v1 (no leave/kick/delete).
create table if not exists public.memberships (
  group_id    uuid not null references public.groups(id) on delete cascade,
  score_owner uuid not null,                           -- = scores.owner (= auth.uid())
  joined_at   timestamptz not null default now(),
  primary key (group_id, score_owner)
);

-- ============================================================================
-- Row-Level Security (asset 02 §4 "RLS intent")
-- ============================================================================

alter table public.scores      enable row level security;
alter table public.groups      enable row level security;
alter table public.memberships enable row level security;

-- scores: public SELECT (any board readable); owner-scoped direct writes
-- (though the client routes writes through submit_score); no deletes.
drop policy if exists scores_select_public on public.scores;
create policy scores_select_public on public.scores for select using (true);

drop policy if exists scores_insert_own on public.scores;
create policy scores_insert_own on public.scores for insert with check (auth.uid() = owner);

drop policy if exists scores_update_own on public.scores;
create policy scores_update_own on public.scores for update
  using (auth.uid() = owner) with check (auth.uid() = owner);

-- groups + memberships: no direct access — reachable ONLY via the SECURITY
-- DEFINER RPCs below (so a non-member cannot scrape rosters or join codes).
-- Enabling RLS with zero policies denies all direct access by default.

-- ============================================================================
-- Helpers
-- ============================================================================

-- A random 6-char Crockford base32 code (alphabet minus I L O U).
create or replace function public._gen_join_code()
returns text
language plpgsql
as $$
declare
  alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  code text := '';
  i int;
begin
  for i in 1..6 loop
    code := code || substr(alphabet, 1 + floor(random() * 32)::int, 1);
  end loop;
  return code;
end;
$$;

-- ============================================================================
-- RPCs — all SECURITY DEFINER (asset 02 §4 "RPC surface")
-- ============================================================================

-- Upsert the caller's canonical score. Each metric is written with GREATEST
-- so a stale/out-of-order post can never regress a legitimate standing;
-- _reached_at is stamped only on a strict increase (the per-metric tie-break).
-- The ownership boundary holds: an existing row updates only when the caller
-- already owns it — re-attach after auth eviction goes through claim_row.
-- THIS is the sanity-cap seam (v1 does no validation).
create or replace function public.submit_score(
  p_device_id uuid, p_nickname text, p_total bigint, p_best bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.scores (
    device_id, owner, nickname, total_banked, best_haul, total_reached_at, best_reached_at
  )
  values (p_device_id, auth.uid(), p_nickname, greatest(p_total, 0), greatest(p_best, 0), now(), now())
  on conflict (device_id) do update set
    nickname         = excluded.nickname,
    total_reached_at = case when excluded.total_banked > public.scores.total_banked
                            then now() else public.scores.total_reached_at end,
    best_reached_at  = case when excluded.best_haul > public.scores.best_haul
                            then now() else public.scores.best_reached_at end,
    total_banked     = greatest(public.scores.total_banked, excluded.total_banked),
    best_haul        = greatest(public.scores.best_haul, excluded.best_haul),
    updated_at       = now()
  where public.scores.owner = auth.uid();
end;
$$;

-- Reassign a device_id row's owner to the caller (re-attach after auth
-- eviction; last-writer-wins). The only path that crosses ownership —
-- forgeable only by someone already holding your exported save (a non-threat
-- at friends scale, inside the accepted client-trusted model).
create or replace function public.claim_row(p_device_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.scores set owner = auth.uid(), updated_at = now()
  where device_id = p_device_id;
end;
$$;

-- Create a group with a unique generated code (retry on the rare collision),
-- add the creator as the first member. Client never picks the code.
create or replace function public.create_group(p_name text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
  attempts int := 0;
begin
  loop
    begin
      insert into public.groups (join_code, name, created_by)
      values (public._gen_join_code(), coalesce(nullif(trim(p_name), ''), 'Group'), auth.uid())
      returning * into g;
      exit;
    exception when unique_violation then
      attempts := attempts + 1;
      if attempts > 8 then raise; end if;
    end;
  end loop;
  insert into public.memberships (group_id, score_owner)
  values (g.id, auth.uid())
  on conflict do nothing;
  return g;
end;
$$;

-- Join a group by code — idempotent (re-join is a no-op); unknown code errors.
create or replace function public.join_group(p_code text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
begin
  select * into g from public.groups where join_code = upper(trim(p_code));
  if g.id is null then
    raise exception 'no such group';
  end if;
  insert into public.memberships (group_id, score_owner)
  values (g.id, auth.uid())
  on conflict do nothing;
  return g;
end;
$$;

-- The groups the caller belongs to (for the group-picker UI).
create or replace function public.my_groups()
returns setof public.groups
language sql
security definer
set search_path = public
as $$
  select g.* from public.groups g
  join public.memberships m on m.group_id = g.id
  where m.score_owner = auth.uid()
  order by g.created_at;
$$;

-- A group's ranked board — ONLY after verifying the caller is a member (the
-- one way to read a group roster; a non-member gets nothing).
create or replace function public.group_board(p_group_id uuid)
returns table (nickname text, total_banked bigint, best_haul bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.memberships
    where group_id = p_group_id and score_owner = auth.uid()
  ) then
    raise exception 'not a member';
  end if;
  return query
    select s.nickname, s.total_banked, s.best_haul
    from public.scores s
    join public.memberships m on m.score_owner = s.owner
    where m.group_id = p_group_id
    order by s.best_haul desc, s.best_reached_at asc;
end;
$$;

-- ============================================================================
-- Grants — anon + authenticated may call the RPCs (definer rights inside)
-- ============================================================================

grant execute on function public.submit_score(uuid, text, bigint, bigint) to anon, authenticated;
grant execute on function public.claim_row(uuid)          to anon, authenticated;
grant execute on function public.create_group(text)       to anon, authenticated;
grant execute on function public.join_group(text)         to anon, authenticated;
grant execute on function public.my_groups()              to anon, authenticated;
grant execute on function public.group_board(uuid)        to anon, authenticated;

-- The global board is a plain PostgREST select on public.scores (public RLS).
grant select on public.scores to anon, authenticated;
