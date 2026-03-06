-- Paragon System - Data Structures & DB Loading
-- Loads service/category/currency data from the store DB schema
-- and paragon point allocations from the characters DB.

local ServiceData = {}
local LinkData = {}
local NavData = {}
local CurrencyData = {}
local ParagonData = {}

local KEYS = {
	currency = {
		id				= 0,
		currencyType	= 1,
		name			= 2,
		icon			= 3,
		data			= 4,
		tooltip			= 5
	},
	category = {
		id				= 1,
		name			= 2,
		icon			= 3,
		requiredRank	= 4,
		flags			= 5,
		enabled			= 6
	},
	service = {
		id				= 0,
		serviceType		= 1,
		name			= 2,
		tooltipName		= 3,
		tooltipType		= 4,
		tooltipText		= 5,
		icon			= 6,
		price			= 7,
		currency		= 8,
		hyperlink		= 9,
		displayOrEntry	= 10,
		discount		= 11,
		flags			= 12,
		reward_1		= 13,
		reward_2		= 14,
		reward_3		= 15,
		reward_4		= 16,
		reward_5		= 17,
		reward_6		= 18,
		reward_7		= 19,
		reward_8		= 20,
		rewardCount_1	= 21,
		rewardCount_2	= 22,
		rewardCount_3	= 23,
		rewardCount_4	= 24,
		rewardCount_5	= 25,
		rewardCount_6	= 26,
		rewardCount_7	= 27,
		rewardCount_8	= 28,
		new				= 29,
		enabled			= 30
	},
}

function GetDataStructKeys()
	return KEYS;
end

-- Data loading functions

function NavData.Load()
	NavData.Cache = {};

	local Query = WorldDBQuery("SELECT * FROM store.store_categories")
	if(Query) then
		repeat
			table.insert(NavData.Cache, {Query:GetUInt32(KEYS.category.id-1), Query:GetString(KEYS.category.name-1), Query:GetString(KEYS.category.icon-1), Query:GetUInt32(KEYS.category.requiredRank-1), Query:GetUInt32(KEYS.category.flags-1), Query:GetUInt32(KEYS.category.enabled-1)})
		until not Query:NextRow()
	end
end

function CurrencyData.Load()
	CurrencyData.Cache = {};

	local Query = WorldDBQuery("SELECT * FROM store.store_currencies")
	if(Query) then
		repeat
			CurrencyData.Cache[Query:GetUInt32(0)] = {
				Query:GetUInt32(1), -- type
				Query:GetString(2), -- name
				Query:GetString(3), -- icon
				Query:GetUInt32(4), -- data
				Query:GetString(5), -- tooltip
			}
		until not Query:NextRow()
	end
end

function ServiceData.Load()
	ServiceData.Cache = {};

	local Query = WorldDBQuery("SELECT * FROM store.store_services;");
	if(Query) then
		repeat
			if(Query:GetUInt32(KEYS.service.enabled) == 1) then
				ServiceData.Cache[Query:GetUInt32(KEYS.service.id)] = {
					Query:GetUInt32(KEYS.service.serviceType),
					Query:GetString(KEYS.service.name),
					Query:GetString(KEYS.service.tooltipName),
					Query:GetString(KEYS.service.tooltipType),
					Query:GetString(KEYS.service.tooltipText),
					Query:GetString(KEYS.service.icon),
					Query:GetUInt32(KEYS.service.price),
					Query:GetUInt32(KEYS.service.currency),
					Query:GetUInt32(KEYS.service.hyperlink),
					Query:GetUInt32(KEYS.service.displayOrEntry),
					Query:GetUInt32(KEYS.service.discount),
					Query:GetUInt32(KEYS.service.flags),
					Query:GetUInt32(KEYS.service.reward_1),
					Query:GetUInt32(KEYS.service.reward_2),
					Query:GetUInt32(KEYS.service.reward_3),
					Query:GetUInt32(KEYS.service.reward_4),
					Query:GetUInt32(KEYS.service.reward_5),
					Query:GetUInt32(KEYS.service.reward_6),
					Query:GetUInt32(KEYS.service.reward_7),
					Query:GetUInt32(KEYS.service.reward_8),
					Query:GetUInt32(KEYS.service.rewardCount_1),
					Query:GetUInt32(KEYS.service.rewardCount_2),
					Query:GetUInt32(KEYS.service.rewardCount_3),
					Query:GetUInt32(KEYS.service.rewardCount_4),
					Query:GetUInt32(KEYS.service.rewardCount_5),
					Query:GetUInt32(KEYS.service.rewardCount_6),
					Query:GetUInt32(KEYS.service.rewardCount_7),
					Query:GetUInt32(KEYS.service.rewardCount_8),
					Query:GetUInt32(KEYS.service.new),
				}
			end
		until not Query:NextRow()
	end
end

function LinkData.Load()
	LinkData.Cache = {};

	local Query = WorldDBQuery("SELECT * FROM store.store_category_service_link;");
	if(Query) then
		repeat
			table.insert(LinkData.Cache, {Query:GetUInt32(0), Query:GetUInt32(1)})
		until not Query:NextRow()
	end
end

-- Data access functions

function GetServiceData()
	return ServiceData.Cache;
end

function GetLinkData()
	return LinkData.Cache;
end

function GetNavData()
	return NavData.Cache;
end

function GetCurrencyData()
	return CurrencyData.Cache;
end

function GetParagonData(characterID)
	ParagonData.Cache = {};
	local Query = CharDBQuery("SELECT `pstrength`, `pintellect`, `pagility`, `pspirit`, `pstamina` FROM `character_paragon_points` WHERE `characterID` = "..characterID)
	if (Query) then
		ParagonData.Cache = {
			Query:GetUInt32(0), -- strength
			Query:GetUInt32(1), -- intellect
			Query:GetUInt32(2), -- agility
			Query:GetUInt32(3), -- spirit
			Query:GetUInt32(4), -- stamina
		}
	end
	return ParagonData.Cache;
end

-- Load all data on startup
ServiceData.Load()
LinkData.Load()
NavData.Load()
CurrencyData.Load()

-- Sound effects for error feedback (race/gender-specific voice lines)
local SoundEffects = {
	notEnoughMoney = {
		[1] = { [0] = 1908, [1] = 2032 }, -- Human
		[2] = { [0] = 2319, [1] = 2356 }, -- Orc
		[3] = { [0] = 1598, [1] = 1669 }, -- Dwarf
		[4] = { [0] = 2151, [1] = 2262 }, -- Night Elf
		[5] = { [0] = 2096, [1] = 2207 }, -- Undead
		[6] = { [0] = 2426, [1] = 2462 }, -- Tauren
		[7] = { [0] = 1724, [1] = 1779 }, -- Gnome
		[8] = { [0] = 1835, [1] = 1945 }, -- Troll
		[10] = { [0] = 9583, [1] = 9584 }, -- Blood Elf
		[11] = { [0] = 9498, [1] = 9499 }, -- Draenei
	},
}

function GetSoundEffect(key, race, gender)
	if SoundEffects[key] and SoundEffects[key][race] and SoundEffects[key][race][gender] then
		return SoundEffects[key][race][gender]
	end
	return 0
end
