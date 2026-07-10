# Godot 4 web export on iOS Safari — viability & mitigations

> Research asset for ticket **0002 — Godot 4 web export viability on iOS Safari**.
> Audience: Fiachra — all-Apple devices, no Apple dev account, web-first platform
> decision. Route-critical: a negative answer would redraw the platform decision.
> Scope: does Godot's HTML5 export run *acceptably* on current iOS Safari, and if
> there are sharp edges, what are the mitigations. Not deciding worldgen, dig-feel,
> or the final performance budget — those are their own tickets (0004, 0005).

## Verdict — web-first HOLDS ✅

**Godot 4's web export runs acceptably on current iOS Safari, and the platform
decision does not need to be redrawn** — *provided the game ships as a
**single-threaded** export and is built to live inside iOS Safari's memory
ceiling.* Both are cheap, well-trodden choices that a small 2D tile-digger fits
comfortably.

The historical horror stories ("Godot 4 web doesn't work on iPhone") are real but
**dated**: they describe the pre-4.3 era when web export *required* threads +
`SharedArrayBuffer`, which is exactly what Safari choked on. Godot 4.3 (Aug 2024)
added a single-threaded export path that removes that requirement, and the official
docs now state it **"works very well on macOS and iOS too, where it always had
compatibility issues with multiple threads exports."** As of this research (Jul
2026) the latest stable is **Godot 4.7**; anything **4.3 or newer** clears the
route, so this is fully consistent with ticket 0001's "latest stable 4.x, hard
floor 4.3" recommendation.

**The one thing that must shape the build from day one is memory** (see §4) — iOS
Safari kills WebGL contexts / WASM allocations far sooner than desktop, and that,
not the CPU/renderer, is the real ceiling for a web game on iPhone.

---

## 1. The core blocker and why it's now solved: threads / `SharedArrayBuffer`

**What used to break.** Godot 4.0–4.2 web exports were multi-threaded only, which
relies on the `SharedArrayBuffer` browser API. `SharedArrayBuffer` requires the
page to be **cross-origin isolated**, which means the server must send two headers
on every response:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

That was a double problem: (a) many hosts (itch.io, Poki, CrazyGames, plain static
hosting) don't let you set those headers, and (b) **iOS/macOS Safari had upstream
bugs handling threaded WASM + `SharedArrayBuffer`**, so even correctly-isolated
pages failed on Apple devices. This is the root of every "won't run on iPhone"
thread.

**The fix — single-threaded export (Godot 4.3+).** The docs are explicit:

> "Since Godot 4.3, Godot supports exporting your game on a single thread, which
> solves this issue." … "the single-threaded export works very well on macOS and
> iOS too, where it always had compatibility issues with multiple threads exports."

Single-threaded is also the **default and recommended** path: it drops the
`SharedArrayBuffer` dependency entirely, so **no COOP/COEP headers are needed** and
the game runs on restrictive hosts. Threads remain an *opt-in* export toggle
("Thread Support") that buys multithreading + lowest-latency audio at the cost of
requiring cross-origin isolation again — **we deliberately do not enable it.**

> **Decision:** ship the **single-threaded** web export. No COOP/COEP server
> headers required; maximal host compatibility; the Apple-Safari thread bugs are
> sidestepped by construction.

## 2. Renderer: Compatibility (WebGL 2.0) only — and that's fine for us

The web platform can **only** use the **Compatibility** renderer, which targets
**WebGL 2.0**. Quoting the docs:

> "Godot 4 can only target WebGL 2.0 (using the Compatibility rendering method).
> Forward+/Mobile are not supported on the web platform, as these rendering methods
> are designed around modern low-level graphics APIs." … "Godot currently does not
> support WebGPU, which is a prerequisite for allowing Forward+/Mobile to run on the
> web platform."

So the Forward+ vs Mobile vs Compatibility question **doesn't exist on web — it's
Compatibility or nothing.** For a 2D sprite/tilemap game this is a non-issue:
Compatibility is the intended renderer for exactly this kind of game and is the
"clear winner for mass-market web export." (WebGPU would unlock Forward+/Mobile on
web eventually, and Godot 4.7 shipped `wasm64` groundwork, but none of it is needed
here.)

**Safari caveat, and why it doesn't bite us.** Safari has a few WebGL 2.0
conformance quirks that Chromium/Firefox don't, and the docs even suggest "using a
Chromium-based browser or Firefox if possible." But: (a) our target *is* iPhone,
where Safari (WebKit) is the only real engine — even Chrome on iOS is WebKit under
the hood — so we design against Safari's WebGL 2.0, not around it; and (b) a plain
2D tilemap uses the boring, well-supported subset of WebGL 2.0, not the exotic
features Safari trips on. Real-world reports have a Compatibility-renderer 2D build
hitting **60 FPS on an iPhone 15**.

