class_name TileArt
extends RefCounted
## The §7 tile painter: real 16 px tiles on the Resurrect-64 master palette
## (Palette.gd), generated procedurally in code — the sanctioned AI/Claude
## lane (spec §7: palette/reference/procedural code-gen only; the hand
## pipeline is Pixelorama). Every painter is deterministic (integer hash,
## no randf), cheap, and swappable: art is first-draft, tuned by eye, and a
## hand-drawn atlas can replace this file wholesale later.
##
## Shared vocabulary: each band tile is shaded from its 3-value ramp
## (dark/mid/light) with blobby value noise + a 1 px top-light/bottom-dark
## bevel so tiles read as chunks of earth, not slabs. The halo is the same
## rock DARKER with a TIGHTER grain + darkest flecks — you see the rock
## harden a beat before you feel it (the vein telegraph, spec §3/§7).


static func _h(x: int, y: int, salt: int) -> int:
	## Small deterministic pixel hash (art only — worldgen has its own).
	var h := (x * 374761393 + y * 668265263 + salt * 2246822519) & 0x7FFFFFFF
	h = (h ^ (h >> 13)) * 1274126177 & 0x7FFFFFFF
	return (h ^ (h >> 16)) & 0x7FFFFFFF


static func _put(img: Image, col: int, px: int, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < px and y >= 0 and y < px:
		img.set_pixel(col * px + x, y, c)


static func paint_rock(img: Image, col: int, px: int, band: int, halo: bool) -> void:
	var dark: Color = Palette.band_dark(band)
	var mid: Color = Palette.band_mid(band)
	var light: Color = Palette.band_light(band)
	if halo:
		# Darker, tighter-grained ring rock — the telegraph look.
		dark = dark.darkened(0.30)
		mid = mid.darkened(0.22)
		light = light.darkened(0.30)
	var cell := 3 if halo else 4  # tighter grain inside the halo
	for y in range(px):
		for x in range(px):
			# Blobby value noise: a coarse cell tone + fine speckle on top.
			var tone := _h(x / cell, y / cell, col * 7 + band) % 8
			var c := mid
			if tone <= 1:
				c = dark
			elif tone >= 6:
				c = light
			var speck := _h(x, y, col * 13 + 5) % 17
			if speck == 0:
				c = c.darkened(0.16)
			elif speck == 1:
				c = c.lightened(0.10)
			# Bevel: top edge catches light, bottom edge falls into shadow.
			if y == 0:
				c = c.lightened(0.14)
			elif y == px - 1:
				c = c.darkened(0.20)
			img.set_pixel(col * px + x, y, c)
	if halo:
		# Darkest flecks — dense, compressed grain, "harder than it should be".
		for i in range(10):
			var fx := _h(i, 3, col) % px
			var fy := _h(7, i, col) % px
			_put(img, col, px, fx, fy, dark.darkened(0.35))


static func paint_wall(img: Image, col: int, px: int) -> void:
	## Unbreakable bedrock: near-black with chisel marks — reads "no".
	for y in range(px):
		for x in range(px):
			var c := Palette.WALL_DARK
			var tone := _h(x / 4, y / 3, 99) % 9
			if tone == 0:
				c = Palette.WALL_CHISEL
			if _h(x, y, 101) % 43 == 0:
				c = Palette.WALL_FLECK
			if y == px - 1:
				c = c.darkened(0.25)
			img.set_pixel(col * px + x, y, c)


static func paint_gem(img: Image, col: int, px: int, tier: int) -> void:
	## A crystal cluster set in dark bed-rock: one main rhombus + two
	## satellite chips, facet highlight top-left. Saturated hues are the
	## gems' alone (reserve saturation).
	var deep := Palette.gem_deep(tier)
	var light := Palette.gem_light(tier)
	# Bed: dark neutral matrix with a faint tint of the gem's own hue.
	for y in range(px):
		for x in range(px):
			var c := Palette.GEM_BED
			if _h(x / 3, y / 3, col) % 7 == 0:
				c = c.lerp(deep, 0.18)
			if _h(x, y, col + 1) % 23 == 0:
				c = c.lightened(0.08)
			img.set_pixel(col * px + x, y, c)
	var mid := px / 2
	# Main crystal: diamond of radius 4 with a light upper-left facet.
	for y in range(px):
		for x in range(px):
			var d := absi(x - mid) + absi(y - mid)
			if d <= 4:
				var c := deep
				if x <= mid and y <= mid and d <= 3:
					c = light
				if d == 4:
					c = deep.darkened(0.35)
				img.set_pixel(col * px + x, y, c)
	_put(img, col, px, mid - 1, mid - 1, Color.WHITE.lerp(light, 0.35))
	# Satellite chips.
	for chip in [Vector2i(3, px - 4), Vector2i(px - 4, 4)]:
		_put(img, col, px, chip.x, chip.y, light)
		_put(img, col, px, chip.x + 1, chip.y, deep)
		_put(img, col, px, chip.x, chip.y + 1, deep.darkened(0.3))


static func paint_prize(img: Image, col: int, px: int) -> void:
	## The prize nodule: a gold multi-facet star in the darkest matrix —
	## the brightest pixels underground (spec §3; its shader glint pierces
	## the dark, this tile is what you finally reach).
	for y in range(px):
		for x in range(px):
			var c := Palette.GEM_BED.darkened(0.2)
			if _h(x / 3, y / 3, 555) % 6 == 0:
				c = c.lerp(Palette.PRIZE_DEEP, 0.15)
			img.set_pixel(col * px + x, y, c)
	var mid := px / 2
	for y in range(px):
		for x in range(px):
			var d := absi(x - mid) + absi(y - mid)
			if d <= 5:
				var c := Palette.PRIZE_DEEP
				if d <= 2:
					c = Palette.PRIZE_GLINT
				elif x <= mid and y <= mid:
					c = Palette.PRIZE_LIGHT
				if d == 5:
					c = Palette.PRIZE_DEEP.darkened(0.35)
				img.set_pixel(col * px + x, y, c)
	# Cross-glint sparkle pixels at the compass points.
	for p in [Vector2i(mid, 1), Vector2i(mid, px - 2), Vector2i(1, mid), Vector2i(px - 2, mid)]:
		_put(img, col, px, p.x, p.y, Palette.PRIZE_GLINT)


static func paint_gas(img: Image, col: int, px: int, band: int) -> void:
	## The gas tell (spec §5/§7): band rock threaded with sickly green wisps
	## seeping from a fissure — legible as "not plain rock" at a glance. The
	## darkness overlay hides it beyond the lit radius (§6).
	paint_rock(img, col, px, band, false)
	for x in range(px):
		# Two sinuous wisp lines drifting upward across the tile.
		var y1 := int(round(px * 0.35 + sin(float(x) * 0.9 + float(band)) * 2.0))
		var y2 := int(round(px * 0.7 + sin(float(x) * 0.7 + 2.1) * 1.6))
		_put(img, col, px, x, y1, Palette.GAS_WISP)
		if x % 2 == 0:
			_put(img, col, px, x, y2, Palette.GAS_DEEP)
			_put(img, col, px, x, y1 + 1, Palette.GAS_DEEP.darkened(0.2))
	# The pocket fissure the wisps rise from.
	var mid := px / 2
	for i in range(3):
		_put(img, col, px, mid - 1 + i, px - 3 + (i % 2), Palette.GAS_DEEP.darkened(0.4))


static func paint_unstable(img: Image, col: int, px: int, band: int) -> void:
	## The cave-in tell (spec §5/§7): band rock split by a dark jagged crack
	## with pale chips dusted along it — "do not undermine".
	paint_rock(img, col, px, band, false)
	var crack: Color = Palette.band_dark(band).darkened(0.45)
	var chip: Color = Palette.band_light(band).lightened(0.22)
	var x := px / 2 - 1
	for y in range(px):
		# Main crack wanders down the tile.
		x = clampi(x + (_h(3, y, col) % 3 - 1), 1, px - 2)
		_put(img, col, px, x, y, crack)
		if y % 3 == 1:
			_put(img, col, px, x + 1, y, crack.lightened(0.12))
		if _h(x, y, col + 9) % 4 == 0:
			_put(img, col, px, x - 1, y, chip)
	# A side branch: the fracture is spreading.
	var by := px / 3
	for bx in range(2, px / 2):
		if _h(bx, 1, col) % 3 != 0:
			_put(img, col, px, bx, by + (bx % 2), crack)


static func paint_lava(img: Image, col: int, px: int) -> void:
	## Lava (spec §5/§7): molten saturated orange with hot bright blooms —
	## self-lit through darkness via the shader glow, not this texture.
	for y in range(px):
		for x in range(px):
			var tone := _h(x / 3, y / 3, 777) % 8
			var c := Palette.LAVA_MID
			if tone <= 2:
				c = Palette.LAVA_DEEP
			elif tone >= 7:
				c = Palette.LAVA_HOT
			if _h(x, y, 778) % 19 == 0:
				c = Palette.LAVA_HOT
			# The exposed top surface glows hottest.
			if y == 0:
				c = Palette.LAVA_HOT
			elif y == 1 and tone % 2 == 0:
				c = c.lerp(Palette.LAVA_HOT, 0.5)
			img.set_pixel(col * px + x, y, c)
