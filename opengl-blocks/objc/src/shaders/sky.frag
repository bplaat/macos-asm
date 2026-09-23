#version 410 core

in float height;
uniform vec3 skyColor;
out vec4 fragmentColor;

void main() {
    fragmentColor = vec4(mix(skyColor, skyColor * 0.35, clamp(height, 0.0, 1.0)), 1.0);
}
