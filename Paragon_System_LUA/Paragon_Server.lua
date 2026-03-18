--[[
    Paragon System v2 - Server Handlers
    Handles point allocation/deallocation and data sync.
    This file is server-only (no AIO.AddAddon).
]]

local AIO = AIO or require("AIO")

local Handlers = AIO.AddHandlers("PARAGON_V2_SERVER", {})

--- Build the serializable stats/categories config to send to the client.
-- Strips server-only fields (dbColumn, auraId) from the data.
local function BuildClientConfig()
	local categories = {}
	for _, cat in ipairs(ParagonV2.CATEGORIES) do
		table.insert(categories, {
			id = cat.id,
			name = cat.name,
			icon = cat.icon,
		})
	end

	local stats = {}
	for _, stat in ipairs(ParagonV2.STATS) do
		table.insert(stats, {
			id = stat.id,
			name = stat.name,
			tooltip = stat.tooltip,
			icon = stat.icon,
			maxPoints = stat.maxPoints,
			categoryId = stat.categoryId,
		})
	end

	return categories, stats
end

--- Send all data needed to build and populate the client UI.
-- Called when the player opens the Paragon frame.
function Handlers.RequestData(player)
	local characterID = player:GetGUIDLow()
	local categories, stats = BuildClientConfig()
	local allocations = ParagonV2.GetAllocations(characterID)
	local availablePoints = ParagonV2.GetAvailablePoints(player)

	AIO.Handle(player, "PARAGON_V2_CLIENT", "ReceiveData",
		categories, stats, allocations, availablePoints)
end

--- Allocate points into a stat.
-- @param player Player object (injected by AIO)
-- @param statId number - the stat to allocate into
-- @param amount number - how many points to allocate (default 1)
function Handlers.AllocatePoint(player, statId, amount)
	local stat = ParagonV2.STAT_BY_ID[statId]
	if not stat then
		player:SendBroadcastMessage("Invalid stat.")
		return
	end

	amount = tonumber(amount) or 1
	if amount < 1 then return end

	local characterID = player:GetGUIDLow()
	local allocations = ParagonV2.GetAllocations(characterID)
	local current = allocations[statId] or 0

	-- Check max points
	if current >= stat.maxPoints then
		player:SendBroadcastMessage(stat.name .. " is already at maximum.")
		return
	end

	-- Check available points
	local available = ParagonV2.GetAvailablePoints(player)
	if available < 1 then
		local soundId = ParagonV2.GetSoundEffect(player)
		AIO.Handle(player, "PARAGON_V2_CLIENT", "PlaySound", soundId)
		return
	end

	-- Clamp amount to what's actually possible
	local maxCanAllocate = stat.maxPoints - current
	if amount > maxCanAllocate then amount = maxCanAllocate end
	if amount > available then amount = available end

	-- Deduct Paragon Point items
	player:RemoveItem(ParagonV2.CURRENCY_ITEM_ID, amount)

	-- Apply aura
	local newValue = current + amount
	if current == 0 then
		player:AddAura(stat.auraId, player)
	end
	local aura = player:GetAura(stat.auraId)
	if aura then
		aura:SetStackAmount(newValue)
	end

	-- Update DB (async) and send known values to client immediately
	ParagonV2.UpdateAllocation(characterID, stat.dbColumn, newValue)
	allocations[statId] = newValue
	local availablePoints = ParagonV2.GetAvailablePoints(player)
	AIO.Handle(player, "PARAGON_V2_CLIENT", "UpdatePoints",
		allocations, availablePoints)
end

--- Deallocate points from a stat.
-- @param player Player object (injected by AIO)
-- @param statId number - the stat to deallocate from
-- @param amount number - how many points to deallocate (default 1)
function Handlers.DeallocatePoint(player, statId, amount)
	local stat = ParagonV2.STAT_BY_ID[statId]
	if not stat then
		player:SendBroadcastMessage("Invalid stat.")
		return
	end

	amount = tonumber(amount) or 1
	if amount < 1 then return end

	local characterID = player:GetGUIDLow()
	local allocations = ParagonV2.GetAllocations(characterID)
	local current = allocations[statId] or 0

	-- Check if there's anything to remove
	if current <= 0 then
		return
	end

	-- Clamp amount to current allocation
	if amount > current then amount = current end

	-- Remove aura stacks
	local newValue = current - amount
	if newValue == 0 then
		player:RemoveAura(stat.auraId)
	else
		local aura = player:GetAura(stat.auraId)
		if aura then
			aura:SetStackAmount(newValue)
		end
	end

	-- Refund Paragon Point items
	player:AddItem(ParagonV2.CURRENCY_ITEM_ID, amount)

	-- Update DB (async) and send known values to client immediately
	ParagonV2.UpdateAllocation(characterID, stat.dbColumn, newValue)
	allocations[statId] = newValue
	local availablePoints = ParagonV2.GetAvailablePoints(player)
	AIO.Handle(player, "PARAGON_V2_CLIENT", "UpdatePoints",
		allocations, availablePoints)
end
