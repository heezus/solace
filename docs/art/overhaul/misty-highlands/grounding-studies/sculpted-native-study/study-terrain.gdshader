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
	vec2 uv = map_px / world_size;
	vec4 masks = texture(terrain_mask, uv);
	// Preserve authored relief; averaging two images flattened the rejected material.
	vec3 meadow = texture(turf_texture, mirrored(map_px / 384.0)).rgb;
	vec3 woodland = texture(woodland_texture, mirrored(map_px / 300.0)).rgb;
	float forest = smoothstep(0.10, 0.78, masks.b + (noise_field(map_px / 75.0) - 0.5) * 0.17);
	meadow *= vec3(0.96, 1.0, 0.97);
	vec3 ground = mix(meadow * vec3(0.91, 0.97, 0.91), mix(meadow * vec3(0.74, 0.80, 0.72), woodland, 0.45), forest);
	ground *= 0.94 + noise_field(map_px / 170.0) * 0.10;
	vec3 earth = texture(earth_texture, mirrored(map_px / 250.0)).rgb;
	vec3 road = mix(earth * vec3(1.12, 1.05, 0.91), vec3(0.63, 0.49, 0.32), 0.50);
	road = mix(road, road * vec3(0.84, 0.88, 0.84), forest * 0.65);
	float apron = masks.a * (0.55 + noise_field(map_px / 9.0) * 0.45);
	ground = mix(ground, road, apron * 0.70);
	float wet = masks.r + (noise_field(map_px / 12.0) - 0.5) * 0.05 + (noise_field(map_px / 48.0) - 0.5) * 0.12;
	float river = smoothstep(0.48, 0.525, wet);
	float damp = smoothstep(0.22, 0.44, wet) * (1.0 - river);
	float bank = smoothstep(0.28, 0.42, wet) * (1.0 - smoothstep(0.53, 0.61, wet));
	ground = mix(ground, earth * vec3(0.75, 0.84, 0.79), damp * 0.70);
	vec3 pebbles = stones(map_px / 6.5, vec3(0.49, 0.48, 0.38));
	float gravel = bank * smoothstep(0.30, 0.66, noise_field(map_px / 17.0));
	ground = mix(ground, pebbles, gravel * 0.20);
	// Preserve the reference's luminous jade depth and curved reflections at a smaller wave scale.
	float depth = smoothstep(0.53, 0.93, wet);
	vec3 source = texture(water_texture, mirrored(map_px / 250.0 + vec2(0.0, -TIME * 0.0025))).rgb;
	vec3 water = mix(source * vec3(0.88, 1.0, 0.88), vec3(0.10, 0.31, 0.32), depth * 0.48);
	water = mix(water, vec3(0.32, 0.48, 0.37), bank * 0.32);
	float thread = sin(map_px.y * 0.24 + sin(map_px.x * 0.07) * 1.8 - TIME * 0.6);
	float glint = smoothstep(0.96, 1.0, thread) * smoothstep(0.48, 0.78, noise_field(map_px / 19.0));
	water += vec3(0.06, 0.10, 0.09) * glint;
	float contact = (1.0 - smoothstep(0.53, 0.60, wet)) * river;
	water *= 1.0 - contact * 0.15;
	vec3 color = mix(ground, water, river);
	float wear = masks.g + (noise_field(map_px / 7.0) - 0.5) * 0.16 + (noise_field(map_px / 28.0) - 0.5) * 0.12;
	float verge = smoothstep(0.04, 0.44, wear);
	float path = smoothstep(0.33, 0.93, wear);
	float grass_breaks = smoothstep(0.65, 0.87, noise_field(map_px / 9.0)) * (1.0 - smoothstep(0.6, 0.97, masks.g));
	path *= 1.0 - grass_breaks * 0.8;
	float dry = 1.0 - smoothstep(0.43, 0.54, wet);
	if (stone_paths) { road = stones(map_px / 9.0, vec3(0.47, 0.46, 0.38)); }
	color = mix(color, mix(ground, road, 0.40), verge * dry * 0.65);
	color = mix(color, road, path * dry * 0.84);
	COLOR = vec4(color, 1.0);
}
