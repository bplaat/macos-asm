#version 410 core

layout(location = 0) in ivec4 cell;
layout(location = 1) in uvec4 face;

uniform mat4 viewProjection;
uniform vec3 cameraPosition;
uniform vec3 sunDirection;
uniform float ambient;
uniform float fogStart;
uniform float fogEnd;
uniform float translucentAlpha;

out vec2 textureCoordinate;
out float shade;
out float fog;
out float alpha;
flat out uint layer;

const vec3 corners[24] = vec3[24](
    vec3(-1, -1,  1), vec3( 1, -1,  1), vec3( 1,  1,  1), vec3(-1,  1,  1),
    vec3( 1, -1, -1), vec3(-1, -1, -1), vec3(-1,  1, -1), vec3( 1,  1, -1),
    vec3( 1, -1,  1), vec3( 1, -1, -1), vec3( 1,  1, -1), vec3( 1,  1,  1),
    vec3(-1, -1, -1), vec3(-1, -1,  1), vec3(-1,  1,  1), vec3(-1,  1, -1),
    vec3(-1,  1,  1), vec3( 1,  1,  1), vec3( 1,  1, -1), vec3(-1,  1, -1),
    vec3(-1, -1, -1), vec3( 1, -1, -1), vec3( 1, -1,  1), vec3(-1, -1,  1)
);
const vec3 normals[6] = vec3[6](
    vec3(0, 0, 1), vec3(0, 0, -1), vec3(1, 0, 0),
    vec3(-1, 0, 0), vec3(0, 1, 0), vec3(0, -1, 0)
);
const vec2 coordinates[4] = vec2[4](vec2(0, 1), vec2(1, 1), vec2(1, 0), vec2(0, 0));

void main() {
    int corner = gl_VertexID;
    vec3 world = corners[int(face.x) * 4 + corner] * 0.5 + vec3(cell.xyz) + 0.5;
    gl_Position = viewProjection * vec4(world, 1.0);
    textureCoordinate = coordinates[corner];
    shade = (ambient + (1.0 - ambient) * max(dot(normals[face.x], sunDirection), 0.0))
        * float(cell.w) / 255.0;
    fog = clamp((length(world - cameraPosition) - fogStart) / (fogEnd - fogStart), 0.0, 1.0);
    alpha = (face.z & 1u) != 0u ? translucentAlpha : 1.0;
    layer = face.y;
}
