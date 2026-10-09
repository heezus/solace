shader_type canvas_item;
render_mode unshaded;

uniform sampler2D road_atlas : source_color, filter_linear;
uniform float tier = 0.0;
uniform vec4 connections = vec4(1.0); // left, right, up, down; visual connectivity supplied by caller
uniform vec2 tile_origin = vec2(0.0);
uniform float tile_size = 48.0;

float rectangle_distance(vec2 p, vec2 center, vec2 extent) {
	vec2 d = abs(p - center) - extent;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 p = UV;
	float distance = length(p - vec2(0.5)) - 0.23;
	if (connections.x > 0.5) distance = min(distance, rectangle_distance(p, vec2(0.25, 0.5), vec2(0.25, 0.21)));
	if (connections.y > 0.5) distance = min(distance, rectangle_distance(p, vec2(0.75, 0.5), vec2(0.25, 0.21)));
	if (connections.z > 0.5) distance = min(distance, rectangle_distance(p, vec2(0.5, 0.25), vec2(0.21, 0.25)));
	if (connections.w > 0.5) distance = min(distance, rectangle_distance(p, vec2(0.5, 0.75), vec2(0.21, 0.25)));
	vec2 world = tile_origin + p * tile_size;
	vec2 sample_uv = abs(vec2(1.0) - mod(world / 16.0, vec2(2.0)));
	sample_uv = mix(vec2(0.006), vec2(0.994), sample_uv);
	vec2 atlas_uv = vec2((clamp(tier, 0.0, 2.0) + sample_uv.x) / 3.0, sample_uv.y);
	vec4 surface = texture(road_atlas, atlas_uv);
	float edge = 1.0 - smoothstep(-0.025, 0.025, distance);
	// Connected arms remain opaque at their shared cell edge, preventing a dashed tile seam.
	if ((connections.x > 0.5 && p.x < 0.03) || (connections.y > 0.5 && p.x > 0.97)) {
		edge = 1.0 - smoothstep(0.19, 0.23, abs(p.y - 0.5));
	}
	if ((connections.z > 0.5 && p.y < 0.03) || (connections.w > 0.5 && p.y > 0.97)) {
		edge = max(edge, 1.0 - smoothstep(0.19, 0.23, abs(p.x - 0.5)));
	}
	COLOR = vec4(surface.rgb, surface.a * edge);
}
