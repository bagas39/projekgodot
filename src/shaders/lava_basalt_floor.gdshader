shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 basalt_color : source_color = vec4(0.08, 0.07, 0.08, 1.0);
uniform vec4 lava_color : source_color = vec4(1.0, 0.32, 0.04, 1.0);
uniform vec4 lava_core_color : source_color = vec4(1.0, 0.85, 0.25, 1.0);
uniform float crack_scale : hint_range(5.0, 50.0) = 24.0;
uniform float crack_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float pulse_speed : hint_range(0.5, 6.0) = 2.4;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;

// Fast procedural Voronoi crack function
vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float voronoi_cracks(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) md = d;
		}
	}
	return sqrt(md);
}

void fragment() {
	vec2 uv = UV * crack_scale;
	float dist = voronoi_cracks(uv);
	
	// Crack edge mask (narrow veins)
	float crack = smoothstep(0.18, 0.03, dist) * crack_intensity;
	float core = smoothstep(0.06, 0.01, dist) * crack_intensity;
	
	// Gentle pulse over time
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed + uv.x * 0.5 + uv.y * 0.5);
	
	vec3 col = mix(basalt_color.rgb, lava_color.rgb, crack);
	col = mix(col, lava_core_color.rgb, core);
	
	ALBEDO = col;
	ROUGHNESS = mix(roughness_val, 0.3, crack);
	SPECULAR = 0.4;
	
	// Glowing molten emission
	vec3 emission_glow = (lava_color.rgb * crack + lava_core_color.rgb * core * 1.5) * pulse * 3.5;
	EMISSION = emission_glow;
}
