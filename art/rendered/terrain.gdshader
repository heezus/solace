shader_type canvas_item;
render_mode unshaded;

uniform sampler2D terrain_mask : filter_linear, repeat_disable;
uniform sampler2D turf_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D water_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D earth_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D woodland_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D woodland_b_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D calm_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D bank_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float south_start;
uniform float east_start;
uniform int era_family = 0;
uniform float turf_columns = 3.0;
uniform vec2 earth_grid = vec2(2.0, 1.0);
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

// Two continuously blended, hash-offset samples suppress the material's period without
// rotating/mirroring the painted light. Noise is world anchored and map seeded.
vec2 grid_uv(vec2 p, vec2 grid, float index) {
	vec2 texel = fract(p) * 1919.0 + vec2(0.5);
	return (texel + vec2(mod(index, grid.x), floor(index / grid.x)) * 1920.0) / (grid * 1920.0);
}

vec3 grid_sample(sampler2D sheet, vec2 p, vec2 grid, float index) {
	float k = noise_field(p * 0.19) * 8.0;
	float cell = floor(k);
	vec2 offset_a = sin(vec2(3.0, 7.0) * cell);
	vec2 offset_b = sin(vec2(3.0, 7.0) * (cell + 1.0));
	return mix(texture(sheet, grid_uv(p + offset_a, grid, index)).rgb,
		texture(sheet, grid_uv(p + offset_b, grid, index)).rgb, smoothstep(0.2, 0.8, fract(k)));
}

vec3 atlas_sample(sampler2D sheet, vec2 p, float columns, float index) {
	return grid_sample(sheet, p, vec2(columns, 1.0), min(index, columns - 1.0));
}

vec3 earth_sample(vec2 p, float index) {
	return grid_sample(earth_texture, p, earth_grid, min(index, earth_grid.x * earth_grid.y - 1.0));
}

vec4 terrain_sample(vec2 uv) {
	vec2 inset = 0.5 / vec2(textureSize(terrain_mask, 0));
	return texture(terrain_mask, clamp(vec2(uv.x * 0.5, uv.y), inset, vec2(0.5, 1.0) - inset));
}

vec3 material_sample(sampler2D sheet, vec2 p) {
	return atlas_sample(sheet, p, 1.0, 0.0);
}

vec3 bank_sample(float along, float across) {
	float k = noise_field(vec2(along * 0.19, 9.0)) * 8.0;
	float cell = floor(k);
	return mix(texture(bank_texture, vec2(fract(along + sin(cell * 3.0)), across)).rgb,
		texture(bank_texture, vec2(fract(along + sin((cell + 1.0) * 3.0)), across)).rgb,
		smoothstep(0.2, 0.8, fract(k)));
}

void vertex() {
	map_px = VERTEX;
}

