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
    vec4 island;
    float islandRadius;
    vec4 leftCircle;
    vec4 rightCircle;
    vec4 leftOuter;
    vec2 leftOuterShape;
    vec4 rightOuter;
    vec2 rightOuterShape;
} ubuf;

vec2 topLeft(vec4 box) { return box.xy; }
vec2 size(vec4 box) { return box.zw; }
vec2 center(vec4 shape) { return shape.xy; }
float diameter(vec4 circle) { return circle.z; }
float blendRadius(vec4 circle) { return circle.w; }
float cornerRadius(vec2 outerShape) { return outerShape.x; }
float blendRadius(vec2 outerShape) { return outerShape.y; }

float roundedBox(vec2 point, vec4 box, float radius)
{
    vec2 halfSize = size(box) * 0.5;
    radius = min(radius, min(halfSize.x, halfSize.y));
    vec2 edge = abs(point - topLeft(box) - halfSize) - halfSize + vec2(radius);
    return length(max(edge, vec2(0.0))) + min(max(edge.x, edge.y), 0.0) - radius;
}

const float FAR_AWAY = 1e5;

float circle(vec2 point, vec4 shape)
{
    if (diameter(shape) <= 0.001)
        return FAR_AWAY;
    return length(point - center(shape)) - diameter(shape) * 0.5;
}

float centeredBox(vec2 point, vec4 shape, float radius)
{
    if (size(shape).x <= 0.001 || size(shape).y <= 0.001)
        return FAR_AWAY;
    return roundedBox(point, vec4(center(shape) - size(shape) * 0.5, size(shape)), radius);
}

float polynomialSmoothMinimum(float first, float second, float radius)
{
    if (radius <= 0.001)
        return min(first, second);
    float influence = max(radius - abs(first - second), 0.0) / radius;
    return min(first, second) - influence * influence * radius * 0.25;
}

float liquidSurfaceDistance(vec2 point)
{
    float island = roundedBox(point, ubuf.island, ubuf.islandRadius);
    float left = circle(point, ubuf.leftCircle);
    float right = circle(point, ubuf.rightCircle);
    float leftOuter = centeredBox(point, ubuf.leftOuter, cornerRadius(ubuf.leftOuterShape));
    float rightOuter = centeredBox(point, ubuf.rightOuter, cornerRadius(ubuf.rightOuterShape));

    float surface = polynomialSmoothMinimum(island, left, blendRadius(ubuf.leftCircle));
    surface = polynomialSmoothMinimum(surface, right, blendRadius(ubuf.rightCircle));
    surface = polynomialSmoothMinimum(surface, leftOuter, blendRadius(ubuf.leftOuterShape));
    surface = polynomialSmoothMinimum(surface, rightOuter, blendRadius(ubuf.rightOuterShape));
    float leftCircleNeckToOuter = polynomialSmoothMinimum(leftOuter, left, blendRadius(ubuf.leftCircle));
    float rightCircleNeckToOuter = polynomialSmoothMinimum(rightOuter, right, blendRadius(ubuf.rightCircle));
    return min(min(surface, leftCircleNeckToOuter), rightCircleNeckToOuter);
}

void main()
{
    vec2 point = qt_TexCoord0 * ubuf.resolution;
    float surface = liquidSurfaceDistance(point);
    vec2 pixelSizeStableAcrossCreases = fwidth(point);
    float onePixel = max(max(pixelSizeStableAcrossCreases.x, pixelSizeStableAcrossCreases.y), 0.001);
    float outer = clamp(0.5 - surface / onePixel, 0.0, 1.0);
    float insideBorder = clamp(0.5 - (surface + 1.0) / onePixel, 0.0, 1.0);
    float border = outer - insideBorder;

    vec4 premultipliedColor = ubuf.fillColor * insideBorder + ubuf.ringColor * border;

    const vec2 shadowOffset = vec2(0.0, 4.0);
    const float shadowSpread = -4.0;
    const float shadowBlur = 12.0;
    float shadowSurface = liquidSurfaceDistance(point - shadowOffset) - shadowSpread;
    float shadow = ubuf.shadowColor.a * (1.0 - smoothstep(-shadowBlur, shadowBlur, shadowSurface));
    premultipliedColor += vec4(ubuf.shadowColor.rgb, 1.0) * shadow * (1.0 - premultipliedColor.a);

    fragColor = premultipliedColor * ubuf.qt_Opacity;
}
