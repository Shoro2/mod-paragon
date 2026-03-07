-- Paragon System - Client UI
-- AIO-based UI for allocating paragon stat points.

local CONFIG = {
	maxCategories = 11,
	strings = {
		categoryAccessDenied = "You do not have access to this category!",
	}
}

--------------------

local AIO = AIO or require("AIO")
if AIO.AddAddon() then
	return
end

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
		displayId		= 10,
		discount		= 11,
		flags			= 12,
		reward_1		= 13,
	},
}

local scaleMulti = 0.85

-- Helpers --

local function CoordsToTexCoords(size, xTop, yTop, xBottom, yBottom)
	local magic = (1/size)/2
	local Top = (yTop/size) + magic
	local Left = (xTop/size) + magic
	local Bottom = (yBottom/size) - magic
	local Right = (xBottom/size) - magic

	return Left, Right, Top, Bottom
end

------------

local ParagonHandler = AIO.AddHandlers("PARAGON_CLIENT", {})

function ParagonHandler.FrameData(services, links, nav, currencies, rank, paragonData)
	PARAGON_UI["Data"].services = services or {}
	PARAGON_UI["Data"].links = links or {}
	PARAGON_UI["Data"].nav = nav or {}
	PARAGON_UI["Data"].currencies = currencies or {}
	PARAGON_UI["Vars"].accountRank = rank or 0
	PARAGON_UI["Vars"].paragonData = paragonData or {}
	PARAGON_UI["Vars"].dataLoaded = true
	PARAGON_UI.NavButtons_OnData()
	PARAGON_UI.CurrencyBadges_OnData()
	PARAGON_UI.ServiceBoxes_OnData()
end

function ParagonHandler.UpdateCurrencies(currencies, paragonData)
	if currencies then
		for k, v in pairs(currencies) do
			PARAGON_UI["Vars"]["playerCurrencies"][k] = v
		end
	end
	if paragonData then
		PARAGON_UI["Vars"].paragonData = paragonData
	end
	PARAGON_UI.CurrencyBadges_Update()
	PARAGON_UI.ServiceBoxes_Update()
end


PARAGON_UI = {
	["Vars"] = {
		currentCategory = 1,
		currentCategoryFlags = 0,
		currentNavId = 1,
		currentPage = 1,
		maxPages = 1,
		accountRank = 0,
		dataLoaded = false,
		paragonData = {},
		["playerCurrencies"] = {}
	},
	["Data"] = {
		nav = {},
		services = {},
		links = {},
		currencies = {}
	}
}

-- Paragon(MainFrame) --
function PARAGON_UI.MainFrame_Create()
	local mainFrame = CreateFrame("Frame", "PARAGON_FRAME", UIParent)
	mainFrame:SetPoint("LEFT", 40, 0)
	mainFrame:Hide()

	mainFrame:SetSize(1024*scaleMulti, 658*scaleMulti)

	-- Background texture
	mainFrame.Background = mainFrame:CreateTexture(nil, "BACKGROUND")
	mainFrame.Background:SetSize(mainFrame:GetSize())
	mainFrame.Background:SetPoint("CENTER", mainFrame, "CENTER")
	mainFrame.Background:SetTexture("Interface/Store_UI/Frames/StoreFrame_Main")
	mainFrame.Background:SetTexCoord(CoordsToTexCoords(1024, 0, 0, 1024, 658))

	-- Title
	mainFrame.Title = mainFrame:CreateFontString()
	mainFrame.Title:SetFont("Fonts\\FRIZQT__.TTF", 14)
	mainFrame.Title:SetShadowOffset(1, -1)
	mainFrame.Title:SetPoint("TOP", mainFrame, "TOP", 0, -3)
	mainFrame.Title:SetText("|cffedd100Character Upgrades|r")

	PARAGON_UI.NavButtons_Create(mainFrame)
	PARAGON_UI.PageButtons_Create(mainFrame)
	PARAGON_UI.ServiceBoxes_Create(mainFrame)
	PARAGON_UI.CurrencyBadges_Create(mainFrame)

	-- Request all data from server
	AIO.Handle("PARAGON_SERVER", "FrameData")
	AIO.Handle("PARAGON_SERVER", "UpdateCurrencies")

	if MainMenuMicroButton then
		MainMenuMicroButton:SetScript(
			"OnClick",
			function()
				if GameMenuFrame and GameMenuFrame:IsShown() then
					MainFrame_Toggle()
				end
			end
		)
	end

	mainFrame.CloseButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
	mainFrame.CloseButton:SetSize(30, 30)
	mainFrame.CloseButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 5, 5)
	mainFrame.CloseButton:EnableMouse(true)
	mainFrame.CloseButton:SetScript(
		"OnClick",
		function()
			MainFrame_Toggle()
		end
	)

	mainFrame:SetScript(
		"OnShow",
		function()
			AIO.Handle("PARAGON_SERVER", "UpdateCurrencies")
			PlaySound("AuctionWindowOpen", "Master")
		end
	)

	mainFrame:SetScript(
		"OnHide",
		function()
			PlaySound("AuctionWindowClose", "Master")
		end
	)

	tinsert(UISpecialFrames, mainFrame:GetName())

	PARAGON_UI["FRAME"] = mainFrame
