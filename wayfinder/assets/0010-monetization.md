# Monetization decision — direction note

> Decision asset for [ticket 0010 — Monetization decision](../tickets/0010-monetization.md).
> Sets the monetization **direction**, not the integration. No payment/ads/accounts
> code is built here.

## The decision in one line

**Gem Miner stays free. One optional, voluntary support channel — itch.io
pay-what-you-want — chosen for portfolio fit and hands-on learning, not income.
It reaches backward into no other decision on the map.**

## Purpose this had to serve

Portfolio-first **and** learning-the-mechanics (the project's stated reasons to
monetize at all). Money is *incidental* under both. That framing is the whole
lever: the model isn't picked to maximise pennies, it's picked to keep the
showcase clean while giving one real, low-cost thing to learn.

## Chosen model

- **The game is free.** No paywall. No gate between a portfolio viewer and the
  thing you're showing them.
- **A single voluntary support channel: itch.io pay-what-you-want (minimum £0).**
  Players play free; a suggested tip sits on the storefront. itch handles all
  payment rails — no backend, no fees to stand it up, no ongoing overhead.

### Distribution (part of this decision) — hybrid, GitHub Pages canonical

- **GitHub Pages (`fiachramcv90.github.io/gem-mining-game/`) stays the canonical
  build.** It is the portfolio-native address, and — decisively — it is where the
  **installable PWA** lives, which *protects the [0009](../tickets/0009-save-system.md)
  iOS save-durability decision*: "Add to Home Screen" is what dodges WebKit's
  7-day IndexedDB eviction cap, and that needs a manifest + service-worker scope
  you only control on your own origin.
- **itch.io page = storefront + devlog + the single support surface.** This is
  where the PWYW ask and the *learning* live (itch HTML5 hosting model, PWYW
  rails, devlog cadence, a real game page with screenshots for the portfolio).
- **No Ko-fi / Patreon / direct.** itch already carries its own tip rails; one
  support surface, not three.

### Where it touches the build — one quiet link

A small **"♥ Support / also on itch.io"** line on the **title / surface-hub
screen only**. Never mid-run, never a modal, never gated behind a milestone or a
paywall. It exists so the ask isn't invisible to the majority of players on the
canonical github.io build — and nowhere else. This is the *only* point at which
monetization touches the game.

## Why the alternatives lost

| Rejected | Why |
| --- | --- |
| **Premium / paywall** | A barrier to the exact people a portfolio piece is *for*; contradicts the free build already shipped. |
| **Ads** (HTML5 SDK or a revenue-share portal like CrazyGames/Poki) | Drags in **branding + exclusivity strings**; **rewarded** ads pay in-game currency → would **reopen [0006](../tickets/0006-economy-upgrades.md)'s no-cash-sink economy**; **video/audio ads collide with the iOS silent-switch mute** ([0011](../tickets/0011-ios-smoke-test.md)/[0002](../tickets/0002-web-export-ios-safari.md)) → broken UX; web-game ad RPMs are tiny. Worst cost-to-benefit of any option, and the "learning" is SDK plumbing you'd not want on a showcase. |
| **IAP / soft-currency** | Needs **store rails that don't exist on the web build** (web-first, no Apple dev account); needs **accounts/entitlements not built** ([0009](../tickets/0009-save-system.md) is a *seam*); would **force reopening [0006](../tickets/0006-economy-upgrades.md)**. Triple collision. |
| **Ko-fi as a second channel** | Redundant once itch PWYW is the support surface; more surfaces to maintain for no gain. |
| **itch.io as *primary* (retire GitHub Pages)** | itch serves HTML5 games in a sandboxed third-party iframe (`html-classic.itch.zone`) where PWA install / service-worker scope is unreliable → would **undercut the 0009 iOS save-durability story**. Kept as a *secondary* storefront instead. |
| **No in-build link at all** | Makes the whole channel a no-op — real players on github.io would never see it. |
| **Post-milestone "enjoying it? ♥" nudge** | Drifts toward engagement-driven monetization — the manipulative flavour already rejected with ads. |

## Consequences for the rest of the map

The headline is that there are **almost none — by design.** This ticket was
deliberately walled off from every other decision at charting; the model that best
serves the purpose is the one that reaches backward into nothing:

- **Economy ([0006](../tickets/0006-economy-upgrades.md) / [0003](../tickets/0003-core-loop.md)): untouched.**
  No rewarded ads, no soft currency, no IAP → the **no-cash-sink / no-death-spiral**
  design stands. **This decision does not reopen 0006.**
- **Save seam ([0009](../tickets/0009-save-system.md)): untouched.** PWYW payment
  is handled entirely by itch; nothing in-game needs accounts or entitlements. The
  cloud-ready `SaveBlob` seam stays a seam.
- **iOS Safari ([0002](../tickets/0002-web-export-ios-safari.md) / [0011](../tickets/0011-ios-smoke-test.md)):
  untouched.** No ads → the silent-switch/audio finding is irrelevant to
  monetization. And GitHub-Pages-canonical *actively protects* the PWA-install
  save-durability path.
- **Out of scope unchanged:** the **native App/Play Store release stays out of
  scope**; *real* store IAP would be a **fresh effort** if the destination is ever
  redrawn, not a resumption of this ticket.

## What this is NOT

Not the integration. No payment/ads/accounts code, no SDK, no itch page created
here. This note fixes the **direction**; standing it up (create the itch page, set
PWYW, add the one title/hub link) is downstream execution, and it's small.
