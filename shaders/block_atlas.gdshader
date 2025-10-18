shader_type spatial;

uniform sampler2D atlas_texture : source_color, filter_nearest;
uniform float atlas_size = 16.0;
uniform float min_brightness = 0.05;  // Minimum ambient light (prevents complete darkness)

void fragment() {
	vec2 repeat_uv = UV;
	vec2 atlas_tile = UV2;
	float brightness = COLOR.b;  // Lighting stored in blue channel
	
	// Apply minimum ambient light
	brightness = max(brightness, min_brightness);
	
	float tile_size = 1.0 / atlas_size;
	vec2 wrapped = fract(repeat_uv);
	vec2 final_uv = (atlas_tile + wrapped) * tile_size;
	
	vec3 base_color = texture(atlas_texture, final_uv).rgb;
	
	// Decode overlay position: subtract 1 to get back original coords
	// 0,0 means no overlay (-1,-1 originally), 1-16 are valid tiles 0-15
	vec2 overlay_encoded = COLOR.rg * 17.0;
	vec2 overlay_tile = overlay_encoded - vec2(1.0, 1.0);
	
	if (overlay_tile.x >= 0.0 && overlay_tile.y >= 0.0) {
		vec2 overlay_uv = (overlay_tile + wrapped) * tile_size;
		vec4 overlay_color = texture(atlas_texture, overlay_uv);
		base_color = mix(base_color, overlay_color.rgb, overlay_color.a);
	}
	
	// Apply lighting
	ALBEDO = base_color * brightness;
}
