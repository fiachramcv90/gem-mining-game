class_name LeaderboardConfig
extends Resource
## Backend wiring for EP1's leaderboard (EP1 spec L1/L4). Absent by default:
## with an empty project_url the whole feature runs FULLY OFFLINE — no
## HTTPRequest is ever created, the headless CI run makes no network call,
## and the board UI shows local-is-truth values (EP1 spec L4/L5-F).
##
## Wiring the live project is the one remaining manual step (EP1 Part IV
## "Supabase live-verify"): drop the project URL + anon key here (or via the
## GEM_MINER_SUPABASE_URL / GEM_MINER_SUPABASE_ANON_KEY env vars, which win
## when set), run the SQL migration under supabase/migrations/, and the
## client layer starts posting. See supabase/README.md.

## Supabase project REST base, e.g. "https://abcd.supabase.co". Empty = off.
@export var project_url := ""
## Supabase anon (publishable) key — client-trusted board, safe to ship.
@export var anon_key := ""
## Seconds between debounced score posts (EP1 spec L3 — few, meaningful).
@export var post_debounce_secs := 5.0
## HTTPRequest timeout; a slow/paused free-tier project must fail fast and
## stay a normal offline state, never hang the game (EP1 spec L4).
@export var request_timeout_secs := 8.0


func url() -> String:
	## Env override wins so a build can point at a project without editing the
	## committed .tres (keeps secrets out of the repo where desired).
	var env := OS.get_environment("GEM_MINER_SUPABASE_URL")
	return env if not env.is_empty() else project_url


func key() -> String:
	var env := OS.get_environment("GEM_MINER_SUPABASE_ANON_KEY")
	return env if not env.is_empty() else anon_key


func enabled() -> bool:
	## The single gate: no URL means no network layer exists at all.
	return not url().is_empty() and not key().is_empty()
