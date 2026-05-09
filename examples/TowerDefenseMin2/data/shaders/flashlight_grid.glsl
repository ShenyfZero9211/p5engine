#ifdef GL_ES
precision mediump float;
#endif

uniform vec2 resolution;
uniform vec2 mouse;
uniform float gridSize;
uniform float lightRadius;
uniform float activation;
uniform vec2 rectSize;

void main() {
    vec2 pixelPos = gl_FragCoord.xy;

    // ---- Grid line detection (anti-aliased) ----
    // Distance from pixel center to nearest horizontal/vertical grid line
    float hLineDist = min(fract(pixelPos.x / gridSize), 1.0 - fract(pixelPos.x / gridSize)) * gridSize;
    float vLineDist = min(fract(pixelPos.y / gridSize), 1.0 - fract(pixelPos.y / gridSize)) * gridSize;

    // Glow layer (5px wide, soft edge)
    float hGlow = 1.0 - smoothstep(0.0, 2.5, hLineDist);
    float vGlow = 1.0 - smoothstep(0.0, 2.5, vLineDist);
    float gridGlow = max(hGlow, vGlow);

    // Main lines (1px wide, sharp edge)
    float hMain = 1.0 - smoothstep(0.0, 0.5, hLineDist);
    float vMain = 1.0 - smoothstep(0.0, 0.5, vLineDist);
    float gridMain = max(hMain, vMain);

    // ---- Radial mask: Gaussian falloff for concentrated glow at center ----
    vec2 delta = abs(pixelPos - mouse) - rectSize;
    float dist = length(max(delta, 0.0));
    float t = dist / lightRadius;
    float mask = exp(-t * t * 3.0);  // Gaussian: bright center, soft tail
    mask = mask * activation;

    // ---- Full brightness colors (for ADD blend mode) ----
    // Glow: (74, 158, 255) @ alpha 255
    vec3 glowColor = vec3(74.0, 158.0, 255.0) / 255.0;
    // Main: (120, 190, 255) @ alpha 255
    vec3 mainColor = vec3(120.0, 190.0, 255.0) / 255.0;

    vec3 color = (glowColor * gridGlow + mainColor * gridMain) * mask;

    gl_FragColor = vec4(color, 1.0);
}
