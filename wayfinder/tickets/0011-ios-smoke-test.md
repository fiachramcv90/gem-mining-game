---
id: 0011
title: "On-device iOS Safari smoke test of a single-threaded web export"
type: task
status: open
assignee: fiachramcv90
blocked-by: []
---

## Question

Ticket 0002 concluded (from docs, release notes, and issue trackers) that a Godot 4.3+
single-threaded, Compatibility-renderer, Sample-audio web export runs acceptably on iOS
Safari — with **memory, not CPU, as the binding ceiling**. This task **confirms that
empirically** on Fiachra's actual iPhone before the platform bet is treated as fully
de-risked.

Task (HITL — Fiachra runs it; no design decision, just verification):

1. In Godot 4.3+, make a throwaway project: a sprite that moves on touch/drag, a plain
   `AudioStreamPlayer` (Sample playback) triggered on tap, and on-screen text confirming
   the renderer/WebGL2 is up.
2. Export **Web**, renderer **Compatibility**, **Thread Support OFF**. Keep the WASM
   max-memory modest. Add a minimal PWA manifest + icon.
3. Host on any static host (GitHub Pages / itch / Netlify — no COOP/COEP headers).
4. On the iPhone, open it in **Safari as a tab** and again via **Add to Home Screen**
   (PWA). Check: it loads, WebGL2 renders (no "context lost"), touch responds, the Sample
   SFX plays cleanly after the first tap, and memory stays stable (no tab crash on
   rotate/resize).

Resolution records: does it match 0002's prediction? Any Safari-specific
rendering/audio/**memory** surprises (context loss, OOM, canvas-resize crash)?
Screenshots/notes linked. If a real blocker appears, feed it back to 0002's mitigation
ladder and flag whether the platform decision needs revisiting.
