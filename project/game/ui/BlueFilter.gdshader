shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float strength = 0.0;

void fragment() {
    vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	c.b *= (1.0 - strength);
	c.g *= (1.0 - 0.15*strength);
    COLOR = c;
}