/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include "ParagonUtils.h"
#include "CharacterDatabase.h"
#include "Log.h"
#include "SpellDefines.h"
#include <array>
#include <mutex>
#include <unordered_map>

constexpr uint32 STAT_COUNT = 17;

// Paragon stat indices. This order matches both the DB column order in
// CHAR_SEL_PARAGON_POINTS and the Lua STATS table.
enum ParagonStat : uint32
{
    PARAGON_STR = 0,
    PARAGON_INT,
    PARAGON_AGI,
    PARAGON_SPI,
    PARAGON_STA,
    PARAGON_HASTE,
    PARAGON_ARMORPEN,
    PARAGON_SPELLPOWER,
    PARAGON_CRIT,
    PARAGON_MOUNTSPEED,
    PARAGON_MANAREGEN,
    PARAGON_HIT,
    PARAGON_BLOCK,
    PARAGON_EXPERTISE,
    PARAGON_PARRY,
    PARAGON_DODGE,
    PARAGON_LIFELEECH
};

// Stat value granted per allocated point (unchanged balance). Life Leech is a
// percentage handled separately in ParagonLifeLeech::OnDamage.
static uint32 const kPerPoint[STAT_COUNT] =
{
    5, 5, 5, 5, 5,   // Str, Int, Agi, Spi, Sta
    5, 5, 10, 10,    // Haste, ArmorPen, SpellPower, Crit
    1, 5,            // MountSpeed, ManaRegen
    10, 4, 3, 10, 10,// Hit, Block, Expertise, Parry, Dodge
    1                // LifeLeech
};

// Module primary-stat index (0..4) -> core Stats enum. The module order is
// Str/Int/Agi/Spi/Sta, which differs from the engine's Stats enum order.
static Stats const kPrimaryStat[5] =
{
    STAT_STRENGTH, STAT_INTELLECT, STAT_AGILITY, STAT_SPIRIT, STAT_STAMINA
};

// Configuration values (loaded from mod_paragon.conf)
static bool     conf_Enable          = true;
static uint32   conf_AuraLevel       = 100000;
static uint32   conf_MountSpeedSpell = 100029;
static uint32   conf_PPL             = 5;
static uint32   conf_MaxLevel        = 666;
static uint32   conf_XPElite         = 1;
static uint32   conf_XPWorldBoss     = 20;
static uint32   conf_XPDungeonElite  = 1;
static uint32   conf_XPDungeonBoss   = 3;
static uint32   conf_XPHCDungeonElite = 2;
static uint32   conf_XPHCDungeonBoss  = 5;
static uint32   conf_XPRaidBoss       = 10;
static uint32   conf_XPQuest          = 3;
static bool     conf_XPPartyReduce    = false;
static float    conf_LifeLeechPct     = 0.1f; // % heal per point

// Per-stat max points (configurable, default 666). 0 = no limit.
static uint32 conf_MaxStats[STAT_COUNT] =
{
    666, 666, 666, 666, 666,
    666, 666, 666, 666,
    666, 666,
    666, 666, 666, 666, 666,
    666
};

// In-memory account-wide level/XP cache.
struct ParagonCache
{
    uint32 level;
    uint32 xp;
};

static std::unordered_map<uint32, ParagonCache> sParagonAcct;
// Exact per-character stat points we last applied (for diff-based reapply and
// for the Life Leech read in OnDamage). Keyed by player GUID.
static std::unordered_map<ObjectGuid, std::array<uint32, STAT_COUNT>>
    sParagonApplied;
static std::mutex sParagonMutex;

static void CacheSet(uint32 accountId, uint32 level, uint32 xp)
{
    std::lock_guard<std::mutex> lock(sParagonMutex);
    sParagonAcct[accountId] = { level, xp };
}

static bool CacheGet(uint32 accountId, ParagonCache& out)
{
    std::lock_guard<std::mutex> lock(sParagonMutex);
    auto it = sParagonAcct.find(accountId);
    if (it == sParagonAcct.end())
        return false;
    out = it->second;
    return true;
}

