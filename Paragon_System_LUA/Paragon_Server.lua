--[[
    Paragon System - Server Handlers
    Handles point allocation/deallocation and data sync.
    This file is server-only (no AIO.AddAddon).
]]

local AIO = AIO or require("AIO")

local Handlers = AIO.AddHandlers("PARAGON_SERVER", {})

--- Apply big+small aura pair for a stat.
-- Each big stack = 100 small stacks, staying within the 255-stack limit.
-- @param player  Player object
-- @param stat    Stat table (must have auraId and bigAuraId)
-- @param value   Total allocated points (0 to remove)
local function ApplyStatAuras(player, stat, value)
	-- Always remove both auras first
	player:RemoveAura(stat.auraId)
	player:RemoveAura(stat.bigAuraId)

	if value <= 0 then return end

	local bigStacks  = math.floor(value / 100)
	local smallStacks = value % 100

	if bigStacks > 0 then
		player:AddAura(stat.bigAuraId, player)
		local aura = player:GetAura(stat.bigAuraId)
		if aura then
			aura:SetStackAmount(bigStacks)
		end
	end

	if smallStacks > 0 then
		player:AddAura(stat.auraId, player)
		local aura = player:GetAura(stat.auraId)
		if aura then
			aura:SetStackAmount(smallStacks)
		end
	end
end

--- Build the serializable stats/categories config to send to the client.
-- Strips server-only fields (dbColumn, auraId) from the data.
local function BuildClientConfig()
	local categories = {}
	for _, cat in ipairs(Paragon.CATEGORIES) do
		table.insert(categories, {
			id = cat.id,
			name = cat.name,
			icon = cat.icon,
		})
	end

	local stats = {}
	for _, stat in ipairs(Paragon.STATS) do
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
	local allocations, unspent = Paragon.GetAllocations(characterID)

	AIO.Handle(player, "PARAGON_CLIENT", "ReceiveData",
		categories, stats, allocations, unspent)
end

--- Allocate points into a stat.
-- @param player Player object (injected by AIO)
-- @param statId number - the stat to allocate into
-- @param amount number - how many points to allocate (default 1)
function Handlers.AllocatePoint(player, statId, amount)
	local stat = Paragon.STAT_BY_ID[statId]
	if not stat then
		player:SendBroadcastMessage("Invalid stat.")
		return
	end

	amount = tonumber(amount) or 1
	if amount < 1 then return end

	local characterID = player:GetGUIDLow()
	local allocations, unspent = Paragon.GetAllocations(characterID)
	local current = allocations[statId] or 0

	-- Check max points
	if current >= stat.maxPoints then
		player:SendBroadcastMessage(stat.name .. " is already at maximum.")
		return
	end

	-- Check available points
	if unspent < 1 then
		local soundId = Paragon.GetSoundEffect(player)
		AIO.Handle(player, "PARAGON_CLIENT", "PlaySound", soundId)
		return
	end

	-- Clamp amount to what's actually possible
	local maxCanAllocate = stat.maxPoints - current
	if amount > maxCanAllocate then amount = maxCanAllocate end
	if amount > unspent then amount = unspent end

	-- Apply big+small aura pair
	local newValue = current + amount
	ApplyStatAuras(player, stat, newValue)

	-- Update DB (async) and send known values to client immediately
	local newUnspent = unspent - amount
	Paragon.UpdateAllocation(characterID, stat.dbColumn, newValue)
	Paragon.UpdateUnspentPoints(characterID, newUnspent)
	allocations[statId] = newValue
	AIO.Handle(player, "PARAGON_CLIENT", "UpdatePoints",
		allocations, newUnspent)
end

--- Deallocate points from a stat.
-- @param player Player object (injected by AIO)
-- @param statId number - the stat to deallocate from
-- @param amount number - how many points to deallocate (default 1)
function Handlers.DeallocatePoint(player, statId, amount)
	local stat = Paragon.STAT_BY_ID[statId]
	if not stat then
		player:SendBroadcastMessage("Invalid stat.")
		return
	end

	amount = tonumber(amount) or 1
	if amount < 1 then return end

	local characterID = player:GetGUIDLow()
	local allocations, unspent = Paragon.GetAllocations(characterID)
	local current = allocations[statId] or 0

	-- Check if there's anything to remove
	if current <= 0 then
		return
	end

	-- Clamp amount to current allocation
	if amount > current then amount = current end

	-- Apply big+small aura pair (or remove if zero)
	local newValue = current - amount
	ApplyStatAuras(player, stat, newValue)

	-- Update DB (async) and send known values to client immediately
	local newUnspent = unspent + amount
	Paragon.UpdateAllocation(characterID, stat.dbColumn, newValue)
	Paragon.UpdateUnspentPoints(characterID, newUnspent)
	allocations[statId] = newValue
	AIO.Handle(player, "PARAGON_CLIENT", "UpdatePoints",
		allocations, newUnspent)
end
