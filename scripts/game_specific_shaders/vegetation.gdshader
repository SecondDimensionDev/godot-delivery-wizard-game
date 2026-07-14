//veghetation.gdshader
shader_type spatial;
render_mode world_vertex_coords, depth_draw_opaque;

// Wind parameters
uniform float windSpeed : hint_range(0.1, 2.0) = 0.2;
uniform float windStrength : hint_range(0.0, 1.0) = 0.1;
uniform sampler2D windNoise;

// Material parameters
uniform vec3 albedoColor : source_color = vec3(0.3, 0.4, 0.2); // Green leaf color
uniform sampler2D alphaTexture : repeat_disable, source_color; // Renamed from albedo to alphaTexture

// Night time tint parameters
uniform vec3 nightColor : source_color = vec3(0.1, 0.2, 0.4);
uniform float nightTime : hint_range(0.0, 1.0) = 0.0;

// Ambient lighting parameters
uniform vec3 ambientColor : source_color = vec3(0.6, 0.2, 0.2);
uniform float ambientStrength : hint_range(0.0, 2.0) = 0.4;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    vec2 world_uv_x = vec2(VERTEX.x / 20.0 + 0.5 * TIME * windSpeed, 0.5);
    vec2 world_uv_z = vec2(VERTEX.z / 20.0 + 0.5 * TIME * windSpeed, 0.5);

    float wind_x = texture(windNoise, world_uv_x).x - 0.5;
    float wind_z = texture(windNoise, world_uv_z).z - 0.5;

    VERTEX.x += wind_x * windStrength * (1.0 - UV.y);
    VERTEX.z += wind_z * windStrength * (1.0 - UV.x);

    world_position = VERTEX;
    world_normal = NORMAL;
}

void fragment() {
    // Sample alpha texture for transparency
    vec4 alphaData = texture(alphaTexture, UV);

    // Calculate basic lighting
    vec3 light_dir = normalize(vec3(0.5, 1.0, 0.3)); // Simulate sun direction
    vec3 normal = normalize(world_normal);

    // Lambert lighting with bias to avoid complete darkness
    float NdotL = dot(normal, light_dir);
    float lambert = max(NdotL, 0.0);

    // Combine lighting components
    vec3 diffuse = vec3(1.0, 0.95, 0.8) * (lambert + 0.3); // Warm sunlight + bias
    vec3 ambient = ambientColor * ambientStrength;

    // Final lighting
    vec3 lighting = diffuse + ambient;
    lighting = clamp(lighting, 0.0, 2.0); // Prevent over-brightening

    // Apply lighting to albedo color
    vec3 litColor = albedoColor * lighting;

    // Apply night tint
    vec3 finalColor = mix(litColor, litColor * nightColor, nightTime);

    ALBEDO = finalColor;
    ALPHA = alphaData.a; // Use alpha channel from the texture
    ALPHA_SCISSOR_THRESHOLD = 0.5;
}