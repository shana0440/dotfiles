#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec4 oldCrop;
    vec4 newCrop;
    vec4 ink;
};
layout(binding = 1) uniform sampler2D oldTexture;
layout(binding = 2) uniform sampler2D newTexture;
layout(binding = 3) uniform sampler2D fieldTexture;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 incomingUV = newCrop.xy + uv * newCrop.zw;
    vec3 oldImage = texture(oldTexture, oldCrop.xy + uv * oldCrop.zw).rgb;
    vec3 newImage = texture(newTexture, incomingUV).rgb;
    vec3 field = texture(fieldTexture, incomingUV).rgb;
    float t = clamp(progress, 0.0, 1.0);
    float distance = (field.r - 0.5) * 64.0;
    float aa = max(fwidth(distance), 0.15);
    float inside = smoothstep(-aa, aa, distance);

    // First trace two strokes around the silhouette; then fill inwards.
    float pen = smoothstep(0.0, 0.35, t);
    float drawn = 1.0 - smoothstep(pen - 0.015, pen + 0.015, field.g);
    float outline = (1.0 - smoothstep(aa * 1.2, aa * 2.2, abs(distance)))
        * drawn * (1.0 - step(0.997, field.g));
    float fillTime = smoothstep(0.34, 0.64, t) * 1.05;
    float fill = inside * (1.0 - smoothstep(fillTime - 0.02, fillTime + 0.02, field.b / 0.49))
        * smoothstep(0.34, 0.37, t);

    // The remaining image spreads out from the subject, not from screen centre.
    float worldTime = smoothstep(0.62, 1.0, t) * 1.05;
    float worldOrder = max(0.0, (field.b - 0.51) / 0.49);
    float world = (1.0 - inside) * (1.0 - smoothstep(worldTime - 0.025, worldTime + 0.025, worldOrder))
        * smoothstep(0.62, 0.65, t);
    float reveal = clamp(fill + world, 0.0, 1.0);
    float dim = 1.0 - 0.40 * smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.62, 1.0, t));
    vec3 color = mix(oldImage * dim, newImage, reveal);
    color = mix(color, ink.rgb, outline * (1.0 - smoothstep(0.46, 0.75, t)));
    // Exact endpoints make both cross-fades invisible, including cropped images.
    if (t <= 0.0) color = oldImage;
    if (t >= 0.9999) color = newImage;
    fragColor = vec4(color, 1.0) * qt_Opacity;
}
