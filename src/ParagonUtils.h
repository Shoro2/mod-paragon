#ifndef PARAGON_UTILS_H
#define PARAGON_UTILS_H

#include "Player.h"
#include "lua.h"

void IncreaseParagonXP(Player* player, uint32 value);
void ApplyParagonStatEffects(Player* player);

void RegisterParagonEluna(lua_State* L);

#endif // PARAGON_UTILS_H
