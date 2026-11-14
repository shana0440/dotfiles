#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec4 fillColor;
    vec4 ringColor;
    vec4 shadowColor;
    // The center island: top-left xy and size zw, with its corner radius.
    vec4 island;
    float islandRadius;
    // Side circles: center xy, diameter z and blend radius w.
    vec4 leftCircle;
    vec4 rightCircle;
    // Rounded boxes beyond each circle: center xy and size zw, with corner radius x
    // and blend radius y in the shape vector.
    vec4 leftOuter;
    vec2 leftOuterShape;
    vec4 rightOuter;
    vec2 rightOuterShape;
} ubuf;

float roundedBox(vec2 point, vec4 box, float radius)
{
    vec2 halfSize = box.zw * 0.5;
    radius = min(radius, min(halfSize.x, halfSize.y));
    vec2 edge = abs(point - box.xy - halfSize) - halfSize + vec2(radius);
    return length(max(edge, vec2(0.0))) + min(max(edge.x, edge.y), 0.0) - radius;
}

float circle(vec2 point, vec4 shape)
{
    if (shape.z <= 0.001)
        return 1e5;
    return length(point - shape.xy) - shape.z * 0.5;
}

float centeredBox(vec2 point, vec4 shape, float radius)
{
    if (shape.z <= 0.001 || shape.w <= 0.001)
        return 1e5;
    return roundedBox(point, vec4(shape.xy - shape.zw * 0.5, shape.zw), radius);
}

// Polynomial smooth minimum: shapes closer than `radius` fuse with a liquid neck.
float smoothMinimum(float first, float second, float radius)
{
    if (radius <= 0.001)
        return min(first, second);
    float influence = max(radius - abs(first - second), 0.0) / radius;
    return min(first, second) - influence * influence * radius * 0.25;
}

float field(vec2 point)
{
    float surface = roundedBox(point, ubuf.island, ubuf.islandRadius);
    surface = smoothMinimum(surface, circle(point, ubuf.leftCircle), ubuf.leftCircle.w);
    surface = smoothMinimum(surface, circle(point, ubuf.rightCircle), ubuf.rightCircle.w);
    surface = smoothMinimum(surface, centeredBox(point, ubuf.leftOuter, ubuf.leftOuterShape.x), ubuf.leftOuterShape.y);
    return smoothMinimum(surface, centeredBox(point, ubuf.rightOuter, ubuf.rightOuterShape.x), ubuf.rightOuterShape.y);
}

void main()
{
    vec2 point = qt_TexCoord0 * ubuf.resolution;
    float surface = field(point);
    float aa = max(fwidth(surface), 0.001);
    float outer = clamp(0.5 - surface / aa, 0.0, 1.0);
    // Like a Rectangle border, the 1 px ring replaces the fill along the edge.
    float inner = clamp(0.5 - (surface + 1.0) / aa, 0.0, 1.0);
    float ring = outer - inner;

    // Qt passes color uniforms premultiplied already.
    vec4 color = ubuf.fillColor * inner + ubuf.ringColor * ring;

    // The Surface drop shadow: 4 px down, spread -4, blur 12.
    float shadowSurface = field(point - vec2(0.0, 4.0)) + 4.0;
    float shadow = ubuf.shadowColor.a * (1.0 - smoothstep(-12.0, 12.0, shadowSurface));
    color += vec4(ubuf.shadowColor.rgb, 1.0) * shadow * (1.0 - color.a);

    fragColor = color * ubuf.qt_Opacity;
}
