---
id: 0009
title: "Save system on the web build"
type: research
status: closed
assignee: fiachramcv (claude session claude/gem-miner-save-0009-vcxsvz)
blocked-by: [0002]
---

## Question

How does a Godot web export persist saves reliably (user:// → IndexedDB behaviour, iOS Safari eviction of site data, export/import as a safety hatch)? Decide the save architecture and data format. Fiachra knows IndexedDB well from Dexie work — capture what transfers.

## Resolution

**Full research asset: [Save system on the web build — architecture, format & Godot save-API notes](../assets/0009-save-system.md).**

Decided architecture and format:

- **Persistence mechanism.** Web `user://` is IndexedDB via Emscripten **IDBFS**.
  Godot **auto-syncs** to IndexedDB itself (`OS_Web::main_loop_iterate` →
  `godot_js_os_fs_sync`, batched once per loop after a persistent file is
  written+closed) — you never call `syncfs`. The sync is async, so the only residual
  risk is losing the *last* write on an abrupt tab kill → mitigated by flushing on
  `visibilitychange → hidden`. Secure context (HTTPS) required.
- **Format.** One file `user://save.dat`, written with **binary `store_var`** as a
  **plain `Dictionary`** (never a `Resource`/class — that binds the save to script
  paths). Envelope: `save_version` (migration), `world_seed` (0005, required),
  `world.dug` + `world.collected` (deltas, below), `wallet` + `upgrades` (0006 fields),
  optional best-effort `run` state, `meta`.
- **Deltas (0005's requirement, 0009's serialization).** Never serialize the world.
  Per **32×32 chunk** (0005's unit): a **128-byte dug bitmask** (1 bit/tile) for
  removed tiles + a **sparse `PackedInt32Array`** of collected-gem coords (dug ≠
  collected, per 0003's full-hold rule). Touched chunks only ⇒ bounded by progress:
  **fully digging the entire designed mine is ≈ 8 KB.** The save is *kilobytes* — so
  quota is a non-issue; the risks are eviction + PWA/Safari divergence, not size.
- **Durability.** Default storage is best-effort/evictable (WebKit **7-day
  no-interaction cap**, LRU, quota). Mitigate with `navigator.storage.persist()` at
  startup and an **"Add to Home Screen" nudge** — the installed web app is **exempt
  from the 7-day cap** (its own use-counter) and gets the same generous quota.
- **Safety hatch (Fiachra's call):** **local export/import now** —
  `JavaScriptBridge.download_buffer()` out, HTML file-input in — **designed cloud-ready
  via a single `SaveBlob` seam** (local file, export, and any future cloud PUT/GET all
  consume the same serialized bytes), so cloud backup is a later *additive* change,
  not a reformat.
- **Dexie transfer (explicit).** The *durability model* transfers 1:1 (same IndexedDB
  — quota, eviction, `persist()`/`estimate()`). What doesn't: `user://` is a **POSIX
  file**, not object stores/indexes/transactions/queries; you read/write whole files
  and hand-roll versioning. Full table in the asset.

No new tickets; no scope changes. Cloud backup is deferred-not-dropped behind the
`SaveBlob` seam.