## 3. Audio on iOS Safari

Two things to know, both manageable:

**Playback mode.** Godot 4.3+ defaults web audio to **"Sample" playback** via the
Web Audio API, which gives **low latency even without thread support** — this is
what makes single-threaded builds sound fine (it fixed the "audio garble" that
plagued early single-threaded 4.3 builds). The tradeoff, per the docs:

> "AudioEffects are not supported. Reverberation and doppler effects are not
> supported. Procedural audio generation is not supported. Positional audio may not
> always work correctly depending on the node's properties."

The alternative **"Stream" playback** restores full audio features (effects, etc.)
but adds latency, especially without threads. **For a digging game whose audio is
one-shot SFX (dig thud, gem chime, engine hum) + a music loop, Sample playback is
the right choice** — we don't need reverb/doppler/procedural. Keep that in mind as a
constraint for the audio ticket (0008): design the sound palette around simple
one-shots and looped streams, not bus effects.

**Autoplay gesture.** iOS Safari (and others) block audio until a user gesture:

> "Some browsers restrict autoplay for audio… The easiest way around this is to
> request the player to click, tap or press a key/button to enable audio."

Trivial to satisfy — the game already opens on a "tap to start / tap to dig" screen,
which doubles as the audio-unlock gesture.

## 4. The real ceiling on iOS: memory (design around this from day one) ⚠️

This is the finding that actually matters for a web game on iPhone. iOS Safari is
far stingier with memory than desktop, and it **kills the WebGL context / WASM
allocation** rather than degrading gracefully.

