shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.88, 0.93, 1.0, 0.22);
uniform float outline_size = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE * outline_size;

	float neighbor_alpha = 0.0;
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-pixel.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, -pixel.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel.x, pixel.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-pixel.x, -pixel.y)).a);

	float outline_alpha = max(neighbor_alpha - tex.a, 0.0);
	COLOR = vec4(outline_color.rgb, outline_color.a * outline_alpha);
}
