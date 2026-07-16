class_name Palette
extends RefCounted
## The one fixed master palette (spec §7): Resurrect-64, with the
## load-bearing RESERVE-SATURATION rule encoded as named roles — rock ramps
## stay desaturated/earthy; gems, lava, and the prize glint own the
## saturated hues, so a few bright pixels read as "not-rock" at the edge of
## the shrinking view radius. Bands are hue+value shifts of one shared rock
## ramp (Topsoil warm/light → Bedrock cold/dark), reinforcing the darkness
## curve. Every colour below is a canonical Resurrect-64 swatch; art is
## first-draft, tuned by eye — swap swatches here, never inline hexes.

## Shared rock ramp, hue+value shifted per band: [dark, mid, light] each.
## Index 0..4 = Topsoil / Clay / Sandstone / Granite / Bedrock band.
const BAND_RAMPS: Array = [
	[Color8(0x69, 0x4F, 0x62), Color8(0x96, 0x6C, 0x6C), Color8(0xAB, 0x94, 0x7A)],  # Topsoil
	[Color8(0x7A, 0x30, 0x45), Color8(0x9E, 0x45, 0x39), Color8(0xCD, 0x68, 0x3D)],  # Clay
	[Color8(0x4C, 0x3E, 0x24), Color8(0x67, 0x66, 0x33), Color8(0xA2, 0xA9, 0x47)],  # Sandstone
	[Color8(0x3E, 0x35, 0x46), Color8(0x62, 0x55, 0x65), Color8(0x7F, 0x70, 0x8A)],  # Granite
	[Color8(0x2E, 0x22, 0x2F), Color8(0x32, 0x33, 0x53), Color8(0x48, 0x4A, 0x77)],  # Bedrock
]

## Unbreakable bedrock wall: near-black, colder than any band.
const WALL_DARK := Color8(0x2E, 0x22, 0x2F)
const WALL_CHISEL := Color8(0x3E, 0x35, 0x46)
const WALL_FLECK := Color8(0x48, 0x4A, 0x77)

## Gems T1..T5 own the saturated hues (reserve saturation): [deep, light].
const GEM_RAMPS: Array = [
	[Color8(0x1E, 0xBC, 0x73), Color8(0x91, 0xDB, 0x69)],  # T1 green
	[Color8(0x0E, 0xAF, 0x9B), Color8(0x30, 0xE1, 0xB9)],  # T2 teal
	[Color8(0x4D, 0x65, 0xB4), Color8(0x4D, 0x9B, 0xE6)],  # T3 blue
	[Color8(0x90, 0x5E, 0xA9), Color8(0xA8, 0x84, 0xF3)],  # T4 purple
	[Color8(0xC3, 0x24, 0x54), Color8(0xF0, 0x4F, 0x78)],  # T5 crimson
]
const GEM_BED := Color8(0x2E, 0x22, 0x2F)

## The prize gem: gold, brightest thing underground (spec §3/§6).
const PRIZE_DEEP := Color8(0xF7, 0x96, 0x17)
const PRIZE_LIGHT := Color8(0xF9, 0xC2, 0x2B)
const PRIZE_GLINT := Color8(0xFB, 0xFF, 0x86)

## Lava: the other saturated owner (spec §5/§7), self-lit through darkness.
const LAVA_DEEP := Color8(0xB3, 0x38, 0x31)
const LAVA_MID := Color8(0xEA, 0x4F, 0x36)
const LAVA_HOT := Color8(0xF9, 0xC2, 0x2B)

## The gas tell: sickly green wisps in the rock (spec §5/§7).
const GAS_WISP := Color8(0xCD, 0xDF, 0x6C)
const GAS_DEEP := Color8(0x91, 0xDB, 0x69)

## The digger robot (feedback #6): the player owns a saturated yellow —
## always visible, never rock.
const DIGGER_BODY := Color8(0xF9, 0xC2, 0x2B)
const DIGGER_SHADE := Color8(0xF7, 0x96, 0x17)
const DIGGER_DARK := Color8(0x45, 0x29, 0x3F)
const DIGGER_METAL := Color8(0x9B, 0xAB, 0xB2)
const DIGGER_METAL_DARK := Color8(0x62, 0x55, 0x65)
const DIGGER_GLASS := Color8(0x8F, 0xD3, 0xFF)
const FLAME_HOT := Color8(0xF9, 0xC2, 0x2B)
const FLAME_MID := Color8(0xFB, 0x6B, 0x1D)

## Sky & surface (grey-box world dressing).
const SKY_HIGH := Color8(0x4D, 0x9B, 0xE6)
const SKY_LOW := Color8(0x8F, 0xD3, 0xFF)
const SURFACE_LINE := Color8(0x45, 0x29, 0x3F)

## UI roles (hub / shop / log typography, feedback #4).
const UI_PANEL_BG := Color8(0x2E, 0x22, 0x2F)
const UI_PANEL_BORDER := Color8(0x62, 0x55, 0x65)
const UI_BUTTON_BG := Color8(0x3E, 0x35, 0x46)
const UI_BUTTON_HOVER := Color8(0x48, 0x4A, 0x77)
const UI_BUTTON_PRESSED := Color8(0x32, 0x33, 0x53)
const UI_TEXT := Color8(0xC7, 0xDC, 0xD0)
const UI_TEXT_DIM := Color8(0x7F, 0x70, 0x8A)
const UI_GOLD := Color8(0xF9, 0xC2, 0x2B)
const UI_DANGER := Color8(0xE8, 0x3B, 0x3B)
const UI_GOOD := Color8(0x1E, 0xBC, 0x73)
const UI_FUEL := Color8(0x4D, 0x9B, 0xE6)


static func band_dark(band: int) -> Color:
	return BAND_RAMPS[band][0]


static func band_mid(band: int) -> Color:
	return BAND_RAMPS[band][1]


static func band_light(band: int) -> Color:
	return BAND_RAMPS[band][2]


static func gem_deep(tier: int) -> Color:
	## tier 1..5, or Worldgen.PRIZE_TIER.
	if tier == Worldgen.PRIZE_TIER:
		return PRIZE_DEEP
	return GEM_RAMPS[tier - 1][0]


static func gem_light(tier: int) -> Color:
	if tier == Worldgen.PRIZE_TIER:
		return PRIZE_LIGHT
	return GEM_RAMPS[tier - 1][1]