// Mount Speed is the only stat backed by an aura. It mirrors the legacy spell:
// effect 0 = MOD_INCREASE_SPEED (run), effect 1 = MOD_INCREASE_SWIM_SPEED.
// Applied once with the full value via custom base points (no stacking).
static void CastParagonMountSpeed(Player* player, uint32 points)
{
    int32 amount = static_cast<int32>(points * kPerPoint[PARAGON_MOUNTSPEED]);
    CustomSpellValues values;
    values.AddSpellMod(SPELLVALUE_BASE_POINT0, amount);
    values.AddSpellMod(SPELLVALUE_BASE_POINT1, amount);
    player->CastCustomSpell(conf_MountSpeedSpell, values, player,
        TRIGGERED_FULL_MASK);
}

// Apply or remove a single stat's full value via the cleanest core API.
// No aura stacking is involved, so the 255-stack ceiling never applies.
static void ApplyStat(Player* player, uint32 idx, uint32 points, bool apply)
{
    if (points == 0)
        return;

    int32 amount = static_cast<int32>(points * kPerPoint[idx]);

    switch (idx)
    {
        case PARAGON_STR:
        case PARAGON_INT:
        case PARAGON_AGI:
        case PARAGON_SPI:
        case PARAGON_STA:
        {
            Stats stat = kPrimaryStat[idx];
            player->HandleStatFlatModifier(
                UnitMods(UNIT_MOD_STAT_STRENGTH + stat), BASE_VALUE,
                static_cast<float>(amount), apply);
            player->UpdateStatBuffMod(stat);
            break;
        }
        case PARAGON_HASTE:
            player->ApplyRatingMod(CR_HASTE_MELEE, amount, apply);
            player->ApplyRatingMod(CR_HASTE_RANGED, amount, apply);
            player->ApplyRatingMod(CR_HASTE_SPELL, amount, apply);
            break;
        case PARAGON_ARMORPEN:
            player->ApplyRatingMod(CR_ARMOR_PENETRATION, amount, apply);
            break;
        case PARAGON_SPELLPOWER:
            player->ApplySpellPowerBonus(amount, apply);
            break;
        case PARAGON_CRIT:
            player->ApplyRatingMod(CR_CRIT_MELEE, amount, apply);
            player->ApplyRatingMod(CR_CRIT_RANGED, amount, apply);
            player->ApplyRatingMod(CR_CRIT_SPELL, amount, apply);
            break;
        case PARAGON_MOUNTSPEED:
            if (apply)
                CastParagonMountSpeed(player, points);
            else
                player->RemoveAura(conf_MountSpeedSpell);
            break;
        case PARAGON_MANAREGEN:
            player->ApplyManaRegenBonus(amount, apply);
            break;
        case PARAGON_HIT:
            player->ApplyRatingMod(CR_HIT_MELEE, amount, apply);
            player->ApplyRatingMod(CR_HIT_RANGED, amount, apply);
            player->ApplyRatingMod(CR_HIT_SPELL, amount, apply);
            break;
        case PARAGON_BLOCK:
            player->ApplyRatingMod(CR_BLOCK, amount, apply);
            break;
        case PARAGON_EXPERTISE:
            player->ApplyRatingMod(CR_EXPERTISE, amount, apply);
            break;
        case PARAGON_PARRY:
            player->ApplyRatingMod(CR_PARRY, amount, apply);
            break;
        case PARAGON_DODGE:
            player->ApplyRatingMod(CR_DODGE, amount, apply);
            break;
        case PARAGON_LIFELEECH:
            // No stat to apply: the value is read from the snapshot in
            // ParagonLifeLeech::OnDamage.
            break;
        default:
            break;
    }
}

// Bring the player's applied stats in line with the desired allocation by
// applying only the delta against the last-applied snapshot. Idempotent.
void ReapplyParagonStats(Player* player, uint32 const desired[STAT_COUNT])
{
    ObjectGuid guid = player->GetGUID();

    std::array<uint32, STAT_COUNT> clamped{};
    for (uint32 i = 0; i < STAT_COUNT; ++i)
    {
        uint32 v = desired[i];
        if (conf_MaxStats[i] > 0 && v > conf_MaxStats[i])
            v = conf_MaxStats[i];
        clamped[i] = v;
    }

    std::array<uint32, STAT_COUNT> prev{};
    {
        std::lock_guard<std::mutex> lock(sParagonMutex);
        auto it = sParagonApplied.find(guid);
        if (it != sParagonApplied.end())
            prev = it->second;
    }

    for (uint32 i = 0; i < STAT_COUNT; ++i)
    {
        if (clamped[i] == prev[i])
            continue;
        if (prev[i] > 0)
            ApplyStat(player, i, prev[i], false);
        if (clamped[i] > 0)
            ApplyStat(player, i, clamped[i], true);
    }

    std::lock_guard<std::mutex> lock(sParagonMutex);
    sParagonApplied[guid] = clamped;
}