end

-- Navigation buttons
function PARAGON_UI.NavButtons_Create(parent)
	PARAGON_UI["NAV_BUTTONS"] = {}
	local offset = 0
	for i = 1, 12 do
		local navButton = CreateFrame("Button", nil, parent)
		navButton.NavId = i

		local size = 220
		navButton:SetSize(size*scaleMulti, (size/4)*scaleMulti)
		navButton:SetPoint("LEFT", parent, "LEFT", 14, 195+offset)

		navButton:SetNormalTexture("Interface/Store_UI/Frames/StoreFrame_Main")
		navButton:SetHighlightTexture("Interface/Store_UI/Frames/StoreFrame_Main")
		navButton:GetNormalTexture():SetTexCoord(CoordsToTexCoords(1024, 768, 897, 1023, 960))
		navButton:GetHighlightTexture():SetTexCoord(CoordsToTexCoords(1024, 768, 960, 1023, 1023))

		navButton.Name = navButton:CreateFontString()
		navButton.Name:SetFont("Fonts\\FRIZQT__.TTF", 14)
		navButton.Name:SetShadowOffset(1, -1)
		navButton.Name:SetPoint("CENTER", navButton, "CENTER", 5, 0)

		navButton.Icon = navButton:CreateTexture(nil, "BACKGROUND")
		navButton.Icon:SetSize(31, 31)
		navButton.Icon:SetPoint("LEFT", navButton, "LEFT", 6, -1)

		offset = offset - 40

		navButton:SetScript("OnClick", PARAGON_UI.NavButtons_OnClick)

		PARAGON_UI["NAV_BUTTONS"][i] = navButton
		navButton:Hide()
	end
end

function PARAGON_UI.NavButtons_OnClick(self)
	if(self.RequiredRank > PARAGON_UI["Vars"].accountRank) then
		UIErrorsFrame:AddMessage(CONFIG.strings.categoryAccessDenied, 1.0, 0.0, 0.0, 2);
		PlaySound("igPlayerInviteDecline", "Master")
		return;
	end

	PlaySound("uChatScrollButton", "Master")
	PARAGON_UI["Vars"].currentCategory = self.CategoryId
	PARAGON_UI["Vars"].currentCategoryFlags = self.CategoryFlags
	PARAGON_UI["Vars"].currentNavId = self.NavId
	PARAGON_UI["Vars"].currentPage = 1

	PARAGON_UI.NavButtons_UpdateSelect()
	PARAGON_UI.ServiceBoxes_Update()
	PARAGON_UI.PageButtons_Update()
end

function PARAGON_UI.NavButtons_UpdateSelect()
	for i = 1, CONFIG.maxCategories do
		PARAGON_UI["NAV_BUTTONS"][i]:UnlockHighlight()
	end

	PARAGON_UI["NAV_BUTTONS"][PARAGON_UI["Vars"].currentNavId]:LockHighlight()
end

