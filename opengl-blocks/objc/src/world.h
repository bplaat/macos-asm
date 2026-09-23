#pragma once

#include <float.h>
#include <math.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>

#include "materials.h"
#include "shader_types.h"

enum {
    WorldSize = 64,
    WorldLowestGround = 6,
    WorldHighestGround = 50,
    WorldWaterPercentage = 35,
    HutSize = 7,
    HutHeight = 4,
};

typedef enum VoxelType {
    VoxelAir = 0,
    VoxelGrass,
    VoxelDirt,
    VoxelSand,
    VoxelStone,
    VoxelGreystone,
    VoxelCoal,
    VoxelIron,
    VoxelGold,
    VoxelDiamond,
    VoxelLava,
    VoxelWater,
    VoxelLeaves,
    VoxelTrunk,
    VoxelCactus,
    VoxelBrick,
    VoxelPlanks,
    VoxelTypeCount,
} VoxelType;

#define VOXEL_FACES(layer) {layer, layer, layer}

// The side, top, and bottom texture array layer of every voxel type.
static const uint8_t voxelFaces[VoxelTypeCount][3] = {
    [VoxelGrass] = {MaterialLayerDirtGrass, MaterialLayerGrassTop, MaterialLayerDirt},
    [VoxelDirt] = VOXEL_FACES(MaterialLayerDirt),
    [VoxelSand] = VOXEL_FACES(MaterialLayerSand),
    [VoxelStone] = VOXEL_FACES(MaterialLayerStone),
    [VoxelGreystone] = VOXEL_FACES(MaterialLayerGreystone),
    [VoxelCoal] = VOXEL_FACES(MaterialLayerStoneCoal),
    [VoxelIron] = VOXEL_FACES(MaterialLayerStoneIron),
    [VoxelGold] = VOXEL_FACES(MaterialLayerStoneGold),
    [VoxelDiamond] = VOXEL_FACES(MaterialLayerStoneDiamond),
    [VoxelLava] = VOXEL_FACES(MaterialLayerLava),
    [VoxelWater] = VOXEL_FACES(MaterialLayerWater),
    [VoxelLeaves] = VOXEL_FACES(MaterialLayerLeaves),
    [VoxelTrunk] = {MaterialLayerTrunkSide, MaterialLayerTrunkTop, MaterialLayerTrunkTop},
    [VoxelCactus] = {MaterialLayerCactusSide, MaterialLayerCactusTop, MaterialLayerCactusTop},
    [VoxelBrick] = VOXEL_FACES(MaterialLayerBrickRed),
    [VoxelPlanks] = VOXEL_FACES(MaterialLayerWood),
};

// The six cube faces in the order the vertex buffer stores them, the grid
// direction each one looks at, and which material of the voxel type it uses.
static const int faceOffsets[6][3] = {{0, 0, 1}, {0, 0, -1}, {1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}};
static const int faceMaterials[6] = {0, 0, 0, 0, 1, 2};

typedef struct {
    VoxelInstance* instances;
    size_t opaqueCount;
    size_t translucentCount;
} WorldInstances;

// Mixed into every hash, so each launch grows a different world.
static uint32_t worldSeed;
static int worldSeaLevel;
static uint8_t worldVoxels[WorldSize][WorldSize][WorldSize];
static uint8_t worldHeights[WorldSize][WorldSize];

static float voxel_hash(uint32_t seed, int x, int y, int z) {
    uint32_t hash =
        worldSeed + seed + (uint32_t)x * 0x8da6b343u + (uint32_t)y * 0xd8163841u + (uint32_t)z * 0xcb1ab31fu;
    hash ^= hash >> 15;
    hash *= 0x2c1b3c6du;
    hash ^= hash >> 12;
    hash *= 0x297a2d39u;
    hash ^= hash >> 15;
    return (float)hash / (float)UINT32_MAX;
}

static float voxel_mix(float from, float to, float weight) {
    return from + (to - from) * weight;
}

// Classic smoothed value noise over the integer lattice.
static float voxel_noise(uint32_t seed, vector_float3 point) {
    vector_float3 cell = {floorf(point.x), floorf(point.y), floorf(point.z)};
    vector_float3 fraction = point - cell;
    vector_float3 weight = fraction * fraction * (3.0f - 2.0f * fraction);
    int x = (int)cell.x, y = (int)cell.y, z = (int)cell.z;
    float front =
        voxel_mix(voxel_mix(voxel_hash(seed, x, y, z), voxel_hash(seed, x + 1, y, z), weight.x),
                  voxel_mix(voxel_hash(seed, x, y + 1, z), voxel_hash(seed, x + 1, y + 1, z), weight.x), weight.y);
    float back = voxel_mix(
        voxel_mix(voxel_hash(seed, x, y, z + 1), voxel_hash(seed, x + 1, y, z + 1), weight.x),
        voxel_mix(voxel_hash(seed, x, y + 1, z + 1), voxel_hash(seed, x + 1, y + 1, z + 1), weight.x), weight.y);
    return voxel_mix(front, back, weight.z);
}

