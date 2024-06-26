shader_type canvas_item;

uniform float level : hint_range(0.0, 1.0);
uniform float final_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec2 size = vec2(1.0);
uniform float wave_width = 100.0;
uniform float wave_height = 20.0;
uniform float depth = 60.0;
uniform vec3 water_color : source_color;
uniform vec3 depth_color : source_color;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float ray_value : hint_range(0.0, 1.0) = 0.3;

uniform sampler2D noise_sampler : repeat_enable;

void fragment() {
	float adapt_height = 1.0 - smoothstep(.7, 1.0, level);
	float n_depth = depth * adapt_height;
	float n_wave_height = wave_height * adapt_height;
	vec2 scaled_uv = UV * size;
	scaled_uv.y *= level;
	float depth_uv_y = scaled_uv.y / n_depth;
	float depth_mask = clamp(scaled_uv.y / n_depth, 0.0, 1.0);
	vec3 screen_color = texture(screen_texture, SCREEN_UV, 1.0 + depth_mask * 1.5).rgb;
	float wave_offset = (2.0 + sin(scaled_uv.x / 820.0 * PI + TIME)) * 0.25 + 1.0;
	float wave_x = (1.0 + sin(scaled_uv.x / wave_width * PI + TIME * 0.5)) / 2.0; 
	float wave_height_mask = level * scaled_uv.y / n_wave_height - wave_offset;
	float wave_mask = clamp(level * wave_x + wave_height_mask, 0.0, 1.0);
	
	float uv_x_scaled = scaled_uv.x / 1000.0 - depth_uv_y * 0.1;
	
	float noise_1 = texture(noise_sampler, vec2(uv_x_scaled + TIME * 0.04, 0.0)).x;
	float noise_2 = texture(noise_sampler, vec2(uv_x_scaled + TIME * 0.01, 0.0)).x;
	float ray = clamp(
		((1.0 - wave_mask) * 0.5) +
		(noise_1 * noise_2) * sin(depth_mask * PI), 0.0, 1.0);
		
	COLOR.rgb = screen_color * mix(water_color, depth_color, depth_mask);
	COLOR.rgb = mix(COLOR.rgb, depth_color, depth_mask * 0.9);
	COLOR.rgb += ray * ray_value;
	float alpha = texture(TEXTURE, UV).a;
	COLOR.a = smoothstep(0.0, 0.06, wave_mask);
	COLOR.a *= alpha * final_alpha;
}