function PARAGON_UI.NavButtons_OnData()
	local index = 1

	for _, v in pairs(PARAGON_UI["Data"].nav) do
		if index > CONFIG.maxCategories then
			break
		end

		if(v[KEYS.category.enabled] == 1) then
			local button = PARAGON_UI["NAV_BUTTONS"][index]
			button.CategoryId = v[KEYS.category.id]
			button.NameText = v[KEYS.category.name]
			button.IconTexture = v[KEYS.category.icon]
			button.RequiredRank = v[KEYS.category.requiredRank]
			button.CategoryFlags = v[KEYS.category.flags]

			button.Icon:SetTexture("Interface/Icons/" .. button.IconTexture .. ".blp")
			button.Name:SetFormattedText("|cffdbe005%s|r", button.NameText)

			button:Show()
			index = index + 1
		end
	end

	local button = PARAGON_UI["NAV_BUTTONS"][1]
	if button and button.CategoryId then
		PARAGON_UI["Vars"].currentCategory = button.CategoryId
		PARAGON_UI["Vars"].currentCategoryFlags = button.CategoryFlags or 0
		PARAGON_UI["Vars"].currentNavId = button.NavId or 1
	end

	PARAGON_UI.NavButtons_UpdateSelect()
end

-- Aura ID to paragon data index mapping
local AURA_TO_PARAGON_INDEX = {
	[100001] = 1, -- Strength
	[100002] = 2, -- Intellect
	[100003] = 3, -- Agility
	[100004] = 4, -- Spirit
	[100005] = 5, -- Stamina
}

