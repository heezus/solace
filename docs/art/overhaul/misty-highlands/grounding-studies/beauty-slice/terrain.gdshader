shader_type canvas_item;
render_mode unshaded;

uniform sampler2D terrain_mask : filter_linear, repeat_disable;
uniform sampler2D turf_texture : source_color, filter_linear, repeat_enable;
uniform sampler2D water_texture : source_color, filter_linear, repeat_enable;
uniform sampler2D earth_texture : source_color, filter_linear, repeat_enable;
uniform sampler2D woodland_texture : source_color, filter_linear, repeat_enable;
uniform vec2 world_size;
uniform float map_seed;
uniform bool stone_paths = false;
varying vec2 map_px;

float noise_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + map_seed) * 43758.5453);
}

float noise_field(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(noise_hash(cell), noise_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(noise_hash(cell + vec2(0.0, 1.0)), noise_hash(cell + vec2(1.0)), f.x), f.y);
}

vec2 mirrored(vec2 uv) {
	return abs(fract(uv * 0.5) * 2.0 - 1.0);
}

void vertex() {
	map_px = VERTEX;
}

// Soft irregular stones: relief follows each cell's rounded boundary, not a square grid.
vec3 stones(vec2 p, vec3 base) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float nearest = 9.0;
	vec2 delta = vec2(0.0);
	vec2 picked = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 q = vec2(float(x), float(y));
			vec2 seed = vec2(noise_hash(cell + q), noise_hash(cell + q + vec2(37.0, 91.0)));
			vec2 d = q + vec2(0.22) + seed * 0.56 - f;
			float dist = length(d * vec2(1.0, 1.3));
			if (dist < nearest) { nearest = dist; delta = d; picked = cell + q; }
		}
	}
	float face = 1.0 - smoothstep(0.25, 0.43, nearest);
	float tone = noise_hash(picked) * 0.20;
	float light = dot(delta, vec2(-0.35, -0.5));
	vec3 stone = base * (0.94 + tone + light);
	return mix(base * 0.62, stone, face);
}

void fragment() {
	vec4 masks = texture(terrain_mask, map_px / world_size);
	float broad = noise_field(map_px / 155.0);
	vec3 turf = texture(turf_texture, mirrored(map_px / 290.0)).rgb;
	// Quiet base retains small blades; sculpted detail is a separate placed layer.
	vec3 ground = mix(vec3(0.31, 0.38, 0.17), turf * vec3(0.88, 0.96, 0.84), 0.58);
	ground *= 0.86 + broad * 0.22;
	float woods = smoothstep(0.10, 0.72, masks.b);
	ground = mix(ground, ground * vec3(0.70, 0.85, 0.76), woods * 0.72);
	vec3 earth = texture(earth_texture, mirrored(map_px / 250.0)).rgb;
	vec3 road = mix(earth * vec3(1.11, 1.07, 0.96), vec3(0.57, 0.45, 0.30), 0.56);
	float wear = masks.g + (noise_field(map_px / 8.0) - 0.5) * 0.15 + (noise_field(map_px / 28.0) - 0.5) * 0.10;
	float path = smoothstep(0.16, 0.86, wear);
	road *= 0.91 + noise_field(map_px / 5.0) * 0.15;
	float apron = masks.a * (0.72 + noise_field(map_px / 9.0) * 0.28);
	ground = mix(ground, road, max(path * 0.88, apron * 0.65));
	float wet = masks.r + (noise_field(map_px / 18.0) - 0.5) * 0.07;
	float river = smoothstep(0.485, 0.535, wet);
	// Broad transitions: moss verge, damp soil, then shallow water, not a hairline border.
	float damp = smoothstep(0.035, 0.38, wet) * (1.0 - river);
	float verge = smoothstep(0.01, 0.20, wet) * (1.0 - smoothstep(0.22, 0.42, wet));
	ground = mix(ground, ground * vec3(0.80, 1.06, 0.89), verge * 0.60);
	ground = mix(ground, earth * vec3(0.71, 0.81, 0.70), damp * 0.75);
	float depth = smoothstep(0.52, 0.93, wet);
	vec3 shallow = vec3(0.25, 0.40, 0.33);
	vec3 deep = vec3(0.075, 0.25, 0.27);
	vec3 water = mix(shallow, deep, depth);
	vec3 painted = texture(water_texture, mirrored(map_px / 330.0 + vec2(0.0, -TIME * 0.0015))).rgb;
	water = mix(water, painted * vec3(0.77, 0.85, 0.73), 0.46);
	water *= 0.94 + noise_field(map_px / 120.0) * 0.12;
	float thread = sin(map_px.y * 0.12 + sin(map_px.x * 0.045) * 1.7 - TIME * 0.35);
	float glint = smoothstep(0.97, 1.0, thread) * smoothstep(0.68, 0.87, noise_field(map_px / 31.0));
	water += vec3(0.065, 0.085, 0.075) * glint;
	float contact = (1.0 - smoothstep(0.52, 0.59, wet)) * river;
	water *= 1.0 - contact * 0.22;
	COLOR = vec4(mix(ground, water, river), 1.0);
}
