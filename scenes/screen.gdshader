shader_type canvas_item;

uniform bool shader_enabled = true;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D palette;

uniform bool dithering = false;
uniform int dithering_size : hint_range(1, 16) = 2;
uniform int quantization_level : hint_range(2, 16) = 16;

int dithering_pattern(ivec2 fragcoord) {
	const int pattern[] = {
		-4, +0, -3, +1,
		+2, -2, +3, -1,
		-3, +1, -4, +0,
		+3, -1, +2, -2
	};
	int x = fragcoord.x % 4;
	int y = fragcoord.y % 4;
	return pattern[y * 4 + x] * dithering_size;
}

float color_distance(vec3 a, vec3 b) {
	vec3 diff = a - b;
	return dot(diff, diff);
}

vec3 quantize_color(vec3 color, int levels) {
	if (levels <= 1) return vec3(0.0);
	float step = 1.0 / float(levels - 1);
	return round(color / step) * step;
}

void fragment() {
	vec4 final_color;

	if (!shader_enabled) {
		final_color = texture(SCREEN_TEXTURE, SCREEN_UV);
	} else {
		vec2 tex_size = vec2(textureSize(SCREEN_TEXTURE, 0));

		if (tex_size.x <= 0.0 || tex_size.y <= 0.0) {
			final_color = vec4(0.0);
		} else {
			ivec2 texel_coord = ivec2(floor(SCREEN_UV * tex_size));
			vec3 color = texelFetch(SCREEN_TEXTURE, texel_coord, 0).rgb;

			if (dithering) {
				int dither = dithering_pattern(texel_coord);
				color += vec3(float(dither) / 255.0);
			}
			color = clamp(color, 0.0, 1.0);
			color = quantize_color(color, quantization_level);

			int palette_size = 16;
			float closest_distance = 9999.0;
			vec4 closest_color = vec4(0.0);

			for (int i = 0; i < palette_size; i++) {
				float u = float(i) / float(palette_size - 1);
				vec3 palette_color = texture(palette, vec2(u, 0.0)).rgb;
				float dist = color_distance(color, palette_color);
				if (dist < closest_distance) {
					closest_distance = dist;
					closest_color = vec4(palette_color, 1.0);
				}
			}

			final_color = closest_color;
		}
	}

	COLOR = final_color;
}
