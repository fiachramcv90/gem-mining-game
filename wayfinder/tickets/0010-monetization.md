---
id: 0010
title: "Monetization decision"
type: grilling
status: closed
assignee: fiachramcv90
blocked-by: [0006]
---

## Question

Explicitly deferred at charting: free/portfolio vs premium vs ads/IAP — and what each implies for a web-first release (web has no store IAP rails). Decide after the economy exists, since the answer shapes (or is shaped by) the upgrade curve.

## Resolution

**Free game + one optional, voluntary support channel — itch.io pay-what-you-want.**
Chosen for portfolio fit and hands-on learning (the stated purposes); money is
incidental under both, so the model is picked to keep the showcase clean and give
one real, low-cost thing to learn — not to maximise income.

**Distribution (part of this decision) is hybrid, GitHub Pages canonical:**

- **GitHub Pages** (`fiachramcv90.github.io/gem-mining-game/`) stays the canonical
  build — the portfolio-native address and, decisively, the home of the
  **installable PWA** that protects [0009](0009-save-system.md)'s iOS
  save-durability path (Add-to-Home-Screen dodges WebKit's 7-day eviction cap).
- **itch.io page (pay-what-you-want, min £0)** = storefront + devlog + the *single*
  support surface, where the PWYW rails and the learning live. itch has its own tip
  rails → **no Ko-fi/Patreon** (one surface, not three). itch as *primary* was
  rejected: its sandboxed third-party iframe makes PWA install unreliable, which
  would undercut 0009.
- **One quiet in-build link** — "♥ Support / also on itch.io" on the title/surface-hub
  screen only; never mid-run, never a modal, never gated. The *only* point
  monetization touches the build (so the ask isn't invisible on the canonical build).

**Rejected:** premium paywall (barrier to the portfolio's own audience); **ads**
(branding/exclusivity strings, rewarded ads reopen [0006](0006-economy-upgrades.md),
video/audio ads collide with the iOS silent-switch mute in
[0011](0011-ios-smoke-test.md), tiny RPMs); **IAP/soft-currency** (no web store
rails, no accounts/entitlements — [0009](0009-save-system.md) is a seam — and would
reopen [0006](0006-economy-upgrades.md)).

**Consequences — almost none, by design.** No rewarded ads / soft currency / IAP →
the **no-cash-sink economy ([0006](0006-economy-upgrades.md)/[0003](0003-core-loop.md))
is NOT reopened**; PWYW is handled entirely by itch → the **save seam
([0009](0009-save-system.md)) stays a seam**, no accounts needed; no ads → the
**iOS silent-switch finding ([0002](0002-web-export-ios-safari.md)/[0011](0011-ios-smoke-test.md))
is irrelevant** and GitHub-Pages-canonical actively protects the PWA-install path.
The **native App/Play Store release stays out of scope**; real store IAP would be a
fresh effort if the destination is redrawn.

This sets the monetization **direction**; standing it up (create the itch page, set
PWYW, add the one link) is small downstream execution, not part of this ticket.

See [decision note](../assets/0010-monetization.md) for the full rationale.
