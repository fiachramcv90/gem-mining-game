# EP1-03 — In-game score capture & metrics

_Resolves [EP1-03: In-game score capture & metrics](https://github.com/fiachramcv90/gem-mining-game/issues/40). Builds directly on [EP1-02 leaderboard data model](https://github.com/fiachramcv90/gem-mining-game/issues/39) and the shipped [save system (0009)](../../tickets/0009-save-system.md) and [meta-progression (0012)](../../tickets/0012-meta-progression.md)._

## What this ticket settles

How the **game** computes, records, and posts the two leaderboard metrics
[EP1-02](https://github.com/fiachramcv90/gem-mining-game/issues/39) defined —
`total_banked` (gross lifetime banked) and `best_haul` (best single
surface-to-surface descent) — and exactly where that touches the existing
save/stats plumbing. Backend schema, identity, and RLS are EP1-02's; this is
the client side.

Design lens carried from the map's Notes: **local values are the source of
truth; the board is a best-effort mirror.** Nothing here may assume the network
exists.

---

## 1. `total_banked` — reuse the existing lifetime stat

`total_banked` is **not a new field.** The shipped Miner's Log already tracks it
exactly: `MinersLog.stats["money_banked"]`, incremented in
`_on_cargo_sold(value)` and never decremented (spending the wallet on upgrades /
consumables does not touch it). That is precisely EP1-02's definition — *gross
lifetime banked, monotonic* — including prize gems, because prizes are part of
`GameState.cargo_value()` at sell time.

- **Source:** read `MinersLog.stats["money_banked"]` directly when submitting.
- **Migration:** none. It already persists under the `stats` dictionary and
  self-heals on load (plain accumulating counter, per 0012).
- **One source of truth:** the leaderboard's total-wealth board reads this
  counter as-is; there is no parallel leaderboard-only tally to drift.

---

## 2. `best_haul` — a per-run accumulator (new)

Nothing tracks per-run banked money today, so this is genuinely new.

### Model

- A transient `_banked_this_run` counter (not persisted; run-scoped).
- **Reset to 0 at descent start** — the first time the player leaves the surface.
- **On every banking event during the run,** add the banked value to
  `_banked_this_run` and immediately fold it into the record:

  ```
  best_haul = max(best_haul, _banked_this_run)
  ```

- **`best_haul` persists** in the save (see §5).

### Why add-and-max on the banking event (not on the depth-0 transition)

Selling happens at the surface (`GameState.sell_cargo → cargo_sold`), and the
run-completion event *also* fires at the surface (depth returns to 0 after a
real descent). Both fire at nearly the same moment, so capturing on the
depth-transition would be order-sensitive — capture-before-add yields a haul of
0 on every normal run. Folding into `best_haul` **on the banking event itself**
is order-independent: the max always already includes the sale that just landed.

### Run boundary

Reuse the **one** existing run definition rather than inventing a second:
`MinersLog.RUN_MIN_DEPTH` (currently `4`) and the same surface-return logic that
resets `_deepest_this_run`. `_banked_this_run` resets alongside it at descent
start. Since banking requires having collected something at depth, a trivial
dip-and-return does not register a meaningful haul anyway; sharing the constant
keeps a single meaning of "a run."

### Forward-compatibility (the reason it is not "max single sell")

Today one run = one sell, so `max(best_haul, sell_value)` would work. It breaks
the moment the **hauler drone** ([EP1-09](https://github.com/fiachramcv90/gem-mining-game/issues/46),
not yet designed) ships: the hauler banks cargo *mid-descent* without ascending,
so one run will produce multiple banking events. The per-run accumulator sums
them into one descent's haul by construction; a per-sell max would let each
partial delivery compete as its own "haul" and understate the metric. The
accumulator is the forward-compatible choice.

### Lost runs

A lost run forfeits **carried** cargo (banks nothing further), so it contributes
only whatever was already delivered before the loss (e.g. an earlier hauler
trip). Honest, and consistent with the shipped *carried = at risk, banked =
safe* rule.

---

## 3. Post triggers — few, meaningful, idempotent

All writes go through EP1-02's `submit_score` RPC. Supabase free tier + the
~1-week idle auto-pause ([EP1-01/#38](https://github.com/fiachramcv90/gem-mining-game/issues/38))
mean we want a small number of meaningful posts, not chatter.

Post on **two triggers**, debounced:

1. **Run completion** — surfaced after a real descent. Both metrics are final
   for that run by then; the natural "worth publishing" beat.
2. **`visibilitychange → hidden`** — piggyback on the hook 0009 already uses to
   flush the save on tab-kill. Catches the player who closes the tab at the hub.

**Absolute values, not deltas.** Each post sends the current
`{ total_banked, best_haul }`. `submit_score` writes with server-side
`GREATEST`, so a post is idempotent and a missed post is harmless — the next one
carries the truth.

Explicitly **not**: per-sell posting (chatty; mid-hub reselling would spam) or
app-foreground posting (nothing changed).

---

## 4. Offline / failure posture — a dirty flag, no queue

The game stays fully playable with no network; "backend unreachable" is a
normal state (free-tier auto-pause), not an error.

- **Local save is the sole source of truth.** `stats.money_banked` and
  `best_haul` live in the save; the board is a best-effort mirror.
- A single **`scores_dirty` boolean** (in-memory, **not persisted**). A banking
  event sets it; a successful `submit_score` clears it.
- On each trigger — run-complete, visibility-hidden, **and app-launch** — if
  dirty and the network is present, submit the current absolute values. On
  failure, stay dirty and retry at the next trigger.
- **No persistent per-event queue.** Because submits are idempotent
  absolute-value writes under `GREATEST`, only the *latest* totals matter;
  "offline for five sessions" collapses into one clean catch-up post.
- The flag is deliberately **not** persisted: worst case a fresh launch does one
  redundant (harmless) post of current values. Simpler than persisting it, and
  correctness is unaffected.

---

## 5. Save envelope — one `save_version` 4 → 5 migration for all of EP1

`best_haul` needs a slot and a version bump. Rather than a v5 here and a v6 for
the leaderboard client a week later, **one migration opens the save format for
the whole EP1 leaderboard feature.**

Bump `SaveManager.SAVE_VERSION` **4 → 5** (linear +1 ladder, add-keys-only), adding:

| Field | Type | Default on migrate | Notes |
|---|---|---|---|
| `best_haul` | int | `0` | Cannot self-heal (no history to derive a best run from) — old saves honestly start at 0 and set their record going forward, mirroring 0012's stance for event-only badges. |
| `device_id` | String (UUID) | generated if absent | EP1-02's durable identity anchor. Generate on migration / first-run. |
| `nickname` | String | EP1-02's auto-assigned default if absent | The nickname **field** is defined here; the entry **UI** stays [EP1-04/#41](https://github.com/fiachramcv90/gem-mining-game/issues/41). |

`total_banked` needs nothing — already persisted under `stats`.

This makes EP1-03 the single owner of "the save envelope grew for EP1"; #41 then
reads/writes fields that already exist.

---

## 6. Recorded amendment to the shipped spec

Per the map's *renegotiation is deliberate & recorded* principle: this ticket
**amends the shipped [0009 save envelope](../../tickets/0009-save-system.md)** —
`save_version` moves 4 → 5 and gains `best_haul`, `device_id`, `nickname`. The
[EP1-11 assembly ticket](https://github.com/fiachramcv90/gem-mining-game/issues/48)
propagates this into the shipped spec's save-envelope section alongside the
0012/0013 fields already there.

## 7. Unblocks

- **[EP1-04: Leaderboard UX surfacing (#41)](https://github.com/fiachramcv90/gem-mining-game/issues/41)** — now has concrete metrics, post triggers, and the `nickname` field to surface.
