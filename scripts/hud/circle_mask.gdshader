shader_type canvas_item;

// Clips a HUD portrait to a soft-edged circle.
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float distance_from_center = length(UV - vec2(0.5));
	color.a *= 1.0 - smoothstep(0.47, 0.5, distance_from_center);
	COLOR = color;
}