static float voxel_fractal_noise(uint32_t seed, vector_float3 point, int octaves) {
    float sum = 0, total = 0, amplitude = 1;
    for (int octave = 0; octave < octaves; octave++) {
        sum += amplitude * voxel_noise(seed + (uint32_t)octave * 7919u, point);
        total += amplitude;
        amplitude *= 0.5f;
        point *= 2.0f;
    }
    return sum / total;
}

static uint8_t world_ore(int x, int y, int z) {
    vector_float3 point = (vector_float3){(float)x, (float)y, (float)z} * 0.14f;
    if (y < 14 && voxel_noise(0x0d1a3f11u, point) > 0.80f) {
        return VoxelDiamond;
    }
    if (y < 22 && voxel_noise(0x901d5c27u, point) > 0.80f) {
        return VoxelGold;
    }
    if (y < 34 && voxel_noise(0x1201ab73u, point) > 0.78f) {
        return VoxelIron;
    }
    if (voxel_noise(0xc0a15e09u, point) > 0.76f) {
        return VoxelCoal;
    }
    return VoxelStone;
}

// Lays out the height of every column, stretched to fill the world so that a
// random seed always produces relief, and puts the water line where the chosen
// share of the columns falls below it.
static void world_generate_heights(void) {
    static float raw[WorldSize][WorldSize];
    float lowest = FLT_MAX, highest = -FLT_MAX;
    for (int z = 0; z < WorldSize; z++) {
        for (int x = 0; x < WorldSize; x++) {
            // Rolling continents with the occasional sharp mountain on top.
            vector_float3 column = {(float)x, 0, (float)z};
            float continents = voxel_fractal_noise(0x51a7b3c9u, column * 0.021f, 4);
            float mountains = voxel_fractal_noise(0x2f8e11d5u, column * 0.045f + 17.0f, 3);
            raw[x][z] = continents + powf(mountains, 4.5f) * 1.2f;
            lowest = raw[x][z] < lowest ? raw[x][z] : lowest;
            highest = raw[x][z] > highest ? raw[x][z] : highest;
        }
    }

    float span = highest - lowest < 0.001f ? 1.0f : highest - lowest;
    int histogram[WorldSize] = {0};
    for (int z = 0; z < WorldSize; z++) {
        for (int x = 0; x < WorldSize; x++) {
            int height = WorldLowestGround +
                         (int)((raw[x][z] - lowest) / span * (float)(WorldHighestGround - WorldLowestGround));
            worldHeights[x][z] = (uint8_t)height;
            histogram[height]++;
        }
    }

    int target = WorldSize * WorldSize * WorldWaterPercentage / 100;
    int submerged = 0;
    worldSeaLevel = WorldLowestGround;
    for (int level = 0; level < WorldSize; level++) {
        submerged += histogram[level];
        if (submerged >= target) {
            worldSeaLevel = level;
            break;
        }
    }
}

static void world_generate_terrain(void) {
    for (int z = 0; z < WorldSize; z++) {
        for (int x = 0; x < WorldSize; x++) {
            vector_float3 column = {(float)x, 0, (float)z};
            float desert = voxel_fractal_noise(0x7b3d90a1u, column * 0.017f - 31.0f, 2);
            int height = worldHeights[x][z];
            bool beach = height <= worldSeaLevel + 1;
            bool dunes = desert > 0.63f;
            bool rocky = height > WorldHighestGround - 10;
            uint8_t surface = beach || dunes ? VoxelSand : (rocky ? VoxelGreystone : VoxelGrass);
            uint8_t filler = beach || dunes ? VoxelSand : (rocky ? VoxelStone : VoxelDirt);

            for (int y = 0; y <= height; y++) {
                uint8_t type;
                if (y < 2) {
                    type = VoxelLava;
                } else if (y < 5) {
                    type = VoxelGreystone;
                } else if (y == height) {
                    type = surface;
                } else if (y > height - 4) {
                    type = filler;
                } else {
                    type = world_ore(x, y, z);
                }
                // Hollow out winding caverns well below the surface.
                if (y > 4 && y < height - 2) {
                    vector_float3 point = {(float)x * 0.075f, (float)y * 0.11f, (float)z * 0.075f};
                    float cave = voxel_fractal_noise(0x3c9d7a15u, point, 2);
                    if (cave > 0.615f && cave < 0.715f) {
                        type = VoxelAir;
                    }
                }
                worldVoxels[x][y][z] = type;
            }
            for (int y = height + 1; y <= worldSeaLevel; y++) {
                worldVoxels[x][y][z] = VoxelWater;
            }
        }
    }
}

