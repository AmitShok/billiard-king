// Billiard King: rolling ball via spherical UV mapping.
// The quad is treated as a sphere seen from the front. For every screen pixel
// we rebuild the sphere normal, rotate it into the ball's own frame with the
// inverse orientation, and look up an equirectangular "skin" (longitude ->
// u, latitude -> v). Rotating the orientation makes numbers, stripes and dots
// roll across the surface. Lighting is quantised into a few bands with a hard
// rim and a pixel glint so it sits with the rest of the pixel art.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D skin : source_color, filter_nearest, repeat_disable;
uniform vec2 cell = vec2(0.0, 0.0);        // atlas cell of this ball's skin
uniform vec2 grid = vec2(4.0, 4.0);        // atlas cells across / down
uniform mat3 orientation = mat3(1.0);      // ball-local -> world rotation
uniform float view_pitch = 0.42;           // look slightly down on the ball so rolls read in 3D
uniform float diameter_px = 16.0;
uniform vec3 light_dir = vec3(-0.55, 0.62, 0.56);
uniform vec4 outline_color : source_color = vec4(0.07, 0.05, 0.07, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.22, 0.16, 0.26, 1.0);
uniform float flash = 0.0;                 // 0..1 white hit flash
uniform float alpha = 1.0;

varying vec4 tint_in; // node modulate (vertex colour), so fades and silhouettes still work

void vertex() {
	tint_in = COLOR;
}

void fragment() {
	// Quantise to the ball's own pixel grid so the sphere is pixel-crisp.
	vec2 pix = (floor(UV * diameter_px) + 0.5) / diameter_px * 2.0 - 1.0;
	float d2 = dot(pix, pix);
	if (d2 > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec3 n_view = vec3(pix.x, -pix.y, sqrt(max(0.0, 1.0 - d2)));
		float c = cos(view_pitch);
		float s = sin(view_pitch);
		vec3 n_world = vec3(n_view.x, c * n_view.y - s * n_view.z, s * n_view.y + c * n_view.z);
		vec3 n_local = transpose(orientation) * n_world;
		float u = atan(n_local.x, n_local.z) / 6.2831853 + 0.5;
		float v = acos(clamp(n_local.y, -1.0, 1.0)) / 3.14159265;
		vec2 texel = vec2(64.0, 32.0);
		u = clamp(u, 0.5 / texel.x, 1.0 - 0.5 / texel.x);
		v = clamp(v, 0.5 / texel.y, 1.0 - 0.5 / texel.y);
		vec3 albedo = textureLod(skin, (cell + vec2(u, v)) / grid, 0.0).rgb;

		vec3 l = normalize(light_dir);
		float lam = max(dot(n_view, l), 0.0);
		float band = lam > 0.72 ? 1.0 : (lam > 0.38 ? 0.84 : (lam > 0.12 ? 0.66 : 0.5));
		vec3 col = mix(albedo * shadow_tint.rgb * 2.0, albedo, band);
		// Bounce light from the felt below.
		col += albedo * 0.08 * clamp(-n_view.y, 0.0, 1.0);
		// Specular glint: a tight hard-edged highlight.
		vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
		float spec = pow(max(dot(n_view, h), 0.0), 40.0);
		if (spec > 0.5) col = mix(col, vec3(1.0), 0.85);
		else if (spec > 0.18) col = mix(col, vec3(1.0), 0.3);
		// 1px rim outline.
		float r_px = sqrt(d2) * diameter_px * 0.5;
		if (r_px > diameter_px * 0.5 - 1.0) col = outline_color.rgb;
		col = mix(col, vec3(1.0), flash);
		COLOR = vec4(col, alpha) * tint_in;
	}
}
