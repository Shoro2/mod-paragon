--[[
    Paragon System v2 - Data Layer
    All stat definitions, categories, and DB access functions.
    This file is server-only (no AIO.AddAddon).
]]

local AIO = AIO or require("AIO")

ParagonV2 = ParagonV2 or {}

-- Currency: Paragon Points item
ParagonV2.CURRENCY_ITEM_ID = 920920
ParagonV2.CURRENCY_NAME = "Paragon Points"
ParagonV2.CURRENCY_ICON = "Interface/Icons/INV_Misc_Gem_Bloodstone_01"

-- Categories
ParagonV2.CATEGORIES = {
	{
		id = 1,
		name = "Primary Stats",
		icon = "Interface/Icons/Achievement_General",
	},
	{
		id = 2,
		name = "Offensive Stats",
		icon = "Interface/Icons/Ability_DualWield",
	},
	{
		id = 3,
		name = "Defensive Stats",
		icon = "Interface/Icons/INV_Shield_06",
	},
	{
		id = 4,
		name = "Utility",
		icon = "Interface/Icons/Spell_Holy_Crusade",
	},
}

-- Stat definitions: all 16 paragon stats
-- Each stat has: id, name, tooltip, icon, auraId, dbColumn, maxPoints, categoryId
ParagonV2.STATS = {
	-- Primary Stats (Category 1)
	{
		id = 1,
		name = "Strength",
		tooltip = "Increases melee attack power and block value.",
		icon = "Interface/Icons/Spell_Holy_FistOfJustice",
		auraId = 100001,
		dbColumn = "pstrength",
		maxPoints = 100,
		categoryId = 1,
	},
	{
		id = 2,
		name = "Intellect",
		tooltip = "Increases mana pool and spell critical strike chance.",
		icon = "Interface/Icons/Spell_Holy_MagicalSentry",
		auraId = 100002,
		dbColumn = "pintellect",
		maxPoints = 100,
		categoryId = 1,
	},
	{
		id = 3,
		name = "Agility",
		tooltip = "Increases ranged attack power, armor, and dodge chance.",
		icon = "Interface/Icons/Ability_Rogue_Eviscerate",
		auraId = 100003,
		dbColumn = "pagility",
		maxPoints = 100,
		categoryId = 1,
	},
	{
		id = 4,
		name = "Spirit",
		tooltip = "Increases health and mana regeneration.",
		icon = "Interface/Icons/Spell_Shadow_Requiem",
		auraId = 100004,
		dbColumn = "pspirit",
		maxPoints = 100,
		categoryId = 1,
	},
	{
		id = 5,
		name = "Stamina",
		tooltip = "Increases maximum health.",
		icon = "Interface/Icons/Spell_Holy_WordFortitude",
		auraId = 100005,
		dbColumn = "pstamina",
		maxPoints = 100,
		categoryId = 1,
	},

	-- Offensive Stats (Category 2)
	{
		id = 6,
		name = "Haste",
		tooltip = "Increases attack and casting speed.",
		icon = "Interface/Icons/Spell_Nature_Bloodlust",
		auraId = 100016,
		dbColumn = "phaste",
		maxPoints = 100,
		categoryId = 2,
	},
	{
		id = 7,
		name = "Armor Penetration",
		tooltip = "Increases armor penetration rating.",
		icon = "Interface/Icons/Ability_Warrior_Sunder",
		auraId = 100017,
		dbColumn = "parmpen",
		maxPoints = 100,
		categoryId = 2,
	},
	{
		id = 8,
		name = "Spell Power",
		tooltip = "Increases damage and healing done by spells.",
		icon = "Interface/Icons/Spell_Holy_MindSooth",
		auraId = 100018,
		dbColumn = "pspellpower",
		maxPoints = 100,
		categoryId = 2,
	},
	{
		id = 9,
		name = "Critical Strike",
		tooltip = "Increases critical strike rating.",
		icon = "Interface/Icons/Spell_Shadow_ShadowPact",
		auraId = 100019,
		dbColumn = "pcrit",
		maxPoints = 100,
		categoryId = 2,
	},
	{
		id = 10,
		name = "Hit Rating",
		tooltip = "Increases hit rating, reducing chance to miss.",
		icon = "Interface/Icons/Spell_Shadow_FingerOfDeath",
		auraId = 100022,
		dbColumn = "phit",
		maxPoints = 100,
		categoryId = 2,
	},

	-- Defensive Stats (Category 3)
	{
		id = 11,
		name = "Block",
		tooltip = "Increases block rating.",
		icon = "Interface/Icons/Ability_Defend",
		auraId = 100023,
		dbColumn = "pblock",
		maxPoints = 100,
		categoryId = 3,
	},
	{
		id = 12,
		name = "Expertise",
		tooltip = "Increases expertise, reducing chance to be dodged or parried.",
		icon = "Interface/Icons/Spell_Holy_SealOfMight",
		auraId = 100024,
		dbColumn = "pexpertise",
		maxPoints = 100,
		categoryId = 3,
	},
	{
		id = 13,
		name = "Parry",
		tooltip = "Increases parry rating.",
		icon = "Interface/Icons/Ability_Parry",
		auraId = 100025,
		dbColumn = "pparry",
		maxPoints = 100,
		categoryId = 3,
	},
	{
		id = 14,
		name = "Dodge",
		tooltip = "Increases dodge rating.",
		icon = "Interface/Icons/Ability_Rogue_Feint",
		auraId = 100026,
		dbColumn = "pdodge",
		maxPoints = 100,
		categoryId = 3,
	},

	-- Utility (Category 4)
	{
		id = 15,
		name = "Mount Speed",
		tooltip = "Increases mounted movement speed.",
		icon = "Interface/Icons/Ability_Mount_RidingHorse",
		auraId = 100020,
		dbColumn = "pmspeed",
		maxPoints = 50,
		categoryId = 4,
	},
	{
		id = 16,
		name = "Mana Regeneration",
		tooltip = "Increases mana regeneration.",
		icon = "Interface/Icons/Spell_Nature_ManaRegenTotem",
		auraId = 100021,
		dbColumn = "pmreg",
		maxPoints = 100,
		categoryId = 4,
	},
}

