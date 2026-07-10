---
label: wayfinder:map
title: Gem Miner — design & tech spec
created: 2026-07-10
---

# Gem Miner — design & tech spec (Wayfinder Map)

> **Tracker conventions (local markdown fallback):** each ticket is a file in
> `tickets/`, named `NNNN-slug.md`. Frontmatter carries `type`, `status`
> (`open`/`closed`), `assignee`, and `blocked-by` (list of ticket ids).
> A ticket is **claimed** by setting `assignee` before work starts.
> The **frontier** = open tickets with an empty/void `blocked-by` (all blockers
> closed) and no assignee. Resolutions are appended to the ticket under
> `## Resolution`, the ticket closed, and a one-line gist added to
> *Decisions so far* below. One ticket per session.

## Destination

A complete design + technical spec for a Motherload-style gem-digging game,
built in **Godot 4** with a **web build first** (stores deferred), sharp enough
that Fiachra can open Godot and start building with no open decisions.

## Notes

- Solo dev, evenings/weekends, no deadline — bias every decision toward small
  scope and steady momentum.
- Godot is a *new* engine for Fiachra (strong TypeScript/web background);
  research tickets should produce learning-path notes, not just answers.
- All personal devices are Apple; no Apple dev account (£100 avoided for now)
  — hence web-first. **iOS Safari compatibility of the web export is a
  route-critical question.**
- Monetization explicitly deferred to its own ticket; don't let it leak into
  other decisions.
- Skills to consult per session: /grilling and /domain-modeling equivalents
  (structured one-question-at-a-time interviewing in chat).

## Decisions so far

<!-- one line per closed ticket: gist + link -->

- [Godot 4 foundations for a 2D tile-digging game](tickets/0001-godot-foundations.md) — target Godot **4.3+**; destructible world = `TileMapLayer` + `erase_cell()` with hardness/gem_type as TileSet custom data; player = `CharacterBody2D`; autoload singletons for run/wallet/save; touch-first input. [Learning-path asset](assets/0001-godot-foundations-learning-path.md).

## Not yet specified

- **Meta-progression & retention** — achievements, milestones, daily hooks.
  Hangs on the core loop and economy decisions; too dim to ticket.
- **Tutorial & onboarding** — shape depends on how intuitive the dig controls
  turn out to be (prototype will tell us).
- **Performance budget** — tile counts, chunk streaming, particle limits;
  can't be phrased sharply until worldgen and the web-export research land.
- **Playtesting plan** — who plays early builds and when; likely graduates
  once a vertical-slice definition exists.
- **Final spec assembly** — the destination document itself; its structure
  will be clear once most decisions are in.

## Out of scope

- **Native App Store / Play Store release** — consciously deferred until the
  web build proves the game; avoids the £100 Apple dev account for now.
  Returns as a fresh effort if the destination is redrawn.
- **Multiplayer** — ruled out in early scoping discussion.
- **Story / NPCs** — ruled out; depth comes from the upgrade curve, not
  narrative content.
- **More than ~8 gem types at launch** — content-volume cap agreed in early
  scoping.
