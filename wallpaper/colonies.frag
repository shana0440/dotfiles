#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float cellPx;
    float screenW;
    float screenH;
    float mapW;
    float mapH;
    float seed;
    vec4 newCrop;
    vec4 ember;
};
layout(binding = 1) uniform sampler2D newTexture;
layout(binding = 2) uniform sampler2D mapTexture;

const float PI = 3.14159265;
const float BURN_DURATION_AS_SHARE_OF_AREA = 0.06;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.31) * 43758.5453); }

vec2 mapCoordinateAtCellCentre(vec2 cell) {
    vec2 screen = vec2(screenW, screenH);
    return clamp((cell + 0.5) * cellPx / screen, vec2(0.0), vec2(1.0));
}

float arrivalAt(vec2 cell) {
    vec4 m = texture(mapTexture, mapCoordinateAtCellCentre(cell));
    return (floor(m.r * 255.0 + 0.5) * 256.0 + floor(m.g * 255.0 + 0.5)) / 65535.0;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = clamp(progress, 0.0, 1.0);
    vec3 newColor = texture(newTexture, newCrop.xy + uv * newCrop.zw).rgb;
    if (t >= 1.0) { fragColor = vec4(newColor, 1.0) * qt_Opacity; return; }
    if (t <= 0.0) { fragColor = vec4(0.0); return; }

    float easedProgress = t * t * (3.0 - 2.0 * t);
    float front = easedProgress * (1.0 + BURN_DURATION_AS_SHARE_OF_AREA + 0.01) - 0.01;
    float energy = sin(PI * t);

    vec2 cell = floor(uv * vec2(screenW, screenH) / cellPx);
    float cellArrival = arrivalAt(cell);
    float flicker = hash(cell);
    vec3 hot = mix(ember.rgb, vec3(1.0), 0.2);
    vec4 premultipliedColor;

    if (cellArrival > front) {
        float ahead = cellArrival - front;
        bool isRareSparkJustAhead = flicker > 0.988 && ahead < 0.025;
        float spark = isRareSparkJustAhead ? (1.0 - ahead / 0.025) * 0.75 * energy : 0.0;
        premultipliedColor = vec4(hot * spark, spark);
    } else {
        bool bordersUnflippedCell = max(max(arrivalAt(cell + vec2(1.0, 0.0)), arrivalAt(cell - vec2(1.0, 0.0))),
                        max(arrivalAt(cell + vec2(0.0, 1.0)), arrivalAt(cell - vec2(0.0, 1.0)))) > front;
        float life = clamp((front - cellArrival) / BURN_DURATION_AS_SHARE_OF_AREA, 0.0, 1.0);
        float burn = (1.0 - life) * (1.0 - life) * (bordersUnflippedCell ? 1.0 : 0.5);
        premultipliedColor = vec4(mix(newColor, hot, burn * (0.55 + 0.45 * flicker) * 0.8 * min(1.0, energy * 3.0)), 1.0);
    }
    float blurredArrival = texture(mapTexture, uv).b;
    vec3 additiveFrontGlow = ember.rgb * 0.18 * energy * exp(-abs(blurredArrival - front) / 0.008);
    premultipliedColor.rgb += additiveFrontGlow;
    fragColor = premultipliedColor * qt_Opacity;
}
