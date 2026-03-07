--[[
    Paragon System v2 - Client UI
    Complete UI for stat allocation, sent to WoW client via AIO.
]]

local AIO = AIO or require("AIO")

-- Register as AIO addon; server-side execution stops here.
if AIO.AddAddon() then
	return
end

---------------------------------------------------------------------------
-- Handler table
---------------------------------------------------------------------------
local Client = AIO.AddHandlers("PARAGON_V2_CLIENT", {})

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local categories = {}       -- received from server
local stats = {}            -- received from server
local allocations = {}      -- stat ID -> current points
local availablePoints = 0
local selectedCategoryId = 1
local initialized = false

-- Lookup: categoryId -> list of stats
local statsByCategory = {}

---------------------------------------------------------------------------
-- Style constants
---------------------------------------------------------------------------
local COLORS = {
	gold       = { 1.0, 0.82, 0.0 },
	white      = { 1.0, 1.0, 1.0 },
	gray       = { 0.5, 0.5, 0.5 },
	dark       = { 0.08, 0.08, 0.08 },
	darkPanel  = { 0.12, 0.12, 0.12 },
	green      = { 0.1, 0.8, 0.1 },
	red        = { 0.8, 0.1, 0.1 },
	highlight  = { 0.2, 0.2, 0.2 },
	selected   = { 0.18, 0.18, 0.25 },
}

local BACKDROP_MAIN = {
	bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	tile     = true,
	tileSize = 16,
	edgeSize = 16,
	insets   = { left = 4, right = 4, top = 4, bottom = 4 },
}

local BACKDROP_PANEL = {
	bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	tile     = true,
	tileSize = 16,
	edgeSize = 12,
	insets   = { left = 3, right = 3, top = 3, bottom = 3 },
}

local FRAME_WIDTH  = 620
local FRAME_HEIGHT = 440
local TAB_WIDTH    = 150
local TAB_HEIGHT   = 36
local ROW_HEIGHT   = 48
local ICON_SIZE    = 32
local BTN_SIZE     = 24

---------------------------------------------------------------------------
-- Frame references
---------------------------------------------------------------------------
local mainFrame
local titleText
local tabButtons = {}
local statRows = {}
local pointsText
local contentPanel

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function SetColor(fontString, colorKey)
	local c = COLORS[colorKey]
	fontString:SetTextColor(c[1], c[2], c[3])
end

local function CreateIcon(parent, size, texturePath)
	local icon = parent:CreateTexture(nil, "ARTWORK")
	icon:SetSize(size, size)
	icon:SetTexture(texturePath)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	return icon
end

---------------------------------------------------------------------------
-- Main Frame
---------------------------------------------------------------------------
local function CreateMainFrame()
	mainFrame = CreateFrame("Frame", "ParagonV2Frame", UIParent)
	mainFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	mainFrame:SetBackdrop(BACKDROP_MAIN)
	mainFrame:SetBackdropColor(COLORS.dark[1], COLORS.dark[2], COLORS.dark[3], 0.95)
	mainFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	mainFrame:SetMovable(true)
	mainFrame:EnableMouse(true)
	mainFrame:RegisterForDrag("LeftButton")
	mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
	mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
	mainFrame:SetFrameStrata("DIALOG")
	mainFrame:SetClampedToScreen(true)
	mainFrame:Hide()

	-- ESC closes
	table.insert(UISpecialFrames, "ParagonV2Frame")

	-- Title
	titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	titleText:SetPoint("TOP", mainFrame, "TOP", 0, -12)
	titleText:SetText("Paragon System")
	SetColor(titleText, "gold")

	-- Close button
	local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -2, -2)

	-- Divider line between tabs and content
	local divider = mainFrame:CreateTexture(nil, "ARTWORK")
	divider:SetSize(1, FRAME_HEIGHT - 80)
	divider:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", TAB_WIDTH + 14, -40)
	divider:SetTexture(0.4, 0.4, 0.4, 0.5)

	-- Content panel (right side)
	contentPanel = CreateFrame("Frame", nil, mainFrame)
	contentPanel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", TAB_WIDTH + 20, -40)
	contentPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 40)

	-- Bottom bar: available points
	pointsText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	pointsText:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 14)
	SetColor(pointsText, "gold")
	pointsText:SetText("Available Points: 0")
end

---------------------------------------------------------------------------
-- Category Tabs (left sidebar)
---------------------------------------------------------------------------
local function SelectCategory(catId)
	selectedCategoryId = catId
	RefreshTabs()
	RefreshStats()
end

