shader_type canvas_item;
// The §6 darkness overlay: a full-screen quad whose fragment shader darkens
// everything outside the lit view radius (GameState.lit_view_radius(), fed
// per frame as a uniform — the Light track visibly pushes this back), plus
// BOTH self-lit exceptions that pierce the dark: the prize gem's gold
// cross-glint (spec §3/§6) and lava's warm glow (spec §5/§6 — the fair
// exception: Bedrock's headline threat can't cheap-shot, so lava points cut
// the overlay open out to lava_glow_radius and lay a flickering heat tint).
// This is §7's one-reused-shader budget: pure GPU fragment work, no
// per-frame CPU pixels.
//
// All positions/lengths are in the viewport's logical pixel space (the
// stretch-mode canvas space the CanvasLayer draws in); the script converts
// world -> screen via the canvas transform, so camera zoom is included.

uniform vec2 view_size = vec2(440.0, 880.0);
uniform vec2 light_pos = vec2(220.0, 440.0);
uniform float lit_radius = 672.0;
uniform float edge_softness = 72.0;
uniform float max_alpha = 1.0;

uniform int glint_count = 0;
uniform vec2 glint_pos[4];
uniform float glint_strength[4];
uniform vec4 glint_color : source_color = vec4(1.0, 0.8, 0.27, 1.0);
uniform float glint_arm = 34.0;
uniform float glint_thickness = 2.6;

uniform int lava_count = 0;
uniform vec2 lava_pos[8];
uniform float lava_radius = 96.0;
uniform vec4 lava_color : source_color = vec4(1.0, 0.42, 0.12, 1.0);
uniform float lava_heat_alpha = 0.4;

void fragment() {
	vec2 p = UV * view_size;
	float dist = distance(p, light_pos);
	float dark = smoothstep(lit_radius - edge_softness, lit_radius, dist) * max_alpha;

	float glow = 0.0;
	for (int i = 0; i < glint_count; i++) {
		vec2 q = p - glint_pos[i];
		float twinkle = 0.65 + 0.35 * sin(TIME * 4.0 + float(i) * 1.7);
		float arm_x = (1.0 - smoothstep(0.0, glint_arm, abs(q.x)))
			* (1.0 - smoothstep(0.0, glint_thickness, abs(q.y)));
		float arm_y = (1.0 - smoothstep(0.0, glint_arm, abs(q.y)))
			* (1.0 - smoothstep(0.0, glint_thickness, abs(q.x)));
		float core = 1.0 - smoothstep(0.0, glint_thickness * 2.5, length(q));
		glow += glint_strength[i] * twinkle * max(max(arm_x, arm_y), core);
	}
	glow = clamp(glow, 0.0, 1.0);

	// Lava's self-lit glow: each point CUTS the darkness open (reveal — the
	// molten tiles underneath actually show) and lays a flickering warm
	// tint (heat) that reads as emitted light even in the lit area.
	float reveal = 0.0;
	float heat = 0.0;
	for (int i = 0; i < lava_count; i++) {
		float d = distance(p, lava_pos[i]);
		float rv = 1.0 - smoothstep(lava_radius * 0.45, lava_radius, d);
		reveal = max(reveal, rv);
		float flicker = 0.8 + 0.2 * sin(TIME * 3.1 + float(i) * 2.3);
		heat = max(heat, rv * rv * flicker);
	}
	dark *= 1.0 - reveal;
	float heat_a = heat * lava_heat_alpha;

	// In the dark (alpha 1) the glint mixes gold into the black; in the lit
	// area it lays a soft gold sparkle over the world. Lava's heat tint
	// rides the same output.
	COLOR = vec4(
		glint_color.rgb * glow + lava_color.rgb * heat,
		clamp(dark + glow + heat_a, 0.0, 1.0)
	);
}
