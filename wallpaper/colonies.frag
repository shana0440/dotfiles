// Pixel-colony transition (WallpaperTransition.qml).
//
// The map (wallpaper-colonies) says WHEN each cell turns into the new image;
// this only draws it: crisp square cells, a brief burn in the new image's
// most vivid colour where cells have just flipped, a soft glow riding the
// front and rare sparks just ahead of it. Every effect is scaled to vanish at
// both ends, so the first frame is exactly the old image and the last exactly
// the new one (what awww shows underneath).
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// std140: matrix and opacity first (Qt requires it), floats, then vec4s.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;    // 0..1, linear in time
    float cellPx;      // cell size in item pixels
    float screenW;
    float screenH;
    float mapW;        // colony map texels
    float mapH;
    float seed;        // differs per change: sparks never repeat
    float fromColor;   // 1 when the old wallpaper is a solid colour
    vec4 oldCrop;      // image uv = xy + screen uv * zw (awww's centred cover)
    vec4 newCrop;
    vec4 ember;
    vec4 oldColor;
};
layout(binding = 1) uniform sampler2D oldTexture;
layout(binding = 2) uniform sampler2D newTexture;
layout(binding = 3) uniform sampler2D mapTexture;

const float PI = 3.14159265;
const float LIFE = 0.06;     // how long a flipped cell burns, in fraction of area

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.31) * 43758.5453); }

// Map coordinate for a screen cell's centre.
vec2 cellUV(vec2 cell) {
    vec2 screen = vec2(screenW, screenH);
    return clamp((cell + 0.5) * cellPx / screen, vec2(0.0), vec2(1.0));
}
// 16-bit arrival from R (high) and G (low); the texture is sampled nearest.
float arrival(vec2 cell) {
    vec4 m = texture(mapTexture, cellUV(cell));
    return (floor(m.r * 255.0 + 0.5) * 256.0 + floor(m.g * 255.0 + 0.5)) / 65535.0;
}

vec3 oldAt(vec2 uv) {
    return fromColor > 0.5 ? oldColor.rgb : texture(oldTexture, oldCrop.xy + uv * oldCrop.zw).rgb;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = clamp(progress, 0.0, 1.0);
    // Soft start and landing; the map itself already spreads area evenly.
    float eased = t * t * (3.0 - 2.0 * t);
    float T = eased * (1.0 + LIFE + 0.01) - 0.01;
    float energy = sin(PI * t);

    vec2 cell = floor(uv * vec2(screenW, screenH) / cellPx);
    float a = arrival(cell);
    float flicker = hash(cell);
    vec3 hot = mix(ember.rgb, vec3(1.0), 0.2);
    vec3 color;

    if (a > T) {
        color = oldAt(uv);
        // A spark: a lone cell just ahead of the front lights up briefly.
        float ahead = a - T;
        if (flicker > 0.988 && ahead < 0.025)
            color = mix(color, hot, (1.0 - ahead / 0.025) * 0.75 * energy);
    } else {
        color = texture(newTexture, newCrop.xy + uv * newCrop.zw).rgb;
        bool edge = max(max(arrival(cell + vec2(1.0, 0.0)), arrival(cell - vec2(1.0, 0.0))),
                        max(arrival(cell + vec2(0.0, 1.0)), arrival(cell - vec2(0.0, 1.0)))) > T;
        float life = clamp((T - a) / LIFE, 0.0, 1.0);
        float burn = (1.0 - life) * (1.0 - life) * (edge ? 1.0 : 0.5);
        color = mix(color, hot, burn * (0.55 + 0.45 * flicker) * 0.8 * min(1.0, energy * 3.0));
    }
    // Soft glow along the front from the blurred arrival (B channel).
    float smoothArrival = texture(mapTexture, uv).b;
    color += ember.rgb * 0.18 * energy * exp(-abs(smoothArrival - T) / 0.008);

    if (t <= 0.0) color = oldAt(uv);
    if (t >= 1.0) color = texture(newTexture, newCrop.xy + uv * newCrop.zw).rgb;
    fragColor = vec4(color, 1.0) * qt_Opacity;
}