// Drops a small brick cabin on the flattest patch of grass in the world.
static void world_build_hut(void) {
    int bestX = -1, bestZ = -1, bestBase = 0, bestRange = HutSize;
    for (int z = 6; z + HutSize < WorldSize - 6; z++) {
        for (int x = 6; x + HutSize < WorldSize - 6; x++) {
            int lowest = WorldSize, highest = 0;
            bool grass = true;
            for (int offsetZ = 0; offsetZ < HutSize && grass; offsetZ++) {
                for (int offsetX = 0; offsetX < HutSize; offsetX++) {
                    int height = worldHeights[x + offsetX][z + offsetZ];
                    lowest = height < lowest ? height : lowest;
                    highest = height > highest ? height : highest;
                    if (worldVoxels[x + offsetX][height][z + offsetZ] != VoxelGrass) {
                        grass = false;
                        break;
                    }
                }
            }
            if (grass && highest - lowest < bestRange) {
                bestX = x;
                bestZ = z;
                bestBase = highest;
                bestRange = highest - lowest;
            }
        }
    }
    if (bestX < 0) {
        return;
    }

    for (int offsetZ = 0; offsetZ < HutSize; offsetZ++) {
        for (int offsetX = 0; offsetX < HutSize; offsetX++) {
            int column = bestX + offsetX, row = bestZ + offsetZ;
            for (int y = worldHeights[column][row]; y < bestBase; y++) {
                worldVoxels[column][y][row] = VoxelDirt;
            }
            worldVoxels[column][bestBase][row] = VoxelPlanks;
            for (int y = bestBase + 1; y <= bestBase + HutHeight; y++) {
                worldVoxels[column][y][row] = VoxelAir;
            }
            bool edgeX = offsetX == 0 || offsetX == HutSize - 1;
            bool edgeZ = offsetZ == 0 || offsetZ == HutSize - 1;
            if (edgeX || edgeZ) {
                for (int y = bestBase + 1; y < bestBase + HutHeight; y++) {
                    worldVoxels[column][y][row] = edgeX && edgeZ ? VoxelTrunk : VoxelBrick;
                }
            }
            worldVoxels[column][bestBase + HutHeight][row] = VoxelPlanks;
            worldHeights[column][row] = (uint8_t)(bestBase + HutHeight);
        }
    }
    // Punch out a door and two windows, then stack a chimney on the roof.
    worldVoxels[bestX + HutSize / 2][bestBase + 1][bestZ] = VoxelAir;
    worldVoxels[bestX + HutSize / 2][bestBase + 2][bestZ] = VoxelAir;
    worldVoxels[bestX][bestBase + 2][bestZ + HutSize / 2] = VoxelAir;
    worldVoxels[bestX + HutSize - 1][bestBase + 2][bestZ + HutSize / 2] = VoxelAir;
    worldVoxels[bestX + 1][bestBase + HutHeight + 1][bestZ + 1] = VoxelGreystone;
    worldVoxels[bestX + 1][bestBase + HutHeight + 2][bestZ + 1] = VoxelGreystone;
    worldHeights[bestX + 1][bestZ + 1] = (uint8_t)(bestBase + HutHeight + 2);
}

static void world_plant_tree(int x, int z, int height) {
    int trunk = 4 + (int)(voxel_hash(0x11ee22ffu, x, 1, z) * 3.0f);
    for (int y = height + 1; y <= height + trunk; y++) {
        worldVoxels[x][y][z] = VoxelTrunk;
    }
    int crown = height + trunk;
    for (int offsetY = -2; offsetY <= 2; offsetY++) {
        for (int offsetZ = -2; offsetZ <= 2; offsetZ++) {
            for (int offsetX = -2; offsetX <= 2; offsetX++) {
                float distance = (float)(offsetX * offsetX + offsetZ * offsetZ) + (float)(offsetY * offsetY) * 1.6f;
                if (distance > 5.2f) {
                    continue;
                }
                int column = x + offsetX, row = z + offsetZ, y = crown + offsetY;
                if (column < 0 || row < 0 || column >= WorldSize || row >= WorldSize || y >= WorldSize) {
                    continue;
                }
                if (worldVoxels[column][y][row] == VoxelAir) {
                    worldVoxels[column][y][row] = VoxelLeaves;
                }
            }
        }
    }
}

