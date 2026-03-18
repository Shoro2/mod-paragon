/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include "ParagonUtils.h"
#include "CharacterDatabase.h"
#include <mutex>
#include <unordered_map>

constexpr uint32 STAT_COUNT = 17;
constexpr uint32 PARAGON_POINT_ITEM = 920920;

// Configuration values (loaded from mod_paragon.conf)
static bool     conf_Enable       = true;
static uint32   conf_AuraLevel    = 100000;
static uint32   conf_PPL          = 5;
static uint32   conf_MaxLevel     = 0; // 0 = no limit
static uint32   conf_XPElite      = 1;
static uint32   conf_XPWorldBoss  = 20;
static uint32   conf_XPDungeonElite   = 1;
static uint32   conf_XPDungeonBoss    = 3;
static uint32   conf_XPHCDungeonElite = 2;
static uint32   conf_XPHCDungeonBoss  = 5;
static uint32   conf_XPRaidBoss       = 10;
static uint32   conf_XPQuest          = 3;
static bool     conf_XPPartyReduce    = false;
static float    conf_LifeLeechPct     = 0.5f; // % heal per stack

// Stat aura IDs (configurable, defaults match Lua system)
static uint32 conf_AuraIds[STAT_COUNT] = {
    100001, // Strength (unified with Lua)
    100002, // Intellect
    100003, // Agility
    100004, // Spirit
    100005, // Stamina
    100016, // Haste
    100017, // Armor Pen
    100018, // Spell Power
    100019, // Crit
    100020, // Mount Speed
    100021, // Mana Regen
    100022, // Hit
    100023, // Block
    100024, // Expertise
    100025, // Parry
    100026, // Dodge
    100027, // Life Leech
};

// In-memory cache for paragon level/XP per account
struct ParagonCache
{
    uint32 level;
    uint32 xp;
};

static std::unordered_map<uint32, ParagonCache> sParagonCache;
static std::mutex sParagonCacheMutex;

static void CacheSet(uint32 accountId, uint32 level, uint32 xp)
{
    std::lock_guard<std::mutex> lock(sParagonCacheMutex);
    sParagonCache[accountId] = { level, xp };
}

static bool CacheGet(uint32 accountId, ParagonCache& out)
{
    std::lock_guard<std::mutex> lock(sParagonCacheMutex);
    auto it = sParagonCache.find(accountId);
    if (it == sParagonCache.end())
        return false;
    out = it->second;
    return true;
}

static void CacheRemove(uint32 accountId)
{
    std::lock_guard<std::mutex> lock(sParagonCacheMutex);
    sParagonCache.erase(accountId);
}

void RefreshParagonAura(Player* player, uint32 const statValues[STAT_COUNT])
{
    for (uint32 i = 0; i < STAT_COUNT; ++i)
        player->RemoveAura(conf_AuraIds[i]);

    for (uint32 i = 0; i < STAT_COUNT; ++i)
    {
        if (statValues[i] > 0)
        {
            player->AddAura(conf_AuraIds[i], player);
            if (Aura* aura = player->GetAura(conf_AuraIds[i]))
                aura->SetStackAmount(statValues[i]);
        }
    }
}

void ApplyParagonStatEffects(Player* player)
{
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

    uint32 unspentPoints = player->GetItemCount(PARAGON_POINT_ITEM);
    uint32 characterID = player->GetGUID().GetCounter();
    uint8 paragonLevel = player->GetAuraCount(conf_AuraLevel);

    if ((totalAllocated + unspentPoints) != paragonLevel * conf_PPL)
    {
        CharacterDatabasePreparedStatement* resetStmt =
            CharacterDatabase.GetPreparedStatement(
                CHAR_UPD_PARAGON_POINTS_RESET);
        resetStmt->SetData(0, characterID);
        CharacterDatabase.Execute(resetStmt);
        ChatHandler(player->GetSession()).SendSysMessage(
            "There was an error loading your Paragon points, "
            "please reallocate them!");
        player->DestroyItemCount(
            PARAGON_POINT_ITEM,
            player->GetItemCount(PARAGON_POINT_ITEM), true);
        player->AddItem(PARAGON_POINT_ITEM, paragonLevel * conf_PPL);

        uint32 zeroStats[STAT_COUNT] = {};
        RefreshParagonAura(player, zeroStats);
        return;
    }

    RefreshParagonAura(player, statValues);
}

