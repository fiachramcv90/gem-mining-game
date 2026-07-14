extends Node2D
## Scene root (spec §10): Main -> Mine + Player + HUD. Wires the references
## (calls down) and reacts to GameState's signals (signals up).

@onready var mine: Mine = $Mine
@onready var player: Player = $Player
@onready var hud: HUD = $HUD


func _ready() -> void:
	# Load-on-boot (spec §13): a valid save restores the persistent mine;
	# absent or corrupt (world_seed missing) starts a new game — whose seed
	# is snapshotted immediately so it survives the very first tab close.
	if not SaveManager.load_game():
		GameState.new_game()
		SaveManager.save_now()
	mine.setup(Worldgen.new(GameState.world, GameState.world_seed))
	mine.player = player
	player.mine = mine
	player.stick = hud.stick
	var px := float(GameState.world.tile_px)
	player.spawn_position = Vector2(px * 0.5, -3.0 * px)
	GameState.run_lost.connect(_on_run_lost)
	player.respawn()
	mine.warm_start()


func _on_run_lost(_reason: String) -> void:
	# Free respawn at the surface, topped up (GameState already reset the
	# pressures and forfeited cargo).
	player.respawn()


func _draw() -> void:
	# Grey-box sky + surface line so "above ground" reads at a glance.
	var half_w := GameState.world.shaft_width * GameState.world.tile_px * 0.6
	draw_rect(
		Rect2(Vector2(-half_w, -2000.0), Vector2(half_w * 2.0, 2000.0)),
		Color(0.45, 0.62, 0.78),
		true
	)
	draw_line(Vector2(-half_w, 0), Vector2(half_w, 0), Color(0.25, 0.2, 0.12), 2.0)
