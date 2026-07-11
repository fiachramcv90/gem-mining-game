# Save system on the web build — architecture, format & Godot save-API notes

> Research asset for ticket **0009 — Save system on the web build**.
> Audience: Fiachra — solo dev, evenings/weekends, no deadline; new to Godot,
> strong TypeScript/web background with real IndexedDB experience (Dexie).
> Scope: how a Godot 4 web export persists reliably, the save **architecture and
> data format** (seed + deltas + wallet/upgrades + run state), versioning, and the
> **safety hatch** given that web storage is evictable + context-local. Explicitly
> captures **what transfers from Dexie/IndexedDB knowledge** and what doesn't.
> **Not** in scope: the worldgen delta *model* (which tiles are deltas is
> [0005](0005-worldgen.md)'s; 0009 only serializes it), economy *values*
> ([0006](../tickets/0006-economy-upgrades.md)), hazards
> ([0007](../tickets/0007-hazards-depth.md)).

## TL;DR — the decision

- **Storage backend:** `user://` on web is a virtual filesystem backed by
  **IndexedDB** via Emscripten's **IDBFS**. Godot **auto-syncs** to IndexedDB
  itself (you do *not* call `syncfs` manually), once per main-loop iteration after
  any persistent-path file is written and closed — but the sync is **asynchronous**,
  so a tab killed in the split-second after a write can lose *that last write*.
- **Format:** one save file, `user://save.dat`, written with Godot **binary
  `store_var`/`get_var`** as a **plain `Dictionary`** (no custom `Resource`/class in
  the file — that would bind the save to script paths and break on refactor). Human
  effort goes into a stable **envelope schema** with a `save_version` int for
  migration.
- **The deltas (0005's requirement, 0009's format):** don't serialize the world.
  Save `world_seed` + a **per-chunk 128-byte "dug" bitmask** (32×32 = 1024 bits) for
  removed tiles, plus a **sparse `collected` coord list** for taken gems. Touched
  chunks only ⇒ bounded by *progress*, not world size. **Fully digging the entire
  ~700×96 designed mine is ≈ 8 KB.** The save is *kilobytes* — so **quota is a
  non-issue**; the only real loss risks are eviction and context-divergence.
- **Durability on iOS Safari:** default storage is **best-effort** ⇒ evictable by
  (a) WebKit's **7-day-no-interaction cap** on script-writable storage, (b) LRU under
  storage pressure, (c) overall-quota overflow (unlikely at KB scale). Mitigations:
  call **`navigator.storage.persist()`** at startup (WebKit grants it silently for
  installed / interacted apps), and **nudge "Add to Home Screen"** — a home-screen
  web app is **exempt from the 7-day cap** and keeps its own storage counter. Note
  the flip side (0002): the installed PWA and the Safari tab hold **independent**
  copies.
- **Safety hatch (Fiachra's call):** ship **local export/import now** — export via
  `JavaScriptBridge.download_buffer()`, import via an HTML file input — **designed so
  cloud backup can be bolted on later** with no format change. Both export and a
  future cloud sync consume the *same* serialized blob (the `SaveBlob` seam, §7).
- **What transfers from Dexie:** the whole *durability mental model* (async persist,
  quota, eviction, `persist()`/`estimate()`) transfers 1:1 — it's literally the same
  IndexedDB. What **doesn't**: you get a **POSIX file**, not object stores /
  indexes / transactions / queries. You read and write *whole files*; you don't
  `.put()` a row and `await` it. Versioning is yours to hand-roll in the file, not
  Dexie's `.version().stores()`. (Full table §5.)

---

## 1. How a Godot web export persists — `user://` → IDBFS → IndexedDB

Godot's docs state it plainly: on web, "**`user://` will refer to a virtual
filesystem stored on the device via IndexedDB**" ([data_paths]). Under the hood this
is **Emscripten's IDBFS**, the persistent filesystem backend Emscripten provides for
browser builds. Two facts about IDBFS drive everything downstream:

1. **IDBFS is MEMFS-backed and syncs in bulk.** File I/O hits an in-memory
   filesystem (MEMFS); a separate call, **`FS.syncfs()`**, serializes the tree into
   an IndexedDB object store (and `syncfs(populate=true)` reads it back at startup).
   IndexedDB is asynchronous and POSIX file I/O is synchronous, so this
   store-then-sync split is unavoidable ([Emscripten FS API]). The Emscripten
   warning is explicit: **if you don't call `FS.syncfs()` before the page closes,
   the MEMFS changes are lost.**

2. **Godot calls `syncfs` for you — automatically.** This is the crucial
   Godot-specific detail and the answer to "does it persist reliably?" Since the
   web-persistence rework ([godot#42266]), `OS_Web::main_loop_iterate` triggers
   `godot_js_os_fs_sync` **once per main-loop iteration if at least one file in a
   persistent path was opened for writing and then closed, and a sync isn't already
   in flight.** That batching was added specifically to fix "autosave doesn't
   persist on web" reports (naïvely syncing on every write never completed under
   heavy write traffic). **Consequence for us:** in GDScript you just
   `FileAccess.open(..., WRITE)` → write → `close()` (or let the handle free), and
   Godot schedules the IndexedDB commit on the next frame. You do **not** wire
   `FS.syncfs` yourself.

**The residual reliability caveat.** The sync is deferred (next iteration) and
asynchronous. If the browser tab is destroyed in the window between your
`close()` and the IndexedDB transaction committing, that write is lost. This is a
*last-write* risk, not a corruption risk — the previously-synced state is intact.
Mitigation is about **when** we save (§6): save at natural safe points and, above
all, **flush on `visibilitychange → hidden`** (the reliable "app is going away"
signal on iOS Safari), giving the sync its best chance to land before teardown.

**Secure-context requirement (from 0002).** IndexedDB, the Storage API, service
workers and PWA install all require a **secure context (HTTPS)**. The GitHub Pages
host already satisfies this; a plain-HTTP host would silently break saves.

## 2. Durability on iOS Safari — the eviction model

The save *mechanism* works; the question 0002 flagged is whether the data *survives*.
iOS Safari's storage is **evictable** and, by default, **best-effort**.

**Best-effort vs persistent** ([MDN storage quotas]). By default every origin is
best-effort: data "persists as long as the origin is below its quota, the device has
enough storage space, and the user doesn't choose to delete it." Best-effort data is
subject to automatic **eviction**; persistent-mode data "is only evicted if the user
chooses to." Three eviction triggers apply to us:

- **WebKit's 7-day cap on script-writable storage.** Under Intelligent Tracking
  Prevention, WebKit **deletes all script-writable storage — IndexedDB,
  LocalStorage, SessionStorage, Cache API, service-worker registrations — after 7
  days of Safari use with no user interaction on the origin** ([WebKit tracking
  prevention]; [MDN] phrases it as eviction "when an origin has no user interaction,
  such as click or tap, in the last seven days of browser use"). For a hobby game
  a player dips into weekly, **this is the single most likely way a save
  disappears.**
- **LRU under storage pressure.** When the device is low on space, WebKit evicts the
  least-recently-used best-effort origin first, then the next ([MDN]). Low risk for
  us given the KB-scale save, but it exists.
- **Overall-quota overflow.** Since Safari 17 / iOS 17 the quota is computed from
  disk size (no more 1 GB prompt); a standalone home-screen app gets the **same**
  generous quota as the browser tab ([WebKit storage-policy update, 2023]). At a
  few-KB save this never binds.

**Two mitigations, both cheap:**

1. **`navigator.storage.persist()` at startup** (via `JavaScriptBridge`, §7). It
   requests persistent mode, which is exempt from eviction. On WebKit there's **no
   prompt** — it's auto-granted/denied from interaction history and installed-app
   status ([MDN]; Storage API is fully supported from **Safari 17+**). Calling it
   costs nothing and upgrades durability wherever WebKit says yes.
2. **Nudge "Add to Home Screen."** A home-screen web app's first-party storage is
   **exempt from the 7-day cap** — WebKit gives the installed app **its own
   day-counter tied to actual app use**, and its first-party data "is not expected to
   have its website data deleted" ([WebKit tracking prevention]). So the same
   onboarding nudge 0002 already wanted ("install first, then play") is *also* the
   strongest save-durability lever we have.

**The divergence gotcha (inherited from 0002, restated because it shapes the safety
hatch).** When iOS installs a PWA it does a **one-time copy** of Safari's storage
into the app's isolated context; thereafter the Safari tab and the installed app have
**fully independent** IndexedDB. A save made in the browser tab does **not** appear in
the installed app, and clearing Safari data can wipe the tab's copy. We cannot make
one canonical store across both — which is precisely why a **portable export/import**
(§7) is the right shape, not an attempt to unify the two contexts.

## 3. Save architecture — one file, plain Dictionary, binary `store_var`

**Storage call.** Godot's recommended save path ([saving_games]) is the
`FileAccess` API: `FileAccess.open("user://save.dat", FileAccess.WRITE)` then either
JSON (`store_string(JSON.stringify(dict))`) or **binary** (`store_var(dict)`),
mirrored by `get_var()` on read.

**Binary `store_var`, not JSON.** `store_var`/`get_var` (Godot's `var_to_bytes`
encoding) is chosen because:

- It round-trips Godot's own types natively — **`Vector2i`, `PackedByteArray`,
  `Dictionary`, `Array`** — which JSON cannot (JSON coerces everything to
  float/string and mangles `Vector2`). Our delta format leans on `Vector2i` keys and
  `PackedByteArray` masks (§4), so binary saves a pile of manual encode/decode.
- It's more compact (no key-name repetition, no base64 for the byte masks).
- The debuggability advantage of JSON is marginal here — the payload is bitmasks, not
  human-readable anyway.

**Plain `Dictionary`, never a custom `Resource`/`Object`.** Godot *can* serialize
script-backed objects (`store_var` with `full_objects`, or `ResourceSaver`), but that
**binds the save file to class/script paths and `PROPERTY_USAGE_STORAGE` flags** —
rename a script or drop a property and old saves fail to load. For a project that
*will* be refactored heavily while Godot is still new, the save must be a **dumb data
`Dictionary`** that has no dependency on the current class layout. (This also keeps
the door open for the export blob to be inspected/migrated without the game code.)

**The envelope schema** (field *ownership* noted; 0009 owns only the *shape*, not the
values other tickets assign):

```gdscript
{
  "save_version": 1,               # 0009 — schema version, drives migration (§6)
  "world_seed":   1234567890,      # 0005 — the generator seed. REQUIRED; without
                                   #        it the persistent mine can't regenerate.
  "world": {
     "dug":       { Vector2i(cx,cy): PackedByteArray(128 bytes), ... },  # §4
     "collected": PackedInt32Array([x0,y0, x1,y1, ...]),                 # §4
  },
  "wallet":   0,                   # 0006 owns the value; 0009 stores the field
  "upgrades": { "drill": 0, "hull": 0, "fuel": 0, "light": 0, ... },     # 0006
  "run":      null,                # optional in-progress run state (§3a); null = at surface
  "meta":     { "saved_at": <unix>, "play_secs": 0, "schema_note": "" },
}
```

### 3a. Run state — save mid-run, or only at the surface?

The core loop (0003) says a **lost run forfeits only carried cargo**; wallet + upgrades
+ the dug mine survive. That means the *load-bearing* persistent state is
**seed + deltas + wallet + upgrades** — all of which change only at safe moments
(digging updates deltas; selling/upgrading happens at the surface hub). **Carried
cargo and live fuel/hull are intentionally disposable** (a lost run drops them
anyway).

So `"run"` is **optional and best-effort**: persisting it lets a player resume an
interrupted descent exactly where they were (nice on mobile, where the OS kills
backgrounded tabs); omitting it simply respawns them at the surface with the mine and
wallet intact — which is *already* a valid game outcome, indistinguishable from a
lost run. **Decision:** save `run` on `visibilitychange → hidden` as a courtesy, but
never let its absence be a failure — load treats a missing/partial `run` as "start at
surface." This keeps the durable core tiny and the disposable part genuinely
disposable.

## 4. The delta format — 0005's requirement, 0009's serialization

0005's hard requirement: **regenerate each chunk as a pure function of
`(world_seed, chunk_x, chunk_y)`, then re-apply the player's dug/collected deltas** —
never serialize the world. 0009 owns *how those deltas are written*. The chunk
(32×32 tiles) is already 0005's load/free unit, so key the deltas by chunk to match
the load path exactly.

**Dug tiles → a per-chunk bitmask.** For each chunk the player has modified, store one
`PackedByteArray` of **128 bytes = 1024 bits**, one bit per tile in the 32×32 chunk:
`1` = the player has dug this tile (it's now empty/passable), `0` = untouched
(regenerate from seed). On chunk load, 0005's generator produces the pristine chunk,
then applies the mask by clearing the set bits. This is:

- **Self-compacting** — only *touched* chunks appear in the dictionary; an untouched
  chunk costs zero bytes, a fully-dug chunk costs a flat 128 bytes. No separate
  compaction pass is ever needed; the format can't bloat with revisits (digging is
  monotonic — a dug tile stays dug).
- **O(1) to look up and apply**, and a perfect fit for `PackedByteArray` (which
  `store_var` writes as raw bytes).

**Collected gems → a sparse coord list.** Digging a plain rock tile and *collecting a
gem* are different events (0003: when the hold is full, gems are **not** collected and
**stay in the ground** even as you dig around them), so "dug" and "collected" are
distinct sets and both must persist — otherwise a collected gem would respawn, or an
uncollected one would vanish. Gems are sparse (~8% of tiles, and *collected* ones far
fewer), so a bitmask is wasteful; store collected gems as a flat
**`PackedInt32Array` of interleaved global `[x, y, x, y, …]`** coordinates. On load,
a gem tile whose coord is in the set is rendered already-taken. *(Which tiles count
as "dug" vs "collected" is 0005/0003's model; 0009 just guarantees the format can
carry both sets independently.)*

**Size math — why quota never matters.** The whole designed mine is ~700 deep × 96
wide ≈ 67,200 tiles ÷ 1024 tiles/chunk ≈ **66 chunks**. Even if the player dug
*every* tile: 66 × 128 bytes ≈ **8.4 KB** of dug-masks. Add a few hundred collected
gems (~8% × explored, but only the taken ones) at 8 bytes each — still low single-digit
KB. **A maximally-explored save is well under ~15 KB.** Against Safari's disk-derived
quota this is nothing: the durability problem is **eviction and divergence, never
size.** (This also means we never need incremental/append saves — rewriting the whole
file is cheap.)

## 5. What transfers from Dexie / IndexedDB knowledge — and what doesn't

Fiachra knows IndexedDB well from Dexie. The backing store on web **is** IndexedDB, so
a lot transfers — but Godot hands you a *filesystem*, not a database, so the access
model is completely different.

| Aspect | Dexie / raw IndexedDB (what you know) | Godot `user://` on web | Transfers? |
|---|---|---|---|
| **Backing store** | IndexedDB | IndexedDB (via Emscripten IDBFS) | ✅ Same engine, same durability physics |
| **Eviction / quota** | best-effort vs persistent; LRU; 7-day cap; `estimate()` | *Identical* — same WebKit rules apply | ✅ 1:1 — your Dexie eviction instincts are correct |
| **`navigator.storage.persist()` / `.estimate()`** | You call them directly in JS | Call via `JavaScriptBridge` (§7); same semantics | ✅ Same API, reached through the bridge |
| **Secure context (HTTPS)** | Required | Required | ✅ Same |
| **Access model** | Typed **object stores**, keys, **indexes**, cursors, range queries | A **POSIX file** (`user://save.dat`). No stores, no indexes, no queries | ❌ **Fundamentally different** — you read/write whole files |
| **Transactions** | `db.transaction()`, atomic multi-op, `await tx.done` | None from GDScript. A file write, then Godot's batched `syncfs` | ❌ No cross-write atomicity; design saves to be whole-file & idempotent |
| **When it's durable** | `await store.put()` resolves ⇒ committed | `close()` → Godot syncs **next frame, async** — no await, no completion signal | ⚠️ Similar async reality, but **you can't await the commit** (§1 caveat) |
| **Schema / migration** | `db.version(n).stores({...})`, `.upgrade()` | Hand-rolled: a `save_version` int + your own migration branch (§6) | ❌ You own versioning; no framework does it |
| **Querying inside a save** | Rich queries over rows | None — deserialize the whole `Dictionary`, work in memory | ❌ Load-all-into-RAM (fine — it's KB) |
| **Inspecting the DB** | DevTools → IndexedDB, or open with Dexie | Emscripten stores the FS as opaque blobs in its own IDB DB; **not** Dexie-openable | ❌ Debug via the game / the export blob, not DevTools rows |

**One-line takeaway:** *durability reasoning transfers completely; data-access
patterns do not.* Treat `user://` as "a file I must serialize a whole object graph
into," not "a queryable store." Your Dexie reflex to reach for indexes/transactions
has no counterpart here — and doesn't need one, because the payload is tiny and read
all-at-once.

## 6. Versioning, migration & save cadence

**Versioning.** `save_version` is the first thing checked on load. If it's older than
the current constant, run an ordered chain of migration steps (add defaults for new
keys, rename/transform old ones) before handing the dict to the game. Because the save
is a plain `Dictionary`, migrations are just dictionary edits — no class-compat
minefield. Rules that keep this painless:

- **Only ever add keys or bump `save_version`**; never silently repurpose a key's
  meaning without a version bump.
- **Load defensively:** a missing key → its default (a fresh field must never break an
  old save). Guard `world_seed` specifically — a save without it is unrecoverable, so
  treat its absence as "corrupt, start new game," never as seed 0.
- Keep a tiny pure `migrate(dict) -> dict` function so migrations are unit-testable
  off-device.

**Cadence — when to write the file.** The save is KB and Godot batches the sync, so
"save often" is cheap, but each write should be a *complete* snapshot at a
*consistent* moment. Write on:

- **Surface events** — arriving at the hub, after a sell, after buying an upgrade
  (wallet/upgrades just changed; these are the load-bearing durable transitions).
- **Run lost** — persist the mine deltas + wallet/upgrades (cargo is forfeit anyway).
- **`visibilitychange → hidden`** — the **most important** one on web. Wire a JS
  listener through `JavaScriptBridge` (or handle
  `NOTIFICATION_APPLICATION_PAUSED` / `NOTIFICATION_WM_GO_BACK_REQUEST`) to force a
  save the instant the tab is backgrounded, giving Godot's async `syncfs` its best
  chance to commit before iOS tears the tab down. `pagehide` is a secondary backstop;
  `beforeunload` is unreliable on iOS and shouldn't be depended on.
- Optionally a low-frequency **autosave tick** (e.g. every N seconds while digging) so
  a hard crash loses at most a few tiles of shaft.

We deliberately **don't** save per-dug-tile — unnecessary given the batched sync and
the visibility-flush, and it'd thrash the file.

## 7. The safety hatch — local export/import now, cloud-ready seam

**Decision (Fiachra):** ship **local export/import now**, but structure it so **cloud
backup can be added later without touching the format.** The enabling idea is a single
serialization choke point:

> **The `SaveBlob` seam.** One function turns the live game state into a
> self-contained `PackedByteArray` (the §3 envelope via `var_to_bytes`), and one
> function loads a `PackedByteArray` back. **Every** persistence path consumes that
> same blob: (1) the local `user://save.dat` write, (2) file export/import, and (3) a
> *future* cloud PUT/GET. Adding cloud backup later = "POST these bytes to a URL, GET
> them back" — no new format, no migration, no change to the game's save logic.

**Local export** (works today, zero backend): serialize to the blob, then hand it to
the browser with Godot's built-in **`JavaScriptBridge.download_buffer(bytes,
"gem-miner-save.dat", "application/octet-stream")`** — this is exactly the
web-export API for pushing a byte buffer to the user as a file download. The player
gets a file they can stash in iCloud/Files/email — durable across cache-clears, and
the *only* bridge between the Safari-tab save and the installed-PWA save given their
independent storage (§2).

**Local import:** trigger a hidden HTML `<input type="file">` (created/clicked via
`JavaScriptBridge.eval` / a small JS glue), read the chosen file's bytes back into
Godot, run them through migration (§6), and overwrite `user://save.dat`. Guard with a
"this replaces your current progress" confirm.

**Persistence opt-in + install nudge** (also today): on first run, call
`navigator.storage.persist()` through the bridge, and surface the **"Add to Home
Screen"** prompt in onboarding (0002 already wanted this; §2 shows it's *also* the
best eviction defence). `navigator.storage.estimate()` is available through the same
bridge if we ever want to show usage.

**Cloud backup — deferred, not designed out.** Kept out of the vertical slice (it
needs a backend, an identity/auth flow, and conflict handling — real weight for a
solo evenings-and-weekends project, and the local hatch already covers device loss and
cache-clears). But because everything flows through the `SaveBlob` seam, switching it
on later is additive. If/when it lands it's the smallest possible service: store one
opaque blob per player, last-write-wins, keyed by an anonymous token — no
server-side understanding of the format required.

## 8. Godot save-API learning notes (continuing the 0001/0004/0005 path)

For a web dev meeting Godot's persistence for the first time:

- **`FileAccess`** is the file handle. `FileAccess.open("user://save.dat",
  FileAccess.WRITE)` returns it; `.store_var(value)` writes one binary-encoded
  Variant, `.get_var()` reads it back; `.close()` (or letting the `RefCounted` handle
  free) flushes. `FileAccess.file_exists("user://save.dat")` gates first-run. There's
  no "database" — it's fopen/fwrite with Godot types.
- **`var_to_bytes(value)` / `bytes_to_var(bytes)`** are the same binary codec exposed
  as pure functions — this *is* the `SaveBlob` serializer (§7); `store_var` is just
  `var_to_bytes` piped to a file. Use `var_to_bytes` for export/cloud, `store_var`
  for the local file — identical bytes either way.
- **`JSON.stringify` / `JSON.parse`** exist if you ever want a human-readable save,
  but they lose Godot types (no `Vector2i`, no `PackedByteArray`) — not used here.
- **`user://` = IndexedDB on web, a real folder on desktop.** Same GDScript code,
  different backend; you never touch IndexedDB or `syncfs` directly — Godot syncs
  after file close (§1). On desktop the file is at
  `~/.local/share/godot/app_userdata/<project>/` etc. ([data_paths]).
- **`JavaScriptBridge`** is the escape hatch to the browser: `.download_buffer()` for
  export downloads, `.eval("…js…")` to call `navigator.storage.persist()` /
  `.estimate()` / wire a `visibilitychange` listener, and `.create_callback()` to call
  back into GDScript from JS (e.g. when the file-import input resolves). It's a no-op
  off-web, so guard web-only paths with `OS.has_feature("web")`.
- **Autoloads (0001)** are the natural home: a `SaveManager` singleton owns the
  envelope, the `SaveBlob` seam, cadence, and migration; `Wallet`/run/world autoloads
  hand it their slice on save and receive it on load.
- **Don't save `Resource`/`Object` graphs** into the file — plain `Dictionary` only
  (§3), or a script rename breaks old saves. This is the one Godot save footgun worth
  memorising.

## 9. What this clears / hands off

- **Answers 0009 fully** and confirms 0002's hand-off: web `user://` *is* evictable +
  context-divergent IndexedDB, and the save system is built for that (persist() +
  install nudge + portable export/import), not against it.
- **Closes the loop with 0005:** the delta *model* stays 0005's; 0009 pins its
  *serialization* — per-chunk 128-byte dug bitmask + sparse collected-coord list,
  keyed by 0005's 32×32 chunk, `world_seed` saved alongside. The chosen keying matches
  0005's chunk load/free path, so re-applying deltas *is* the existing chunk-load step.
- **Touches 0006 only as fields:** `wallet` + `upgrades` are named slots in the
  envelope; their *values and curves* remain 0006's. No economy decision is made here.
- **Reinforces the 0002 onboarding nudge** ("Add to Home Screen first") by giving it a
  second, independent reason: home-screen apps dodge the 7-day storage cap.
- **No new tickets, no scope changes.** Cloud backup is explicitly *deferred, not
  dropped* — the `SaveBlob` seam keeps it a future additive change, so it stays out of
  the map as anything but a possible later enhancement. The performance-budget /
  playtesting fog is untouched by this ticket.

## Sources

- [Saving games — official Godot docs (`tutorials/io/saving_games.rst`, master)](https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/io/saving_games.rst) — `FileAccess` save API, `store_var`/`get_var` binary vs JSON, `PROPERTY_USAGE_STORAGE`, `ConfigFile`. *(Primary; docs site egress-blocked, read via godot-docs GitHub source, as in 0002.)*
- [File paths in Godot projects — official Godot docs (`tutorials/io/data_paths.rst`, master)](https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/io/data_paths.rst) — "`user://` … a virtual filesystem stored on the device via **IndexedDB**" on HTML5; per-platform paths; `JavaScriptBridge` note. *(Primary, via GitHub source.)*
- [Emscripten File System API — IDBFS / `FS.syncfs`](https://emscripten.org/docs/api_reference/Filesystem-API.html) — MEMFS-backed IDBFS, `syncfs(populate)`, `autoPersist`, and the "changes lost if you don't sync before the page closes" warning. *(Primary — the storage layer under Godot web.)*
- [godot#42266 — "[HTML5] Synchronous main, better persistence…" (Faless)](https://github.com/godotengine/godot/pull/42266) — Godot's own auto-sync: `OS_Web::main_loop_iterate` → `godot_js_os_fs_sync`, batched once/loop after a persistent-path file is written+closed; the fix for "autosave doesn't persist on web." *(Primary — Godot source/PR.)*
- [Storage quotas and eviction criteria — MDN](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria) — best-effort vs persistent, LRU eviction, `navigator.storage.persist()` (WebKit auto-decides, no prompt), `estimate()`, and Safari's 7-day-no-interaction eviction. *(High-trust reference.)*
- [Tracking Prevention in WebKit — WebKit.org](https://webkit.org/tracking-prevention/) — the **7-day cap on all script-writable storage** (IndexedDB/LocalStorage/SessionStorage/Cache/SW regs) and the **home-screen-web-app exemption** (own day-counter, first-party data not deleted). *(Primary — WebKit; page itself egress-blocked via the proxy, content confirmed through search excerpts + MDN corroboration.)*
- [Updates to Storage Policy — WebKit.org blog 14403 (2023)](https://webkit.org/blog/14403/updates-to-storage-policy/) — Safari 17/iOS 17 disk-derived quota (browser origin ≤60%/overall ≤80%; standalone app gets the **same** quota as the browser), eviction triggers. *(Primary — WebKit; egress-blocked, figures confirmed via search excerpts.)*
- [StorageManager: persist() — MDN](https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/persist) & Storage API support from Safari 17+ — persistent-mode semantics and platform support. *(High-trust reference.)*
- `JavaScriptBridge.download_buffer()` — Godot 4 web-export API for pushing a `PackedByteArray` to the user as a file download (the local-export mechanism). Godot `JavaScriptBridge` class reference, `docs.godotengine.org`.
- Inherited constraints: [0002 web-export asset](0002-web-export-ios-safari.md) (user:// = evictable/context-divergent IndexedDB; secure context; PWA one-time-copy divergence; install nudge), [0005 worldgen asset](0005-worldgen.md) (regenerate-from-seed + re-apply deltas; 32×32 chunks; `world_seed` saved), [0003 core-loop asset](0003-core-loop.md) (persist dug-tile state; wallet/upgrades survive a lost run; cargo is disposable).
- Method: `/research` against primary sources + `/domain-modeling` to keep the format aligned with CONTEXT.md's ubiquitous language (world seed, chunk, delta, wallet, cargo, run).