-- Service boxes (stat allocation cards)
function PARAGON_UI.ServiceBoxes_Create(parent)
	PARAGON_UI["SERVICE_BUTTONS"] = {}
	for i = 1, 8 do
		local service = CreateFrame("Button", nil, parent)

		service.ServiceId = 0
		service.Name = ""
		service.TooltipName = nil
		service.TooltipText = nil
		service.TooltipType = ""

		-- Determine box coordinates (4x2 grid)
		local row1_y = 100
		local row2_y = -135
		local x_offsets = {-140, 20, 180, 340}
		local BoxCoordX, BoxCoordY
		if i <= 4 then
			BoxCoordY = row1_y
		else
			BoxCoordY = row2_y
		end
		BoxCoordX = x_offsets[(i - 1) % 4 + 1]

		service:SetSize(150, 230)
		service:SetPoint("CENTER", parent, "CENTER", BoxCoordX, BoxCoordY)
		service:SetNormalTexture("Interface/Store_UI/Frames/StoreFrame_Main")
		service:SetHighlightTexture("Interface/Store_UI/Frames/StoreFrame_Main")
		service:GetNormalTexture():SetTexCoord(CoordsToTexCoords(1024, 0, 658, 215, 1023))
		service:GetHighlightTexture():SetTexCoord(CoordsToTexCoords(1024, 215, 658, 430, 1023))

		-- Icon
		service.Icon = service:CreateTexture(nil, "BACKGROUND")
		service.Icon:SetSize(40, 40)
		service.Icon:SetPoint("CENTER", service, "CENTER", 0, 64)

		-- Stat name
		service.NameFont = service:CreateFontString()
		service.NameFont:SetFont("Fonts\\FRIZQT__.TTF", 11)
		service.NameFont:SetShadowOffset(1, -1)
		service.NameFont:SetPoint("CENTER", service, "CENTER", 0, 16)

		-- Cost display
		service.PriceFont = service:CreateFontString()
		service.PriceFont:SetFont("Fonts\\FRIZQT__.TTF", 13)
		service.PriceFont:SetShadowOffset(1, -1)
		service.PriceFont:SetPoint("CENTER", service, "CENTER", -3, -30)

		-- Cost currency icon
		service.currencyIcon = service:CreateTexture(nil, "OVERLAY")
		service.currencyIcon:SetSize(18, 18)
		service.currencyIcon:SetPoint("LEFT", service.PriceFont, "RIGHT", 0, 0)

		-- Allocated points display
		service.ParagonDisplay = service:CreateFontString()
		service.ParagonDisplay:SetFont("Fonts\\FRIZQT__.TTF", 11)
		service.ParagonDisplay:SetShadowOffset(1, -1)
		service.ParagonDisplay:SetPoint("CENTER", service, "CENTER", 0, -65)

		-- Plus button (allocate point)
		service.buyButton = CreateFrame("Button", nil, service)
		service.buyButton:SetSize(20, 20)
		service.buyButton:SetPoint("CENTER", service, "CENTER", -25, -85)
		service.buyButton:SetNormalTexture("Interface/Store_UI/Frames/StoreFrame_Main")
		service.buyButton:SetHighlightTexture("Interface/Store_UI/Frames/StoreFrame_Main")
		service.buyButton:SetPushedTexture("Interface/Store_UI/Frames/StoreFrame_Main")
		service.buyButton:GetNormalTexture():SetTexCoord(CoordsToTexCoords(1024, 709, 849, 837, 873))
		service.buyButton:GetHighlightTexture():SetTexCoord(CoordsToTexCoords(1024, 709, 849, 837, 873))
		service.buyButton:GetPushedTexture():SetTexCoord(CoordsToTexCoords(1024, 709, 873, 837, 897))

		service.buyButton.ButtonText = service.buyButton:CreateFontString()
		service.buyButton.ButtonText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
		service.buyButton.ButtonText:SetPoint("CENTER", service.buyButton, 0, 0)
		service.buyButton.ButtonText:SetText(" + ")

		service.buyButton:SetScript(
			"OnClick",
			function(self)
				AIO.Handle("PARAGON_SERVER", "AllocatePoint", self:GetParent().ServiceId)
				PlaySound("STORE_CONFIRM", "Master")
			end
		)

		-- Minus button (deallocate point)
		service.sellButton = CreateFrame("Button", nil, service)
		service.sellButton:SetSize(20, 20)
		service.sellButton:SetPoint("CENTER", service, "CENTER", 25, -85)
		service.sellButton:SetNormalTexture("Interface/Store_UI/Frames/StoreFrame_Main")
		service.sellButton:SetHighlightTexture("Interface/Store_UI/Frames/StoreFrame_Main")
		service.sellButton:SetPushedTexture("Interface/Store_UI/Frames/StoreFrame_Main")
		service.sellButton:GetNormalTexture():SetTexCoord(CoordsToTexCoords(1024, 709, 849, 837, 873))
		service.sellButton:GetHighlightTexture():SetTexCoord(CoordsToTexCoords(1024, 709, 849, 837, 873))
		service.sellButton:GetPushedTexture():SetTexCoord(CoordsToTexCoords(1024, 709, 873, 837, 897))

		service.sellButton.ButtonText = service.sellButton:CreateFontString()
		service.sellButton.ButtonText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
		service.sellButton.ButtonText:SetPoint("CENTER", service.sellButton, 0, 0)
		service.sellButton.ButtonText:SetText(" - ")

		service.sellButton:SetScript(
			"OnClick",
			function(self)
				AIO.Handle("PARAGON_SERVER", "DeallocatePoint", self:GetParent().ServiceId)
				PlaySound("STORE_CONFIRM", "Master")
			end
		)

		-- Tooltip
		service:SetScript(
			"OnEnter",
			function(self)
				if(self.TooltipName or self.TooltipText) then
					GameTooltip:SetOwner(self, "ANCHOR_NONE")
					GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, 0)
					if(self.TooltipName) then
						GameTooltip:AddLine("|cffffffff" .. self.TooltipName .. "|r")
					end
					if(self.TooltipText) then
						GameTooltip:AddLine(self.TooltipText)
					end
					GameTooltip:Show()
				end
			end
		)

		service:SetScript(
			"OnLeave",
			function(self)
				GameTooltip:Hide()
			end
		)

		service:Hide()
		PARAGON_UI["SERVICE_BUTTONS"][i] = service
	end
end

local function GetCategoryServiceIds()
	local services = {}

	for k, v in pairs(PARAGON_UI["Data"].links) do
		if(v[1] == PARAGON_UI["Vars"].currentCategory) then
			table.insert(services, v[2])
		end
	end

	return services
end

local function GetServiceData(serviceIds)
	local serviceData = {}
	local serviceTable = PARAGON_UI["Data"].services

	for _, v in pairs(serviceIds) do
		local service = serviceTable[v]
		if(service) then
			service.ID = v
			table.insert(serviceData, service)
		end
	end

	return serviceData
