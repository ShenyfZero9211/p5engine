uniform sampler2D texture;
uniform float edgeWidth;
uniform float globalAlpha;

varying vec4 vertColor;
varying vec4 vertTexCoord;

void main() {
    vec4 texColor = texture2D(texture, vertTexCoord.st);
    float s = vertTexCoord.s;
    float edge = smoothstep(0.0, edgeWidth, s) * (1.0 - smoothstep(1.0 - edgeWidth, 1.0, s));
    texColor.a *= edge * globalAlpha;
    gl_FragColor = texColor;
}
