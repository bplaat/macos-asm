#version 410 core

out float height;

void main() {
    vec2 corner = vec2(gl_VertexID == 2 ? 3.0 : -1.0, gl_VertexID == 0 ? -3.0 : 1.0);
    gl_Position = vec4(corner, 1.0, 1.0);
    height = corner.y * 0.5 + 0.5;
}
