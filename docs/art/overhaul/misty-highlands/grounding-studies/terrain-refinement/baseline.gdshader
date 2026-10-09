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

void fragment() {
	vec2 uv = map_px / world_size;
	vec4 masks = texture(terrain_mask, uv);
	vec3 meadow = texture(turf_texture, mirrored(map_px / 320.0)).rgb;
	vec3 woodland = texture(woodland_texture, mirrored(map_px / 350.0)).rgb;
	float forest = smoothstep(0.12, 0.72, masks.b + (noise_field(map_px / 75.0) - 0.5) * 0.14);
	vec3 ground = mix(meadow * vec3(0.90, 0.96, 0.91), woodland * vec3(0.86, 0.92, 0.89), forest);
	ground *= 0.96 + noise_field(map_px / 300.0) * 0.08;
	vec3 earth = texture(earth_texture, mirrored(map_px / 350.0)).rgb;
	vec3 road = mix(earth, vec3(0.56, 0.46, 0.32), 0.65);
	road = mix(road, road * vec3(0.76, 0.83, 0.80), forest * 0.65);
	// Worn aprons are independent of road topology: they never pretend to connect networks.
	ground = mix(ground, road, masks.a * 0.72);
	float wet = masks.r + (noise_field(map_px / 14.0) - 0.5) * 0.035 + (noise_field(map_px / 65.0) - 0.5) * 0.14;
	float river = smoothstep(0.475, 0.535, wet);
	float damp = smoothstep(0.25, 0.45, wet) * (1.0 - river);
	float bank = smoothstep(0.38, 0.46, wet) * (1.0 - smoothstep(0.49, 0.55, wet));
	vec2 grad = vec2(texture(terrain_mask, uv + vec2(3.0 / world_size.x, 0.0)).r - texture(terrain_mask, uv - vec2(3.0 / world_size.x, 0.0)).r,
		texture(terrain_mask, uv + vec2(0.0, 3.0 / world_size.y)).r - texture(terrain_mask, uv - vec2(0.0, 3.0 / world_size.y)).r);
	float light = clamp(dot(grad * 8.0, vec2(-0.6, -0.8)), -0.25, 0.25);
	ground = mix(ground, ground * vec3(0.70, 0.78, 0.73), damp * 0.65);
	ground = mix(ground, earth * vec3(0.75, 0.82, 0.77) * (1.0 + light), bank * 0.85);
	vec2 flow = vec2(sin(TIME * 0.19) * 0.001, -TIME * 0.0035);
	vec3 water = texture(water_texture, mirrored(map_px / 440.0 + flow)).rgb;
	float depth = smoothstep(0.54, 0.96, wet);
	water = mix(water * vec3(0.98, 1.05, 0.94), water * vec3(0.54, 0.75, 0.79), depth * 0.70);
	float contact = (1.0 - smoothstep(0.54, 0.62, wet)) * river;
	water *= 1.0 - contact * 0.20;
	float ripple = sin(map_px.y * 0.10 + sin(map_px.x * 0.025) * 2.0 - TIME * 0.7);
	float shore = (1.0 - smoothstep(0.012, 0.045, abs(wet - 0.55))) * (0.12 + ripple * 0.07);
	water += vec3(0.10, 0.16, 0.15) * shore;
	vec3 color = mix(ground, water, river);
	float wear = masks.g + (noise_field(map_px / 17.0) - 0.5) * 0.23;
	float verge = smoothstep(0.025, 0.48, wear);
	float path = smoothstep(0.30, 0.91, wear);
	float dry = 1.0 - smoothstep(0.42, 0.54, wet);
	if (stone_paths) {
		float joints = smoothstep(0.05, 0.13, min(fract(map_px.x / 13.0), fract(map_px.y / 11.0)));
		road = mix(road * 0.72, road * vec3(0.97, 1.05, 1.09), joints);
	}
	color = mix(color, mix(ground, road, 0.3), verge * dry * 0.6);
	color = mix(color, road, path * dry * 0.96);
	COLOR = vec4(color, 1.0);
}
