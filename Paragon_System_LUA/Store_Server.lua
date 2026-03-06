-- The below config options can be changed to suit your needs.
-- Anything not in the config options requires changes to the code below,
-- do so at your own discretion.

local CONFIG = {
	maxLevel = 80, -- Character max level of server
	mailSenderGUID = 1, -- GUID of the character shown as sender of purchase mails
	strings = {
		-- Currency name is appended to the end of this string
		insufficientFunds = "You don't have enough",
		-- Type is appended, ie. title, mount, pet etc.
		alreadyKnown = "You already have this",
		tooHighLevel = "Your level is too high",
		mailBody = "Thank you for your purchase!",
		-- The service name is prefixed to this message
		successfulPurchase = "Successfully allocated paragon point!",
		successfulRemove = "Successfully removed paragon point!"
	}
}

--------------------

local AIO = AIO or require("AIO") and require("Store_DataStruct")


local CURRENCY_TYPES = {
	[1] = "GOLD",
	[2] = "ITEM_TOKEN",
	[3] = "SERVER_HANDLED"
}
-- strength, intellect, agility, spirit, stamina


local SHOP_UI = {
	serviceHandlers = {
		[1] = "ItemHandler", 		-- Okay
		[2] = "GoldHandler", 		-- Okay
		[3] = "MountHandler",		-- Okay
		[4] = "PetHandler",  		-- Okay
		[5] = "BuffHandler", 		-- Okay
		[6] = "UnusedHandler",		-- UNUSED
		[7] = "ServiceHandler", 	-- Okay
		[8] = "LevelHandler", 		-- Okay
		[9] = "TitleHandler",		-- Okay
		[10] = "ParagonPlus",
		[11] = "ParagonMinus",
	}
}

local KEYS = GetDataStructKeys();

local StoreHandler = AIO.AddHandlers("STORE_SERVER", {})

function StoreHandler.FrameData(player)
	AIO.Handle(player, "STORE_CLIENT", "FrameData", GetServiceData(), GetLinkData(), GetNavData(), GetCurrencyData(), player:GetGMRank(), GetParagonData(player:GetGUIDLow()))
end

function StoreHandler.UpdateCurrencies(player)
	local tmp = {}
	for currencyId, currency in pairs(GetCurrencyData()) do
		local val = 0
		local currencyTypeText = CURRENCY_TYPES[currency[KEYS.currency.currencyType]]
		
		-- Handle the different currency types
		if(currencyTypeText == "GOLD") then
			val = math.floor(player:GetCoinage() / 10000)
		end
		
		if(currencyTypeText == "ITEM_TOKEN") then
			val = player:GetItemCount(currency[KEYS.currency.data])
		end
		
		if(currencyTypeText == "SERVER_HANDLED") then
			-- Add your custom handling here for retreiving your server handled currencies
			
		end
		
		-- If value is larger than 10k then truncate to make sure it fits within the shop frame
		if(val > 9999) then
			val = "9999+"
		end
		
		table.insert(tmp, val)
	end
	local paragonData = {}
	local paragonDataReq = GetParagonData(player:GetGUIDLow())
	
	local pstrength = paragonDataReq[0]
	local pintellect = paragonDataReq[1]
	local pagility = paragonDataReq[2]
	local pspirit = paragonDataReq[3]
	local pstamina = paragonDataReq[4]
	paragonData = {pstrength, pintellect, pagility, pspirit, pstamina}
	
	AIO.Handle(player, "STORE_CLIENT", "UpdateCurrencies", tmp)
	--AIO.Handle(player, "STORE_CLIENT", "UpdateParagon", paragonData)
end

