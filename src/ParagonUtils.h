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

// Raises the player's account to at least `level` (capped at Paragon.MaxLevel):
// the level, the XP towards the next one, this character's unspent points for
// the new levels, the level aura and the applied stats. Never lowers a level;
// false when nothing changed (already there, or the account has no Paragon row
// yet - a character below 80). For mod-ptr-template's Paragon floor.
bool SetParagonLevelAtLeast(Player* player, uint32 level);

#endif // PARAGON_UTILS_H
