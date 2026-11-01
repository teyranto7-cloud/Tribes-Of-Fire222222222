shader_type spatial;
render_mode cull_disabled;
uniform vec4 water_color : source_color = vec4(0.18, 0.43, 0.48, 0.84);
uniform float rain = 0.0;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world.x * 0.34 + TIME * 0.8) * cos(world.z * 0.25 + TIME * 0.6) * 0.035;
}
void fragment() {
	ALBEDO = water_color.rgb;
	METALLIC = 0.5;
	ROUGHNESS = mix(0.12, 0.29, rain);
	vec2 wave = vec2(sin(UV.x * 210.0 + TIME * 1.2), cos(UV.y * 170.0 + TIME));
	NORMAL_MAP = vec3(wave * (0.04 + rain * 0.035) + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.4;
	ALPHA = water_color.a;
}