end

function PARAGON_UI.ServiceBoxes_Update()
	if not PARAGON_UI["Vars"].dataLoaded then return end
	local currentPage = PARAGON_UI["Vars"].currentPage

	local categoryServices = GetCategoryServiceIds()
	local services = GetServiceData(categoryServices)

	local startIndex = (currentPage - 1) * 8 + 1
	local endIndex = startIndex + 8 - 1
	local maxPages = math.ceil(#services / 8)
	if(maxPages < 1) then
		maxPages = 1
	end
	PARAGON_UI["Vars"].maxPages = maxPages

	local index = 1
	for i, serviceData in ipairs(services) do
		if i >= startIndex and i <= endIndex then
			local service = PARAGON_UI["SERVICE_BUTTONS"][index]
			service.ServiceId = serviceData.ID
			service.Type = serviceData[KEYS.service.serviceType]
			service.Name = serviceData[KEYS.service.name]
			service.TooltipName = serviceData[KEYS.service.tooltipName]
			service.TooltipText = serviceData[KEYS.service.tooltipText]
			service.IconTexture = serviceData[KEYS.service.icon]
			service.Price = serviceData[KEYS.service.price]
			service.Currency = serviceData[KEYS.service.currency]
			service.AuraId = serviceData[KEYS.service.reward_1]

			local currencyData = PARAGON_UI["Data"].currencies
			local currencyEntry = currencyData[service.Currency]
			local currencyIcon = currencyEntry and currencyEntry[KEYS.currency.icon]

			service.Icon:SetTexture("Interface/Icons/" .. service.IconTexture)
			service.NameFont:SetFormattedText("|cffffffff%s|r", service.Name)
			service.PriceFont:SetFormattedText("|cffdbe005%i|r", service.Price)
			if currencyIcon then
				service.currencyIcon:SetTexture("Interface/Store_UI/Currencies/" .. currencyIcon)
			end

			-- Show allocated points from paragon data
			local paragonIndex = AURA_TO_PARAGON_INDEX[service.AuraId]
			local currentPoints = 0
			if paragonIndex and PARAGON_UI["Vars"].paragonData[paragonIndex] then
				currentPoints = PARAGON_UI["Vars"].paragonData[paragonIndex]
			end
			service.ParagonDisplay:SetFormattedText("|cffffffff%s|r", currentPoints.."/255")

			service:Show()
			index = index + 1
		end
	end

	-- Hide unused boxes
	if index <= 8 then
		for i = index, 8 do
			PARAGON_UI["SERVICE_BUTTONS"][i]:Hide()
		end
	end
end

function PARAGON_UI.ServiceBoxes_OnData()
	PARAGON_UI.ServiceBoxes_Update()
	PARAGON_UI.PageButtons_Update()
end

-- Page buttons
function PARAGON_UI.PageButtons_Create(parent)
	local backButton = CreateFrame("Button", nil, parent)
	backButton:SetSize(25, 25)
	backButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -100, -28)

	local backTopX, backTopY, backBotX, backBotY = 837, 866, 868, 897
	backButton:SetDisabledTexture("Interface/Store_UI/Frames/StoreFrame_Main")
	backButton:SetNormalTexture("Interface/Store_UI/Frames/StoreFrame_Main")
	backButton:SetPushedTexture("Interface/Store_UI/Frames/StoreFrame_Main")
	backButton:GetDisabledTexture():SetTexCoord(CoordsToTexCoords(1024, backTopX, backTopY, backBotX, backBotY))
	backButton:GetNormalTexture():SetTexCoord(CoordsToTexCoords(1024, backTopX+31, backTopY, backBotX+31, backBotY))
	backButton:GetPushedTexture():SetTexCoord(CoordsToTexCoords(1024, backTopX+62, backTopY, backBotX+62, backBotY))

	backButton:SetScript(
		"OnClick",
		function()
			PARAGON_UI.PageButtons_OnClick(-1)
		end
	)

	local pageText = parent:CreateFontString()
	pageText:SetFont("Fonts\\FRIZQT__.TTF", 13)
	pageText:SetShadowOffset(1, -1)
	pageText:SetPoint("LEFT", backButton, "RIGHT", 20, 0)

	local forwardButton = CreateFrame("Button", nil, parent)
	forwardButton:SetSize(25, 25)
	forwardButton:SetPoint("LEFT", backButton, "RIGHT", 65, 0)

	local forwTopX, forwTopY, forwBotX, forwBotY = 930, 866, 961, 897
	forwardButton:SetDisabledTexture("Interface/Store_UI/Frames/StoreFrame_Main")
	forwardButton:SetNormalTexture("Interface/Store_UI/Frames/StoreFrame_Main")
	forwardButton:SetPushedTexture("Interface/Store_UI/Frames/StoreFrame_Main")
	forwardButton:GetDisabledTexture():SetTexCoord(CoordsToTexCoords(1024, forwTopX, forwTopY, forwBotX, forwBotY))
	forwardButton:GetNormalTexture():SetTexCoord(CoordsToTexCoords(1024, forwTopX+31, forwTopY, forwBotX+31, forwBotY))
	forwardButton:GetPushedTexture():SetTexCoord(CoordsToTexCoords(1024, forwTopX+62, forwTopY, forwBotX+62, forwBotY))

	forwardButton:SetScript(
		"OnClick",
		function()
			PARAGON_UI.PageButtons_OnClick(1)
		end
	)

	PARAGON_UI["PAGING_ELEMENTS"] = {backButton, forwardButton, pageText}
