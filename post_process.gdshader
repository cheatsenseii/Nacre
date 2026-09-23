shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float tension = 0.0;
uniform float vignette_strength = 0.26;
uniform float grain_strength = 0.014;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float radius = length(centered);
	float vignette = 1.0 - smoothstep(0.25, 0.9, radius);
	// Keep exploration sharp; colour separation is a short reaction to a scare.
	vec3 colour = textureLod(screen_texture, uv, 0.0).rgb;
	if (tension > 0.01) {
		vec2 aberration = centered * tension * 0.0028;
		colour.r = textureLod(screen_texture, uv + aberration, 0.0).r;
		colour.b = textureLod(screen_texture, uv - aberration, 0.0).b;
	}

	float noise = fract(sin(dot(uv / SCREEN_PIXEL_SIZE + floor(TIME * 24.0), vec2(12.9898, 78.233))) * 43758.5453);
	colour += (noise - 0.5) * grain_strength * (0.35 + tension);
	colour *= mix(1.0 - vignette_strength, 1.0, vignette);
	COLOR = vec4(colour, 1.0);
}
