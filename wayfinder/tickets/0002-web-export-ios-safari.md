---
id: 0002
title: "Godot 4 web export viability on iOS Safari"
type: research
status: closed
assignee: fiachramcv (Claude session)
blocked-by: []
---

## Question

Web-first is the chosen platform and all of Fiachra's devices are Apple. Does Godot 4.x's HTML5 export run acceptably on current iOS Safari (threads/SharedArrayBuffer requirements, compatibility renderer vs Forward+, audio quirks, home-screen PWA behaviour, performance)? If not, what are the mitigations (compatibility renderer, single-threaded export) or fallback engines? This is route-critical: a negative answer redraws the platform decision.

## Resolution

**Web-first HOLDS — the platform decision is confirmed, not redrawn.** ✅ Full
findings in the linked asset:
[Godot 4 web export on iOS Safari — viability & mitigations](../assets/0002-web-export-ios-safari.md).

Verdict: Godot 4's HTML5 export runs acceptably on current iOS Safari **provided
we ship a single-threaded export and design within iOS Safari's memory ceiling** —
both cheap, default-path choices a small 2D tile-digger fits easily. The "won't run
on iPhone" reputation is real but pre-4.3; Godot 4.3+ (latest stable is 4.7 as of
Jul 2026) fixed it.

Key findings:

- **Threads/`SharedArrayBuffer`:** the historical blocker. Solved by the
  **single-threaded** export (default since 4.3) — no COOP/COEP headers, sidesteps
  Safari's threaded-WASM bugs. Docs: single-threaded "works very well on macOS and
  iOS." **Decision: single-threaded, Thread Support OFF.**
- **Renderer:** web is **Compatibility / WebGL 2.0 only** — Forward+/Mobile and
  WebGPU are not available on web. A non-issue for a 2D tilemap game (Compatibility
  is the intended renderer); ~60 FPS on iPhone 15 in real reports.
- **Audio:** default **Sample playback** gives low latency without threads but no
  effects/reverb/doppler/procedural — fine for one-shot SFX + looped music. Audio
  needs a user gesture to start ("tap to dig" covers it).
- **The real ceiling is memory, not CPU** ⚠️: iOS Safari rejects the old 2 GB WASM
  max (OOM), the engine baseline heap alone (~400 MB hosted) can cause "WebGL
  context lost," and a WebKit canvas-resize leak crashes the tab ~1.25 GB. All
  mitigable: modest max-memory, chunk-stream/free the mine, don't recreate the WebGL
  context, avoid orientation thrash.
- **PWA/home-screen:** Godot's PWA export gives iOS a chrome-less standalone WebClip
  with offline caching — good. But **no Fullscreen API/orientation lock on iOS**
  (use safe-area insets), and installed-PWA storage **diverges** from Safari's
  (one-time copy) — a hard requirement handed to the save system (0009).

**Map effects:** unblocks **0004 (dig-feel prototype)** (its only remaining blocker);
sharpens the *Performance budget* fog into a **binding memory constraint** for
worldgen (0005); constrains **0008 (audio)** to Sample-playback one-shots; hands
**0009 (save)** an evictable/context-divergent web-storage requirement. No new
tickets and nothing ruled out of scope.

> **Addendum (follow-up session):** on reflection, one Task ticket *was* graduated —
> [0011 · on-device iOS Safari smoke test](0011-ios-smoke-test.md) — to empirically
> confirm this docs-based verdict on Fiachra's real iPhone before the platform bet is
> treated as fully de-risked. Everything above stands; this only adds the confirmation
> step.
