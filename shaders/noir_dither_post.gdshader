shader_type canvas_item;

// Noir dither post - ours, from scratch.
//
// Quantizes LUMINANCE only: hue and saturation pass through untouched,
// so the warm spot / cool fill contrast stays pure with no rainbow
// speckle. An 8x8 Bayer pattern bridges the brightness steps, weighted
// so the darks carry most of the grain (film-noir texture) while
// midtones and highlights stay clean and readable.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
// steps of brightness - the main intensity knob (lower = harsher)
uniform int luma_levels : hint_range(4, 64) = 24;
// overall dither amount; 1.0 bridges the steps exactly, below that
// banding creeps back in, above it the grain outgrows the steps
uniform float grain : hint_range(0.0, 2.0) = 1.0;
// extra grain weight in the darks, fading out by the midtones
uniform float shadow_grain : hint_range(0.0, 4.0) = 1.5;
// noir: shadows lose their color before they lose their shape
uniform float shadow_desat : hint_range(0.0, 1.0) = 0.35;
// brightness below this crushes to true black
uniform float black_floor : hint_range(0.0, 0.2) = 0.02;
// each dither dot covers this many screen pixels - the render stays
// sharp, only the grain gets chunky
uniform int dot_size : hint_range(1, 8) = 1;
// 0 = full color, 1 = black and white, between = partially drained
uniform float mono : hint_range(0.0, 1.0) = 0.0;
// tints the black-and-white end: cold blue, sepia, newsprint...
uniform vec3 mono_tint : source_color = vec3(1.0, 1.0, 1.0);

const int BAYER8[64] = int[64](
	 0, 32,  8, 40,  2, 34, 10, 42,
	48, 16, 56, 24, 50, 18, 58, 26,
	12, 44,  4, 36, 14, 46,  6, 38,
	60, 28, 52, 20, 62, 30, 54, 22,
	 3, 35, 11, 43,  1, 33,  9, 41,
	51, 19, 59, 27, 49, 17, 57, 25,
	15, 47,  7, 39, 13, 45,  5, 37,
	63, 31, 55, 23, 61, 29, 53, 21);

// ordered dither offset in [-0.5, 0.5)
float bayer8(vec2 p) {
	ivec2 i = ivec2(mod(p, 8.0));
	return float(BAYER8[i.y * 8 + i.x]) / 64.0 - 0.5;
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));

	// darks get more grain than lights
	float weight = grain * mix(1.0 + shadow_grain, 1.0, smoothstep(0.0, 0.45, luma));

	float levels = float(luma_levels);
	float d = bayer8(floor(FRAGCOORD.xy / float(dot_size))) * weight / levels;
	float q = floor(clamp(luma + d, 0.0, 1.0) * levels + 0.5) / levels;

	// reapply the quantized brightness without touching hue. The ratio
	// is clamped (near-black pixels would otherwise amplify their hue
	// into colored flicker) and clipped channels roll toward white so
	// bright warm edges don't ring red - both only visible in color.
	float ratio = min(q / max(luma, 1e-4), 3.0);
	vec3 out_col = col * ratio;
	float peak = max(out_col.r, max(out_col.g, out_col.b));
	if (peak > 1.0) {
		out_col = mix(out_col / peak, vec3(1.0), clamp((peak - 1.0) * 0.5, 0.0, 1.0));
	}

	float desat = shadow_desat * (1.0 - smoothstep(0.0, 0.35, q));
	out_col = mix(out_col, vec3(q), desat);

	out_col = mix(out_col, q * mono_tint, mono);

	out_col *= smoothstep(0.0, black_floor, q);

	COLOR = vec4(out_col, 1.0);
}
