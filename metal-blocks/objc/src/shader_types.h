#pragma once

#include <simd/simd.h>

typedef enum BufferIndex {
    BufferIndexVertices = 0,
    BufferIndexInstances = 1,
    BufferIndexUniforms = 2,
} BufferIndex;

typedef enum TextureIndex {
    TextureIndexMaterials = 0,
} TextureIndex;

typedef enum SamplerIndex {
    SamplerIndexMaterials = 0,
} SamplerIndex;

typedef enum InstanceFlag {
    InstanceFlagTranslucent = 1 << 0,
} InstanceFlag;

typedef struct {
    vector_float4 position;
    vector_float4 normal;
    vector_float2 textureCoordinate;
    vector_float2 padding;
} Vertex;

typedef struct {
    matrix_float4x4 viewProjectionMatrix;
    vector_float3 cameraPosition;
    vector_float3 sunDirection;
    vector_float3 skyColor;
    float ambient;
    float translucentAlpha;
    float fogStart;
    float fogEnd;
} Uniforms;

// One visible cube face: only the faces that touch open space become instances,
// so the interior of the world costs nothing to draw.
typedef struct {
    vector_short4 position;  // xyz grid cell, w baked ambient occlusion
    vector_uchar4 face;      // x cube face, y texture layer, z instance flags
} VoxelInstance;