- **WASM max-memory cap.** A default Godot web build historically requested a
  **2 GB** WASM maximum, which **iOS Safari refuses to initialize** → out-of-memory
  at `WebAssembly.Memory` creation (Godot issue #70621, iOS 16.2). The reporter's
  fix was lowering `WASM_MEM_MAX` (e.g. to 256 MB); the issue is tracked/confirmed
  upstream and the default ceiling has since been tuned down. **Action for us:**
  verify the exported build's max memory is modest and test allocation on a real
  iPhone early.
- **Baseline heap is not free.** A *default, empty-ish* Godot 4.3/4.4 web export
  already sits around a **~77 MB heap on localhost but ~400 MB when server-hosted**,
  and that 400 MB is enough to trigger **"WebGL context lost"** on iOS Safari 16.2
  (issue #104422). So the engine baseline eats a big chunk of the budget before our
  content loads.
- **Canvas-resize leak (WebKit bug).** A confirmed WebKit bug leaks memory on every
  canvas resize / WebGL-context recreation until the tab crashes around **~1.25 GB**.
  Orientation changes are the trigger. **Mitigation:** never recreate the WebGL
  context; resize the existing canvas dimensions instead, and minimise resize churn
  (e.g. lock/accept a single orientation, handle rotation by resizing not
  re-initing). Godot manages the canvas itself, so mostly this means **don't fight
  the canvas / avoid orientation thrash** in the HTML shell.

**Why a Motherload-style game is well-placed to fit.** The one genuinely
memory-hungry axis of this genre is the *ever-deeper mine* — a naïvely-retained,
unbounded `TileMapLayer` plus accumulated pickups/particles is exactly the "floor 7
exceeds what floor 1 fit because you never released floor 3" failure mode. The
counter is chunk streaming / freeing off-screen tiles and capping particles — which
is **already the substance of the map's "Performance budget" fog** and worldgen
(0005). This research promotes that fog from "nice to have" to **"the binding
constraint on iOS,"** and gives it a concrete target: **keep steady-state memory
comfortably under the iOS Safari ceiling (budget against ~few-hundred-MB, not GBs).**

## 5. Performance

CPU/GPU performance is **not** the limiting factor for a 2D tile game here — memory
(§4) is. With the Compatibility renderer and sane assets, a 2D Godot web build
reaches **60 FPS on iPhone 15** in real-world reports. Standard web-export
optimisations apply and are cheap:

- **Texture compression:** use **Basis Universal** for textures (the setting that
  took a mobile test from failed-load/20 FPS on Forward+ to **60 FPS on iPhone 15**
  on Compatibility) — smaller GPU memory + faster loads, directly helping §4 too.
- **Download size / first load:** the WASM + PCK download is the other web tax; keep
  the atlas count and audio bitrate modest, and PWA caching (§6) makes the *second*
  load instant.
- **Single-threaded means one core:** no worker parallelism, so keep per-frame work
  (worldgen chunking, physics on many tiles) incremental rather than bursty. This is
  a 0004/0005 concern, flagged here as a constraint.

## 6. PWA / home-screen behaviour on iOS

Godot's export has a built-in **Progressive Web App** toggle that provides
home-screen install icons, an offline service worker (loads without a connection
after the first visit), a configurable offline fallback page, and — usefully —
**auto-applies the COOP/COEP cross-origin-isolation headers via the service
worker**. (That last part only matters if you ever enable threads; for our
single-threaded build it's simply harmless.)

**iOS-specific realities of "Add to Home Screen":**

- iOS creates a **WebClip in standalone mode** — the app opens **with no Safari
  chrome**, custom splash screen and status-bar theming work. This is the closest
  thing to "it feels like an app" without an App Store account, and it's genuinely
  good for our use case.
- **No true Fullscreen API on iOS, and no orientation lock.** Standalone mode
  already hides the browser UI, so we don't *need* the Fullscreen API — but **don't
  build anything that depends on `requestFullscreen()` or programmatic orientation
  lock on iOS**; neither is available. Handle layout with the safe-area insets
  (`viewport-fit=cover` + `env(safe-area-inset-*)`) so the notch/home-indicator
  don't clip the HUD.
- **Storage isolation gotcha that touches saves (0009).** When a PWA is installed to
  the home screen, iOS does a **one-time copy** of Safari's cookies/storage into the
  PWA's isolated context, after which **Safari and the installed PWA have fully
  independent cookies / localStorage / IndexedDB.** Godot's `user://` filesystem is
  backed by **IndexedDB** on web. **Consequence:** a save made in the *browser* tab
  won't appear in the *installed* PWA (and vice-versa), and clearing Safari data can
  wipe it. The save system (0009) must treat web storage as **evictable and
  context-local** — provide manual export/import or cloud backup if progress must
  survive — and onboarding should nudge "add to home screen first, then play."

## 7. Mitigations & fallbacks — summary

| Risk on iOS Safari | Mitigation (all in-scope, cheap) |
|---|---|
| Threaded WASM / `SharedArrayBuffer` fails on Safari | **Ship single-threaded export** (default since 4.3). No COOP/COEP needed. |
| 2 GB WASM max rejected → OOM on init | Keep exported **max memory modest**; test alloc on a real iPhone early. |
| ~400 MB baseline heap → "WebGL context lost" | Chunk-stream the mine; free off-screen tiles/pickups; cap particles (0005/perf budget). |
| Canvas-resize memory leak → tab crash ~1.25 GB | Don't recreate the WebGL context; avoid orientation thrash; resize don't re-init. |
| Safari WebGL 2.0 quirks | Use the plain 2D subset (tilemaps/sprites); test on device, not just Chromium. |
| Audio blocked until gesture / no effects | "Tap to start" unlocks audio; design SFX as one-shots (Sample playback). |
| No Fullscreen API / orientation lock on iOS | Use PWA standalone + safe-area insets; don't depend on Fullscreen API. |
| Web storage evicted / PWA-vs-Safari divergence | Save system (0009): treat `user://`/IndexedDB as evictable + context-local; offer export/backup. |

**Fallback engines — not needed, and noted for completeness.** Because the answer is
positive, we don't invoke a fallback. *If* a future finding reversed this (e.g. the
memory ceiling proved unworkable for our content), the escape hatches would be, in
order: (1) trim content/memory harder and stay on Godot web; (2) wrap the same web
build in a thin native shell later *only if* an Apple dev account is acquired (this
is the already-out-of-scope App Store path, not a re-engine); (3) as a last resort,
a lighter web-native engine (e.g. a JS/TS 2D framework Fiachra already knows) — but
that discards the Godot investment from 0001 and is explicitly **not** recommended.
**None of these are on the table given the positive verdict.**

## 8. Recommended web export settings (concrete)

When Fiachra reaches the export step, the iOS-safe configuration is:

- **Renderer:** Compatibility (forced on web anyway).
- **Thread Support:** **OFF** (single-threaded). ← the key toggle.
- **PWA:** **ON** — for home-screen install, offline caching, icons, safe headers.
- **Audio playback:** **Sample** (default) — low latency, no bus effects.
- **Textures:** Basis Universal (VRAM Compressed) for anything large.
- **Memory:** confirm the export's max WASM memory is modest (not 2 GB); verify on a
  physical iPhone, not the simulator (simulators don't reproduce the memory/safe-area
  behaviour).
- **Serving:** HTTPS (secure context is required for `user://`/IndexedDB, PWA, and
  most web features). No special COOP/COEP headers required in the single-threaded
  config.

## 9. What this unblocks / hands off

- **Unblocks ticket 0004 (Dig feel & touch controls prototype)** — 0004 was
  `blocked-by: [0001, 0002]`; with 0001 already closed, **0002 closing makes 0004 a
  frontier ticket.** The prototype can now be built knowing the platform is Godot
  web, single-threaded, Compatibility renderer, touch-first.
- **Sharpens the "Performance budget" fog into a *binding constraint*.** It's no
  longer a vague "we'll profile later" — it's **"steady-state memory must stay under
  iOS Safari's ceiling,"** which drives chunk-streaming/tile-freeing in worldgen
  (0005). Still fog (needs 0005's worldgen shape before a number can be set), but now
  with a clear target and reason. Left in *Not yet specified* with that framing.
- **Hands the save system (0009) a hard requirement:** web `user://` is IndexedDB —
  **evictable and context-divergent between Safari and the installed PWA** — so 0009
  must design for lossy/portable saves (manual export/import or cloud backup), not
  assume durable local storage.
- **Constrains the audio ticket (0008):** design around **Sample-playback** one-shots
  + looped music; no reverb/doppler/procedural/bus effects on web.
- **No new decisions needed that aren't already ticketed or fogged**, so no new
  tickets are created by this resolution.

## Sources

- [Exporting for the Web — official Godot docs (latest)](https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/export/exporting_for_web.html) — threading/single-thread, COOP/COEP, WebGL2-only/Compatibility, WebGPU status, audio (Sample vs Stream), PWA, iOS/macOS notes, full limitations list. *(Primary source; docs site itself was egress-blocked, read via the godot-docs GitHub source `tutorials/export/exporting_for_web.rst`.)*
- [Web Export in 4.3 — Godot Engine blog](https://godotengine.org/article/progress-report-web-export-in-4-3/) — single-threaded export lands, iOS/macOS thread issues "disappear" single-threaded, audio-garble fix. *(Summarised via search; site egress-blocked for direct fetch.)*
- [godot4 Exporting web functional on macOS and iOS — godot-proposals #8896](https://github.com/godotengine/godot-proposals/discussions/8896) — root causes (SharedArrayBuffer + WebGL 2.0), single-threaded as the fix.
- [WebAssembly max memory 2GB causes OOM on iOS Safari 16.2 — godot #70621](https://github.com/godotengine/godot/issues/70621) — the WASM max-memory ceiling; `WASM_MEM_MAX` → 256 MB workaround; confirmed/tracked.
- [400MB memory heap in default web build — godot #104422](https://github.com/godotengine/godot/issues/104422) — ~77 MB (localhost) vs ~400 MB (hosted) baseline heap; "WebGL context lost" on iOS Safari.
- [Godot 4.3 will finally fix web builds, no SharedArrayBuffers required — Godot forum](https://forum.godotengine.org/t/godot-4-3-will-finally-fix-web-builds-no-sharedarraybuffers-required/38885) — community confirmation of the 4.3 change. *(Forum egress-blocked; via search summary.)*
- [PWA iOS limitations & Safari support](https://www.magicbell.com/blog/pwa-ios-limitations-safari-support-complete-guide) and [iPhone PWA game guide (gist)](https://gist.github.com/fozzedout/5e77925381991a9570151550992baf14) — WebClip/standalone, no Fullscreen API/orientation lock, canvas-resize ~1.25 GB crash, cookie/IndexedDB one-time-copy then divergence, safe-area/`viewport-fit=cover`.
- [Godot 4 web export optimization guide (2026)](https://best-games.io/blog/godot-web-export-optimization-guide) and search corroboration — Compatibility + Basis Universal = 60 FPS iPhone 15 vs Forward+ failed-load/20 FPS. *(Secondary; site egress-blocked for direct fetch, figures cross-checked via search.)*
- [Godot releases](https://github.com/godotengine/godot/releases) / [endoflife.date/godot](https://endoflife.date/godot) — latest stable is 4.7 (Jun 2026); 4.3 (Aug 2024) is the floor that introduced single-threaded web export; 4.7 added `wasm64` (raises the 4 GB heap ceiling on supporting browsers).
</content>
</invoke>
