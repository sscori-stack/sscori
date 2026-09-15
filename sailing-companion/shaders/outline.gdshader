shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;
// 뒤집힌 껍질 외곽선: next_pass 로 붙인다.

uniform vec4 line_color : source_color = vec4(0.32, 0.2, 0.22, 1.0);
uniform float thickness = 0.012;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
