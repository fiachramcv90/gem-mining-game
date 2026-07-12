---
id: 0011
title: "On-device iOS Safari smoke test of a single-threaded web export"
type: task
status: closed
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

## Build-ready handoff — 2026-07-12 (ticket stays OPEN, awaiting Fiachra's on-device run)

The smoke-test harness is **built, CI-verified, and ready to deploy** — but this is a
task with a HITL boundary: the iOS result is Fiachra's to observe on a physical iPhone
(0002 §8 — neither desktop nor the iOS Simulator reproduces the memory/safe-area
behaviour). So the build phase ends here with a URL + checklist; the ticket does **not**
close until Fiachra reports back.

**What was built:** [`smoke-test/`](../../smoke-test/) — a throwaway Godot 4.3 diagnostic
scene that surfaces every platform result on-screen (touch sprite, Sample-audio blip on
tap, renderer/`WebGL2 OK` string, live FPS, live WASM heap + Godot static memory + peak,
resize counter, and a big red banner if a WebGL context is ever lost). Exported Web with
the iOS-safe settings from 0002 §8 (Compatibility, Thread Support OFF, PWA ON with
144/180/512 icons + manifest, Sample audio, Basis Universal `for_mobile`, WASM max clamped
to 512 MB). Godot/CI/PWA/JavaScriptBridge learning notes:
[`assets/0011-ios-smoke-test-notes.md`](../assets/0011-ios-smoke-test-notes.md).

