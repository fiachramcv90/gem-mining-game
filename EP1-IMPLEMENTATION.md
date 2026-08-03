# Enhancement Pack 1 — Implementation Notes

Built against `wayfinder/enhancement-pack-1/assets/12-ep1-final-spec.md` (the
EP1 final spec) and the ⟲ amendments propagated into
`wayfinder/assets/0014-final-spec.md`. Two features slot around the shipped
Gem Miner design: a **social leaderboard** (Part I) and a **six-tool
consumable loadout** (Part II).

## What's done

### Foundation — save v4 → v5
- `SaveManager.SAVE_VERSION` 4 → 5 with a one-step, add-keys-only
  `_migrate_4_to_5`: adds `best_haul` (int), `device_id` (UUID, minted if
  absent), `nickname` (String, default derived from the device_id), and a
  `consumables` block. `total_banked` is unchanged — it stays the existing
  `MinersLog.stats["money_banked"]`. EP1 onboarding flags ride in the existing
  `nudges` dict (no extra migration). Verified: v4 saves migrate without data
  loss; v5 round-trips exactly.

### Part II — consumables (fully offline, no backend)
- **`Loadout` autoload**: the 3-slot × one-type × N-charges model. Depth-gated
  shop visibility, one-time unlock price, per-charge garage stock capped at
  `maxCharges` (drones at 2 — scarcity is not loosened). Active-slot charges
  are forfeited on a lost run; inactive garage stock is safe.
- **`ConsumablesConfig` resource**: every tuning value is a named `@export`
  knob at the spec Appendix first-draft defaults (unlock schedule/pricing,
  dynamite teardrop/fuse/self-damage, drone trip/scan, relief fractions).
- **Six tools** (`ToolRunner` + entities): dynamite (drop-at-digger, lit fuse,
  downward teardrop ignoring hardness, prize-immune, caught gems destroyed,
  proximity self-damage routed through the 0007 `apply_hazard_damage` system);
  hauler drone (dispatch cargo → bank at surface via `cargo_sold`, refuses the
  prize, self-powered, 2 trips); scout drone (tunnels to the nearest tier-4+/
  prize gem via worldgen, leaves it to mine, refuses with no lead); and
  instant flare / fuel-cell / repair-kit.
- **Corners HUD** (`ConsumablesHUD`): three top-right one-tap buttons, charge
  counts, refusal feedback, off the stick's territory.
- **Garage gear shop**: a UPGRADES | GEAR toggle inside the existing shop (no
  new hub button) — unlock, buy charges, equip up to 3.
- **Diegetic onboarding**: loadout, first-descent gear, and dynamite
  "GET CLEAR!" one-shot ghost lines (the lit fuse is the permanent teacher),
  all riding the existing `nudges` dict.

### Part I — leaderboard
- **`Leaderboard` autoload**: dual identity (durable `device_id` + lazy
  auto-nickname), the `best_haul` per-run accumulator (folds every banking
  event — surface sale and hauler mid-descent bank — order-independent),
  `total_banked` read-through, the non-persisted `scores_dirty` flag (no
  queue), and post triggers on run-complete / visibility-hidden / app-launch.
- **UX in the Miner's Log**: scope tabs (Stats / Global / Groups), metric
  toggle (best haul / total banked), always-pinned+highlighted player row,
  lazy nickname rename, join-by-Crockford-code + create-group with
  tap-to-share, a non-blocking post-run best-haul banner, and offline-normal
  reassurance.
- **Backend client**: REST via `HTTPRequest` — anonymous sign-in, the
  `submit_score` post, and gated group/board RPC + global-select reads.

### Backend (committed, not yet applied)
- `supabase/migrations/0001_ep1_leaderboard.sql`: schema (`scores` / `groups`
  / `memberships`), RLS (public-select / owner-scoped-write on `scores`;
  RPC-only `groups`/`memberships`), and the six `SECURITY DEFINER` RPCs
  (`submit_score`, `claim_row`, `create_group`, `join_group`, `my_groups`,
  `group_board`) with GREATEST monotonic writes and Crockford join codes.

## Offline posture (verified)
Everything runs fully offline. `LeaderboardConfig` ships with an empty
`project_url`, so `online_configured()` is `false`, **no `HTTPRequest` is ever
created**, the headless CI run makes no network call, and the board UI shows
local-is-truth values. A broke player always progresses by drilling + free
refuel/repair — consumables are discretionary, never mandatory.

## The one remaining manual step
**Supabase live-verify + wiring** (a documented "confirm-during-build" item,
EP1 Part IV). Apply the SQL migration to a real project and set the project
URL + anon key (via `game/config/leaderboard.tres` or the
`GEM_MINER_SUPABASE_URL` / `GEM_MINER_SUPABASE_ANON_KEY` env vars). The
anonymous-auth endpoint/body, RLS enforcement, `SECURITY DEFINER` execution,
and REST-upsert semantics were doc-confirmed but not live-tested (the Supabase
MCP was unauthenticated). Full steps in `supabase/README.md`.

## CI
All four gates pass locally against Godot 4.3: `gdlint game/`,
`gdformat --check game/`, the `--headless` Web export, and the headless run
that fails on any script/parse error. The implementation branch is added to
`.github/workflows/deploy-prototype.yml`'s push triggers so CI runs on it.
