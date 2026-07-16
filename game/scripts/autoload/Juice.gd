extends Node
## Autoload: the §7 juice layer — visual-first feedback punctuation. Every
## beat fully lands with sound OFF (the iOS silent switch mutes Web Audio,
## spec §11): short sharp screen-shake + flash is the haptics-equivalent;
## capped POOLED CPUParticles2D handle debris/sparkle bursts (4–8 each,
## clamped to WorldgenConfig.particle_cap); best-effort navigator.vibrate
## and Sfx one-shots ride along as additive layers only.
##
## The §8 milestone celebration IS this same shake+flash beat — the banner
## text is the HUD's, the punch is here. The reduce-motion toggle
## (Settings) kills the shake; flashes stay brief and low-alpha.

var config: JuiceConfig = preload("res://config/juice.tres")

var _camera: Camera2D
var _world: Node2D
var _pool: Array[CPUParticles2D] = []
var _pool_next := 0
var _trauma := 0.0
var _shake_clock := 0.0
var _flash: ColorRect
var _flash_tween: Tween
## Shake offsets come from noise, not randf — smooth, directionless jitter.
var _noise := FastNoiseLite.new()


func _ready() -> void:
	# Flash must fade even while the tree is paused (sell/upgrade/milestone
	# beats can land inside the paused hub).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	var layer := CanvasLayer.new()
	layer.layer = 3  # above the HUD: the flash punctuates everything
	add_child(layer)
	_flash = ColorRect.new()
	# Code-built full-screen control: anchors AND offsets (session-5 lesson).
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	layer.add_child(_flash)

	GameState.hazard_survived.connect(_on_hazard_survived)
	GameState.run_lost.connect(_on_run_lost)
	GameState.cargo_sold.connect(_on_cargo_sold)
	MinersLog.milestone_earned.connect(_on_milestone_earned)
	Upgrades.upgrades_changed.connect(_on_upgrade_bought)


func register(camera: Camera2D, world: Node2D) -> void:
	## Called by Main on every scene boot: the shake target and the world
	## node the particle pool lives under (world space, so the darkness
	## overlay applies to bursts too).
	_camera = camera
	_world = world
	_pool.clear()
	_pool_next = 0
	for i in range(config.emitter_pool_size):
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 1.0
		p.spread = 180.0
		p.gravity = Vector2(0, 200)
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.0
		world.add_child(p)
		_pool.append(p)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		if is_instance_valid(_camera):
			_camera.offset = Vector2.ZERO
		return
	_trauma = maxf(0.0, _trauma - config.shake_decay_per_sec * delta)
	_shake_clock += delta * 18.0
	if not is_instance_valid(_camera):
		return
	if Settings.reduce_motion():
		_camera.offset = Vector2.ZERO
		return
	var amount := _trauma * _trauma * config.shake_max_offset_px
	_camera.offset = Vector2(
		_noise.get_noise_2d(_shake_clock, 0.0) * amount,
		_noise.get_noise_2d(0.0, _shake_clock) * amount
	)


# --- the three primitives -------------------------------------------------------


func shake(trauma: float) -> void:
	_trauma = minf(1.0, _trauma + trauma)


func flash(color: Color, alpha: float) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = Color(color.r, color.g, color.b, alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, config.flash_fade_secs)


func burst(pos: Vector2, color: Color, count: int, speed_scale: float = 1.0) -> void:
	## One pooled debris/sparkle burst, capped by particle_cap (spec §12).
	if _pool.is_empty() or not is_instance_valid(_world):
		return
	var p := _next_emitter()
	if p == null:
		return
	p.global_position = pos
	p.amount = clampi(count, 1, GameState.world.particle_cap)
	p.lifetime = config.particle_lifetime_secs
	p.color = color
	p.initial_velocity_min = config.particle_speed_px * 0.5 * speed_scale
	p.initial_velocity_max = config.particle_speed_px * speed_scale
	p.restart()


