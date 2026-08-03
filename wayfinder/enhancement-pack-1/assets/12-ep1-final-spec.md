# Gem Miner — Enhancement Pack 1: Final Design & Technical Specification

_The assembled EP1 spec ([#48](https://github.com/fiachramcv90/gem-mining-game/issues/48)). Compiles the [EP1 map](https://github.com/fiachramcv90/gem-mining-game/issues/37)'s eleven decisions (#38–#47, #51) into one build-ready document, in the shape of the shipped [Final Design & Technical Specification](../../assets/0014-final-spec.md). Enhancement Pack 1 = a **social leaderboard** + a **six-tool consumable loadout**, slotting around the shipped design and renegotiating it only where recorded below._

> **Reads as one design with the shipped spec.** The shipped-spec sections this pack amends have been propagated in place (see §E); the two documents are meant to be read together. Every EP1 value is a named `@export` knob (Appendix).

---

# Part I — Leaderboard

## L1. Backend — [#38](https://github.com/fiachramcv90/gem-mining-game/issues/38)
Supabase free tier, **anonymous sign-in** keyed on `auth.uid()` (server-enforced per-row ownership; score *validity* stays client-trusted). RLS: `scores` public-select / owner-scoped-write; `groups`+`memberships` reachable only via `SECURITY DEFINER` RPCs. Integrated by **REST via Godot `HTTPRequest`** — no COOP/COEP headers, so the single-threaded web export (§11 shipped) is untouched. **Free projects auto-pause after ~1 week idle** → the client must degrade gracefully (§L4). _Detail: [research on branch `research/ep1-supabase-viability`]._

## L2. Data model, identity & schema — [#39](https://github.com/fiachramcv90/gem-mining-game/issues/39)
- **Dual identity:** `device_id` UUID (durable save-blob anchor) + anonymous `auth.uid()` (write credential). Auth-eviction re-attach via `claim_row(device_id)` SECURITY DEFINER RPC (last-writer-wins).
- **Two boards, one canonical `scores` row:** `total_banked` (gross lifetime, monotonic) + `best_haul` (best single surface-to-surface descent), both `bigint`, written with `GREATEST` (never regress), per-metric `_reached_at` tie-break.
- **Scope:** `scores` (1 row/player) + `groups` + `memberships` (M:N); boards are views, never copies. 6-char Crockford join codes, permanent, idempotent, add-only.
- **Client-trusted v1;** `submit_score` is the designated future sanity-cap seam. _Detail: [`02-leaderboard-data-model.md`](https://github.com/fiachramcv90/gem-mining-game/blob/feature/ep1-02-leaderboard-schema/wayfinder/enhancement-pack-1/assets/02-leaderboard-data-model.md) (PR #49)._
- **Pre-implementation checkpoint (blocks the migration, not the spec):** live-verify anon-signin / RLS / SECURITY DEFINER / REST-upsert against Supabase before writing the migration — the MCP was unauthenticated during charting.

## L3. Score capture — [#40](https://github.com/fiachramcv90/gem-mining-game/issues/40)
- **`total_banked` = the existing `MinersLog.stats["money_banked"]`** (gross, monotonic, incl. prizes) — no new counter, no migration for it.
- **`best_haul` = a new per-run accumulator:** `_banked_this_run` resets at descent start; every banking event adds to it and immediately `best_haul = max(best_haul, _banked_this_run)` (order-independent). Reuses the one `RUN_MIN_DEPTH` run definition. **Per-run, not per-sell** — forward-compatible with the hauler drone banking mid-descent; a lost run contributes only what was hauled up first.
- **Posting:** `submit_score` on **run-complete + `visibilitychange→hidden`**, debounced, **absolute values** (idempotent via server `GREATEST`). Never per-sell. _Detail: [`03-score-capture.md`](https://github.com/fiachramcv90/gem-mining-game/blob/claude/wayfinder-av5tn7/wayfinder/enhancement-pack-1/assets/03-score-capture.md)._

## L4. Offline posture — [#40](https://github.com/fiachramcv90/gem-mining-game/issues/40)
Local save is the **sole source of truth**; the board is a best-effort mirror. A single **non-persisted `scores_dirty`** flag; submit current absolute values on any trigger (incl. app-launch) with live network; failure stays dirty and retries. **No queue** — idempotent absolute writes collapse any backlog into one catch-up post. "Backend unreachable" is a normal state, never an error.

## L5. UX surfacing — [#41](https://github.com/fiachramcv90/gem-mining-game/issues/41)
- **No new hub button** — the board folds into the existing **Miner's Log** screen (hub census unchanged — §E4).
- **One screen, two switchers:** scope tabs (Stats / Global / Groups) + metric toggle (Best haul / Total banked). Player row always pinned + highlighted.
- **Post-run compare = non-blocking banner** on the sell screen (reuses [§7 shipped](../../assets/0014-final-spec.md) shake+flash), only on rank change; never a mid-run modal.
- **Groups:** tap-to-share Crockford codes; add-only membership.
- **Lazy identity:** no first-run modal; auto-name + lazy row on first bank; editable from the Log.
- **Offline/empty states** show local values and reassure. _Prototype: [`04-leaderboard-ux-prototype.html`](https://github.com/fiachramcv90/gem-mining-game/blob/claude/wayfinder-av5tn7/wayfinder/enhancement-pack-1/assets/04-leaderboard-ux-prototype.html) · [`04-leaderboard-ux.md`](https://github.com/fiachramcv90/gem-mining-game/blob/claude/wayfinder-av5tn7/wayfinder/enhancement-pack-1/assets/04-leaderboard-ux.md)._

---

# Part II — Consumable dig-tools

## C1. Loadout system — [#42](https://github.com/fiachramcv90/gem-mining-game/issues/42)
**3 active slots × one-type-each × N-charges** (slots gate variety, charges gate quantity, HUD = 3 buttons). Tools **unlock by depth-gated shop visibility + a one-time unlock price**; charges bought into garage stock (`perChargePrice`, capped at `maxCharges`). **Only the 3 active types descend and are at risk — carried charges are forfeited on a lost run** (extends the shipped *carried = at risk, banked = safe* asymmetry). **Scarcity lives in `maxCharges`** — drones capped at 2.

**Unlock schedule & first-draft pricing (validated unchanged by #43):**

| Tool | Pressure | `unlockDepth` | `unlockPrice` | `perChargePrice` | `maxCharges` |
|---|---|:---:|:---:|:---:|:---:|
| Flare | darkness | 120 | 150 | 8 | 5 |
| Fuel cell | fuel | 180 | 300 | 25 | 3 |
| Dynamite | hard rock | 260 | 600 | 40 | 4 |
| Repair kit | hull | 340 | 500 | 35 | 3 |
| Scout drone | discovery | 450 | 2000 | 60 | 2 |
| Hauler drone | cargo | 550 | 3500 | 80 | 2 |

## C2. Economy validation — [#43](https://github.com/fiachramcv90/gem-mining-game/issues/43)
Re-sim with a consumable-spending player (modelled as a **pure zero-benefit sink** = worst case): **GO, knobs above validated unchanged.** First-hour pacing untouched; no-death-spiral guardrail airtight (wallet never negative, over-buyer recovers by drilling); only a worst-case ~8-run Bedrock deferral concentrated in the drone tier. **One optional playtest-gated lever:** drone unlock price, if the deep game later feels slow. _Runner: [`consumables-sim.js`](https://github.com/fiachramcv90/gem-mining-game/blob/claude/wayfinder-av5tn7/economy-sim/consumables-sim.js) · [`06-economy-resim.md`](https://github.com/fiachramcv90/gem-mining-game/blob/claude/wayfinder-av5tn7/wayfinder/enhancement-pack-1/assets/06-economy-resim.md)._

## C3. Control & HUD — [#44](https://github.com/fiachramcv90/gem-mining-game/issues/44) (chosen on-device)
**Corners layout** — 3 slot buttons top-right, opposite the dynamic trailing stick; all reachable with no grip change, two thumbs independent (no mis-taps). **Instant items → one tap, no aim. Scout → tap-target directional lead. Dynamite → drops at the digger, then flee.** _Prototype: [`07-hud-greybox.html`](https://github.com/fiachramcv90/gem-mining-game/blob/claude/wayfinder-av5tn7/wayfinder/enhancement-pack-1/assets/07-hud-greybox.html) · [`07-consumables-control-hud.md`](https://github.com/fiachramcv90/gem-mining-game/blob/claude/wayfinder-av5tn7/wayfinder/enhancement-pack-1/assets/07-consumables-control-hud.md)._

## C4. The six tools

**Dynamite — [#45](https://github.com/fiachramcv90/gem-mining-game/issues/45):** downward-biased teardrop (~3-tile radius); **ignores hardness, no cap** (guardrail holds via drill-superset + scarcity; doesn't extend reach); **destroys** caught gems (traversal not harvest), **prize immune**; **short auto-fuse ~1.3s** with proximity-scaled self-damage capped ~40% of current hull. _[`08-dynamite-mechanics.md`](https://github.com/fiachramcv90/gem-mining-game/blob/claude/wayfinder-av5tn7/wayfinder/enhancement-pack-1/assets/08-dynamite-mechanics.md)._

**Hauler drone — [#46](https://github.com/fiachramcv90/gem-mining-game/issues/46):** dispatch with current cargo → auto-sells at surface (feeds `best_haul`/`total_banked`), returns empty; self-powered (no fuel draw), depth-scaled trip time, **refuses the prize**; 2 trips.

**Scout drone — [#46](https://github.com/fiachramcv90/gem-mining-game/issues/46):** tunnels a thin path toward the nearest tier-4+/prize gem in a generously-wide-but-bounded radius (you still mine it), refuses to fire with no target, reveals nothing else, queries 0005's deterministic gem positions; 2 goes. _[`09-drone-mechanics.md`](https://github.com/fiachramcv90/gem-mining-game/blob/claude/wayfinder-av5tn7/wayfinder/enhancement-pack-1/assets/09-drone-mechanics.md)._

**Fuel cell / Repair kit / Flare — [#47](https://github.com/fiachramcv90/gem-mining-game/issues/47):** all instant one-tap. Fuel cell tops up ~40% of max fuel (extends the greed gamble, keeps the gate). Repair kit heals ~40% of max hull. Flare drops just ahead, lights a wide-but-local area ~10s (complements the permanent+personal Light). _[`10-relief-consumables.md`](https://github.com/fiachramcv90/gem-mining-game/blob/claude/wayfinder-av5tn7/wayfinder/enhancement-pack-1/assets/10-relief-consumables.md)._

## C5. Onboarding — [#51](https://github.com/fiachramcv90/gem-mining-game/issues/51)
Diegetic, 0013-style, no modals: three one-shot ghost lines (loadout, HUD, dynamite "GET CLEAR!") with the lit fuse as dynamite's permanent teacher; drones/relief teach via their own feedback; one first-board-view line covers nickname-rename + groups. All flags reuse 0013's existing `nudges` dict — **no new migration**. _[`11-onboarding-nudges.md`](https://github.com/fiachramcv90/gem-mining-game/blob/claude/wayfinder-av5tn7/wayfinder/enhancement-pack-1/assets/11-onboarding-nudges.md)._

---

# Part III — Reconciled contracts (cross-check)

Every knob shared between an EP1 tool and the shipped design, stated once. **No contradictions found.**

- **⟲ Consumable pricing × the shipped economy** ([#43](https://github.com/fiachramcv90/gem-mining-game/issues/43)): the C1 price table is the reconciled contract — validated to preserve the shipped first-hour pacing and no-death-spiral guardrail. The `unlockDepth ≥ 120` gate keeps the opening hour pure core-loop.
- **⟲ Dynamite self-damage × the [§5 hazard](../../assets/0014-final-spec.md) bands** ([#45](https://github.com/fiachramcv90/gem-mining-game/issues/45)×0007): self-damage uses 0007's currency (a fraction of **current** hull, like falls' 45% cap) and sits **within** the existing hazard budget — **Hull/Light prices do not move**.
- **⟲ Hauler & fuel cell × the round-trip fuel gate** ([#46](https://github.com/fiachramcv90/gem-mining-game/issues/46)/[#47](https://github.com/fiachramcv90/gem-mining-game/issues/47)×0003): both are self-powered / additive and scarcity-capped; they **extend** the greed gamble, never remove the gate. The hauler doesn't draw the fuel tank; the fuel cell tops up but you still reserve for ascent.
- **⟲ Scout & flare × the darkness/Light contract** ([#46](https://github.com/fiachramcv90/gem-mining-game/issues/46)/[#47](https://github.com/fiachramcv90/gem-mining-game/issues/47)×0007): scout reveals *one gem path only* (no hazard-sight, no map); flare is temporary+placed vs Light's permanent+personal. **Light stays essential.**
- **⟲ Leaderboard fields × the [§13 save envelope](../../assets/0014-final-spec.md)** ([#40](https://github.com/fiachramcv90/gem-mining-game/issues/40)×0009): the new fields fold into one `save_version` migration (§E3).
- **⟲ New surfaces × the [§9 hub census](../../assets/0014-final-spec.md)** ([#41](https://github.com/fiachramcv90/gem-mining-game/issues/41)×0013): the board lives inside the Miner's Log; the loadout lives in the garage shop — **no new hub button** (§E4).

---

# Part IV — Confirm during build

Mirroring how the shipped spec carried §16/§17, EP1 hands the build phase these execution-gated items (not open decisions):

- **Supabase live-verify** (from L2) — confirm anon-signin / RLS / SECURITY DEFINER / REST-upsert against a real project before writing the migration.
- **Godot HUD feel** (from C3) — the corners layout + activation model were settled on an HTML grey-box; confirm the real Godot HUD over the actual stick still feels right (0011-style).
- **Public-board anti-cheat caps** (map fog) — only if a *global* board ever attracts griefers; the `submit_score` RPC is the ready seam.

---

# Part V (§E) — Propagation into the shipped spec

The recorded amendments, applied in place to [`0014-final-spec.md`](../../assets/0014-final-spec.md) so the two specs read as one:

- **§E1 — §4 Economy, the "no per-run cash sink" line** (#42 Amendment A): consumables are the game's **first deliberate cash sink**, but discretionary/never-mandatory, so the **no-death-spiral property is preserved** (validated by #43). Refuel/repair stays free.
- **§E2 — §1 Core loop, the economy & failure/asymmetry lines** (#42 Amendments B & C): economy = permanent upgrades **plus a discretionary consumables sink**; the *carried = at risk* set now also includes **active-slot charges** (forfeited on a lost run); banked = safe still (wallet + upgrades + garage-stored charges).
- **§E3 — §13 Save envelope** (#40): adds `best_haul` (int), `device_id` (UUID), `nickname` (string) under a `save_version` bump (v4 → v5 in the built game); EP1 onboarding flags ride in the **existing `nudges` dict** (no extra change). `total_banked` needs nothing (already `stats.money_banked`).
- **§E4 — §9 hub census** (#41): **unchanged** — the board folds into the Miner's Log and the loadout into the garage shop; **no new hub button**. Recorded explicitly so a future reader knows the census was re-checked against EP1, not overlooked.

---

# Appendix — EP1 master knob list

**Leaderboard:** `device_id`, `nickname` (3–16 chars), post-triggers (run-complete, visibility-hidden), `scores_dirty` (runtime).
**Loadout:** per-tool `unlockDepth`, `unlockPrice`, `perChargePrice`, `maxCharges` (table in C1); active-slot count (3); optional `price_scale` reuse.
**Dynamite:** `blast_down`/`blast_up`/`blast_wide` (~3-tile teardrop), `fuse_time` (~1.3s), `self_dmg_frac` (~0.40 current hull), `self_dmg_radius` (~3 tiles).
**Hauler:** `haul_trip_time` (depth-scaled), trip capacity (= cargo cap), `maxCharges` 2.
**Scout:** `scout_radius` (wide, bounded), value threshold (tier ≥ 4 / prize), tunnel speed, `maxCharges` 2.
**Relief:** `fuel_cell_frac` (~0.40 max fuel), `repair_frac` (~0.40 max hull), `flare_radius`, `flare_duration` (~10s).
**Onboarding:** `nudges.loadout_shown`, `nudges.dynamite_taught`, `nudges.board_intro_shown` (in 0013's dict).

**Destination reached — EP1 is buildable against the existing project with no open decisions.**