function StoreHandler.Purchase(player, serviceId)
	local services = GetServiceData()
	
	-- See if the requested service exists
	if(services[serviceId])then
		-- add the id to the service subtable so we don't have to pass an additional variable around
		services[serviceId].ID = serviceId
		local typeId = services[serviceId][KEYS.service.serviceType]
		
		local serviceHandler = SHOP_UI[SHOP_UI.serviceHandlers[typeId]]
		if(serviceHandler) then
			local success = serviceHandler(player, services[serviceId])
			if(success) then
				-- If purchase is successful, update the players currencies in UI and log purchase
				StoreHandler.UpdateCurrencies(player)
				SHOP_UI.LogPurchase(player, services[serviceId])
				
				-- Play success sound
				player:PlayDirectSound(120, player)
				
				-- Send success toast
				player:SendAreaTriggerMessage(services[serviceId][KEYS.service.name] .. " "..CONFIG.strings.successfulPurchase)
			end
		end
	end
end

function StoreHandler.Sell(player, serviceId)
	local services = GetServiceData()
	
	-- See if the requested service exists
	if(services[serviceId])then
		-- add the id to the service subtable so we don't have to pass an additional variable around
		services[serviceId].ID = serviceId
		local typeId = services[serviceId][KEYS.service.serviceType]
		
		local serviceHandler = SHOP_UI[SHOP_UI.serviceHandlers[typeId]]
		if(serviceHandler) then
			local success = serviceHandler(player, services[serviceId])
			if(success) then
				-- If purchase is successful, update the players currencies in UI and log purchase
				StoreHandler.UpdateCurrencies(player)
				SHOP_UI.LogPurchase(player, services[serviceId])
				
				-- Play success sound
				player:PlayDirectSound(120, player)
				
				-- Send success toast
				player:SendAreaTriggerMessage(services[serviceId][KEYS.service.name] .. " "..CONFIG.strings.successfulRemove)
			end
		end
	end
end

-- Helper functions
function SHOP_UI.DeductCurrency(player, currencyId, amount)
	local currency = GetCurrencyData()
	local currencyType = currency[currencyId][KEYS.currency.currencyType]
	local currencyName = currency[currencyId][KEYS.currency.name]
	local currencyData = currency[currencyId][KEYS.currency.data]
	
	-- Gold handling
	if(CURRENCY_TYPES[currencyType] == "GOLD") then
		if(player:GetCoinage() < amount * 10000) then
			player:SendAreaTriggerMessage("|cFFFF0000"..CONFIG.strings.insufficientFunds.." "..currencyName.."|r")
			player:PlayDirectSound(GetSoundEffect("notEnoughMoney", player:GetRace(), player:GetGender()), player)
			return false
		end
		
		player:SetCoinage(player:GetCoinage() - (amount * 10000))
	end
	
	-- Token handling
	if(CURRENCY_TYPES[currencyType] == "ITEM_TOKEN") then
		if not(player:HasItem(currencyData, amount)) then
			player:SendAreaTriggerMessage("|cFFFF0000"..CONFIG.strings.insufficientFunds.." "..currencyName.."|r")
			player:PlayDirectSound(GetSoundEffect("notEnoughMoney", player:GetRace(), player:GetGender()), player)
			return false
		end
		
		player:RemoveItem(currencyData, amount) 
	end
	
	-- Other special handlingm you have to add your own integration here.
	if(CURRENCY_TYPES[currencyType] == "SERVER_HANDLED") then
		return false
	end
	
	return true
end

function SHOP_UI.AddCurrency(player, currencyId, amount)
	local currency = GetCurrencyData()
	local currencyType = currency[currencyId][KEYS.currency.currencyType]
	local currencyName = currency[currencyId][KEYS.currency.name]
	local currencyData = currency[currencyId][KEYS.currency.data]
	
	-- Gold handling
	if(CURRENCY_TYPES[currencyType] == "GOLD") then
		if(player:GetCoinage() < amount * 10000) then
			player:SendAreaTriggerMessage("|cFFFF0000"..CONFIG.strings.insufficientFunds.." "..currencyName.."|r")
			player:PlayDirectSound(GetSoundEffect("notEnoughMoney", player:GetRace(), player:GetGender()), player)
			return false
		end
		
		player:SetCoinage(player:GetCoinage() + (amount * 10000))
	end
	
	-- Token handling
	if(CURRENCY_TYPES[currencyType] == "ITEM_TOKEN") then
		player:AddItem(currencyData, amount) 
	end
	
	-- Other special handlingm you have to add your own integration here.
	if(CURRENCY_TYPES[currencyType] == "SERVER_HANDLED") then
		return false
	end
	
	return true