func vibrate(ms: int) -> void:
	## Best-effort navigator.vibrate — additive only (spec §7): present on
	## Android Chrome, silently absent on iOS, never relied on.
	if ms <= 0 or not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if (navigator.vibrate) { navigator.vibrate(%d); }" % ms, true)


func _next_emitter() -> CPUParticles2D:
	# Prefer an idle emitter; past the pool, steal round-robin (the burst is
	# 0.45 s — stealing reads as nothing).
	for p in _pool:
		if is_instance_valid(p) and not p.emitting:
			return p
	var steal := _pool[_pool_next % _pool.size()]
	_pool_next += 1
	return steal if is_instance_valid(steal) else null


# --- the feedback beats (0008's §4 checklist) ------------------------------------


func dig_beat(pos: Vector2, band: int, kind: int) -> void:
	## Dig thud / break-through: debris burst + micro-shake; a halo or gem
	## tile pops slightly bigger — the telegraph's payoff (spec §7).
	var payoff := (
		kind == Worldgen.Kind.HALO or kind == Worldgen.Kind.GEM or kind == Worldgen.Kind.PRIZE
	)
	var color := Palette.band_mid(band)
	if kind == Worldgen.Kind.HALO:
		color = Palette.band_dark(band)
	burst(pos, color, config.burst_break if payoff else config.burst_dig)
	shake(config.shake_small * (1.0 if payoff else 0.5))
	Sfx.play("break" if payoff else "dig", 0.0, 0.92 + fposmod(pos.x + pos.y, 5.0) * 0.035)


func gem_beat(pos: Vector2, tier: int) -> void:
	## Gem collect: sparkle in the gem's own hue; the prize sings louder.
	burst(pos, Palette.gem_light(tier), config.burst_gem, 0.8)
	if tier == Worldgen.PRIZE_TIER:
		shake(config.shake_medium)
		flash(Palette.PRIZE_LIGHT, config.flash_alpha_small)
		Sfx.play("prize")
	else:
		Sfx.play("gem")
	vibrate(config.vibrate_gem_ms)


func _on_hazard_survived(kind: String, amount: float) -> void:
	## Hazard hit, hull holds: red flash + shake sized by the spike. Lava
	## ticks small and often (5 per 0.2 s) — they get the small beat, never
	## the big one, or Bedrock would be a strobe.
	var big := amount > 6.0
	shake(config.shake_large if big else config.shake_small)
	flash(Palette.UI_DANGER, config.flash_alpha_big if big else config.flash_alpha_small)
	if big:
		vibrate(config.vibrate_hazard_ms)
	Sfx.play("hit")
	if kind == GameState.HAZARD_GAS:
		Sfx.play("gas")
	elif kind == GameState.HAZARD_CAVEIN:
		Sfx.play("rumble")


func _on_run_lost(_reason: String, _cargo_lost: int) -> void:
	shake(config.shake_large)
	flash(Palette.UI_DANGER.darkened(0.3), config.flash_alpha_big)
	vibrate(config.vibrate_lost_ms)
	Sfx.play("lost")


func _on_cargo_sold(value: int) -> void:
	if value <= 0:
		return
	flash(Palette.UI_GOLD, config.flash_alpha_small)
	shake(config.shake_small)
	vibrate(config.vibrate_sell_ms)
	Sfx.play("sell")


func _on_milestone_earned(_id: String, line: String) -> void:
	## The §8 celebration: 0008's existing shake+flash, reused — the banner
	## line is the HUD's, this is the punch under it.
	if line.is_empty():
		return
	shake(config.shake_medium)
	flash(Palette.UI_GOLD, config.flash_alpha_big)
	vibrate(config.vibrate_milestone_ms)
	Sfx.play("milestone")


func _on_upgrade_bought() -> void:
	flash(Palette.UI_GOLD, config.flash_alpha_small * 0.7)
	Sfx.play("upgrade")
