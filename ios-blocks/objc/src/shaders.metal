#include <metal_stdlib>

#include "shader_types.h"

using namespace metal;

struct SkyData {
    float4 position [[position]];
    float height;
};

struct RasterizerData {
    float4 position [[position]];
    float2 texture_coordinate;
    float shade;
    float fog;
    float alpha;
    uint layer [[flat]];
};

// Draws a full screen triangle holding the vertical sky gradient.
vertex SkyData sky_vertex(uint vertex_id [[vertex_id]]) {
    const float2 corners[] = {float2(-1, -3), float2(-1, 1), float2(3, 1)};
    return {
        .position = float4(corners[vertex_id], 1.0, 1.0),
        .height = corners[vertex_id].y * 0.5 + 0.5,
    };
}

fragment float4 sky_fragment(SkyData input [[stage_in]], constant Uniforms& uniforms [[buffer(BufferIndexUniforms)]]) {
    return float4(mix(uniforms.skyColor, uniforms.skyColor * 0.35, saturate(input.height)), 1.0);
}

vertex RasterizerData voxel_vertex(const device Vertex* vertices [[buffer(BufferIndexVertices)]],
                                   const device VoxelInstance* instances [[buffer(BufferIndexInstances)]],
                                   constant Uniforms& uniforms [[buffer(BufferIndexUniforms)]],
                                   uint vertex_id [[vertex_id]], uint instance_id [[instance_id]]) {
    VoxelInstance instance = instances[instance_id];
    // The four corners of this cube face, snapped to its grid cell.
    Vertex input = vertices[instance.face.x * 4 + vertex_id];
    float3 normal = input.normal.xyz;
    float3 world = input.position.xyz * 0.5 + float3(instance.position.xyz) + 0.5;

    float occlusion = float(instance.position.w) / 255.0;
    float sun = max(dot(normal, uniforms.sunDirection), 0.0);
    float distance = length(world - uniforms.cameraPosition);
    bool translucent = (instance.face.z & InstanceFlagTranslucent) != 0;
    return {
        .position = uniforms.viewProjectionMatrix * float4(world, 1.0),
        .texture_coordinate = input.textureCoordinate,
        .shade = (uniforms.ambient + (1.0 - uniforms.ambient) * sun) * occlusion,
        .fog = saturate((distance - uniforms.fogStart) / (uniforms.fogEnd - uniforms.fogStart)),
        .alpha = translucent ? uniforms.translucentAlpha : 1.0,
        .layer = instance.face.y,
    };
}

fragment float4 voxel_fragment(RasterizerData input [[stage_in]],
                               constant Uniforms& uniforms [[buffer(BufferIndexUniforms)]],
                               texture2d_array<float> materials [[texture(TextureIndexMaterials)]],
                               sampler material_sampler [[sampler(SamplerIndexMaterials)]]) {
    float3 color = materials.sample(material_sampler, input.texture_coordinate, input.layer).rgb;
    return float4(mix(color * input.shade, uniforms.skyColor, input.fog), input.alpha);
}