// Remove any legacy stacking auras from the previous design (saved rows in
// character_aura, or auras re-added by a stale pre-redesign Lua deployment).
// The gap 100006-100015 is load-bearing: those IDs are unrelated FL spells
// (Bestial speed, Lunar Blessing, tablet purifications) and must survive.
static void RemoveLegacyParagonAuras(Player* player)
{
    for (uint32 id = 100001; id <= 100005; ++id)
        player->RemoveAura(id);
    for (uint32 id = 100016; id <= 100027; ++id)
        player->RemoveAura(id);
    for (uint32 id = 100201; id <= 100227; ++id)
        player->RemoveAura(id);
}

// Read the per-character allocation from the DB and reapply it.
void ApplyParagonStatEffects(Player* player)
{
    // Purge legacy auras on every reconcile so a stale aura-stacking Lua (or
    // an old character_aura row) can never double-count a stat mid-session.
    RemoveLegacyParagonAuras(player);

    CharacterDatabasePreparedStatement* stmt =
        CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_POINTS);
    stmt->SetData(0, player->GetGUID().GetCounter());
    PreparedQueryResult qr = CharacterDatabase.Query(stmt);
    if (!qr)
        return;

    uint32 statValues[STAT_COUNT];
    uint32 totalAllocated = 0;
    for (uint32 i = 0; i < STAT_COUNT; ++i)
    {
        statValues[i] = (*qr)[i].Get<uint32>();
        totalAllocated += statValues[i];
    }

    uint32 unspentPoints = (*qr)[STAT_COUNT].Get<uint32>();
    uint32 characterID = player->GetGUID().GetCounter();

    // Paragon level is account-wide; read it from cache/DB (never from an aura
    // stack, which is uint8 and caps at 255).
    uint32 accountID = player->GetSession()->GetAccountId();
    uint32 paragonLevel = 0;
    ParagonCache cached;
    if (CacheGet(accountID, cached))
    {
        paragonLevel = cached.level;
    }
    else
    {
        CharacterDatabasePreparedStatement* lvlStmt =
            CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_LEVEL);
        lvlStmt->SetData(0, accountID);
        PreparedQueryResult lvlQr = CharacterDatabase.Query(lvlStmt);
        if (lvlQr)
            paragonLevel = (*lvlQr)[0].Get<uint32>();
    }

    // Defensive: only re-derive unspent_points on mismatch; never wipe the
    // player's stat allocation.
    if ((totalAllocated + unspentPoints) != paragonLevel * conf_PPL)
    {
        uint32 totalPoints = paragonLevel * conf_PPL;
        int64 expectedUnspent =
            static_cast<int64>(totalPoints) -
            static_cast<int64>(totalAllocated);
        if (expectedUnspent < 0)
            expectedUnspent = 0;

        if (static_cast<uint32>(expectedUnspent) != unspentPoints)
        {
            LOG_WARN("module.paragon",
                "ApplyParagonStatEffects: integrity mismatch for "
                "player {} (GUID {}, level={}, total_alloc={}, "
                "unspent={}, expected_unspent={}). Soft-recover "
                "unspent without resetting stats.",
                player->GetName(),
                player->GetGUID().ToString(),
                paragonLevel, totalAllocated, unspentPoints,
                static_cast<uint32>(expectedUnspent));

            CharacterDatabasePreparedStatement* setStmt =
                CharacterDatabase.GetPreparedStatement(
                    CHAR_UPD_PARAGON_UNSPENT_SET);
            setStmt->SetData(0, static_cast<uint32>(expectedUnspent));
            setStmt->SetData(1, characterID);
            CharacterDatabase.Execute(setStmt);
        }
    }

    ReapplyParagonStats(player, statValues);
}

// Remove every applied paragon stat (used by the NPC reset). Applies zero
// directly, so it does not depend on the async reset DB write being visible.
void ClearParagonStats(Player* player)
{
    uint32 zeros[STAT_COUNT] = {};
    ReapplyParagonStats(player, zeros);
}

