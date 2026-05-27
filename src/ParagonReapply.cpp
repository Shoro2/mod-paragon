/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 */

#include "ScriptMgr.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "Player.h"
#include "ParagonUtils.h"

// Hidden trigger spell cast by the Lua/AIO layer after it writes a point
// allocation to the DB. It re-derives and applies the player's stats in C++,
// keeping C++ the single source of truth for stat application (the Lua side no
// longer applies any auras itself).
class spell_paragon_reapply : public SpellScript
{
    PrepareSpellScript(spell_paragon_reapply);

    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        if (Player* player = GetCaster()->ToPlayer())
            ApplyParagonStatEffects(player);
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(
            spell_paragon_reapply::HandleDummy, EFFECT_0,
            SPELL_EFFECT_DUMMY);
    }
};

void AddParagonReapplyScripts()
{
    RegisterSpellScript(spell_paragon_reapply);
}