end

function SHOP_UI.LogPurchase(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price] - data[KEYS.service.discount]
	WorldDBExecute("INSERT INTO store.store_logs(account, guid, serviceId, currencyId, cost) VALUES("..player:GetAccountId()..", "..player:GetGUIDLow()..", "..data.ID..", "..currency..", "..amount..");")
end

-- ITEMS
function SHOP_UI.ItemHandler(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price] - data[KEYS.service.discount]
	
	-- Deduct currency
	local deducted = SHOP_UI.DeductCurrency(player, currency, amount)
	
	-- If currency was not deducted from the player, abort and send message
	if not(deducted) then
		return false
	end
	
	-- Fetch all the rewards and store them temporarily
	local items = {}
	for i = 0, 7 do
		if(data[KEYS.service.reward_1+i] > 0 and data[KEYS.service.rewardCount_1+i] > 0) then
			table.insert(items, data[KEYS.service.reward_1+i])
			table.insert(items, data[KEYS.service.rewardCount_1+i])
		end
	end
	
	-- Send reward mail
	SendMail("Purchase of: "..data[KEYS.service.name], CONFIG.strings.mailBody, player:GetGUIDLow(), CONFIG.mailSenderGUID, 62, 0, 0, 0, unpack(items))
	return true
end

-- GOLD
function SHOP_UI.GoldHandler(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price] - data[KEYS.service.discount]
	
	-- Deduct currency
	local deducted = SHOP_UI.DeductCurrency(player, currency, amount)
	
	-- If currency was not deducted from the player, abort and send message
	if not(deducted) then
		return false
	end
	
	-- Add gold to player
	player:ModifyMoney(data[KEYS.service.reward_1]*10000)
	return true
end

-- MOUNTS
function SHOP_UI.MountHandler(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price] - data[KEYS.service.discount]
	
	local knownCount, rewardCount = 0, 0
	for i = 0, 7 do
		if(data[KEYS.service.reward_1+i] > 0) then
			if(player:HasSpell(data[KEYS.service.reward_1+i])) then
				knownCount = knownCount + 1
			end
			rewardCount = rewardCount + 1
		end
	end
	
	-- check if player already has the spells learned
	if(knownCount == rewardCount) then
		player:SendAreaTriggerMessage("|cFFFF0000"..CONFIG.strings.alreadyKnown.." mount|r")
		player:PlayDirectSound(GetSoundEffect("cantLearn", player:GetRace(), player:GetGender()), player)
		return false
	end
	
	-- Deduct currency
	local deducted = SHOP_UI.DeductCurrency(player, currency, amount)
	
	-- If currency was not deducted from the player, abort and send message
	if not(deducted) then
		return false
	end
	
	-- Teach mounts
	for i = 0, 7 do
		if(data[KEYS.service.reward_1+i] > 0) then
			player:LearnSpell(data[KEYS.service.reward_1+i])
		end
	end
	return true
end