// The mount-speed bonus is the only stat backed by an aura. Re-assert it if a
// game event stripped it; uses the snapshot, so no DB query is needed.
static void EnsureParagonAuras(Player* player)
{
    uint32 points = 0;
    {
        std::lock_guard<std::mutex> lock(sParagonMutex);
        auto it = sParagonApplied.find(player->GetGUID());
        if (it != sParagonApplied.end())
            points = it->second[PARAGON_MOUNTSPEED];
    }

    if (points > 0 && !player->HasAura(conf_MountSpeedSpell))
        CastParagonMountSpeed(player, points);
}

// True paragon level (up to conf_MaxLevel), readable by other modules instead
// of GetAuraCount(100000), which caps at 255.
uint32 GetParagonLevel(Player* player)
{
    if (!player)
        return 0;

    uint32 accountID = player->GetSession()->GetAccountId();
    ParagonCache cached;
    if (CacheGet(accountID, cached))
        return cached.level;

    CharacterDatabasePreparedStatement* stmt =
        CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_LEVEL);
    stmt->SetData(0, accountID);
    if (PreparedQueryResult qr = CharacterDatabase.Query(stmt))
        return (*qr)[0].Get<uint32>();
    return 0;
}

class ParagonPlayer : public PlayerScript
{
public:
    ParagonPlayer() : PlayerScript("ParagonPlayer") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!conf_Enable)
            return;

        uint32 accountID = player->GetSession()->GetAccountId();
        uint32 characterID = player->GetGUID().GetCounter();

        CharacterDatabasePreparedStatement* stmt =
            CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_LEVEL_XP);
        stmt->SetData(0, accountID);
        PreparedQueryResult qr = CharacterDatabase.Query(stmt);

        if (qr)
        {
            uint32 paragonLevel = (*qr)[0].Get<uint32>();
            uint32 paragonXP = (*qr)[1].Get<uint32>();
            CacheSet(accountID, paragonLevel, paragonXP);

            player->AddAura(conf_AuraLevel, player);
            player->SetAuraStack(conf_AuraLevel, player,
                std::min(paragonLevel, static_cast<uint32>(255)));

            CharacterDatabasePreparedStatement* ptsStmt =
                CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_POINTS);
            ptsStmt->SetData(0, characterID);
            PreparedQueryResult ptsQr = CharacterDatabase.Query(ptsStmt);
            if (!ptsQr)
            {
                CharacterDatabasePreparedStatement* insStmt =
                    CharacterDatabase.GetPreparedStatement(
                        CHAR_INS_PARAGON_POINTS);
                insStmt->SetData(0, characterID);
                CharacterDatabase.Execute(insStmt);
            }
            ApplyParagonStatEffects(player);
        }
        else
        {
            CharacterDatabasePreparedStatement* insParagon =
                CharacterDatabase.GetPreparedStatement(CHAR_INS_PARAGON);
            insParagon->SetData(0, accountID);
            CharacterDatabase.Execute(insParagon);
            CharacterDatabasePreparedStatement* insPoints =
                CharacterDatabase.GetPreparedStatement(CHAR_INS_PARAGON_POINTS);
            insPoints->SetData(0, characterID);
            CharacterDatabase.Execute(insPoints);
            // Cache must mirror the INSERT above (level 1, xp 100); caching
            // 0/0 made the first level-up write DB level 2 while the cache
            // said 1 until the next relog.
            CacheSet(accountID, 1, 100);
            player->AddAura(conf_AuraLevel, player);
            player->SetAuraStack(conf_AuraLevel, player, 1);
            // If a points row already exists (account row lost/mismatched),
            // still apply its stats; on a truly fresh row this is a no-op.
            ApplyParagonStatEffects(player);
        }
    }

    void OnPlayerMapChanged(Player* player) override
    {
        if (!conf_Enable)
            return;

        // Direct stat modifiers persist across map changes (the Player object
        // is not recreated), but reconcile against the DB anyway: it is a
        // cheap PK lookup, the diff-based reapply makes it a no-op when
        // nothing drifted, and it self-heals any snapshot-vs-DB divergence
        // (e.g. an allocation that never reached C++). The mount-speed aura
        // may additionally need re-asserting when points did not change.
        ApplyParagonStatEffects(player);
        EnsureParagonAuras(player);
    }

    void OnPlayerResurrect(Player* player, float /*restorePercent*/,
                           bool& /*applySickness*/) override
    {
        if (!conf_Enable)
            return;

        ApplyParagonStatEffects(player);
        EnsureParagonAuras(player);
    }

    void OnPlayerLevelChanged(Player* player,
                              uint8 /*oldlevel*/) override
    {
        if (!conf_Enable)
            return;

        if (player->GetLevel() == 80
            && !player->HasAura(conf_AuraLevel))
        {
            uint32 characterID = player->GetGUID().GetCounter();
            uint32 accountID = player->GetSession()->GetAccountId();

            CharacterDatabasePreparedStatement* stmt =
                CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_LEVEL);
            stmt->SetData(0, accountID);
            PreparedQueryResult qr = CharacterDatabase.Query(stmt);
            if (!qr)
            {
                CharacterDatabasePreparedStatement* insParagon =
                    CharacterDatabase.GetPreparedStatement(CHAR_INS_PARAGON);
                insParagon->SetData(0, accountID);
                CharacterDatabase.Execute(insParagon);
                CharacterDatabasePreparedStatement* insPoints =
                    CharacterDatabase.GetPreparedStatement(
                        CHAR_INS_PARAGON_POINTS);
                insPoints->SetData(0, characterID);
                CharacterDatabase.Execute(insPoints);
                // Mirror the INSERT (level 1, xp 100) and grant the marker
                // right away so XP gain works without a relog.
                CacheSet(accountID, 1, 100);
                player->AddAura(conf_AuraLevel, player);
                player->SetAuraStack(conf_AuraLevel, player, 1);
            }
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!conf_Enable)
            return;

        uint32 accountID = player->GetSession()->GetAccountId();
        std::lock_guard<std::mutex> lock(sParagonMutex);
        sParagonAcct.erase(accountID);
        sParagonApplied.erase(player->GetGUID());
    }

    void OnPlayerCompleteQuest(Player* player,
                               Quest const* quest) override
    {
        if (!conf_Enable)
            return;

        if (quest->IsDailyOrWeekly() && quest->GetQuestLevel() == 80)
            IncreaseParagonXP(player, conf_XPQuest);
    }

    void OnPlayerCreatureKill(Player* killer,
                              Creature* killed) override
    {
        if (conf_Enable)
            CalculateXPGain(killer, killed);
    }

    void OnPlayerCreatureKilledByPet(Player* killer,
                                     Creature* killed) override
    {
        if (conf_Enable)
            CalculateXPGain(killer, killed);
    }

    void CalculateXPGain(Player* killer, Creature* killed)
    {
        if (!killer->HasAura(conf_AuraLevel))
            return;

        if (killed->GetLevel() < killer->GetLevel() || killed->IsPet())
            return;

        uint32 xpAmount = 0;
        bool isElite = killed->isElite();
        bool isDungeon = killed->GetMap()->IsNonRaidDungeon();
        bool isRaid = killed->GetMap()->IsRaid();
        bool isWorldBoss = killed->isWorldBoss();
        bool isHeroic = killed->GetMap()->IsHeroic();
        bool isDungeonBoss = killed->IsDungeonBoss();

        if (isElite && isRaid && isWorldBoss)
            xpAmount = conf_XPRaidBoss;
        else if (isElite && !isDungeon && !isRaid && isWorldBoss)
            xpAmount = conf_XPWorldBoss;
        else if (isElite && isDungeon && isHeroic && isDungeonBoss)
            xpAmount = conf_XPHCDungeonBoss;
        else if (isElite && isDungeon && isHeroic && !isDungeonBoss)
            xpAmount = conf_XPHCDungeonElite;
        else if (isElite && isDungeon && !isHeroic && isDungeonBoss)
            xpAmount = conf_XPDungeonBoss;
        else if (isElite && isDungeon && !isHeroic && !isDungeonBoss)
            xpAmount = conf_XPDungeonElite;
        else if (isElite && !isDungeon && !isRaid && !isWorldBoss)
            xpAmount = conf_XPElite;

        if (xpAmount == 0)
            return;

        if (Group* group = killer->GetGroup())
        {
            Group::MemberSlotList const& members =
                group->GetMemberSlots();
            for (auto const& slot : members)
            {
                Player* p = ObjectAccessor::GetPlayer(
                    killer->GetMap(), slot.guid);
                if (p)
                    IncreaseParagonXP(p, xpAmount);
            }
        }
        else
            IncreaseParagonXP(killer, xpAmount);
    }
};

