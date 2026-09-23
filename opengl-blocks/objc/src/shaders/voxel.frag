#version 410 core

in vec2 textureCoordinate;
in float shade;
in float fog;
in float alpha;
flat in uint layer;

uniform sampler2DArray materials;
uniform vec3 skyColor;
out vec4 fragmentColor;

void main() {
    vec3 color = texture(materials, vec3(textureCoordinate, float(layer))).rgb;
    fragmentColor = vec4(mix(color * shade, skyColor, fog), alpha);
}