// Restore paragon aura from cache (no DB query)
static void RestoreFromCache(Player* player, uint32 accountID)
{
    ParagonCache cached;
    if (CacheGet(accountID, cached) && cached.level > 0)
    {
        player->AddAura(conf_AuraLevel, player);
        player->SetAuraStack(conf_AuraLevel, player, cached.level);
        ApplyParagonStatEffects(player);
    }
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
            CharacterDatabase.GetPreparedStatement(
                CHAR_SEL_PARAGON_LEVEL_XP);
        stmt->SetData(0, accountID);
        PreparedQueryResult qr = CharacterDatabase.Query(stmt);

        if (qr)
        {
            uint32 paragonLevel = (*qr)[0].Get<uint32>();
            uint32 paragonXP = (*qr)[1].Get<uint32>();
            CacheSet(accountID, paragonLevel, paragonXP);

            player->AddAura(conf_AuraLevel, player);
            player->SetAuraStack(conf_AuraLevel, player, paragonLevel);

            CharacterDatabasePreparedStatement* ptsStmt =
                CharacterDatabase.GetPreparedStatement(
                    CHAR_SEL_PARAGON_POINTS);
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
                CharacterDatabase.GetPreparedStatement(
                    CHAR_INS_PARAGON_POINTS);
            insPoints->SetData(0, characterID);
            CharacterDatabase.Execute(insPoints);
            CacheSet(accountID, 0, 0);
        }
    }

    void OnPlayerMapChanged(Player* player) override
    {
        if (!conf_Enable)
            return;

        uint32 accountID = player->GetSession()->GetAccountId();

        if (!player->HasAura(conf_AuraLevel))
            RestoreFromCache(player, accountID);
        else
            ApplyParagonStatEffects(player);
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
                CharacterDatabase.GetPreparedStatement(
                    CHAR_SEL_PARAGON_LEVEL);
            stmt->SetData(0, accountID);
            PreparedQueryResult qr = CharacterDatabase.Query(stmt);
            if (!qr)
            {
                CharacterDatabasePreparedStatement* insParagon =
                    CharacterDatabase.GetPreparedStatement(
                        CHAR_INS_PARAGON);
                insParagon->SetData(0, accountID);
                CharacterDatabase.Execute(insParagon);
                CharacterDatabasePreparedStatement* insPoints =
                    CharacterDatabase.GetPreparedStatement(
                        CHAR_INS_PARAGON_POINTS);
                insPoints->SetData(0, characterID);
                CharacterDatabase.Execute(insPoints);
                CacheSet(accountID, 0, 0);
            }
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!conf_Enable)
            return;

        uint32 accountID = player->GetSession()->GetAccountId();
        CacheRemove(accountID);
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
            uint32 memberCount = 0;
            Group::MemberSlotList const& members =
                group->GetMemberSlots();
            for (auto const& slot : members)
            {
                Player* p = ObjectAccessor::GetPlayer(
                    killer->GetMap(), slot.guid);
                if (p)
                {
                    IncreaseParagonXP(p, xpAmount);
                    ++memberCount;
                }
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
            CharacterDatabase.GetPreparedStatement(
                CHAR_SEL_PARAGON_LEVEL_XP);
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
            CharacterDatabase.GetPreparedStatement(
                CHAR_UPD_PARAGON_LEVELUP);
        updStmt->SetData(0, static_cast<uint32>(newXP));
        updStmt->SetData(1, accountID);
        CharacterDatabase.Execute(updStmt);

        CacheSet(accountID, newLevel, static_cast<uint32>(newXP));

        player->SetAuraStack(conf_AuraLevel, player, newLevel);

        std::ostringstream ss;
        ss << "Congratulations " << player->GetName()
           << "! You increased your Paragon level to "
           << newLevel << ".";
        ChatHandler(player->GetSession()).SendSysMessage(
            ss.str().c_str());
        player->AddItem(PARAGON_POINT_ITEM, conf_PPL);
    }
    else
    {
        uint32 newXP = paragonXP - value;

        CharacterDatabasePreparedStatement* updStmt =
            CharacterDatabase.GetPreparedStatement(
                CHAR_UPD_PARAGON_XP);
        updStmt->SetData(0, value);
        updStmt->SetData(1, accountID);
        CharacterDatabase.Execute(updStmt);

        CacheSet(accountID, paragonLevel, newXP);

        if (value > 0 && (newXP % 100 == 0 || value >= 10))
        {
            std::ostringstream ss;
            ss << "Increasing Paragon XP by " << value << ". "
               << newXP << " needed to level up.";
            ChatHandler(player->GetSession()).SendSysMessage(
                ss.str().c_str());
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
        conf_PPL = sConfigMgr->GetOption<uint32>(
            "Paragon.PPL", 5);
        conf_MaxLevel = sConfigMgr->GetOption<uint32>(
            "Paragon.MaxLevel", 0);
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

        // Stat aura IDs
        conf_AuraIds[0]  = sConfigMgr->GetOption<uint32>(
            "Paragon.IdStr", 100001);
        conf_AuraIds[1]  = sConfigMgr->GetOption<uint32>(
            "Paragon.IdInt", 100002);
        conf_AuraIds[2]  = sConfigMgr->GetOption<uint32>(
            "Paragon.IdAgi", 100003);
        conf_AuraIds[3]  = sConfigMgr->GetOption<uint32>(
            "Paragon.IdSpi", 100004);
        conf_AuraIds[4]  = sConfigMgr->GetOption<uint32>(
            "Paragon.IdSta", 100005);
        conf_AuraIds[5]  = sConfigMgr->GetOption<uint32>(
            "Paragon.IdHaste", 100016);
        conf_AuraIds[6]  = sConfigMgr->GetOption<uint32>(
            "Paragon.IdArmorPen", 100017);
        conf_AuraIds[7]  = sConfigMgr->GetOption<uint32>(
            "Paragon.IdSpellPower", 100018);
        conf_AuraIds[8]  = sConfigMgr->GetOption<uint32>(
            "Paragon.IdCrit", 100019);
        conf_AuraIds[9]  = sConfigMgr->GetOption<uint32>(
            "Paragon.IdMountSpeed", 100020);
        conf_AuraIds[10] = sConfigMgr->GetOption<uint32>(
            "Paragon.IdManaRegen", 100021);
        conf_AuraIds[11] = sConfigMgr->GetOption<uint32>(
            "Paragon.IdHit", 100022);
        conf_AuraIds[12] = sConfigMgr->GetOption<uint32>(
            "Paragon.IdBlock", 100023);
        conf_AuraIds[13] = sConfigMgr->GetOption<uint32>(
            "Paragon.IdExpertise", 100024);
        conf_AuraIds[14] = sConfigMgr->GetOption<uint32>(
            "Paragon.IdParry", 100025);
        conf_AuraIds[15] = sConfigMgr->GetOption<uint32>(
            "Paragon.IdDodge", 100026);
        conf_AuraIds[16] = sConfigMgr->GetOption<uint32>(
            "Paragon.IdLifeLeech", 100027);
        conf_LifeLeechPct = sConfigMgr->GetOption<float>(
            "Paragon.LifeLeechPct", 0.5f);
    }
};

class ParagonLifeLeech : public UnitScript
{
public:
    ParagonLifeLeech() : UnitScript(
        "ParagonLifeLeech", true,
        { UNITHOOK_ON_DAMAGE }) { }

    void OnDamage(Unit* attacker, Unit* /*victim*/,
                  uint32& damage) override
    {
        if (!conf_Enable || !attacker || damage == 0)
            return;

        Player* player = attacker->ToPlayer();
        if (!player)
            return;

        uint32 leechAura = conf_AuraIds[16]; // Life Leech
        Aura* aura = player->GetAura(leechAura);
        if (!aura)
            return;

        uint32 stacks = aura->GetStackAmount();
        if (stacks == 0)
            return;

        // heal = damage * stacks * pct / 100
        float healPct = stacks * conf_LifeLeechPct;
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