void IncreaseParagonXP(Player* player, uint32 value)
{
    if (!player->HasAura(conf_AuraLevel))
        return;

    uint32 accountID = player->GetSession()->GetAccountId();

    // Try cache first, fall back to DB
    ParagonCache cached;
    uint32 paragonLevel, paragonXP;
    if (CacheGet(accountID, cached))
    {
        paragonLevel = cached.level;
        paragonXP = cached.xp;
    }
    else
    {
        CharacterDatabasePreparedStatement* stmt =
            CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARAGON_LEVEL_XP);
        stmt->SetData(0, accountID);
        PreparedQueryResult qr = CharacterDatabase.Query(stmt);
        if (!qr)
            return;
        paragonLevel = (*qr)[0].Get<uint32>();
        paragonXP = (*qr)[1].Get<uint32>();
        CacheSet(accountID, paragonLevel, paragonXP);
    }

    // Max level cap check
    if (conf_MaxLevel > 0 && paragonLevel >= conf_MaxLevel)
        return;

    int32 diff = static_cast<int32>(paragonXP) - static_cast<int32>(value);

    if (diff <= 0) // level up
    {
        // Max level cap: don't level past the limit
        if (conf_MaxLevel > 0 && (paragonLevel + 1) > conf_MaxLevel)
            return;

        uint32 xpLeft = value - paragonXP;
        double xpRequired = 100.0 * pow(1.1, paragonLevel);
        if (xpRequired > 2000000000.0)
            xpRequired = 2000000000.0;
        int64 newXP =
            static_cast<int64>(xpRequired) - static_cast<int64>(xpLeft);
        if (newXP < 0)
            newXP = static_cast<int64>(xpRequired);

        uint32 newLevel = paragonLevel + 1;

        CharacterDatabasePreparedStatement* updStmt =
            CharacterDatabase.GetPreparedStatement(CHAR_UPD_PARAGON_LEVELUP);
        updStmt->SetData(0, static_cast<uint32>(newXP));
        updStmt->SetData(1, accountID);
        CharacterDatabase.Execute(updStmt);

        CacheSet(accountID, newLevel, static_cast<uint32>(newXP));

        player->SetAuraStack(conf_AuraLevel, player,
            std::min(newLevel, static_cast<uint32>(255)));

        std::ostringstream ss;
        ss << "Congratulations " << player->GetName()
           << "! You increased your Paragon level to "
           << newLevel << ".";
        ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());

        uint32 characterID = player->GetGUID().GetCounter();
        CharacterDatabasePreparedStatement* ptsStmt =
            CharacterDatabase.GetPreparedStatement(
                CHAR_UPD_PARAGON_UNSPENT_ADD);
        ptsStmt->SetData(0, conf_PPL);
        ptsStmt->SetData(1, characterID);
        CharacterDatabase.Execute(ptsStmt);
    }
    else
    {
        uint32 newXP = paragonXP - value;

        CharacterDatabasePreparedStatement* updStmt =
            CharacterDatabase.GetPreparedStatement(CHAR_UPD_PARAGON_XP);
        updStmt->SetData(0, value);
        updStmt->SetData(1, accountID);
        CharacterDatabase.Execute(updStmt);

        CacheSet(accountID, paragonLevel, newXP);

        if (value > 0 && (newXP % 100 == 0 || value >= 10))
        {
            std::ostringstream ss;
            ss << "Increasing Paragon XP by " << value << ". "
               << newXP << " needed to level up.";
            ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
        }
    }
}

