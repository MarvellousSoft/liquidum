shader_type canvas_item;

uniform float cutoff : hint_range(0.0, 1.0);
uniform float wave_size : hint_range(0.0, 1.0) = 0.1;
uniform float wave_frequency : hint_range(0.0, 0.1) = 0.04;
uniform float wave_speed : hint_range(0.0, 30.0) = 20.0;
uniform float wave_foam_size : hint_range(0, 0.1) = 0.01;
uniform vec4 water_color : source_color;
uniform vec4 foam_color : source_color;

void fragment() {
	float value = (1.0 - UV.x) * (1.0 - wave_size - wave_foam_size);
	float alpha = 1.0;
	vec3 color = water_color.rgb + vec3(0.0, value, 0.0) / 5.0;
	
	float wave_cutoff_percent = (sin(UV.y / wave_frequency + TIME * wave_speed) + 1.0) / 2.0;
	float wave_cutoff_value = cutoff - wave_cutoff_percent * wave_size;

	if (value < wave_cutoff_value) {
		if (value > wave_cutoff_value - wave_foam_size) {
			color = foam_color.rgb;
			alpha = foam_color.a;
		} else {
			alpha = 0.0;
		}
	}
	
	COLOR = vec4(color, alpha);
}