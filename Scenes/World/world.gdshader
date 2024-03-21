shader_type spatial;
uniform float grass_level = 0.5;
uniform float snow_level = 2.5;
uniform float stone_level = 1.7;
uniform float barren_level = 0.0;
uniform sampler2D noise_texture; // New: noise texture for grass detail
varying float height_val;
varying vec3 normal;

void vertex(){
    height_val = VERTEX.y;
    normal = NORMAL;
}

void fragment(){
    vec3 dirt = vec3(0.6,0.3,0.1);
    vec3 grass = vec3(0.3,0.6,0.1);
    vec3 snow = vec3(0.9,0.9,0.9);
    vec3 stone = vec3(0.5, 0.5, 0.5);
    vec3 barren = vec3(0.8, 0.7, 0.3);

    float slope = 1.0 - normal.y;
    float grass_cutoff = smoothstep(barren_level, grass_level, height_val);
    float stone_cutoff = smoothstep(grass_level, stone_level, height_val);
    float snow_cutoff = smoothstep(stone_level, snow_level, height_val);

    vec3 col = mix(barren, grass, grass_cutoff);
    col = mix(col, stone, stone_cutoff);
    col = mix(col, snow, snow_cutoff);

    // New: add detail to grass layer using noise texture
    if (grass_cutoff > 0.0 && stone_cutoff == 0.0) {
        float noise = texture(noise_texture, UV).r;
        col = mix(col, col * noise, 0.1);
    }

    ALBEDO = col;
}