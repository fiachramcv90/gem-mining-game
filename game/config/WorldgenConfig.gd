class_name WorldgenConfig
extends Resource
## Every worldgen/streaming/darkness tunable from the final spec's Appendix A
## (0005 worldgen + the §12 memory-budget numbers). Launch defaults; all stay
## named @export Inspector knobs.

# --- world shape (spec §3) ---------------------------------------------------
## Designed bottom, in tiles below the surface.
@export var designed_bottom_depth := 700
## Diggable shaft width in tiles, walled by unbreakable bedrock.
@export var shaft_width := 96
## Band edges in tiles: Topsoil / Clay / Sandstone / Granite / Bedrock.
@export var band_edges := PackedInt32Array([0, 40, 120, 260, 450, 700])
@export var baseline_hardness := PackedInt32Array([1, 2, 3, 4, 5])
## Vein halo rock is +1 hardness; the prize nodule +2 (spec §3).
@export var halo_hardness_bonus := 1
@export var prize_hardness_bonus := 2

# --- gems & veins (spec §3) --------------------------------------------------
## ~8% of tiles, roughly flat with depth — deeper pays via tier, never count.
@export var base_gem_density := 0.08
@export var vein_size_min := 2
@export var vein_size_max := 5
## Deterministic vein placement grid: one candidate find per cell of this
## many tiles square (implementation detail of tier_weight/vein placement).
@export var vein_cell_size := 8
## tier_weight(tier, depth): moving peak + tails. Weight falls off by this
## factor per tier of distance from the depth-scaled peak.
@export var tier_tail_falloff := 0.30

# --- prize gem (spec §3) — SEAM: spawning is a later session, knobs live now -
@export var prize_spawn_chance_base := 0.0
@export var prize_spawn_chance_depth_gain := 0.0

# --- caves (spec §3): sparse voids, more common and larger with depth --------
@export var cave_noise_frequency := 0.06
## Noise-01 threshold above which a tile is void, at the surface / bottom.
## Lower threshold = more cave; kept sparse — mostly-holes stops feeling
## like earth.
@export var cave_threshold_surface := 0.82
@export var cave_threshold_bottom := 0.66

# --- streaming & the bounded resident window (spec §12 — non-negotiable) -----
@export var tile_px := 16
@export var chunk_size := 32
## Resident = camera view + this many chunks of margin ring; all else freed.
@export var resident_margin := 1
## Incremental generation budget (single-threaded web).
@export var chunks_per_frame_budget := 2
@export var pickup_cap := 64
@export var particle_cap := 8

# --- darkness base curve (spec §6) — SEAM: renderer is a later session -------
@export var surface_view_radius := 14.0
@export var shrink_rate_per_depth := 0.016
@export var min_floor_radius := 2.5
@export var prize_glint_radius := 10.0