-- PETS
function SHOP_UI.PetHandler(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price] - data[KEYS.service.discount]
	
	local knownCount, rewardCount = 0, 0
	for i = 0, 7 do
		if(data[KEYS.service.reward_1+i] > 0) then
			if(player:HasSpell(data[KEYS.service.reward_1+i])) then
				knownCount = knownCount + 1
			end
			rewardCount = rewardCount + 1
		end
	end
	
	-- check if player already has the spells learned
	if(knownCount == rewardCount) then
		player:SendAreaTriggerMessage("|cFFFF0000"..CONFIG.strings.alreadyKnown.." pet|r")
		player:PlayDirectSound(GetSoundEffect("cantLearn", player:GetRace(), player:GetGender()), player)
		return false
	end
	
	-- Deduct currency
	local deducted = SHOP_UI.DeductCurrency(player, currency, amount)
	
	-- If currency was not deducted from the player, abort and send message
	if not(deducted) then
		return false
	end
	
	-- Teach pets
	for i = 0, 7 do
		if(data[KEYS.service.reward_1+i] > 0) then
			player:LearnSpell(data[KEYS.service.reward_1+i])
		end
	end
	return true
end

-- BUFFS
function SHOP_UI.BuffHandler(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price] - data[KEYS.service.discount]
	
	-- Deduct currency
	local deducted = SHOP_UI.DeductCurrency(player, currency, amount)
	
	-- If currency was not deducted from the player, abort and send message
	if not(deducted) then
		return false
	end
	
	-- iterate over all reward slots and buff the player with all configured spells
	for i = 0, 7 do
		if(data[KEYS.service.reward_1+i] > 0) then
			player:CastSpell(player, data[KEYS.service.reward_1+i], true)
		end
	end
	return true
end

-- SERVICES
function SHOP_UI.ServiceHandler(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price] - data[KEYS.service.discount]
	
	-- Deduct currency
	local deducted = SHOP_UI.DeductCurrency(player, currency, amount)
	
	-- If currency was not deducted from the player, abort and send message
	if not(deducted) then
		return false
	end
	
	-- Set the AtLogin flag to whatever is defined in reward_1
	player:SetAtLoginFlag(data[KEYS.service.reward_1])
	
	return true
end

-- LEVELS
function SHOP_UI.LevelHandler(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price] - data[KEYS.service.discount]
	-- If flag is set to 1, then we set the player to the specified level instead of adding levels
	-- We need to check this before deducting any money
	if(data[KEYS.service.flags] == 1) then
		if(player:GetLevel() >= data[KEYS.service.reward_1]) then
			player:SendAreaTriggerMessage("|cFFFF0000"..CONFIG.strings.tooHighLevel.."|r")
			player:PlayDirectSound(GetSoundEffect("cantUse", player:GetRace(), player:GetGender()), player)
			return false
		end
	end
	
	-- Deduct currency
	local deducted = SHOP_UI.DeductCurrency(player, currency, amount)
	
	-- If currency was not deducted from the player, abort and send message
	if not(deducted) then
		return false
	end
	
	local level = player:GetLevel() + data[KEYS.service.reward_1]
	
	-- Ensure that players can't level higher than configured max
	if(level > CONFIG.maxLevel) then
		level = CONFIG.maxLevel
	end
	
	-- and again, if flag = 1 then we set the level instead of adding onto
	if(data[KEYS.service.flags] == 1) then
		level = data[KEYS.service.reward_1]
	end
	
	player:SetLevel(level)
	return true
end

-- TITLES
function SHOP_UI.TitleHandler(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price] - data[KEYS.service.discount]
	
	-- Check whether or not the player already has the specified title
	if(player:HasTitle(data[KEYS.service.reward_1])) then
		player:SendAreaTriggerMessage("|cFFFF0000"..CONFIG.strings.alreadyKnown.." title|r")
		player:PlayDirectSound(GetSoundEffect("cantLearn", player:GetRace(), player:GetGender()), player)
		return false
	end
	
	-- Deduct currency
	local deducted = SHOP_UI.DeductCurrency(player, currency, amount)
	
	-- If currency was not deducted from the player, abort and send message
	if not(deducted) then
		return false
	end
	
	-- Give the player the defined title
	player:SetKnownTitle(data[KEYS.service.reward_1])
	return true
end

