shader_type spatial;

uniform sampler2D atlas_texture : source_color, filter_nearest;
uniform float atlas_size = 16.0; // Number of tiles in atlas (16x16)

void fragment() {
	// UV contains the repeat count (0 to width/height in blocks)
	// UV2 contains the atlas tile coordinate (e.g., (1, 0) for tile at column 1, row 0)
	
	vec2 repeat_uv = UV;  // 0 to width/height
	vec2 atlas_tile = UV2;  // Which tile in the atlas (integer coordinates)
	
	float tile_size = 1.0 / atlas_size;
	
	// Wrap the repeat UV using fract (this creates the tiling effect)
	vec2 wrapped = fract(repeat_uv);
	
	// Calculate final UV: atlas tile position + wrapped offset within that tile
	vec2 final_uv = (atlas_tile + wrapped) * tile_size;
	
	ALBEDO = texture(atlas_texture, final_uv).rgb;
}
