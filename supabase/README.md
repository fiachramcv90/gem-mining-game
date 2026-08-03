# EP1 Leaderboard — Supabase backend

This directory holds the leaderboard's server side: the SQL migration
(`migrations/0001_ep1_leaderboard.sql`) with the schema, RLS, and the six
`SECURITY DEFINER` RPCs (`submit_score`, `claim_row`, `create_group`,
`join_group`, `my_groups`, `group_board`).

The game runs **fully offline without any of this**. The leaderboard is
best-effort: `game/config/LeaderboardConfig.gd` ships with an empty
`project_url`, so `Leaderboard.online_configured()` is `false`, **no
`HTTPRequest` is ever created**, and the board UI shows local-is-truth values
(spec L4/L5-F). Everything below is the *optional* step that turns the mirror
on.

## ⚠️ The one remaining manual step (EP1 Part IV — "Supabase live-verify")

The Supabase MCP was unauthenticated during design, so these primitives are
**doc-confirmed but not live-tested** (asset 02, "Pre-implementation
checkpoint"). Confirm them against a real project before trusting the board:

1. **Anonymous sign-in** issues a usable `auth.uid()` over REST. Enable
   *Anonymous sign-ins* in **Authentication → Providers**. Verify the exact
   endpoint/body the client uses in `Leaderboard._ensure_session()`
   (`POST /auth/v1/signup` with `{}` + `apikey` header) actually returns an
   `access_token` — adjust that one function if your project's GoTrue version
   differs.
2. **RLS** `auth.uid() = owner` enforcement on `scores` writes.
3. The **`SECURITY DEFINER` RPCs** execute with definer rights without
   recursive-policy errors.
4. **REST upsert** semantics for the one-row-per-owner path (`submit_score`).

## Apply the migration

```bash
# with the Supabase CLI, linked to your project:
supabase db push
# — or paste migrations/0001_ep1_leaderboard.sql into the SQL editor.
```

## Wire the game to the project

Set the project URL + anon (publishable) key in
`game/config/leaderboard.tres` (`project_url`, `anon_key`). The anon /
publishable key is **designed to be public** and ships in every client-side
Supabase app — data is protected by RLS, not by hiding the key — so committing
it is the intended, safe path here. (Never commit the `service_role` key.)

> The `GEM_MINER_SUPABASE_URL` / `GEM_MINER_SUPABASE_ANON_KEY` env vars are a
> convenience for **local desktop runs only**. They do NOT reach the web
> export: `OS.get_environment()` runs in the player's browser, which has no
> process env vars, and CI env vars are not baked into the export. For the
> GitHub Pages build the values must live in the committed `.tres` (above), or
> be injected into it by a build step from GitHub Actions Secrets.

Once a URL + key resolve, the client begins posting on the spec L3 triggers
(run-complete, visibility-hidden, app-launch) and the Global/Groups tabs light
up.

## Trust model (do not build on top of this)

Scores are **client-trusted and forgeable by design** (asset 02 §6). Anyone
with the endpoint + their own JWT can `PATCH` arbitrary numbers onto *their
own* row. This is intended at friends scale. `submit_score` is the ready seam
for later hardening (sanity caps, rate-limits) *if* a public global board ever
attracts griefers — the client never changes. Nothing downstream may assume
scores are authoritative.

## Fog (out of v1, per asset 02)

Leave/kick/delete group, nickname profanity filter, and CAPTCHA/bot-hardening
on anon sign-in all graduate alongside a public global board, not before.
