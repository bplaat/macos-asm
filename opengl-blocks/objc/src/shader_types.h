#pragma once

#include <simd/simd.h>
#include <stdint.h>

enum { InstanceFlagTranslucent = 1 << 0 };

typedef struct {
    vector_short4 position;
    vector_uchar4 face;
} VoxelInstance;
