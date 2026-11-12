// Pixel-colony transition layer (WallpaperTransition.qml).
//
// The map (wallpaper-colonies) says WHEN each cell turns into the new image;
// this only draws it: crisp square cells, a brief burn in the new image's
// most vivid colour where cells have just flipped, a soft glow riding the
// front and rare sparks just ahead of it.
//
// Cells that have not flipped yet are transparent, so whatever is beneath
// shows through: awww's wallpaper, or another transition still running. That
// is what lets several transitions overlap. Effects vanish at both ends: the
// first frame draws nothing and the last is exactly the new image (what awww
// is switched to underneath before this layer goes away).
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
    vec4 newCrop;      // image uv = xy + screen uv * zw (awww's centred cover)
    vec4 ember;
};
layout(binding = 1) uniform sampler2D newTexture;
layout(binding = 2) uniform sampler2D mapTexture;

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

void main() {
    vec2 uv = qt_TexCoord0;
    float t = clamp(progress, 0.0, 1.0);
    vec3 newColor = texture(newTexture, newCrop.xy + uv * newCrop.zw).rgb;
    if (t >= 1.0) { fragColor = vec4(newColor, 1.0) * qt_Opacity; return; }
    if (t <= 0.0) { fragColor = vec4(0.0); return; }

    // Soft start and landing; the map itself already spreads area evenly.
    float eased = t * t * (3.0 - 2.0 * t);
    float T = eased * (1.0 + LIFE + 0.01) - 0.01;
    float energy = sin(PI * t);

    vec2 cell = floor(uv * vec2(screenW, screenH) / cellPx);
    float a = arrival(cell);
    float flicker = hash(cell);
    vec3 hot = mix(ember.rgb, vec3(1.0), 0.2);
    vec4 color;   // premultiplied

    if (a > T) {
        // Not yet arrived: transparent, except a lone spark just ahead of the front.
        float ahead = a - T;
        float spark = flicker > 0.988 && ahead < 0.025 ? (1.0 - ahead / 0.025) * 0.75 * energy : 0.0;
        color = vec4(hot * spark, spark);
    } else {
        bool edge = max(max(arrival(cell + vec2(1.0, 0.0)), arrival(cell - vec2(1.0, 0.0))),
                        max(arrival(cell + vec2(0.0, 1.0)), arrival(cell - vec2(0.0, 1.0)))) > T;
        float life = clamp((T - a) / LIFE, 0.0, 1.0);
        float burn = (1.0 - life) * (1.0 - life) * (edge ? 1.0 : 0.5);
        color = vec4(mix(newColor, hot, burn * (0.55 + 0.45 * flicker) * 0.8 * min(1.0, energy * 3.0)), 1.0);
    }
    // Soft glow along the front from the blurred arrival (B channel); zero
    // alpha makes it additive over whatever lies beneath.
    float smoothArrival = texture(mapTexture, uv).b;
    color.rgb += ember.rgb * 0.18 * energy * exp(-abs(smoothArrival - T) / 0.008);
    fragColor = color * qt_Opacity;
}
