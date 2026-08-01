# EP1-06 — Economy re-simulation with consumables

_Resolves [EP1-06: Economy re-simulation with consumables](https://github.com/fiachramcv90/gem-mining-game/issues/43). Validates the consumable pricing/unlock knobs [EP1-02 (#42)](https://github.com/fiachramcv90/gem-mining-game/issues/42) set, against the shipped [0006 economy](../../tickets/0006-economy-upgrades.md)._

Runner: [`economy-sim/consumables-sim.js`](../../../economy-sim/consumables-sim.js) (`node economy-sim/consumables-sim.js`), layered on the unchanged [`economy-sim/economy-model.js`](../../../economy-sim/economy-model.js) so the core run + upgrade logic is identical to 0006's.

## Verdict: **GO — first-draft knobs validated, no re-tune required.**

The consumable cash sink does **not** break the shipped economy. The first-hour ratchet is untouched, the no-death-spiral guardrail is airtight by construction, and the only measurable effect is a *worst-case* deferral of the deep-game milestones that real tool benefits will claw back.

---

## Modelling choice — consumables as a pure sink, zero benefit

The per-item **benefits** (hauler cargo trips, scout leads, dynamite blasts, relief items) belong to [#45](https://github.com/fiachramcv90/gem-mining-game/issues/45)/[#46](https://github.com/fiachramcv90/gem-mining-game/issues/46)/[#47](https://github.com/fiachramcv90/gem-mining-game/issues/47) and aren't designed yet — so consumables are modelled as **pure spend with zero gameplay upside**. This is deliberately the worst case for both questions #43 asks:

- **Spiral test:** if a spender can't spiral with *no* upside, they can't once the tools help.
- **Pacing test:** money diverted to a zero-benefit sink is an **upper bound** on how much the sink can delay the 0006 milestones. Real tools also help you earn and reach, so the true delay is no worse than what's shown here.

Three players, same seed (12345), 40 runs: **baseline** (no consumables — the 0006 reference), **sensible** (upgrades first, surplus to tools), **pathological** (drain the wallet on tools first, upgrades last).

## Knobs under test (EP1-02 first-draft)

| Tool | unlockDepth | unlockPrice | perCharge | maxCharges | full-loadout $/run |
|------|:---:|:---:|:---:|:---:|:---:|
| Flare | 120 | 150 | 8 | 5 | 40 |
| Fuel cell | 180 | 300 | 25 | 3 | 75 |
| Dynamite | 260 | 600 | 40 | 4 | 160 |
| Repair kit | 340 | 500 | 35 | 3 | 105 |
| Scout | 450 | 2000 | 60 | 2 | 120 |
| Hauler | 550 | 3500 | 80 | 2 | 160 |

---

## Finding 1 — first-hour pacing is untouched

| Milestone | Baseline | Sensible | Pathological |
|---|:---:|:---:|:---:|
| first upgrade (run) | **3** | **3** | **3** |
| first upgrade (min) | **4.5** | **4.5** | **4.5** |
| first tool unlock (run) | — | 11 | 11 |
| band @ 60 min | Sandstone | Sandstone | Sandstone |

The first hour reaches only Topsoil→Sandstone, and the **only** tool that unlocks in that window is the Flare (depth 120, a $40 loadout). The 0006 first-hour target — *first upgrade ~run 3* — is **identical across all three players**. The `unlockDepth ≥ 120` gate (#42's "nothing before Sandstone" rule) is doing exactly its job: the opening hour stays pure core-loop + permanent ratchet.

## Finding 2 — the guardrail is structurally airtight (no spiral)

- **Wallet never goes negative.** `walletMin` = **0** for the pathological over-buyer (purchases are affordability-gated). There is no state in which spending traps the player.
- **Earning is independent of spending.** Drilling is free, so **every surviving run still banks money** — 40/40 runs banked > 0 even for the over-buyer, who burned **$14,864** total on consumables across the session and stayed solvent throughout.
- **Recovery is immediate.** The over-buyer who stops at run 20 (wallet $121) and just drills climbs to **$40,417 by run 40**. "Recover by simply drilling" is demonstrated, not asserted.

This is the shipped *carried = at risk, banked = safe* asymmetry generalised to charges: because spending is discretionary and refuel/repair stays free, a broke player carries nothing, loses nothing, and keeps earning. **No death-spiral.**

## Finding 3 — deep-game deferral is the only real cost (and it's worst-case)

| Milestone | Baseline | Sensible | Δ |
|---|:---:|:---:|:---:|
| reach Bedrock (run) | 19 | 27 | **+8** |
| reach bottom 700 (run) | 27 | 34 | +7 |

A sensible spender reaches Bedrock ~8 runs later and the 700-tile bottom ~7 runs later than a pure-upgrade player. Read this correctly:

- It is a **worst-case upper bound** — zero tool benefit is modelled. Real drones/dynamite raise effective reach and haul, pulling this back.
- It is concentrated in the **drone tier**: the sensible trace shows the ratchet coasting through Granite, then the $2000 Scout + $3500 Hauler unlocks (near Hoist's $5000) landing at Bedrock entry (runs 30–31) are what defer the bottom. Early/mid tools (Flare/Fuel cell/Dynamite/Repair kit) barely dent the curve.
- The deferral is the player **choosing** to spend on tools instead of depth — exactly the "which pressure do I insure against?" tension the loadout is meant to create. It never threatens solvency: by the Bedrock runs the wallet is banking $2k–5k/run and absorbs the $385/run top-loadout charge cost easily.

## Reconciled price knobs for #48

The first-draft knobs above are **validated as-is** — bake them into the spec unchanged. The `unlockDepth ≥ 120` gate and the premium drone pricing (near-Hoist unlock + `maxCharges` capped at 2) are the two load-bearing values and both behave as intended.

**Optional tuning lever (playtest-gated, not required now):** if the deep game later *feels* too slow for tool-buyers, the cleanest single dial is the **drone unlock prices** (Scout $2000 / Hauler $3500) — shaving them narrows the ~8-run Bedrock gap without touching the first-hour pacing or the guardrail. Left at first-draft values pending real play; noted here so #48 records it as a known knob rather than an open decision.

## No scope changes

No new tickets; no fog graduated (onboarding still waits on 44–47). The economy renegotiation amendments (#42's Amendments A–C) are confirmed to hold numerically and remain [#48](https://github.com/fiachramcv90/gem-mining-game/issues/48)'s to propagate into the shipped spec.
