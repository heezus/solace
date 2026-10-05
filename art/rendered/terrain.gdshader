shader_type canvas_item;
render_mode unshaded;

uniform sampler2D terrain_mask : filter_linear, repeat_disable;
uniform sampler2D turf_texture : source_color, filter_linear, repeat_enable;
uniform sampler2D water_texture : source_color, filter_linear, repeat_enable;
uniform sampler2D earth_texture : source_color, filter_linear, repeat_enable;
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
	vec3 masks = texture(terrain_mask, map_px / world_size).rgb;
	vec2 detail_uv = map_px / 300.0;
	vec3 turf = texture(turf_texture, mirrored(detail_uv)).rgb;
	vec3 secondary = texture(turf_texture, mirrored(detail_uv.yx * 0.73 + vec2(0.37, 0.19))).rgb;
	turf = mix(turf, secondary, 0.22);
	turf = (turf - vec3(0.26, 0.34, 0.20)) * 0.52 + vec3(0.28, 0.37, 0.28);
	turf *= 0.92 + noise_field(map_px / 260.0) * 0.13;

	float edge_noise = (noise_field(map_px / 9.0) - 0.5) * 0.035
		+ (noise_field(map_px / 57.0) - 0.5) * 0.18;
	float wet = masks.r + edge_noise;
	float river = smoothstep(0.465, 0.535, wet);
	float damp = smoothstep(0.25, 0.44, wet) * (1.0 - river);
	float bank = smoothstep(0.35, 0.455, wet) * (1.0 - smoothstep(0.485, 0.54, wet));
	vec3 earth = texture(earth_texture, mirrored(map_px / 260.0)).rgb;
	turf = mix(turf, turf * vec3(0.66, 0.72, 0.69), damp * 0.7);
	turf = mix(turf, earth * vec3(0.76, 0.81, 0.76), bank * 0.75);

	vec2 flow = vec2(0.0018 * sin(TIME * 0.21), -TIME * 0.006);
	vec3 water = texture(water_texture, mirrored(map_px / 420.0 + flow)).rgb;
	vec3 reflection = texture(water_texture, mirrored(map_px.yx / 690.0 + vec2(TIME * 0.002, 0.27))).rgb;
	water = mix(water, reflection, 0.22);
	float depth = smoothstep(0.54, 0.96, wet);
	water = mix(water * vec3(1.02, 1.12, 1.07), water * vec3(0.63, 0.77, 0.84), depth * 0.62);
	float glint = smoothstep(0.63, 0.82, reflection.g) * (0.55 + 0.45 * sin(TIME * 0.7 + map_px.y * 0.05));
	water += vec3(0.035, 0.06, 0.065) * glint;
	float shore = (1.0 - smoothstep(0.025, 0.065, abs(wet - 0.525))) * (0.12 + 0.16 * noise_field(map_px / 14.0 + vec2(0.0, TIME * 0.18)));
	water += vec3(0.15, 0.2, 0.18) * shore;
	vec3 color = mix(turf, water, river);

	float path = smoothstep(0.1, 0.86, masks.g + (noise_field(map_px / 6.0) - 0.5) * 0.19);
	path *= 1.0 - smoothstep(0.42, 0.54, wet);
	vec3 road = earth * vec3(0.91, 0.88, 0.81);
	if (stone_paths) {
		float joints = smoothstep(0.055, 0.12, min(fract(map_px.x / 11.0), fract(map_px.y / 9.0)));
		road = mix(road * 0.68, road * vec3(0.97, 1.05, 1.09), joints);
	}
	color = mix(color, road, path * 0.94);
	COLOR = vec4(color, 1.0);
}
