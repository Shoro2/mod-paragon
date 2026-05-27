#ifndef PARAGON_UTILS_H
#define PARAGON_UTILS_H

#include "Player.h"

void IncreaseParagonXP(Player* player, uint32 value);
void ApplyParagonStatEffects(Player* player);
void ReapplyParagonStats(Player* player, uint32 const* desired);
void ClearParagonStats(Player* player);

// True paragon level (up to the configured max). Other modules should use this
// instead of GetAuraCount(100000), whose uint8 stack caps at 255.
uint32 GetParagonLevel(Player* player);

#endif // PARAGON_UTILS_H
