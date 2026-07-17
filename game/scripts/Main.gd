extends Node2D
## Scene root (spec §10): Main -> Mine + Player + HUD. Wires the references
## (calls down) and reacts to GameState's signals (signals up).

@onready var mine: Mine = $Mine
@onready var player: Player = $Player
@onready var hud: HUD = $HUD
@onready var darkness: DarknessOverlay = $DarknessLayer/Darkness


func _ready() -> void:
	# Load-on-boot (spec §13): a valid save restores the persistent mine;
	# absent or corrupt (world_seed missing) starts a new game — whose seed
	# is snapshotted immediately so it survives the very first tab close.
	if not SaveManager.load_game():
		GameState.new_game()
		SaveManager.save_now()
	mine.setup(Worldgen.new(GameState.world, GameState.hazards, GameState.world_seed))
	mine.player = player
	player.mine = mine
	player.stick = hud.stick
	darkness.player = player
	darkness.mine = mine
	# The juice layer's shake target and particle-pool home (spec §7).
	Juice.register(player.get_node("Camera2D"), mine)
	# The §16 overlay's counter source (observes the window, never changes it).
	DebugOverlay.register(mine)
	var px := float(GameState.world.tile_px)
	# Spawn beside the garage door (feedback #3): home is the first thing
	# you see, and flying into it is how the hub opens.
	player.spawn_position = Vector2(-px * 1.0, -2.0 * px)
	GameState.run_lost.connect(_on_run_lost)
	player.respawn()
	# Best-effort mid-run restore (spec §13 `run`): a complete, sane snapshot
	# resumes the run where the tab died; anything less already fell back to
	# the surface start in SaveManager. Before warm_start, so the initial
	# window generates around the restored spot.
	var run_pos: Variant = SaveManager.consume_run_position()
	if run_pos is Vector2:
		player.restore_at(run_pos)
	mine.warm_start()

	# The garage (feedback #3): the physical hub trigger, drawn between the
	# mine and the player so the digger flies in front of it.
	var garage := Garage.new()
	garage.player = player
	garage.hud = hud
	add_child(garage)
	move_child(garage, mine.get_index() + 1)


func _on_run_lost(_reason: String, _cargo_lost: int) -> void:
	# Free respawn at the surface, topped up (GameState already reset the
	# pressures and forfeited cargo).
	player.respawn()


func _draw() -> void:
	# Palette sky + surface line so "above ground" reads at a glance. The
	# sky spans well past the shaft: the unbounded side walls (feedback #2)
	# draw over it, so the cliff tops read against blue, never the clear
	# colour. Two tones: deeper blue up high, hazy near the horizon.
	var shaft_w := GameState.world.shaft_width * GameState.world.tile_px
	var half_w := shaft_w * 0.5
	draw_rect(
		Rect2(Vector2(-shaft_w * 3.0, -2000.0), Vector2(shaft_w * 6.0, 1880.0)),
		Palette.SKY_HIGH,
		true
	)
	draw_rect(
		Rect2(Vector2(-shaft_w * 3.0, -120.0), Vector2(shaft_w * 6.0, 120.0)), Palette.SKY_LOW, true
	)
	draw_line(Vector2(-half_w, 0), Vector2(half_w, 0), Palette.SURFACE_LINE, 2.0)
