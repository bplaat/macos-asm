#include <metal_stdlib>

#include "ShaderTypes.h"

using namespace metal;

struct RasterizerData {
    float4 position [[position]];
    float4 color;
};

vertex RasterizerData vertex_main(const device Vertex* vertices [[buffer(BufferIndexVertices)]],
                                  uint vertex_id [[vertex_id]]) {
    Vertex input = vertices[vertex_id];
    return {
        .position = float4(input.position, 0.0, 1.0),
        .color = input.color,
    };
}

fragment float4 fragment_main(RasterizerData input [[stage_in]]) {
    return input.color;
}
