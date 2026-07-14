shader_type canvas_item;

uniform float scope_radius : hint_range(0.0, 1.0) = 0.4;
uniform float edge_blur : hint_range(0.0, 0.1) = 0.01;
uniform vec4 blackout_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float aspect_ratio = 1.777; // Default to 16:9

void fragment() {
    // Shift UVs so 0,0 is exactly in the center of the screen
    vec2 centered_uv = UV - vec2(0.5);
    
    // Multiply the X axis by the aspect ratio so the circle doesn't stretch into an oval
    centered_uv.x *= aspect_ratio;
    
    // Calculate the distance from the center pixel
    float dist = length(centered_uv);
    
    // Smoothstep creates the hole. It returns 0.0 inside the radius, and 1.0 outside.
    float alpha = smoothstep(scope_radius - edge_blur, scope_radius, dist);
    
    // Apply the color and the calculated alpha transparency
    COLOR = blackout_color;
    COLOR.a = alpha * blackout_color.a;
}