class ParagonConfig : public WorldScript
{
public:
    ParagonConfig() : WorldScript("ParagonConfig") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        conf_Enable = sConfigMgr->GetOption<bool>(
            "Paragon.Enable", true);
        conf_AuraLevel = sConfigMgr->GetOption<uint32>(
            "Paragon.IdLevel", 100000);
        conf_MountSpeedSpell = sConfigMgr->GetOption<uint32>(
            "Paragon.MountSpeedSpellId", 100029);
        conf_PPL = sConfigMgr->GetOption<uint32>(
            "Paragon.PPL", 5);
        conf_MaxLevel = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxLevel", 666);
        conf_XPElite = sConfigMgr->GetOption<uint32>(
            "Paragon.XPElite", 1);
        conf_XPWorldBoss = sConfigMgr->GetOption<uint32>(
            "Paragon.XPWorldBoss", 20);
        conf_XPDungeonElite = sConfigMgr->GetOption<uint32>(
            "Paragon.XPDungeonElite", 1);
        conf_XPDungeonBoss = sConfigMgr->GetOption<uint32>(
            "Paragon.XPDungeonBoss", 3);
        conf_XPHCDungeonElite = sConfigMgr->GetOption<uint32>(
            "Paragon.XPHCDungeonElite", 2);
        conf_XPHCDungeonBoss = sConfigMgr->GetOption<uint32>(
            "Paragon.XPHCDungeonBoss", 5);
        conf_XPRaidBoss = sConfigMgr->GetOption<uint32>(
            "Paragon.XPRaidBoss", 10);
        conf_XPQuest = sConfigMgr->GetOption<uint32>(
            "Paragon.XPQuest", 3);
        conf_XPPartyReduce = sConfigMgr->GetOption<bool>(
            "Paragon.XPPartyReduce", false);
        conf_LifeLeechPct = sConfigMgr->GetOption<float>(
            "Paragon.LifeLeechPct", 0.1f);

