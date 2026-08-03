# EP1-04 — Leaderboard UX surfacing

_Resolves [EP1-04: Leaderboard UX surfacing](https://github.com/fiachramcv90/gem-mining-game/issues/41). Prototype: [`04-leaderboard-ux-prototype.html`](./04-leaderboard-ux-prototype.html) (six mobile screens, reviewed and approved on-device with no changes)._

The prototype's six design calls are **locked as-is**. Each surfaces the leaderboard without disturbing the shipped hub census ([0013](../../tickets/0013-tutorial-onboarding.md)) or the no-modal onboarding tone, and honours [#39](https://github.com/fiachramcv90/gem-mining-game/issues/39)'s data model and [#40](https://github.com/fiachramcv90/gem-mining-game/issues/40)'s local-is-truth posture.

## Locked decisions

- **A — Entry point: no new hub button.** The board folds **into the existing Miner's Log screen**, so the hub census stays 4 actions + Log + ♥ + 💾 (0013 untouched). The Log button leads to a tabbed screen.
- **B — One screen, two switchers.** Tabs for **scope** (Stats / Global / Groups) plus a **metric toggle** (Best haul / Total banked — [#39](https://github.com/fiachramcv90/gem-mining-game/issues/39)'s two boards). The player's own row is **always pinned and highlighted**, even when their rank is off-screen.
- **C — Post-run compare = a non-blocking banner.** On the existing sell / surface screen, a "🏆 new best haul — you jumped to #N" banner reusing [0008](../../tickets/0008-art-audio.md)'s shake+flash. Shows **only when a rank actually changed**; **never a mid-run modal** (surfaces at the surface, where banking already happens — consistent with [#40](https://github.com/fiachramcv90/gem-mining-game/issues/40)).
- **D — Groups.** 6-char Crockford join codes ([#39](https://github.com/fiachramcv90/gem-mining-game/issues/39)); **idempotent, add-only** membership in v1 (no leave/kick — that's fog); tap-to-share the code via the native share sheet.
- **E — Identity is lazy.** **No first-run nickname modal** ([#39](https://github.com/fiachramcv90/gem-mining-game/issues/39)): default auto-assigned name, lazy row on first bank, editable any time from the Log (3–16 chars, not unique). The board never gates play behind a name prompt.
- **F — Offline is a normal state.** Free-tier auto-pause ([#38](https://github.com/fiachramcv90/gem-mining-game/issues/38)) is routine, not an error: **show the player's own local values**, reassure that scores are saved and will sync, never block. Empty global board reads as an invitation ("be the first to dig deep").

## Feeds the onboarding fog

The **nickname-entry** and **join-by-code** flows (E, D) are the leaderboard half of the map's *"onboarding / nudges"* fog. This resolution sharpens them, but the fog stays fogged until the consumable UIs ([#44](https://github.com/fiachramcv90/gem-mining-game/issues/44), [#47](https://github.com/fiachramcv90/gem-mining-game/issues/47)) also land — then it graduates into a single onboarding ticket.

## No scope changes

No new tickets, no shipped-spec amendments (the board is purely additive). [#48](https://github.com/fiachramcv90/gem-mining-game/issues/48) folds these surfacing decisions into the EP1 spec.