local function CreateCategoryTab(index, cat)
	local btn = CreateFrame("Button", nil, mainFrame)
	btn:SetSize(TAB_WIDTH, TAB_HEIGHT)
	btn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -40 - (index - 1) * (TAB_HEIGHT + 4))

	-- Background
	btn.bg = btn:CreateTexture(nil, "BACKGROUND")
	btn.bg:SetAllPoints()
	btn.bg:SetTexture(COLORS.darkPanel[1], COLORS.darkPanel[2], COLORS.darkPanel[3], 0.8)

	-- Highlight
	btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
	btn.highlight:SetAllPoints()
	btn.highlight:SetTexture(COLORS.highlight[1], COLORS.highlight[2], COLORS.highlight[3], 0.5)

	-- Icon
	btn.icon = CreateIcon(btn, 20, cat.icon)
	btn.icon:SetPoint("LEFT", btn, "LEFT", 8, 0)

	-- Text
	btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 8, 0)
	btn.text:SetText(cat.name)
	btn.text:SetJustifyH("LEFT")
	SetColor(btn.text, "white")

	btn.categoryId = cat.id
	btn:SetScript("OnClick", function()
		SelectCategory(cat.id)
	end)

	tabButtons[index] = btn
end

function RefreshTabs()
	for _, btn in ipairs(tabButtons) do
		if btn.categoryId == selectedCategoryId then
			btn.bg:SetTexture(COLORS.selected[1], COLORS.selected[2], COLORS.selected[3], 1)
			SetColor(btn.text, "gold")
		else
			btn.bg:SetTexture(COLORS.darkPanel[1], COLORS.darkPanel[2], COLORS.darkPanel[3], 0.8)
			SetColor(btn.text, "white")
		end
	end
end

---------------------------------------------------------------------------
-- Stat Rows (right side content)
---------------------------------------------------------------------------
local MAX_VISIBLE_ROWS = 8

local function CreateStatRow(index)
	local row = CreateFrame("Frame", nil, contentPanel)
	row:SetSize(contentPanel:GetWidth() or (FRAME_WIDTH - TAB_WIDTH - 30), ROW_HEIGHT)
	row:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 0, -(index - 1) * (ROW_HEIGHT + 4))

	-- Row backdrop
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.bg:SetTexture(COLORS.darkPanel[1], COLORS.darkPanel[2], COLORS.darkPanel[3], 0.6)

	-- Icon
	row.icon = CreateIcon(row, ICON_SIZE, "Interface/Icons/INV_Misc_QuestionMark")
	row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)

	-- Stat name
	row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 10, 6)
	row.nameText:SetJustifyH("LEFT")
	SetColor(row.nameText, "white")

	-- Tooltip text
	row.tooltipText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.tooltipText:SetPoint("LEFT", row.icon, "RIGHT", 10, -8)
	row.tooltipText:SetJustifyH("LEFT")
	SetColor(row.tooltipText, "gray")

	-- Points display: "X / MAX"
	row.pointsText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.pointsText:SetPoint("RIGHT", row, "RIGHT", -70, 0)
	row.pointsText:SetJustifyH("RIGHT")
	SetColor(row.pointsText, "gold")

	-- Minus button
	row.minusBtn = CreateFrame("Button", nil, row)
	row.minusBtn:SetSize(BTN_SIZE, BTN_SIZE)
	row.minusBtn:SetPoint("RIGHT", row, "RIGHT", -38, 0)

	row.minusBtn.bg = row.minusBtn:CreateTexture(nil, "BACKGROUND")
	row.minusBtn.bg:SetAllPoints()
	row.minusBtn.bg:SetTexture(COLORS.red[1], COLORS.red[2], COLORS.red[3], 0.7)

	row.minusBtn.text = row.minusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.minusBtn.text:SetPoint("CENTER")
	row.minusBtn.text:SetText("-")
	SetColor(row.minusBtn.text, "white")

	row.minusBtn.highlight = row.minusBtn:CreateTexture(nil, "HIGHLIGHT")
	row.minusBtn.highlight:SetAllPoints()
	row.minusBtn.highlight:SetTexture(1, 1, 1, 0.15)

	-- Plus button
	row.plusBtn = CreateFrame("Button", nil, row)
	row.plusBtn:SetSize(BTN_SIZE, BTN_SIZE)
	row.plusBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)

	row.plusBtn.bg = row.plusBtn:CreateTexture(nil, "BACKGROUND")
	row.plusBtn.bg:SetAllPoints()
	row.plusBtn.bg:SetTexture(COLORS.green[1], COLORS.green[2], COLORS.green[3], 0.7)

	row.plusBtn.text = row.plusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.plusBtn.text:SetPoint("CENTER")
	row.plusBtn.text:SetText("+")
	SetColor(row.plusBtn.text, "white")

	row.plusBtn.highlight = row.plusBtn:CreateTexture(nil, "HIGHLIGHT")
	row.plusBtn.highlight:SetAllPoints()
	row.plusBtn.highlight:SetTexture(1, 1, 1, 0.15)

	-- Store stat ID on the row
	row.statId = nil

	-- Click handlers
	row.plusBtn:SetScript("OnClick", function()
		if row.statId then
			AIO.Handle("PARAGON_V2_SERVER", "AllocatePoint", row.statId)
		end
	end)

	row.minusBtn:SetScript("OnClick", function()
		if row.statId then
			AIO.Handle("PARAGON_V2_SERVER", "DeallocatePoint", row.statId)
		end
	end)

	row:Hide()
	statRows[index] = row
