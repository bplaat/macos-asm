#include <metal_stdlib>

#include "ShaderTypes.h"

using namespace metal;

struct RasterizerData {
    float4 position [[position]];
    float2 texture_coordinate;
};

vertex RasterizerData vertex_main(const device Vertex* vertices [[buffer(BufferIndexVertices)]],
                                  const device InstanceData* instances [[buffer(BufferIndexInstances)]],
                                  constant Uniforms& uniforms [[buffer(BufferIndexUniforms)]], uint vertex_id [[vertex_id]],
                                  uint instance_id [[instance_id]]) {
    Vertex input = vertices[vertex_id];
    InstanceData instance = instances[instance_id];
    float angle = instance.localOffsetAndPhase.w + uniforms.time.x * instance.axisAndSpeed.w;
    float sine = sin(angle);
    float cosine = cos(angle);
    float3 axis = instance.axisAndSpeed.xyz;
    float3 point = input.position.xyz * instance.positionAndScale.w;
    point = point * cosine + cross(axis, point) * sine + axis * dot(axis, point) * (1.0 - cosine);
    point += instance.localOffsetAndPhase.xyz;
    float3 center = instance.positionAndScale.xyz;
    float distance = -center.z;
    center.x *= distance / uniforms.projectionMatrix[0][0];
    center.y *= distance / uniforms.projectionMatrix[1][1];
    point += center;
    return {
        .position = uniforms.projectionMatrix * float4(point, 1.0),
        .texture_coordinate = input.textureCoordinate,
    };
}

fragment float4 fragment_main(RasterizerData input [[stage_in]],
                              texture2d<float> color_texture [[texture(TextureIndexColor)]],
                              sampler color_sampler [[sampler(SamplerIndexColor)]]) {
    return color_texture.sample(color_sampler, input.texture_coordinate);
}
