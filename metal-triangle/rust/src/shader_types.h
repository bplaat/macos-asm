#pragma once

#include <simd/simd.h>

typedef enum BufferIndex {
    BufferIndexVertices = 0,
} BufferIndex;

typedef struct {
    vector_float2 position;
    vector_float4 color;
} Vertex;
