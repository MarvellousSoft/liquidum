shader_type canvas_item;

uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform float ratio : hint_range(0.0, 1.0);

void fragment() {
	COLOR = mix(top_color, bottom_color, UV.y*ratio);
}
