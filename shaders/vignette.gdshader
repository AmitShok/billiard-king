// Vertical Billiard: soft corner darkening, quantised with a 4x4 ordered dither
// so it stays pixel-art crisp at the game's native 512x288.
shader_type canvas_item;

uniform float strength = 0.5;
uniform vec4 tint : source_color = vec4(0.02, 0.01, 0.03, 1.0);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.1;
	float d = dot(p, p);
	float a = smoothstep(0.45, 1.7, d) * strength;
	ivec2 c = ivec2(FRAGCOORD.xy) % 4;
	float threshold = (BAYER[c.y * 4 + c.x] + 0.5) / 16.0;
	a = floor(a * 4.0 + threshold) / 4.0;
	COLOR = vec4(tint.rgb, a);
}
