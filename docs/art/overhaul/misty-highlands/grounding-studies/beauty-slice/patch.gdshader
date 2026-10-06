shader_type canvas_item;
render_mode unshaded;
uniform sampler2D terrain_mask : filter_linear, repeat_disable;
uniform vec2 world_size;
uniform vec2 patch_center;
uniform float patch_scale;
uniform vec2 region_origin;
uniform vec2 region_size;
uniform float opacity;
varying vec2 map_px;
void vertex() { map_px = VERTEX * patch_scale + patch_center; }
void fragment() {
	vec4 masks = texture(terrain_mask, map_px / world_size);
	vec2 local_uv = (UV * vec2(textureSize(TEXTURE, 0)) - region_origin) / region_size;
	float edge = min(min(local_uv.x, local_uv.y), min(1.0 - local_uv.x, 1.0 - local_uv.y));
	float feather = smoothstep(0.0, 0.18, edge);
	float dry = 1.0 - smoothstep(0.33, 0.52, masks.r);
	float clear = 1.0 - smoothstep(0.16, 0.72, max(masks.g, masks.a));
	vec4 source = texture(TEXTURE, UV);
	source.rgb *= vec3(0.92, 0.97, 0.90);
	COLOR = vec4(source.rgb, source.a * feather * dry * clear * opacity);
}
