#pragma once

typedef enum BufferIndex {
    BufferIndexVertices = 0,
} BufferIndex;

#ifdef __METAL_VERSION__
typedef struct {
    float2 position;
    float4 color;
} Vertex;
#else
typedef struct __attribute__((aligned(16))) {
    float position[2];
    float padding[2];
    float color[4];
} Vertex;
#endif