end

function RefreshStats()
	local catStats = statsByCategory[selectedCategoryId] or {}

	for i = 1, MAX_VISIBLE_ROWS do
		local row = statRows[i]
		if not row then break end

		local stat = catStats[i]
		if stat then
			row.statId = stat.id
			row.icon:SetTexture(stat.icon)
			row.nameText:SetText(stat.name)
			row.tooltipText:SetText(stat.tooltip)

			local current = allocations[stat.id] or 0
			local max = stat.maxPoints
			row.pointsText:SetText(current .. " / " .. max)

			-- Color the points text based on allocation
			if current >= max then
				SetColor(row.pointsText, "gold")
			elseif current > 0 then
				SetColor(row.pointsText, "green")
			else
				SetColor(row.pointsText, "gray")
			end

			-- Disable buttons at boundaries
			if current >= max then
				row.plusBtn.bg:SetTexture(COLORS.gray[1], COLORS.gray[2], COLORS.gray[3], 0.3)
			else
				row.plusBtn.bg:SetTexture(COLORS.green[1], COLORS.green[2], COLORS.green[3], 0.7)
			end

			if current <= 0 then
				row.minusBtn.bg:SetTexture(COLORS.gray[1], COLORS.gray[2], COLORS.gray[3], 0.3)
			else
				row.minusBtn.bg:SetTexture(COLORS.red[1], COLORS.red[2], COLORS.red[3], 0.7)
			end

			row:Show()
		else
			row:Hide()
		end
	end

	-- Update points display
	pointsText:SetText("Available Points: " .. availablePoints)
end

---------------------------------------------------------------------------
-- Build UI once categories/stats are known
---------------------------------------------------------------------------
local function BuildUI()
	if initialized then return end
	initialized = true

	CreateMainFrame()

	-- Create category tabs
	for i, cat in ipairs(categories) do
		CreateCategoryTab(i, cat)
	end

	-- Create stat rows (pool)
	for i = 1, MAX_VISIBLE_ROWS do
		CreateStatRow(i)
	end

	-- Select first category
	if #categories > 0 then
		selectedCategoryId = categories[1].id
	end

	RefreshTabs()
	RefreshStats()
end

---------------------------------------------------------------------------
-- AIO Client Handlers
---------------------------------------------------------------------------

--- Receive full data from server (on first open).
function Client.ReceiveData(player, cats, sts, allocs, points)
	categories = cats
	stats = sts
	allocations = allocs
	availablePoints = points

	-- Build lookup
	statsByCategory = {}
	for _, stat in ipairs(stats) do
		if not statsByCategory[stat.categoryId] then
			statsByCategory[stat.categoryId] = {}
		end
		table.insert(statsByCategory[stat.categoryId], stat)
	end

	BuildUI()
	RefreshTabs()
	RefreshStats()
	mainFrame:Show()
end

--- Receive updated points after allocate/deallocate.
function Client.UpdatePoints(player, allocs, points)
	allocations = allocs
	availablePoints = points
	RefreshStats()
end

--- Play a sound effect (e.g., "not enough points").
function Client.PlaySound(player, soundId)
	PlaySoundFile(soundId)
end

---------------------------------------------------------------------------
-- Game Menu Integration
---------------------------------------------------------------------------
local function AddParagonToGameMenu()
	local menuBtn = CreateFrame("Button", "GameMenuButtonParagonV2", GameMenuFrame, "GameMenuButtonTemplate")
	menuBtn:SetText("Paragon")
	menuBtn:SetPoint("TOP", GameMenuButtonLogout, "BOTTOM", 0, -2)

	menuBtn:SetScript("OnClick", function()
		HideUIPanel(GameMenuFrame)
		-- Request data from server, which will trigger ReceiveData -> Show
		AIO.Handle("PARAGON_V2_SERVER", "RequestData")
	end)

	-- Shift the existing buttons down to make room
	GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + menuBtn:GetHeight() + 2)
end

-- Hook into game menu creation
local menuHook = CreateFrame("Frame")
menuHook:RegisterEvent("PLAYER_LOGIN")
menuHook:SetScript("OnEvent", function()
	AddParagonToGameMenu()
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
SLASH_PARAGONV2_1 = "/paragon"
SlashCmdList["PARAGONV2"] = function()
	AIO.Handle("PARAGON_V2_SERVER", "RequestData")
end