end

function PARAGON_UI.PageButtons_OnClick(val)
	local currentPage = PARAGON_UI["Vars"].currentPage
	local maxPages = PARAGON_UI["Vars"].maxPages

	if(currentPage+val < 1 or currentPage+val > maxPages) then
		return
	end

	PlaySound("igSpellBookOpen", "Master")
	PARAGON_UI["Vars"].currentPage = currentPage + val
	PARAGON_UI.ServiceBoxes_Update()
	PARAGON_UI.PageButtons_Update()
end

function PARAGON_UI.PageButtons_Update()
	local currentPage = PARAGON_UI["Vars"].currentPage
	local maxPages = PARAGON_UI["Vars"].maxPages

	if(maxPages == 1) then
		PARAGON_UI["PAGING_ELEMENTS"][1]:Hide()
		PARAGON_UI["PAGING_ELEMENTS"][2]:Hide()
		PARAGON_UI["PAGING_ELEMENTS"][3]:Hide()
		return
	end

	PARAGON_UI["PAGING_ELEMENTS"][1]:Show()
	PARAGON_UI["PAGING_ELEMENTS"][2]:Show()
	PARAGON_UI["PAGING_ELEMENTS"][3]:Show()

	if(currentPage == 1) then
		PARAGON_UI["PAGING_ELEMENTS"][1]:Disable()
	else
		PARAGON_UI["PAGING_ELEMENTS"][1]:Enable()
	end

	if(currentPage == maxPages) then
		PARAGON_UI["PAGING_ELEMENTS"][2]:Disable()
	else
		PARAGON_UI["PAGING_ELEMENTS"][2]:Enable()
	end

	PARAGON_UI["PAGING_ELEMENTS"][3]:SetFormattedText("|cffffffff%i / %i|r", currentPage, maxPages)
end

-- Currency badges
function PARAGON_UI.CurrencyBadges_Create(parent)
	PARAGON_UI["CURRENCY_BUTTONS"] = {}

	local currencyBackdrop = CreateFrame("Frame", nil, parent)
	currencyBackdrop:SetSize(180, 20)
	currencyBackdrop:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 30)

	for i = 1, 4 do
		local currencyButton = CreateFrame("Button", nil, currencyBackdrop)
		currencyButton:SetSize(15, 15)

		currencyButton.Amount = currencyButton:CreateFontString()
		currencyButton.Amount:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
		currencyButton.Amount:SetPoint("CENTER", currencyButton, "CENTER", 0, 0)

		currencyButton.Icon = currencyButton:CreateTexture(nil, "OVERLAY")
		currencyButton.Icon:SetSize(15, 15)
		currencyButton.Icon:SetPoint("LEFT", currencyButton.Amount, "RIGHT")

		currencyButton:SetScript(
			"OnEnter",
			function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 18, 0)
				GameTooltip:AddLine("|cffffffff" .. self.currencyName .. "|r")
				if(self.currencyTooltip) then
					GameTooltip:AddLine(self.currencyTooltip)
				end
				GameTooltip:Show()
			end
		)

		currencyButton:SetScript(
			"OnLeave",
			function(self)
				GameTooltip:Hide()
			end
		)

		currencyButton:Hide()
		PARAGON_UI["CURRENCY_BUTTONS"][i] = currencyButton
	end
