#version 460 core

// The fill of a plasma meter: QSR blue with light moving through it from
// the start of the bar to the level, so the level reads as something held,
// not as a painted stripe. The track beyond the level is flat.
//
// Written for Flutter's GLSL subset and for Impeller's OpenGL ES backend
// on Windows: no loops, no arrays, no call GLSL leaves undefined.
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_time; // seconds
uniform float u_fill; // the level, 0 to 1
uniform float u_dir;  // 1 fills from the left, -1 from the right

uniform vec3 u_base;  // the fill
uniform vec3 u_hot;   // the light's tint at its brightest
uniform vec4 u_track; // behind the fill, straight alpha

out vec4 fragColor;

// A band of light at c along the bar, w wide, with no edge.
float band(float x, float c, float w) {
  float d = (x - c) / w;
  return exp(-d * d);
}

void main() {
  vec2 px = FlutterFragCoord().xy;

  // Distance from the end the bar fills from, in bar heights, so the bands
  // are the same size on a short meter and on a long one.
  float along = u_dir > 0.0 ? px.x : u_size.x - px.x;
  float fillWidth = u_fill * u_size.x;

  // The track needs no lighting, including while the fill edge is moving.
  vec4 track = vec4(u_track.rgb * u_track.a, u_track.a);
  if (along >= fillWidth + 0.5) {
    fragColor = track;
    return;
  }

  // Only the ends of a partly filled bar need rounded-edge coverage.
  float radius = min(u_size.y, fillWidth) * 0.5;
  float inside = 1.0;
  if (u_fill < 1.0 && (along < radius + 0.5
      || along > fillWidth - radius - 0.5)) {
    vec2 center = vec2(fillWidth, u_size.y) * 0.5;
    vec2 q = abs(vec2(along, px.y) - center) - (center - radius);
    float distance = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    inside = clamp(0.5 - distance, 0.0, 1.0);
  }
  if (inside == 0.0) {
    fragColor = track;
    return;
  }

  // Two bands at different speeds; each wraps a little past the level so it
  // leaves the fill before it comes back in.
  float x = along / u_size.y;
  float level = fillWidth / u_size.y;
  float span = level + 12.0;
  float a = band(x, mod(u_time * 5.0, span) - 6.0, 4.5);
  float b = band(x, mod(u_time * 2.2 + 0.5 * span, span) - 6.0, 7.0);

  vec3 lit = mix(u_base, vec3(1.0), 0.28);
  vec3 fill = mix(u_base, lit, 0.55 * b);
  fill = mix(fill, u_hot, 0.55 * a);
  // The light gathers at the level's edge, where the plasma ends.
  fill = mix(fill, lit, 0.5 * band(x, level, 1.2));

  fragColor = mix(track, vec4(fill, 1.0), inside);
}