**CI:** the export builds green on the branch (run #14); deploy is main-only, so the URL
below goes live **once the PR is merged to `main`**.

**URL (live after merge):** https://fiachramcv90.github.io/gem-mining-game/smoke/
(the 0004 prototype stays at `/`; the smoke test is served alongside it at `/smoke/`.)

### On-device checklist (run each row in BOTH contexts)

Open the URL **(A) in a Safari tab**, then **(B) via Share → Add to Home Screen** and
launch the installed icon. For each check, read the on-screen readouts — no devtools
needed.

1. **Loads?** The scene appears (dark screen, "iOS SMOKE TEST (0011)" title, a cyan gem).
2. **WebGL2 renders?** Top line reads **"WebGL2 OK"** with `gl_compatibility / opengl3`.
   The gem draws crisply. **No** red "WEBGL CONTEXT LOST" banner.
3. **Touch responds?** Drag a finger — the gem follows your thumb smoothly; `taps:`
   increments on each tap.
4. **Audio unlocks?** First **tap** plays a short blip cleanly (no garble/crackle);
   every later tap re-plays it. (iOS blocks audio until the first gesture — this is the
   unlock.)
5. **WASM max accepted at init?** The memory line shows a `cap 512 MB` and a "WASM heap"
   figure well under it (the old 2 GB cap is exactly what 0002 §4 says iOS rejects — a
   modest cap that boots is the confirmation).
6. **Memory stable on rotate/resize?** Rotate the phone several times (portrait↔landscape),
   background/foreground the tab. Watch `resizes:` climb while **FPS holds ~60** and the
   **"WASM heap" / "Godot static" peaks do NOT creep up** with each resize. **No tab
   crash** (0002 §4's ~1.25 GB canvas-resize leak is the thing this is probing).
7. **PWA specifics (context B only):** the installed app opens **chrome-less** (no Safari
   UI); the home-screen icon is the gem; safe-area/notch doesn't clip the readouts.

### What to send back to close this ticket

- A one-word verdict per row above for **both** A and B (pass / fail / weird).
- **Screenshots** of the readouts (especially the memory line after several rotates).
- Any Safari surprise: context loss, OOM/reload, audio quirk, render glitch, resize crash.

I'll record the result in `## Resolution` (match vs 0002's prediction + any surprises),
close the ticket, add a one-line gist to the map, and note that it feeds 0002's
mitigation ladder (§7) and sharpens the Performance-budget fog. If a **real blocker**
shows up, I won't quietly redesign — it goes back to 0002 §7 and we flag whether the
platform bet needs revisiting.

## Resolution — 2026-07-12: 0002 CONFIRMED on-device ✅

Fiachra ran the harness on his **physical iPhone** (WebKit — first attempt used
iOS Chrome, which is WebKit-under-the-hood, then confirmed the working build in
**Safari**). After a one-round build bug was fixed (see below), the smoke test
**passed and matches 0002's prediction**. The web-first platform bet is now
**empirically de-risked**, not just reasoned from docs.

### What the device showed (screenshots on the ticket)

| Checklist row (Safari tab) | Result |
|---|---|
| Loads | **PASS** — title + gem + readouts render |
| WebGL2 renders, no context-lost | **PASS** — readout: `WebGL2 OK · gl_compatibility · OpenGL ES 3.0 (WebGL 2.0) · WebKit WebGL`; no "context lost" banner |
| Touch responds | **PASS** — gem tracks the finger; tap counter climbed into the hundreds |
| Sample SFX after first tap | **PASS (observed)** — Safari's tab audio indicator lit on tap; audio unlocked on gesture as 0002 §3 predicts. *(Clean-vs-glitchy not separately reported.)* |
| Memory stable on rotate/resize, no crash | **PASS (qualitative)** — `resizes` climbed 2 → 9 incl. portrait↔landscape; **FPS pinned at 60**; no tab crash, no context loss. See caveat below on the numbers. |

This directly validates the four things 0002 rests on: single-threaded
Compatibility/WebGL2 runs on iOS WebKit; audio unlocks on first gesture; and —
the headline — **WebKit survived repeated rotate/resize without the §4
canvas-resize crash or a lost context.**

### Safari surprises / caveats

- **No hard memory number.** The two on-screen memory figures did **not**
  instrument on the web export: `Performance.get_monitor(MEMORY_STATIC)` reads
  **0.0 MB** on web (the WASM heap is Emscripten-managed, not counted by Godot's
  static allocator), and the **"WASM heap" line never appeared** — i.e. the
  `head_include` shim's `window.__godotWasmMemory` capture **did not catch the
  engine's `WebAssembly.Memory`**, so the live heap readout and the **512 MB
  clamp are UNCONFIRMED** (the on-screen "cap 512 MB" is only the shim announcing
  intent, not proof it applied). So the memory-ceiling result is **qualitative**
  (no OOM, stable FPS, no crash across 9 resizes) — strong but not a measured
  number. The exact figure is deferred to the real profiling pass.
- **PWA / Add-to-Home-Screen (checklist context B) not separately confirmed** in
  this pass — all screenshots are the Safari tab. The PWA export itself builds
  correctly (manifest + service worker + 144/180/512 icons + apple-touch-icon,
  verified in CI), and the standalone install is a cheap spot-check to record
  later; it does not gate the platform verdict.
- **Build bug found and fixed en route (a real learning).** The first deploy
  showed a blank **grey** screen on device: the diagnostic script called
  `OS.get_current_rendering_method()/driver_name()`, which **do not exist in
  Godot 4.3** (nor on `RenderingServer` — later-4.x additions). In GDScript that's
  a *parse error* that fails the whole script to load, so the scene ran nothing
  (grey = default clear colour). Crucially `godot --export-release` compiles-and-
  packs the script but never *runs* it, so it passed a green export and only died
  on load. Fixed by reading the method from `ProjectSettings` and the live WebGL
  string from `RenderingServer.get_video_adapter_name()/get_video_adapter_api_version()`,
  and by adding a **CI headless-run gate** that runs the scene and fails the build
  on any script error (it caught a second bad guess before it reached the phone).
  Written up in the learning-notes asset §8.

### Does the platform bet need revisiting? No.

Nothing here feeds 0002 §7's fallback ladder — there was **no blocker**, only a
throwaway-harness bug of my own making. 0002's verdict **HOLDS, now confirmed on
metal.**

### Feeds forward

- **0002's mitigation ladder (§7):** the canvas-resize/​context-loss row is now
  **empirically clear** on this device — WebKit took 9 resizes incl. rotation at
  60 FPS with no crash. (Still design against it — one device isn't a guarantee.)
- **Performance-budget fog (map):** sharpened. The *qualitative* memory result is
  reassuring, but this pass produced **no measured heap number** on iOS — so the
  on-device profiling task that graduates from that fog must **fix the web memory
  instrumentation first** (the `MEMORY_STATIC`-reads-0 problem and the
  `WebAssembly.Memory` capture that didn't fire) before it can set the real
  resident-window/chunk budget. That's a concrete, newly-known requirement for the
  profiling pass.

Artifacts: harness in [`smoke-test/`](../../smoke-test/) (throwaway — delete when
the profiling task no longer needs it); learning notes in
[`assets/0011-ios-smoke-test-notes.md`](../assets/0011-ios-smoke-test-notes.md);
CI script-error gate in `.github/workflows/deploy-prototype.yml`.
