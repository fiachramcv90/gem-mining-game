# EP1-02 — Leaderboard data model, identity & schema

**Ticket:** [#39](https://github.com/fiachramcv90/gem-mining-game/issues/39) · **Map:** [#37](https://github.com/fiachramcv90/gem-mining-game/issues/37) · **Builds on:** [#38 Supabase viability — GO](https://github.com/fiachramcv90/gem-mining-game/issues/38)

The concrete "how scores are stored and shared" decision for Enhancement Pack 1's leaderboard: identity, the two boards' metrics, the schema, RLS/trust posture, and the join-by-code flow. Everything here stands on the documented Supabase behavior confirmed in #38 — see the **Pre-implementation checkpoint** at the end for what still needs live verification.

---

## 1. Identity — dual anchor

Two identifiers, split by duty:

| Identifier | What it is | Role |
| --- | --- | --- |
| `device_id` (UUID) | Self-generated, stored in the [save blob](https://github.com/fiachramcv90/gem-mining-game/blob/main/wayfinder/tickets/0009-save-system.md) | **Durable identity anchor** — the source of truth for "who am I", survives auth-cache eviction |
| `owner` (= `auth.uid()`) | Supabase **anonymous sign-in** (`signInAnonymously()`) | **Write credential** — drives RLS; proves "I may write this row" |

**Why both** (renegotiates #39's original device-UUID-only bullet, per #38's anonymous-auth upgrade): anonymous auth gives real, server-enforced per-row *ownership* at zero infra cost — strictly better than a client-body UUID for the *write* path. But the anon session (JWT + refresh token) lives in evictable web storage (WebKit's 7-day no-interaction cap, per 0009), while the save blob persists independently. A pure-`auth.uid()` identity would make leaderboard standing *more* fragile than the local save — wrong for a sporadically-played friends board. So the save blob's `device_id` remains the anchor; `auth.uid()` is layered on for server-enforced ownership.

**Re-attach after auth eviction.** On startup: anon sign-in → fresh `auth.uid()`. If the save blob still carries an old `device_id` whose `scores` row is owned by a now-gone `auth.uid()`, the client calls **`claim_row(device_id)`** (SECURITY DEFINER RPC) to reassign that row's `owner` to the caller. This is the *only* path that crosses an ownership boundary — direct table `update` stays strictly `auth.uid() = owner`. Semantics: **last-writer-wins on `device_id`** (whoever most recently ran the game with that save owns the row — correct for export/import to a new device). Forgeable only by someone already holding your exported save file → a non-threat at friends scale, inside the accepted client-trusted model.

### Nickname

- Lives **on the `scores` row** (denormalized — one nickname per player, no other player attributes, so no separate `players` table).
- **3–16 characters**, Unicode letters/digits/spaces/basic punctuation, trimmed; empty/whitespace-only rejected. Client-enforced **and** a server-side `CHECK` on length so a forged blank can't land.
- **Not unique** — two players can both be "Dave"; identity is the `device_id`, the nickname is a display label. No reservation/landgrab.
- **Editable anytime**, in place, no history.
- **No v1 profanity filter** (friends scale, self-selected groups) → *fog*.

---

## 2. The two boards — metric definitions

Both metrics are **columns on the single `scores` row**. A board is a **sort on one column**, never a copy.

### `total_banked` — lifetime banked (career/dedication)
- Cumulative sum of every amount ever **banked** (secured via ascent — per the shipped loop, *carried = at risk, banked = safe*) over the player's whole history.
- **Gross, not net of shop spending** — buying consumables/upgrades never lowers your rank. Spending is progress, not a penalty.
- **Monotonic** — only ever increases; updated in place.
- Rank: `total_banked DESC`, tie-break `total_reached_at ASC` (first to reach the value ranks higher).

### `best_haul` — best single descent (skill/greed)
- The largest amount banked from a **single surface-to-surface descent** — one dive from the surface until the player next returns to the surface (self-ascent, hoist, or hauler). *Not* session-until-quit — surface-to-surface rewards the core bank-now-vs-push-deeper risk/greed tension the game is built on.
- Raised only when a new descent beats the stored max. A **lost** descent banks nothing → cannot set a best-haul.
- Rank: `best_haul DESC`, tie-break `best_reached_at ASC`.

### Integrity — monotonic, never regress
`submit_score` writes each metric as `GREATEST(existing, incoming)`, so a stale device (old save re-imported, or an out-of-order retry after the Supabase auto-pause outage) can never *lower* a legitimately-earned standing. A forged huge value is "sticky" — fine, inside the accepted threat model. This is data integrity, **not** anti-cheat.

Because the two metrics rise at different moments, **one timestamp can't serve both tie-breaks** → two columns, `total_reached_at` / `best_reached_at`, each stamped only when *that* metric strictly increases. A generic `updated_at` stays for debugging only (not used for ranking).

---

## 3. Board scope — one canonical score, N views

- **Score stored once per player, globally.** Groups are pure membership; a board is who you're ranked *against*, not a separate copy of your number. Joining a new group is free (no score copy); one `submit_score` updates your standing on every board at once.
- **Global board** = `scores ORDER BY <metric> DESC LIMIT N` (degenerate "everyone" view).
- **Group board** = `scores` for the group's members, served by the `group_board(group_id)` RPC (see §4 — membership tables aren't directly selectable).
- Many-to-many membership: a player in three groups has three `memberships` rows, still **one** `scores` row.

---

## 4. Schema

```sql
-- One row per player, globally. The canonical score.
create table scores (
  device_id        uuid primary key,                 -- durable anchor (from save blob)
  owner            uuid not null,                     -- = auth.uid(); RLS write credential
  nickname         text not null check (char_length(trim(nickname)) between 3 and 16),
  total_banked     bigint not null default 0,         -- gross lifetime banked, monotonic
  best_haul        bigint not null default 0,         -- best single surface-to-surface descent
  total_reached_at timestamptz not null default now(),-- when total_banked last increased (tie-break)
  best_reached_at  timestamptz not null default now(),-- when best_haul last increased (tie-break)
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now() -- generic row-touch; NOT used for ranking
);
create unique index scores_owner_idx on scores (owner);

-- Friend groups. Codes are system-generated, permanent.
create table groups (
  id         uuid primary key default gen_random_uuid(),
  join_code  text not null unique
               check (join_code ~ '^[0-9A-HJ-NP-TV-Z]{6}$'),  -- Crockford base32, minus I L O U
  name       text not null,                                   -- cosmetic, not unique
  created_by uuid not null,                                    -- = auth.uid() of creator
  created_at timestamptz not null default now()
);

-- Many-to-many membership. Add-only for v1.
create table memberships (
  group_id    uuid not null references groups(id),
  score_owner uuid not null,                          -- = scores.owner
  joined_at   timestamptz not null default now(),
  primary key (group_id, score_owner)
);
```

### RLS intent (locked-down posture)

| Table | `select` | `insert` / `update` | `delete` |
| --- | --- | --- | --- |
| `scores` | **public** (any board readable) | **owner-scoped** (`auth.uid() = owner`); writes go through `submit_score` RPC; cross-owner claim via `claim_row` | **none** — boards stay stable |
| `groups` | **none direct** — access only via RPC | only via `create_group` RPC | none |
| `memberships` | **none direct** — access only via RPC | only via `join_group` RPC | none (add-only) |

**Locked-down consequence:** rendering a group board is an RPC call (`group_board`), not a raw join — a non-member cannot read a group's roster or scrape join codes at all. This closes the "code confidentiality" concern by construction rather than parking it as fog.

### RPC surface (all `SECURITY DEFINER`)

| RPC | Does | Notes |
| --- | --- | --- |
| `submit_score(total, best)` | Upsert caller's `scores` row; each metric `GREATEST(existing, incoming)`; stamp `_reached_at` on strict increase | **The future sanity-cap seam** — v1 does no validation; caps/rate-limits attach here later, touching one function not the client |
| `set_nickname(name)` | Update caller's nickname in place | Or fold into `submit_score` |
| `claim_row(device_id)` | Reassign a `device_id` row's `owner` to the caller | Re-attach after auth eviction; last-writer-wins |
| `create_group(name)` | Generate a random unique `join_code` (retry on collision), insert group, add creator to `memberships` | Client never picks the code |
| `join_group(code)` | Look up group by code, insert caller's `memberships` row | **Idempotent** (re-join = no-op); unknown code → clean "no such group" error |
| `my_groups()` | Return metadata (name, id) for groups the caller belongs to | For the group-picker UI |
| `group_board(group_id)` | Ranked scores for a group **after verifying caller is a member** | The only way to read a group board |

---

## 5. Join-by-code flow

- **Code format:** 6 chars, **Crockford base32** (`0-9A-Z` minus `I L O U`), stored uppercase, case-insensitive on entry. ~1 billion codes — collision-safe, short enough to read aloud/text. e.g. `K7Q2Z9`.
- **Generation:** `create_group` generates + checks against the `unique` constraint, retrying on the rare collision. Client never picks.
- **Join:** `join_group(code)` — idempotent, unknown code → clean error.
- **Names** creator-supplied, cosmetic, non-unique.
- **Membership add-only** for v1 — **no leave / kick / delete**. Leaving a group → *fog* (nobody's clamoring to leave "The Lads" at friends scale).
- **Codes permanent** — a friend group is long-lived; expiry adds a lifecycle nobody asked for.

---

## 6. Trust model

**Client-trusted for v1 — advisory/social, forgeable by design** (confirms the map's standing principle; mirrors the shipped "milestones are honorific-only" line).

- The client computes `total_banked`/`best_haul` locally from the save blob and submits them. The server does **zero** validation of physical achievability. Anyone with the REST endpoint + their own JWT can PATCH arbitrary numbers onto **their own** row.
- This is **intended** at friends scale — the fun is comparing, not policing. Nothing downstream may assume scores are trustworthy.
- **The forge surface, recorded so nothing assumes trust:** own-row write via `submit_score`. It cannot silently overwrite a *stranger's* score (RLS owner-scoping + `claim_row` needing the device_id).
- **Where hardening later attaches (fog, not v1):** `submit_score` is a designated seam — server-side sanity caps (reject physically-impossible ceilings, rate-limit jumps) drop into that one function *if* a public global board ever attracts griefers. Routing writes through it now (a no-op passthrough) means later hardening touches **one function, not the client**.

---

## 7. First-run bootstrap

Respects the shipped near-zero-modal onboarding ([0013](https://github.com/fiachramcv90/gem-mining-game/blob/main/wayfinder/tickets/0013-tutorial-onboarding.md)):

- **No nickname prompt on first launch.** A default nickname is auto-assigned (e.g. `Miner-4F2A` from the `device_id`).
- **Lazy row creation** — no `scores` row exists until the **first bank event** produces a real number to post. No empty/zero rows from people who launched once and never banked.
- The player is invited to set a real nickname the first time they open the leaderboard screen — teaching stays diegetic and deferred.
- The precise onboarding **copy/trigger** is map fog ("Onboarding/nudges for new tools & board"); this asset fixes only the **mechanism**.

---

## 8. Integration posture (from #38, carried here)

- **REST via Godot `HTTPRequest`** — dependency-free, thread-free, works in single-threaded WebGL2, needs no COOP/COEP headers. Writes go through the RPCs (POST to `/rest/v1/rpc/<fn>`); reads (global board, own row) are PostgREST selects on `scores`.
- **Auto-pause degradation is #40's job.** Free Supabase projects auto-pause after ~1 week idle → the board can be silently "down" after a quiet week. The client must degrade gracefully (local-only fallback + retry, maybe keep-warm ping). This asset's `GREATEST` monotonic writes make out-of-order retry-after-outage safe by construction; the offline UX/posture is specified in [#40](https://github.com/fiachramcv90/gem-mining-game/issues/40).

---

## Fog handed to the map

- **Leave / kick / delete group** — membership is add-only in v1; graduates if group churn ever matters.
- **Profanity filter on nicknames** — graduates alongside a public global board.
- **CAPTCHA / bot-hardening on anon sign-in** — the #38-recommended Turnstile is **out of v1** (friction on a friends-scale, client-trusted board; the mass-fake-row scenario it guards is already parked fog). Graduates alongside the anti-cheat-caps fog if a public global board is abused.
- (Already resolved by design, not fog: **join-code confidentiality** — closed by the locked-down RLS + `group_board` RPC.)

## Pre-implementation checkpoint (blocks the migration, not this design)

The #38 research marked several primitives *"(verify live)"* to be confirmed against the Supabase MCP during this ticket. **The Supabase MCP was unauthenticated in the design session, so these remain doc-confirmed but not live-tested:**

- `signInAnonymously()` issuing a usable `auth.uid()` over REST.
- RLS `auth.uid() = owner` enforcement on `scores` writes.
- `SECURITY DEFINER` RPCs (`join_group`, `create_group`, `claim_row`, `submit_score`, `group_board`, `my_groups`) executing with definer rights without recursive-policy errors.
- REST upsert semantics for the one-row-per-owner path.

**Before writing the migration:** authenticate the Supabase MCP (or use a scratch project) and confirm the above. The schema/identity/trust *design* stands on documented behavior and is not blocked; only the implementation step gates on this check.
