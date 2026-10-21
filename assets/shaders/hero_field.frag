#version 460 core

// The light behind the Home hero: three wide, soft sources that drift
// under the card colour. It is the one plasma surface of the page, so it
// is kept low: the balance in front of it must read as text on a card, and
// nothing here may move fast enough to pull the eye off a number.
//
// Written for Flutter's GLSL subset and for Impeller's OpenGL ES backend
// on Windows: no loops, no arrays, no call GLSL leaves undefined.
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_time; // seconds

// The card colour, and the three lights mixed into it.
uniform vec3 u_base;
uniform vec3 u_a;
uniform vec3 u_b;
uniform vec3 u_c;

// How far a light pulls the card colour at its centre, 0 to 1.
uniform float u_strength;

out vec4 fragColor;

// A source at c with radius r: 1 at the centre, falling off as a gaussian,
// so there is no edge to see anywhere on the card.
float light(vec2 p, vec2 c, float r) {
  vec2 d = (p - c) / r;
  return exp(-dot(d, d));
}

void main() {
  vec2 px = FlutterFragCoord().xy;

  // One unit is the card's height, so a source stays round on a card that
  // is seven times as wide as it is tall.
  vec2 p = px / u_size.y;
  float w = u_size.x / u_size.y;
  float t = u_time;

  // Each source wanders on its own slow ellipse, with periods that share
  // no small multiple: the field never visibly repeats.
  vec2 ca = vec2(w * (0.14 + 0.09 * sin(t * 0.110)), 0.25 + 0.45 * cos(t * 0.130));
  vec2 cb = vec2(w * (0.52 + 0.12 * cos(t * 0.090 + 1.7)), 0.95 + 0.40 * sin(t * 0.070 + 0.6));
  vec2 cc = vec2(w * (0.90 + 0.07 * sin(t * 0.080 + 3.1)), 0.10 + 0.50 * cos(t * 0.100 + 2.2));

  float a = light(p, ca, 1.9);
  float b = light(p, cb, 2.3);
  float c = light(p, cc, 1.7);

  // Mixed, not added: the same numbers then work on a white card, where
  // adding light does nothing.
  vec3 color = u_base;
  color = mix(color, u_a, u_strength * a);
  color = mix(color, u_b, u_strength * b);
  color = mix(color, u_c, u_strength * c);

  // A wide, faint gradient on an 8-bit surface shows as bands. One level of
  // noise per pixel breaks them up.
  float n = fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453123);
  color += (n - 0.5) / 255.0;

  fragColor = vec4(color, 1.0);
}