static void world_grow_plants(void) {
    for (int z = 3; z < WorldSize - 3; z++) {
        for (int x = 3; x < WorldSize - 3; x++) {
            int height = worldHeights[x][z];
            uint8_t surface = worldVoxels[x][height][z];
            if (height <= worldSeaLevel + 1 || worldVoxels[x][height + 1][z] != VoxelAir) {
                continue;
            }
            if (surface == VoxelGrass && voxel_hash(0x4f2c81a3u, x, 0, z) > 0.980f) {
                world_plant_tree(x, z, height);
            } else if (surface == VoxelSand && voxel_hash(0x9ab30f57u, x, 0, z) > 0.950f) {
                int cactus = 2 + (int)(voxel_hash(0x6d4e2b19u, x, 0, z) * 3.0f);
                for (int y = height + 1; y <= height + cactus; y++) {
                    worldVoxels[x][y][z] = VoxelCactus;
                }
            }
        }
    }
}

static bool voxel_is_opaque(uint8_t type) {
    return type != VoxelAir && type != VoxelWater;
}

static uint8_t world_voxel(int x, int y, int z) {
    if ((unsigned)x >= (unsigned)WorldSize || (unsigned)y >= (unsigned)WorldSize ||
        (unsigned)z >= (unsigned)WorldSize) {
        return VoxelAir;
    }
    return worldVoxels[x][y][z];
}

// A face is drawn when the voxel next to it does not hide it. Water hides only
// itself, so the terrain stays visible through it.
static bool world_face_is_visible(uint8_t neighbor, uint8_t type) {
    return neighbor == VoxelAir || (neighbor == VoxelWater && type != VoxelWater);
}

// Bakes how enclosed a voxel is into a single shading factor.
static uint8_t world_ambient_occlusion(int x, int y, int z) {
    int blocked = 0;
    for (int offsetZ = -1; offsetZ <= 1; offsetZ++) {
        for (int offsetY = -1; offsetY <= 1; offsetY++) {
            for (int offsetX = -1; offsetX <= 1; offsetX++) {
                if ((offsetX != 0 || offsetY != 0 || offsetZ != 0) &&
                    voxel_is_opaque(world_voxel(x + offsetX, y + offsetY, z + offsetZ))) {
                    blocked++;
                }
            }
        }
    }
    return (uint8_t)(255.0f * (1.0f - 0.45f * (float)blocked / 26.0f));
}

// Appends every visible face; passing a null buffer only counts them.
static size_t world_emit_faces(VoxelInstance* instances, size_t count, bool translucent) {
    for (int z = 0; z < WorldSize; z++) {
        for (int y = 0; y < WorldSize; y++) {
            for (int x = 0; x < WorldSize; x++) {
                uint8_t type = worldVoxels[x][y][z];
                if (type == VoxelAir || (type == VoxelWater) != translucent) {
                    continue;
                }
                int occlusion = -1;
                for (int face = 0; face < 6; face++) {
                    uint8_t neighbor =
                        world_voxel(x + faceOffsets[face][0], y + faceOffsets[face][1], z + faceOffsets[face][2]);
                    if (!world_face_is_visible(neighbor, type)) {
                        continue;
                    }
                    if (instances != NULL) {
                        if (occlusion < 0) {
                            occlusion = world_ambient_occlusion(x, y, z);
                        }
                        instances[count] = (VoxelInstance){
                            .position = {(short)x, (short)y, (short)z, (short)occlusion},
                            .face = {(uint8_t)face, voxelFaces[type][faceMaterials[face]],
                                     translucent ? InstanceFlagTranslucent : 0, 0},
                        };
                    }
                    count++;
                }
            }
        }
    }
    return count;
}

// Generates the whole world and packs its visible faces into instances, with
// the opaque ones first and the translucent water surface behind them. The
// caller owns the returned buffer.
static WorldInstances world_build(void) {
    worldSeed = (uint32_t)clock_gettime_nsec_np(CLOCK_REALTIME);
    world_generate_heights();
    world_generate_terrain();
    world_build_hut();
    world_grow_plants();

    WorldInstances result = {NULL, 0, 0};
    size_t total = world_emit_faces(NULL, 0, false);
    total = world_emit_faces(NULL, total, true);
    result.instances = malloc(total * sizeof(VoxelInstance));
    if (result.instances == NULL) {
        return result;
    }
    result.opaqueCount = world_emit_faces(result.instances, 0, false);
    result.translucentCount = world_emit_faces(result.instances, result.opaqueCount, true) - result.opaqueCount;
    return result;
}