-- Build lookup tables
ParagonV2.STAT_BY_ID = {}
ParagonV2.STAT_BY_AURA = {}
ParagonV2.STATS_BY_CATEGORY = {}

for _, stat in ipairs(ParagonV2.STATS) do
	ParagonV2.STAT_BY_ID[stat.id] = stat
	ParagonV2.STAT_BY_AURA[stat.auraId] = stat

	if not ParagonV2.STATS_BY_CATEGORY[stat.categoryId] then
		ParagonV2.STATS_BY_CATEGORY[stat.categoryId] = {}
	end
	table.insert(ParagonV2.STATS_BY_CATEGORY[stat.categoryId], stat)
end

-- DB column order matching SELECT query
ParagonV2.DB_COLUMN_ORDER = {
	"pstrength", "pintellect", "pagility", "pspirit", "pstamina",
	"phaste", "parmpen", "pspellpower", "pcrit", "pmspeed",
	"pmreg", "phit", "pblock", "pexpertise", "pparry", "pdodge",
}

-- Map DB column to stat ID
ParagonV2.COLUMN_TO_STAT_ID = {}
for _, stat in ipairs(ParagonV2.STATS) do
	ParagonV2.COLUMN_TO_STAT_ID[stat.dbColumn] = stat.id
end

--- Get current stat allocations for a character.
-- @param characterID number
-- @return table mapping stat ID -> allocated points
function ParagonV2.GetAllocations(characterID)
	local allocations = {}
	for _, stat in ipairs(ParagonV2.STATS) do
		allocations[stat.id] = 0
	end

	local columns = table.concat(ParagonV2.DB_COLUMN_ORDER, ", ")
	local query = CharDBQuery("SELECT " .. columns .. " FROM character_paragon_points WHERE characterID = " .. characterID)
	if query then
		for i, colName in ipairs(ParagonV2.DB_COLUMN_ORDER) do
			local statId = ParagonV2.COLUMN_TO_STAT_ID[colName]
			if statId then
				allocations[statId] = query:GetInt32(i - 1)
			end
		end
	end

	return allocations
end

--- Get the number of available (unspent) Paragon Points for a player.
-- @param player Player object
-- @return number
function ParagonV2.GetAvailablePoints(player)
	return player:GetItemCount(ParagonV2.CURRENCY_ITEM_ID)
end

--- Update a single stat allocation in the DB.
-- @param characterID number
-- @param dbColumn string
-- @param newValue number
function ParagonV2.UpdateAllocation(characterID, dbColumn, newValue)
	CharDBExecute("UPDATE character_paragon_points SET " .. dbColumn .. " = " .. newValue .. " WHERE characterID = " .. characterID)
end

--- Race/gender-specific "not enough money" sound effects.
-- Index: [raceId][gender] where gender 0=male, 1=female.
ParagonV2.SOUND_EFFECTS = {
	[1]  = { [0] = 1838,  [1] = 2032  }, -- Human
	[2]  = { [0] = 2262,  [1] = 2370  }, -- Orc
	[3]  = { [0] = 2502,  [1] = 2590  }, -- Dwarf
	[4]  = { [0] = 2686,  [1] = 2818  }, -- Night Elf
	[5]  = { [0] = 2930,  [1] = 3058  }, -- Undead
	[6]  = { [0] = 3166,  [1] = 3274  }, -- Tauren
	[7]  = { [0] = 3382,  [1] = 3490  }, -- Gnome
	[8]  = { [0] = 3598,  [1] = 3706  }, -- Troll
	[9]  = { [0] = 9730,  [1] = 9734  }, -- Goblin
	[10] = { [0] = 9584,  [1] = 9584  }, -- Blood Elf
	[11] = { [0] = 9498,  [1] = 9498  }, -- Draenei
}

--- Get the sound effect ID for a player's "not enough points" feedback.
-- @param player Player object
-- @return number sound ID
function ParagonV2.GetSoundEffect(player)
	local race = player:GetRace()
	local gender = player:GetGender()
	if ParagonV2.SOUND_EFFECTS[race] and ParagonV2.SOUND_EFFECTS[race][gender] then
		return ParagonV2.SOUND_EFFECTS[race][gender]
	end
	return 1838 -- Default: Human Male
end