-- PARAGON Plus
function SHOP_UI.ParagonPlus(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price] - data[KEYS.service.discount]
	
	-- Deduct currency
	local deducted = SHOP_UI.DeductCurrency(player, currency, amount)
	
	-- If currency was not deducted from the player, abort and send message
	if not(deducted) then
		return false
	end
	
	-- iterate over all reward slots and buff the player with all configured spells

	if(data[KEYS.service.reward_1] > 0) then
		
		local aura = player:GetAura(data[KEYS.service.reward_1])
        if (aura) then
            aura:SetStackAmount(aura:GetStackAmount()+1)
        else
            player:AddAura(data[KEYS.service.reward_1], player)
		end
		local accoundID = player:GetAccountId()
			if(data[KEYS.service.reward_1] == 100001) then
				CharDBExecute("UPDATE character_paragon_points SET pstrength = pstrength + 1 WHERE accoundID = "..accoundID..";")
			end
			if(data[KEYS.service.reward_1] == 100002) then
				CharDBExecute("UPDATE character_paragon_points SET pintellect = pintellect + 1 WHERE accoundID = "..accoundID..";")
			end
			if(data[KEYS.service.reward_1] == 100003) then
				CharDBExecute("UPDATE character_paragon_points SET pagility = pagility + 1 WHERE accoundID = "..accoundID..";")
			end
			if(data[KEYS.service.reward_1] == 100004) then
				CharDBExecute("UPDATE character_paragon_points SET pspirit = pspirit + 1 WHERE accoundID = "..accoundID..";")
			end
			if(data[KEYS.service.reward_1] == 100005) then
				CharDBExecute("UPDATE character_paragon_points SET pstamina = pstamina + 1 WHERE accoundID = "..accoundID..";")
			end
	end
	return true
end

-- PARAGON Minus
function SHOP_UI.ParagonMinus(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price]
	
	
	-- Check for Stat Aura
	local aura = player:GetAura(data[KEYS.service.reward_1])
	if not(aura) then
		return false
	end
	
	
	-- Add currency
	local added = SHOP_UI.AddCurrency(player, currency, amount)

	-- If currency was not deducted from the player, abort and send message
	if not(added) then
		return false	
	end
	
	-- iterate over all reward slots and buff the player with all configured spells

	if(data[KEYS.service.reward_1] > 0) then
		if (aura) then
			local stacks = aura:GetStackAmount()
			if (stacks >= 1) then
				aura:SetStackAmount(aura:GetStackAmount()-1)
			else
				player:RemoveAura(data[KEYS.service.reward_1])
			end
			local accoundID = player:GetAccountId()
			if(data[KEYS.service.reward_1] == 100001) then
				CharDBExecute("UPDATE character_paragon_points SET pstrength = pstrength - 1 WHERE accoundID = "..accoundID..";")
			end
			if(data[KEYS.service.reward_1] == 100002) then
				CharDBExecute("UPDATE character_paragon_points SET pintellect = pintellect - 1 WHERE accoundID = "..accoundID..";")
			end
			if(data[KEYS.service.reward_1] == 100003) then
				CharDBExecute("UPDATE character_paragon_points SET pagility = pagility - 1 WHERE accoundID = "..accoundID..";")
			end
			if(data[KEYS.service.reward_1] == 100004) then
				CharDBExecute("UPDATE character_paragon_points SET pspirit = pspirit - 1 WHERE accoundID = "..accoundID..";")
			end
			if(data[KEYS.service.reward_1] == 100005) then
				CharDBExecute("UPDATE character_paragon_points SET pstamina = pstamina - 1 WHERE accoundID = "..accoundID..";")
			end
		end
	end
	
	return true
end

-- UNUSED
function SHOP_UI.UnusedHandler(player, data)
	local currency, amount = data[KEYS.service.currency], data[KEYS.service.price] - data[KEYS.service.discount]
	
	-- Since this is unused, always return false until the function is in use.
	return false
end