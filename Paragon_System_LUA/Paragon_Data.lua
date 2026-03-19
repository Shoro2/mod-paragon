--[[
    Paragon System - Data Layer
    All stat definitions, categories, and DB access functions.
    This file is server-only (no AIO.AddAddon).
]]

local AIO = AIO or require("AIO")

Paragon = Paragon or {}

-- Currency: Paragon Points item
Paragon.CURRENCY_ITEM_ID = 920920
Paragon.CURRENCY_NAME = "Paragon Points"
Paragon.CURRENCY_ICON = "Interface/Icons/INV_Misc_Gem_Bloodstone_01"

-- Max points per stat (must match mod_paragon.conf Paragon.Max* values)
Paragon.MAX_POINTS = {
	Strength       = 255,
	Intellect      = 255,
	Agility        = 255,
	Spirit         = 255,
	Stamina        = 255,
	Haste          = 255,
	ArmorPen       = 255,
	SpellPower     = 255,
	Crit           = 255,
	Hit            = 255,
	Block          = 255,
	Expertise      = 255,
	Parry          = 255,
	Dodge          = 255,
	MountSpeed     = 255,
	ManaRegen      = 255,
	LifeLeech      = 255,
}

-- Categories
Paragon.CATEGORIES = {
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
Paragon.STATS = {
	-- Primary Stats (Category 1)
	{
		id = 1,
		name = "Strength",
		tooltip = "Increases melee attack power and block value.",
		icon = "Interface/Icons/Spell_Holy_FistOfJustice",
		auraId = 100001,
		dbColumn = "pstrength",
		maxPoints = Paragon.MAX_POINTS.Strength,
		categoryId = 1,
	},
	{
		id = 2,
		name = "Intellect",
		tooltip = "Increases mana pool and spell critical strike chance.",
		icon = "Interface/Icons/Spell_Holy_MagicalSentry",
		auraId = 100002,
		dbColumn = "pintellect",
		maxPoints = Paragon.MAX_POINTS.Intellect,
		categoryId = 1,
	},
	{
		id = 3,
		name = "Agility",
		tooltip = "Increases ranged attack power, armor, and dodge chance.",
		icon = "Interface/Icons/Ability_Rogue_Eviscerate",
		auraId = 100003,
		dbColumn = "pagility",
		maxPoints = Paragon.MAX_POINTS.Agility,
		categoryId = 1,
	},
	{
		id = 4,
		name = "Spirit",
		tooltip = "Increases health and mana regeneration.",
		icon = "Interface/Icons/Spell_Shadow_Requiem",
		auraId = 100004,
		dbColumn = "pspirit",
		maxPoints = Paragon.MAX_POINTS.Spirit,
		categoryId = 1,
	},
	{
		id = 5,
		name = "Stamina",
		tooltip = "Increases maximum health.",
		icon = "Interface/Icons/Spell_Holy_WordFortitude",
		auraId = 100005,
		dbColumn = "pstamina",
		maxPoints = Paragon.MAX_POINTS.Stamina,
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
		maxPoints = Paragon.MAX_POINTS.Haste,
		categoryId = 2,
	},
	{
		id = 7,
		name = "Armor Penetration",
		tooltip = "Increases armor penetration rating.",
		icon = "Interface/Icons/Ability_Warrior_Sunder",
		auraId = 100017,
		dbColumn = "parmpen",
		maxPoints = Paragon.MAX_POINTS.ArmorPen,
		categoryId = 2,
	},
	{
		id = 8,
		name = "Spell Power",
		tooltip = "Increases damage and healing done by spells.",
		icon = "Interface/Icons/Spell_Holy_MindSooth",
		auraId = 100018,
		dbColumn = "pspellpower",
		maxPoints = Paragon.MAX_POINTS.SpellPower,
		categoryId = 2,
	},
	{
		id = 9,
		name = "Critical Strike",
		tooltip = "Increases critical strike rating.",
		icon = "Interface/Icons/Spell_Shadow_ShadowPact",
		auraId = 100019,
		dbColumn = "pcrit",
		maxPoints = Paragon.MAX_POINTS.Crit,
		categoryId = 2,
	},
	{
		id = 10,
		name = "Hit Rating",
		tooltip = "Increases hit rating, reducing chance to miss.",
		icon = "Interface/Icons/Spell_Shadow_FingerOfDeath",
		auraId = 100022,
		dbColumn = "phit",
		maxPoints = Paragon.MAX_POINTS.Hit,
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
		maxPoints = Paragon.MAX_POINTS.Block,
		categoryId = 3,
	},
	{
		id = 12,
		name = "Expertise",
		tooltip = "Increases expertise, reducing chance to be dodged or parried.",
		icon = "Interface/Icons/Spell_Holy_SealOfMight",
		auraId = 100024,
		dbColumn = "pexpertise",
		maxPoints = Paragon.MAX_POINTS.Expertise,
		categoryId = 3,
	},
	{
		id = 13,
		name = "Parry",
		tooltip = "Increases parry rating.",
		icon = "Interface/Icons/Ability_Parry",
		auraId = 100025,
		dbColumn = "pparry",
		maxPoints = Paragon.MAX_POINTS.Parry,
		categoryId = 3,
	},
	{
		id = 14,
		name = "Dodge",
		tooltip = "Increases dodge rating.",
		icon = "Interface/Icons/Ability_Rogue_Feint",
		auraId = 100026,
		dbColumn = "pdodge",
		maxPoints = Paragon.MAX_POINTS.Dodge,
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
		maxPoints = Paragon.MAX_POINTS.MountSpeed,
		categoryId = 4,
	},
	{
		id = 16,
		name = "Mana Regeneration",
		tooltip = "Increases mana regeneration.",
		icon = "Interface/Icons/Spell_Nature_ManaRegenTotem",
		auraId = 100021,
		dbColumn = "pmreg",
		maxPoints = Paragon.MAX_POINTS.ManaRegen,
		categoryId = 4,
	},

	-- Special (Category 2 - Offensive)
	{
		id = 17,
		name = "Life Leech",
		tooltip = "Heals you for a percentage of damage dealt.",
		icon = "Interface/Icons/Spell_Shadow_LifeDrain02",
		auraId = 100027,
		dbColumn = "plifeleech",
		maxPoints = Paragon.MAX_POINTS.LifeLeech,
		categoryId = 2,
	},
}

-- Build lookup tables
Paragon.STAT_BY_ID = {}
Paragon.STAT_BY_AURA = {}
Paragon.STATS_BY_CATEGORY = {}

for _, stat in ipairs(Paragon.STATS) do
	Paragon.STAT_BY_ID[stat.id] = stat
	Paragon.STAT_BY_AURA[stat.auraId] = stat

	if not Paragon.STATS_BY_CATEGORY[stat.categoryId] then
		Paragon.STATS_BY_CATEGORY[stat.categoryId] = {}
	end
	table.insert(Paragon.STATS_BY_CATEGORY[stat.categoryId], stat)
end

-- DB column order matching SELECT query
Paragon.DB_COLUMN_ORDER = {
	"pstrength", "pintellect", "pagility", "pspirit", "pstamina",
	"phaste", "parmpen", "pspellpower", "pcrit", "pmspeed",
	"pmreg", "phit", "pblock", "pexpertise", "pparry", "pdodge",
	"plifeleech",
}

-- Map DB column to stat ID
Paragon.COLUMN_TO_STAT_ID = {}
for _, stat in ipairs(Paragon.STATS) do
	Paragon.COLUMN_TO_STAT_ID[stat.dbColumn] = stat.id
end

--- Get current stat allocations for a character.
-- @param characterID number
-- @return table mapping stat ID -> allocated points
function Paragon.GetAllocations(characterID)
	local allocations = {}
	for _, stat in ipairs(Paragon.STATS) do
		allocations[stat.id] = 0
	end

	local columns = table.concat(Paragon.DB_COLUMN_ORDER, ", ")
	local query = CharDBQuery("SELECT " .. columns .. " FROM character_paragon_points WHERE characterID = " .. characterID)
	if query then
		for i, colName in ipairs(Paragon.DB_COLUMN_ORDER) do
			local statId = Paragon.COLUMN_TO_STAT_ID[colName]
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
function Paragon.GetAvailablePoints(player)
	return player:GetItemCount(Paragon.CURRENCY_ITEM_ID)
end

--- Update a single stat allocation in the DB.
-- @param characterID number
-- @param dbColumn string
-- @param newValue number
function Paragon.UpdateAllocation(characterID, dbColumn, newValue)
	CharDBExecute("UPDATE character_paragon_points SET " .. dbColumn .. " = " .. newValue .. " WHERE characterID = " .. characterID)
end

--- Race/gender-specific "not enough money" sound effects.
-- Index: [raceId][gender] where gender 0=male, 1=female.
Paragon.SOUND_EFFECTS = {
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
function Paragon.GetSoundEffect(player)
	local race = player:GetRace()
	local gender = player:GetGender()
	if Paragon.SOUND_EFFECTS[race] and Paragon.SOUND_EFFECTS[race][gender] then
		return Paragon.SOUND_EFFECTS[race][gender]
	end
	return 1838 -- Default: Human Male
end
