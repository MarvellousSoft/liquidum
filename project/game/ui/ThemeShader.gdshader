shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec3 theme_color : source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(theme_color.r*g, theme_color.g*g, theme_color.b*g, c.a);
	
}
