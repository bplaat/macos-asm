#pragma once

#include <stddef.h>

typedef enum MaterialLayer {
    MaterialLayerBrickRed,
    MaterialLayerCactusSide,
    MaterialLayerCactusTop,
    MaterialLayerDirt,
    MaterialLayerDirtGrass,
    MaterialLayerGrassTop,
    MaterialLayerGreystone,
    MaterialLayerLava,
    MaterialLayerLeaves,
    MaterialLayerSand,
    MaterialLayerStone,
    MaterialLayerStoneCoal,
    MaterialLayerStoneDiamond,
    MaterialLayerStoneGold,
    MaterialLayerStoneIron,
    MaterialLayerTrunkSide,
    MaterialLayerTrunkTop,
    MaterialLayerWater,
    MaterialLayerWood,
    MaterialLayerCount,
} MaterialLayer;

static const unsigned char brickRedTexture[] = {
#embed "brick_red.png"
};
static const unsigned char cactusSideTexture[] = {
#embed "cactus_side.png"
};
static const unsigned char cactusTopTexture[] = {
#embed "cactus_top.png"
};
static const unsigned char dirtTexture[] = {
#embed "dirt.png"
};
static const unsigned char dirtGrassTexture[] = {
#embed "dirt_grass.png"
};
static const unsigned char grassTopTexture[] = {
#embed "grass_top.png"
};
static const unsigned char greystoneTexture[] = {
#embed "greystone.png"
};
static const unsigned char lavaTexture[] = {
#embed "lava.png"
};
static const unsigned char leavesTexture[] = {
#embed "leaves.png"
};
static const unsigned char sandTexture[] = {
#embed "sand.png"
};
static const unsigned char stoneTexture[] = {
#embed "stone.png"
};
static const unsigned char stoneCoalTexture[] = {
#embed "stone_coal.png"
};
static const unsigned char stoneDiamondTexture[] = {
#embed "stone_diamond.png"
};
static const unsigned char stoneGoldTexture[] = {
#embed "stone_gold.png"
};
static const unsigned char stoneIronTexture[] = {
#embed "stone_iron.png"
};
static const unsigned char trunkSideTexture[] = {
#embed "trunk_side.png"
};
static const unsigned char trunkTopTexture[] = {
#embed "trunk_top.png"
};
static const unsigned char waterTexture[] = {
#embed "water.png"
};
static const unsigned char woodTexture[] = {
#embed "wood.png"
};

static const struct {
    const unsigned char* bytes;
    size_t length;
} materialTextures[MaterialLayerCount] = {
    [MaterialLayerBrickRed] = {brickRedTexture, sizeof(brickRedTexture)},
    [MaterialLayerCactusSide] = {cactusSideTexture, sizeof(cactusSideTexture)},
    [MaterialLayerCactusTop] = {cactusTopTexture, sizeof(cactusTopTexture)},
    [MaterialLayerDirt] = {dirtTexture, sizeof(dirtTexture)},
    [MaterialLayerDirtGrass] = {dirtGrassTexture, sizeof(dirtGrassTexture)},
    [MaterialLayerGrassTop] = {grassTopTexture, sizeof(grassTopTexture)},
    [MaterialLayerGreystone] = {greystoneTexture, sizeof(greystoneTexture)},
    [MaterialLayerLava] = {lavaTexture, sizeof(lavaTexture)},
    [MaterialLayerLeaves] = {leavesTexture, sizeof(leavesTexture)},
    [MaterialLayerSand] = {sandTexture, sizeof(sandTexture)},
    [MaterialLayerStone] = {stoneTexture, sizeof(stoneTexture)},
    [MaterialLayerStoneCoal] = {stoneCoalTexture, sizeof(stoneCoalTexture)},
    [MaterialLayerStoneDiamond] = {stoneDiamondTexture, sizeof(stoneDiamondTexture)},
    [MaterialLayerStoneGold] = {stoneGoldTexture, sizeof(stoneGoldTexture)},
    [MaterialLayerStoneIron] = {stoneIronTexture, sizeof(stoneIronTexture)},
    [MaterialLayerTrunkSide] = {trunkSideTexture, sizeof(trunkSideTexture)},
    [MaterialLayerTrunkTop] = {trunkTopTexture, sizeof(trunkTopTexture)},
    [MaterialLayerWater] = {waterTexture, sizeof(waterTexture)},
    [MaterialLayerWood] = {woodTexture, sizeof(woodTexture)},
};