void fragment() {
	vec2 uv = map_px / world_size;
	vec4 masks = terrain_sample(uv);
	vec2 inset = 0.5 / vec2(textureSize(terrain_mask, 0));
	vec4 regions = texture(terrain_mask, clamp(vec2(0.5 + uv.x * 0.5, uv.y), vec2(0.5, 0.0) + inset, vec2(1.0) - inset));
	// Retain the kit's fine brush subscale: painted foliage must stay below miniature scale.
	float motif_scale = 3.0;
	// Contract sheets span 20 tiles; fine brush marks use hash-offset subscales.
	vec2 material_uv = map_px / 960.0;
	float broad = noise_field(map_px / 1920.0);
	float detail_mix = smoothstep(0.25, 0.75, noise_field(map_px / 310.0));
	vec3 meadow = mix(atlas_sample(turf_texture, (material_uv) * motif_scale, turf_columns, 0.0),
		atlas_sample(turf_texture, (map_px / 1296.0 + vec2(0.37, 0.61)) * motif_scale, turf_columns, 0.0), detail_mix * 0.46);
	float biome = noise_field(map_px / 1560.0 + vec2(15.1, 27.3));
	meadow = mix(meadow, atlas_sample(turf_texture, (material_uv + vec2(0.23, 0.59)) * motif_scale, turf_columns, 1.0),
		smoothstep(0.48, 0.85, biome) * 0.65);
	meadow = mix(meadow, atlas_sample(turf_texture, (material_uv + vec2(0.63, 0.17)) * motif_scale, turf_columns, 2.0),
		(1.0 - smoothstep(0.18, 0.55, biome)) * 0.65);
	vec3 woodland = mix(atlas_sample(woodland_texture, (material_uv) * motif_scale, 1.0, 0.0),
		atlas_sample(woodland_b_texture, (map_px / 1296.0 + vec2(0.41, 0.21)) * motif_scale, 1.0, 0.0), broad);
	float forest = smoothstep(0.12, 0.72, masks.b + (noise_field(map_px / 45.0) - 0.5) * 0.24);
	if (era_family == 2) {
		float east = smoothstep(east_start - 96.0, east_start + 144.0,
			map_px.x + (noise_field(map_px / 160.0) - 0.5) * 96.0);
		vec3 west = atlas_sample(turf_texture, material_uv * 3.0, turf_columns, 0.0);
		vec3 hills = atlas_sample(turf_texture, material_uv * motif_scale, turf_columns, 1.0);
		meadow = mix(west, hills, east);
		woodland = mix(woodland, hills * vec3(0.86, 0.91, 0.84), east * 0.65);
	}
	vec3 ground = mix(meadow, woodland, forest);
	ground *= 0.97 + broad * 0.06;
	vec3 earth = earth_sample(material_uv * turf_columns, 0.0);
	float south = smoothstep(south_start - 96.0, south_start + 144.0,
		map_px.y + (noise_field(map_px / 160.0) - 0.5) * 96.0);
	ground = mix(ground, earth_sample(material_uv * motif_scale, 1.0), south * 0.86);
	if (era_family == 3) {
		ground = mix(ground, earth_sample(material_uv * motif_scale, 2.0), smoothstep(0.04, 0.8, regions.r) * south * 0.93);
	}
	if (era_family == 3 || era_family == 4) {
		float bloom = clamp(regions.g + (noise_field(map_px / 19.0) - 0.5) * 0.12, 0.0, 1.0);
		// Growth is strongest at the patch boundary; healthy interiors stay quieter.
		float edge = bloom * (0.25 + 0.75 * (1.0 - smoothstep(0.3, 0.95, bloom)));
		vec3 growth = earth_sample(material_uv * motif_scale, era_family == 4 ? 2.0 : 3.0);
		ground = mix(ground, growth, edge * 1.7);
		ground = mix(ground, earth_sample(material_uv * motif_scale, 3.0), smoothstep(0.12, 0.85, regions.b));
	}
	vec3 road = mix(earth, vec3(0.56, 0.46, 0.32), 0.18);
	road = mix(road, road * vec3(0.76, 0.83, 0.80), forest * 0.65);
	// Worn aprons are independent of road topology: they never pretend to connect networks.
	ground = mix(ground, road, masks.a * 0.72);
	float wet = masks.r + (noise_field(map_px / 14.0) - 0.5) * 0.035 + (noise_field(map_px / 65.0) - 0.5) * 0.14;
	float river = smoothstep(0.475, 0.535, wet);
	float damp = smoothstep(0.25, 0.45, wet) * (1.0 - river);
	float bank = smoothstep(0.38, 0.46, wet) * (1.0 - smoothstep(0.49, 0.55, wet));
	vec2 grad = vec2(terrain_sample(uv + vec2(3.0 / world_size.x, 0.0)).r - terrain_sample(uv - vec2(3.0 / world_size.x, 0.0)).r,
		terrain_sample(uv + vec2(0.0, 3.0 / world_size.y)).r - terrain_sample(uv - vec2(0.0, 3.0 / world_size.y)).r);
	float light = clamp(dot(grad * 8.0, vec2(-0.6, -0.8)), -0.25, 0.25);
	ground = mix(ground, ground * vec3(0.70, 0.78, 0.73), damp * 0.65);
	ground = mix(ground, earth * vec3(0.75, 0.82, 0.77) * (1.0 + light), bank * 0.85);
	vec2 flow = vec2(sin(TIME * 0.19) * 0.001, -TIME * 0.0035);
	vec3 water = mix(material_sample(calm_texture, (material_uv) * 1.7),
		material_sample(water_texture, (material_uv + flow) * 1.7), smoothstep(0.25, 0.8, masks.r));
	float depth = smoothstep(0.54, 0.96, wet);
	water = mix(water * vec3(0.98, 1.05, 0.94), water * vec3(0.54, 0.75, 0.79), depth * 0.70);
	float contact = (1.0 - smoothstep(0.54, 0.62, wet)) * river;
	water *= 1.0 - contact * 0.20;
	float ripple = sin(map_px.y * 0.10 + sin(map_px.x * 0.025) * 2.0 - TIME * 0.7);
	float shore = (1.0 - smoothstep(0.012, 0.045, abs(wet - 0.55))) * (0.12 + ripple * 0.07);
	water += vec3(0.10, 0.16, 0.15) * shore;
	vec3 color = mix(ground, water, river);
	// Project the painted strip onto both contour tangents. Blending by normal avoids
	// atan branch seams and abrupt orientation flips at bends and river ends.
	vec2 normal = grad / max(length(grad), 0.0001);
	float bank_distance = (wet - 0.5) * 6.0 / max(length(grad), 0.001);
	float across = clamp(0.5 + bank_distance / 40.0, 0.02, 0.98);
	vec3 bank_x = bank_sample(map_px.x / 480.0, across);
	vec3 bank_y = bank_sample(map_px.y / 480.0 + 0.31, across);
	float tangent_weight = smoothstep(0.15, 0.85, normal.y * normal.y);
	vec3 painted_bank = mix(bank_y, bank_x, tangent_weight);
	float bank_band = (1.0 - smoothstep(12.0, 22.0, abs(bank_distance)))
		* smoothstep(0.002, 0.04, length(grad));
	color = mix(color, painted_bank * (1.0 + light * 0.28), bank_band);
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
