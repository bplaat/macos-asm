#pragma once

#include <simd/simd.h>

typedef enum BufferIndex {
    BufferIndexVertices = 0,
    BufferIndexInstances = 1,
    BufferIndexUniforms = 2,
} BufferIndex;

typedef enum TextureIndex {
    TextureIndexColor = 0,
} TextureIndex;

typedef enum SamplerIndex {
    SamplerIndexColor = 0,
} SamplerIndex;

typedef struct {
    vector_float4 position;
    vector_float2 textureCoordinate;
    vector_float2 padding;
} Vertex;

typedef struct {
    matrix_float4x4 projectionMatrix;
    vector_float4 time;
} Uniforms;

typedef struct {
    vector_float4 positionAndScale;
    vector_float4 axisAndSpeed;
    vector_float4 localOffsetAndPhase;
} InstanceData;
