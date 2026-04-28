shader_type canvas_item;

uniform float mana_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 full_color : source_color = vec4(0.15, 0.45, 1.0, 1.0);
uniform vec4 empty_color : source_color = vec4(0.06, 0.06, 0.10, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) discard;

	// Drains from tips (UV.y = 1) toward roots (UV.y = 0)
	float drain = smoothstep(mana_ratio - 0.12, mana_ratio + 0.12, UV.y);
	vec3 hair_color = mix(full_color.rgb, empty_color.rgb, drain);

	// Subtle pulse glow when mana is high
	float glow = (sin(TIME * 3.0) * 0.5 + 0.5) * pow(mana_ratio, 2.0);
	hair_color += vec3(0.05, 0.10, 0.30) * glow;

	COLOR = vec4(hair_color, tex.a);
}