end

function PARAGON_UI.CurrencyBadges_OnData()
	local index = 1
	local shownCount = 0
	for k, v in pairs(PARAGON_UI["Data"].currencies) do
		if index > 4 then
			break;
		end

		local button = PARAGON_UI["CURRENCY_BUTTONS"][index]
		button.currencyId = k
		button.currencyType = v[KEYS.currency.currencyType]
		button.currencyName = v[KEYS.currency.name]
		button.currencyIcon = v[KEYS.currency.icon]
		button.currencyTooltip = v[KEYS.currency.tooltip]
		button.shown = true

		button:Show()

		shownCount = shownCount + 1
		index = index + 1
	end

	for i = 1, shownCount do
		local button = PARAGON_UI["CURRENCY_BUTTONS"][i]
		local padding = 10*(shownCount-1)
		local spacing = (150+padding) / shownCount
		local total_width = (shownCount - 1) * spacing
		local offset_x = -total_width / 2
		local x = offset_x + (i - 1) * spacing

		button:SetPoint("CENTER", button:GetParent(), "CENTER", x, 0)
	end

	PARAGON_UI.CurrencyBadges_Update()
end

function PARAGON_UI.CurrencyBadges_Update()
	if not PARAGON_UI["Vars"].dataLoaded then return end
	for _, button in pairs(PARAGON_UI["CURRENCY_BUTTONS"]) do
		if(button.shown) then
			button.currencyValue = PARAGON_UI["Vars"]["playerCurrencies"][button.currencyId] or 0
			button.Amount:SetText(button.currencyValue)
			if button.currencyIcon then
				button.Icon:SetTexture("Interface/Store_UI/Currencies/"..button.currencyIcon)
			end
		end
	end
end

-- Main frame toggle
function MainFrame_Toggle()
	if PARAGON_UI["FRAME"]:IsShown() and PARAGON_UI["FRAME"]:IsVisible() then
		PARAGON_UI["FRAME"]:Hide()
	else
		PARAGON_UI["FRAME"]:Show()
	end
end

-- Add Paragon button to game menu
local gameMenuModified = false
local function ModifyGameMenuFrame()
	if gameMenuModified then return end
	local frame = _G["GameMenuFrame"]
	if not frame then return end

	local videoButton = _G["GameMenuButtonOptions"]
	if not videoButton then return end

	gameMenuModified = true
	frame:SetSize(195, 270)
	videoButton:SetPoint("CENTER", frame, "TOP", 0, -70)

	local paragonButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	paragonButton:SetPoint("CENTER", frame, 0, 95)
	paragonButton:SetSize(144, 21)
	paragonButton.Text = paragonButton:CreateFontString()
	paragonButton.Text:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
	paragonButton.Text:SetShadowOffset(1, -1)
	paragonButton.Text:SetPoint("CENTER", paragonButton, "CENTER", 0, 1)
	paragonButton.Text:SetText("|cffdbe005Paragon");

	paragonButton:SetScript("OnClick", function()
		HideUIPanel(frame)
		MainFrame_Toggle()
	end)
end

-- Initialize
PARAGON_UI.MainFrame_Create()

-- Try immediately; if GameMenuFrame doesn't exist yet, retry on PLAYER_ENTERING_WORLD
ModifyGameMenuFrame()
if not gameMenuModified then
	local initFrame = CreateFrame("Frame")
	initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	initFrame:SetScript("OnEvent", function(self)
		ModifyGameMenuFrame()
		self:UnregisterAllEvents()
	end)
end