        conf_MaxStats[PARAGON_STR] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxStr", 666);
        conf_MaxStats[PARAGON_INT] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxInt", 666);
        conf_MaxStats[PARAGON_AGI] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxAgi", 666);
        conf_MaxStats[PARAGON_SPI] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxSpi", 666);
        conf_MaxStats[PARAGON_STA] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxSta", 666);
        conf_MaxStats[PARAGON_HASTE] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxHaste", 666);
        conf_MaxStats[PARAGON_ARMORPEN] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxArmorPen", 666);
        conf_MaxStats[PARAGON_SPELLPOWER] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxSpellPower", 666);
        conf_MaxStats[PARAGON_CRIT] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxCrit", 666);
        conf_MaxStats[PARAGON_MOUNTSPEED] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxMountSpeed", 666);
        conf_MaxStats[PARAGON_MANAREGEN] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxManaRegen", 666);
        conf_MaxStats[PARAGON_HIT] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxHit", 666);
        conf_MaxStats[PARAGON_BLOCK] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxBlock", 666);
        conf_MaxStats[PARAGON_EXPERTISE] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxExpertise", 666);
        conf_MaxStats[PARAGON_PARRY] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxParry", 666);
        conf_MaxStats[PARAGON_DODGE] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxDodge", 666);
        conf_MaxStats[PARAGON_LIFELEECH] = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxLifeLeech", 666);
    }
};

class ParagonLifeLeech : public UnitScript
{
public:
    ParagonLifeLeech() : UnitScript(
        "ParagonLifeLeech", true,
        { UNITHOOK_ON_DAMAGE }) { }

    void OnDamage(Unit* attacker, Unit* victim,
                  uint32& damage) override
    {
        if (!conf_Enable || !attacker || !victim || damage == 0)
            return;

        // Resolve to the player owner so pet/totem/mind-control damage also
        // triggers leech (Demonology Warlock, Frost Mage, BM Hunter, Shaman
        // totems, etc.).
        Player* player =
            attacker->GetCharmerOrOwnerPlayerOrPlayerItself();
        if (!player)
            return;

        // Skip self/friendly-controlled damage (fall, environmental, own
        // spell splash) — never heal off your own HP loss.
        if (victim == player ||
            victim->GetCharmerOrOwnerPlayerOrPlayerItself() == player)
            return;

        uint32 leechPoints = 0;
        {
            std::lock_guard<std::mutex> lock(sParagonMutex);
            auto it = sParagonApplied.find(player->GetGUID());
            if (it != sParagonApplied.end())
                leechPoints = it->second[PARAGON_LIFELEECH];
        }

        if (leechPoints == 0)
            return;

        float healPct = leechPoints * conf_LifeLeechPct;
        uint32 healAmount =
            static_cast<uint32>(damage * healPct / 100.0f);
        if (healAmount == 0)
            return;

        Unit::DealHeal(player, player, healAmount);
    }
};

void AddParagonPlayerScripts()
{
    new ParagonPlayer();
    new ParagonConfig();
    new ParagonLifeLeech();
}
