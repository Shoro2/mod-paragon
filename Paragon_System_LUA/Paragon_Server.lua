--[[
    Paragon System - Server Handlers
    Handles point allocation/deallocation and data sync.
    This file is server-only (no AIO.AddAddon).

    Stat application lives entirely in C++ (single source of truth). After a DB
    write, we cast the hidden reapply-trigger spell so the C++ SpellScript
    re-derives and applies the player's stats.
]]

local AIO = AIO or require("AIO")

-- Optional shared validation lib (share-public/AIO_Server/Dep_Validation/).
-- Eluna loads scripts alphabetically, so `Dep_*` is available before
-- `Paragon_*`. If the lib is missing, fall back to permissive shims + warn.
local Validate = _G.Validate
if not Validate then
	print("[Paragon] WARNING: Dep_Validation/validation.lua not loaded — "
		.. "input validation runs permissive. Deploy "
		.. "share-public/AIO_Server/Dep_Validation/ to lua_scripts/.")
	Validate = {
		IsIntInRange = function(v, lo, hi)
			return type(v) == "number" and v == math.floor(v)
				and v >= lo and v <= hi
		end,
		IsPositiveInt = function(v, cap)
			return type(v) == "number" and v == math.floor(v)
				and v >= 1 and v <= (cap or 2147483647)
		end,
		Reject = function(player, handler, reason)
			print(string.format("[Validate] reject handler=%s reason=%s",
				tostring(handler), tostring(reason)))
			return false
		end,
	}
end

-- Hard cap for the client-supplied amount. Allocation is clamped to
-- unspent_points anyway; this just rejects absurd values early.
local MAX_AMOUNT = 666

local Handlers = AIO.AddHandlers("PARAGON_SERVER", {})

--- Build the serializable stats/categories config to send to the client.
-- Strips server-only fields (dbColumn) from the data.
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
	-- Server-side validation: never trust client args.
	if not Validate.IsIntInRange(statId, 1, #Paragon.STATS) then
		return Validate.Reject(player, "AllocatePoint", "statId out of range")
	end
	if amount == nil then amount = 1 end
	if not Validate.IsPositiveInt(amount, MAX_AMOUNT) then
		return Validate.Reject(player, "AllocatePoint",
			"amount not a positive int <= " .. MAX_AMOUNT)
	end

	local stat = Paragon.STAT_BY_ID[statId]
	if not stat then
		player:SendBroadcastMessage("Invalid stat.")
		return
	end

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

	local newValue = current + amount
	local newUnspent = unspent - amount

	-- Atomic synchronous DB write first, then trigger the C++ reapply so it
	-- reads a consistent row. C++ owns stat application.
	Paragon.UpdateAllocationAndUnspent(characterID, stat.dbColumn, newValue, newUnspent)
	player:CastSpell(player, Paragon.REAPPLY_SPELL, true)

	allocations[statId] = newValue
	AIO.Handle(player, "PARAGON_CLIENT", "UpdatePoints",
		allocations, newUnspent)
end

--- Deallocate points from a stat.
-- @param player Player object (injected by AIO)
-- @param statId number - the stat to deallocate from
-- @param amount number - how many points to deallocate (default 1)
function Handlers.DeallocatePoint(player, statId, amount)
	-- Server-side validation: never trust client args.
	if not Validate.IsIntInRange(statId, 1, #Paragon.STATS) then
		return Validate.Reject(player, "DeallocatePoint", "statId out of range")
	end
	if amount == nil then amount = 1 end
	if not Validate.IsPositiveInt(amount, MAX_AMOUNT) then
		return Validate.Reject(player, "DeallocatePoint",
			"amount not a positive int <= " .. MAX_AMOUNT)
	end

	local stat = Paragon.STAT_BY_ID[statId]
	if not stat then
		player:SendBroadcastMessage("Invalid stat.")
		return
	end

	local characterID = player:GetGUIDLow()
	local allocations, unspent = Paragon.GetAllocations(characterID)
	local current = allocations[statId] or 0

	-- Check if there's anything to remove
	if current <= 0 then
		return
	end

	-- Clamp amount to current allocation
	if amount > current then amount = current end

	local newValue = current - amount
	local newUnspent = unspent + amount

	-- Atomic synchronous DB write first, then trigger the C++ reapply.
	Paragon.UpdateAllocationAndUnspent(characterID, stat.dbColumn, newValue, newUnspent)
	player:CastSpell(player, Paragon.REAPPLY_SPELL, true)

	allocations[statId] = newValue
	AIO.Handle(player, "PARAGON_CLIENT", "UpdatePoints",
		allocations, newUnspent)
end
