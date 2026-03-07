-- Paragon System - Server Logic
-- Handles paragon point allocation and deallocation via AIO.

local CONFIG = {
	strings = {
		insufficientFunds = "You don't have enough",
		successfulAllocate = "Successfully allocated paragon point!",
		successfulDeallocate = "Successfully removed paragon point!",
		noPointsAllocated = "You have no points allocated in this stat!",
	}
}

--------------------

local AIO = AIO or require("AIO") and require("Paragon_DataStruct")

local CURRENCY_TYPES = {
	[1] = "GOLD",
	[2] = "ITEM_TOKEN",
	[3] = "SERVER_HANDLED"
}

-- Aura ID to DB column name mapping
local AURA_COLUMN_MAP = {
	[100001] = "pstrength",
	[7507]   = "pstrength",
	[100002] = "pintellect",
	[100003] = "pagility",
	[100004] = "pspirit",
	[100005] = "pstamina",
	[100016] = "phaste",
	[100017] = "parmpen",
	[100018] = "pspellpower",
	[100019] = "pcrit",
	[100020] = "pmspeed",
	[100021] = "pmreg",
	[100022] = "phit",
	[100023] = "pblock",
	[100024] = "pexpertise",
	[100025] = "pparry",
	[100026] = "pdodge",
}

local KEYS = GetDataStructKeys();

local ParagonHandler = AIO.AddHandlers("PARAGON_SERVER", {})

function ParagonHandler.FrameData(player)
	local paragonData = GetParagonData(player:GetGUIDLow())
	AIO.Handle(player, "PARAGON_CLIENT", "FrameData", GetServiceData(), GetLinkData(), GetNavData(), GetCurrencyData(), player:GetGMRank(), paragonData)
end

function ParagonHandler.UpdateCurrencies(player)
	local tmp = {}
	for currencyId, currency in pairs(GetCurrencyData()) do
		local val = 0
		local currencyTypeText = CURRENCY_TYPES[currency[KEYS.currency.currencyType]]

		if(currencyTypeText == "GOLD") then
			val = math.floor(player:GetCoinage() / 10000)
		end

		if(currencyTypeText == "ITEM_TOKEN") then
			val = player:GetItemCount(currency[KEYS.currency.data])
		end

		if(currencyTypeText == "SERVER_HANDLED") then
			-- Add your custom handling here
		end

		if(val > 9999) then
			val = "9999+"
		end

		tmp[currencyId] = val
	end

	local paragonData = GetParagonData(player:GetGUIDLow())
	AIO.Handle(player, "PARAGON_CLIENT", "UpdateCurrencies", tmp, paragonData)
end

-- Allocate a paragon point (spend currency, add aura stack, update DB)
function ParagonHandler.AllocatePoint(player, serviceId)
	local services = GetServiceData()

	if not services[serviceId] then
		return
	end

	services[serviceId].ID = serviceId
	local data = services[serviceId]
	local auraId = data[KEYS.service.reward_1]

	if not auraId or auraId <= 0 then
		return
	end

	local column = AURA_COLUMN_MAP[auraId]
	if not column then
		return
	end

	-- Deduct currency
	local currency = data[KEYS.service.currency]
	local amount = data[KEYS.service.price] - data[KEYS.service.discount]
	local deducted = DeductCurrency(player, currency, amount)
	if not deducted then
		return
	end

	-- Add or increment aura stack
	local aura = player:GetAura(auraId)
	if aura then
		aura:SetStackAmount(aura:GetStackAmount() + 1)
	else
		player:AddAura(auraId, player)
	end

	-- Update DB
	local characterId = player:GetGUIDLow()
	CharDBQuery("UPDATE `character_paragon_points` SET `"..column.."` = `"..column.."` + 1 WHERE `characterID` = "..characterId..";")

	-- Refresh UI
	ParagonHandler.UpdateCurrencies(player)

	player:PlayDirectSound(120, player)
	player:SendAreaTriggerMessage(data[KEYS.service.name] .. " " .. CONFIG.strings.successfulAllocate)
end

-- Deallocate a paragon point (refund currency, remove aura stack, update DB)
function ParagonHandler.DeallocatePoint(player, serviceId)
	local services = GetServiceData()

	if not services[serviceId] then
		return
	end

	services[serviceId].ID = serviceId
	local data = services[serviceId]
	local auraId = data[KEYS.service.reward_1]

	if not auraId or auraId <= 0 then
		return
	end

	local column = AURA_COLUMN_MAP[auraId]
	if not column then
		return
	end

	-- Check if player has the aura
	local aura = player:GetAura(auraId)
	if not aura then
		player:SendAreaTriggerMessage("|cFFFF0000"..CONFIG.strings.noPointsAllocated.."|r")
		return
	end

	-- Refund currency
	local currency = data[KEYS.service.currency]
	local amount = data[KEYS.service.price]
	local added = AddCurrency(player, currency, amount)
	if not added then
		return
	end

	-- Decrement or remove aura stack
	local stacks = aura:GetStackAmount()
	if stacks > 1 then
		aura:SetStackAmount(stacks - 1)
	else
		player:RemoveAura(auraId)
	end

	-- Update DB
	local characterId = player:GetGUIDLow()
	CharDBQuery("UPDATE `character_paragon_points` SET `"..column.."` = `"..column.."` - 1 WHERE `characterID` = "..characterId..";")

	-- Refresh UI
	ParagonHandler.UpdateCurrencies(player)

	player:PlayDirectSound(120, player)
	player:SendAreaTriggerMessage(data[KEYS.service.name] .. " " .. CONFIG.strings.successfulDeallocate)
end

-- Currency helpers

function DeductCurrency(player, currencyId, amount)
	local currency = GetCurrencyData()
	local currencyType = currency[currencyId][KEYS.currency.currencyType]
	local currencyName = currency[currencyId][KEYS.currency.name]
	local currencyData = currency[currencyId][KEYS.currency.data]

	if(CURRENCY_TYPES[currencyType] == "GOLD") then
		if(player:GetCoinage() < amount * 10000) then
			player:SendAreaTriggerMessage("|cFFFF0000"..CONFIG.strings.insufficientFunds.." "..currencyName.."|r")
			player:PlayDirectSound(GetSoundEffect("notEnoughMoney", player:GetRace(), player:GetGender()), player)
			return false
		end
		player:SetCoinage(player:GetCoinage() - (amount * 10000))
	end

	if(CURRENCY_TYPES[currencyType] == "ITEM_TOKEN") then
		if not(player:HasItem(currencyData, amount)) then
			player:SendAreaTriggerMessage("|cFFFF0000"..CONFIG.strings.insufficientFunds.." "..currencyName.."|r")
			player:PlayDirectSound(GetSoundEffect("notEnoughMoney", player:GetRace(), player:GetGender()), player)
			return false
		end
		player:RemoveItem(currencyData, amount)
	end

	if(CURRENCY_TYPES[currencyType] == "SERVER_HANDLED") then
		return false
	end

	return true
end

function AddCurrency(player, currencyId, amount)
	local currency = GetCurrencyData()
	local currencyType = currency[currencyId][KEYS.currency.currencyType]
	local currencyData = currency[currencyId][KEYS.currency.data]

	if(CURRENCY_TYPES[currencyType] == "GOLD") then
		player:SetCoinage(player:GetCoinage() + (amount * 10000))
	end

	if(CURRENCY_TYPES[currencyType] == "ITEM_TOKEN") then
		player:AddItem(currencyData, amount)
	end

	if(CURRENCY_TYPES[currencyType] == "SERVER_HANDLED") then
		return false
	end

	return true
end
