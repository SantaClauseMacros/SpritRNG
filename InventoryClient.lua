-- InventoryHandler.client.lua  (redesigned — Pet Sim-style layout)
-- Layout:  Title bar  |  Equipped slots (3/3) + Equip Best  |  Inventory grid
-- Clears and rebuilds MainFrame children programmatically so no Studio changes needed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local SpiritRNG         = require(ReplicatedStorage:WaitForChild("SpiritRNG"))
local GetInventoryEvent = ReplicatedStorage:WaitForChild("GetInventoryEvent")
local RollEvent         = ReplicatedStorage:WaitForChild("RollSpiritEvent")
local InventoryStuff    = ReplicatedStorage:WaitForChild("Inventory Stuff")

local ToggleInventory = ReplicatedStorage:FindFirstChild("ToggleInventory")
	or Instance.new("BindableEvent", ReplicatedStorage)
ToggleInventory.Name = "ToggleInventory"

-- Expedition remotes (optional — gracefully absent if ExpeditionServer not added yet)
local ExpEquipSpiritEvent = ReplicatedStorage:FindFirstChild("ExpEquipSpiritEvent")
local ExpGetDataEvent     = ReplicatedStorage:FindFirstChild("ExpGetDataEvent")
local ExpUpdateEvent      = ReplicatedStorage:FindFirstChild("ExpUpdateEvent")

local gui       = script.Parent
local mainFrame = gui:WaitForChild("MainFrame")

-- Clear any Studio-built children so we own the full layout
for _, c in ipairs(mainFrame:GetChildren()) do c:Destroy() end

mainFrame.Visible         = false
mainFrame.Size            = UDim2.new(0,0,0,0)
mainFrame.AnchorPoint     = Vector2.new(0.5,0.5)
mainFrame.BackgroundColor3= Color3.fromRGB(245,245,250)
mainFrame.BorderSizePixel = 0
Instance.new("UICorner",mainFrame).CornerRadius = UDim.new(0,16)

local OPEN_SIZE = UDim2.new(0.58,0,0.86,0)
local OPEN_POS  = UDim2.new(0.50,0,0.50,0)
local isOpen    = false

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────────────────────────────────────

local function tw(obj,t,s,d,p)
	TweenService:Create(obj,TweenInfo.new(t,s or Enum.EasingStyle.Quad,d or Enum.EasingDirection.Out),p):Play()
end

local function corner(p,r) Instance.new("UICorner",p).CornerRadius=UDim.new(0,r or 8) end

local function lbl(parent,text,size,pos,color,font,xalign)
	local l=Instance.new("TextLabel",parent)
	l.BackgroundTransparency=1; l.Text=text
	l.TextColor3=color or Color3.fromRGB(30,30,30)
	l.TextScaled=true; l.Font=font or Enum.Font.GothamBold
	l.Size=size; l.Position=pos or UDim2.new(0,0,0,0)
	l.TextXAlignment=xalign or Enum.TextXAlignment.Center
	return l
end

local RARITY_ORDER = { Common=0,Uncommon=1,Rare=2,Epic=3,Legendary=4,Mythic=5,Divine=6,Celestial=7 }
local RARITY_STARS = {
	Common   ="⭐",  Uncommon="⭐⭐", Rare    ="⭐⭐⭐",
	Epic     ="💜",  Legendary="🏆",  Mythic  ="💎",
	Divine   ="👑",  Celestial="🌟",
}
local RARITY_ACCENT = {
	Common   =Color3.fromRGB(200,200,200), Uncommon=Color3.fromRGB(100,210,100),
	Rare     =Color3.fromRGB(80,160,255),  Epic    =Color3.fromRGB(180,80,255),
	Legendary=Color3.fromRGB(255,190,30),  Mythic  =Color3.fromRGB(255,80,160),
	Divine   =Color3.fromRGB(80,230,255),  Celestial=Color3.fromRGB(255,140,255),
}

local function getRarityBg(rarity)
	local folder = InventoryStuff:FindFirstChild(rarity)
	local tmpl   = folder and folder:FindFirstChild("Background")
	return tmpl
end

-- Expedition DigSpeed stat label  (e.g. "2.0⚡")
local EXP_DATA_OK, ExpeditionData = pcall(require, ReplicatedStorage:FindFirstChild("ExpeditionData"))
local function getDigSpeedStat(spiritName)
	if not EXP_DATA_OK or not ExpeditionData then return "" end
	local rarity = SpiritRNG.GetRarityName(spiritName)
	local stats  = ExpeditionData.RarityStats and ExpeditionData.RarityStats[rarity]
	if stats then return tostring(stats.DigSpeed).."⚡" end
	return ""
end

-- ─────────────────────────────────────────────────────────────────────────────
-- TITLE BAR
-- ─────────────────────────────────────────────────────────────────────────────

local titleBar = Instance.new("Frame",mainFrame)
titleBar.Size             = UDim2.new(1,0,0,52)
titleBar.BackgroundColor3 = Color3.fromRGB(235,235,242)
titleBar.BorderSizePixel  = 0
Instance.new("UICorner",titleBar).CornerRadius = UDim.new(0,16)

-- Paw icon + title
local iconLbl = lbl(titleBar,"🐾",UDim2.new(0,38,0,38),UDim2.new(0,10,0,7),
	Color3.fromRGB(30,30,30))

local titleLbl = lbl(titleBar,"Spirits",UDim2.new(0,130,0,36),UDim2.new(0,52,0,8),
	Color3.fromRGB(30,30,30),Enum.Font.GothamBold,Enum.TextXAlignment.Left)

-- Search box
local searchBox = Instance.new("TextBox",titleBar)
searchBox.Size             = UDim2.new(0,210,0,32)
searchBox.Position         = UDim2.new(1,-300,0,10)
searchBox.BackgroundColor3 = Color3.fromRGB(255,255,255)
searchBox.BorderSizePixel  = 0
searchBox.PlaceholderText  = "Search"
searchBox.PlaceholderColor3= Color3.fromRGB(160,160,175)
searchBox.Text             = ""
searchBox.TextColor3       = Color3.fromRGB(30,30,30)
searchBox.Font             = Enum.Font.Gotham
searchBox.TextSize         = 15
searchBox.ClearTextOnFocus = false
corner(searchBox,8)

-- X close button
local closeBtn = Instance.new("TextButton",titleBar)
closeBtn.Size             = UDim2.new(0,46,0,46)
closeBtn.Position         = UDim2.new(1,-52,0,3)
closeBtn.BackgroundColor3 = Color3.fromRGB(210,50,50)
closeBtn.TextColor3       = Color3.fromRGB(255,255,255)
closeBtn.Text             = "✕"
closeBtn.TextScaled       = true
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.BorderSizePixel  = 0
corner(closeBtn,12)

-- ─────────────────────────────────────────────────────────────────────────────
-- EQUIPPED SECTION
-- ─────────────────────────────────────────────────────────────────────────────

local equippedSection = Instance.new("Frame",mainFrame)
equippedSection.Size             = UDim2.new(1,-20,0,152)
equippedSection.Position         = UDim2.new(0,10,0,58)
equippedSection.BackgroundTransparency = 1

-- "Equipped (X/3)" label
local equippedLabel = lbl(equippedSection,"Equipped (0/3)",
	UDim2.new(0.55,0,0,24),UDim2.new(0,0,0,0),
	Color3.fromRGB(30,30,30),Enum.Font.GothamBold,Enum.TextXAlignment.Left)

-- Equip Best button
local equipBestBtn = Instance.new("TextButton",equippedSection)
equipBestBtn.Size             = UDim2.new(0,120,0,26)
equipBestBtn.Position         = UDim2.new(1,-122,0,0)
equipBestBtn.BackgroundColor3 = Color3.fromRGB(220,170,20)
equipBestBtn.TextColor3       = Color3.fromRGB(255,255,255)
equipBestBtn.Text             = "⭐ Equip Best"
equipBestBtn.TextScaled       = true
equipBestBtn.Font             = Enum.Font.GothamBold
equipBestBtn.BorderSizePixel  = 0
corner(equipBestBtn,7)

-- Slot holder (3 slots, centred)
local slotHolder = Instance.new("Frame",equippedSection)
slotHolder.Size                    = UDim2.new(1,0,1,-30)
slotHolder.Position                = UDim2.new(0,0,0,30)
slotHolder.BackgroundTransparency  = 1

local slotLayout = Instance.new("UIListLayout",slotHolder)
slotLayout.FillDirection           = Enum.FillDirection.Horizontal
slotLayout.HorizontalAlignment     = Enum.HorizontalAlignment.Center
slotLayout.Padding                 = UDim.new(0,14)

local MAX_SLOTS  = 3
local slotFrames = {}   -- [slot] = { frame, img, nameLbl, statLbl, starLbl, stripe }

local function buildSlot(slot)
	local sf = Instance.new("Frame",slotHolder)
	sf.Size             = UDim2.new(0,110,0,115)
	sf.BackgroundColor3 = Color3.fromRGB(215,215,228)
	sf.BorderSizePixel  = 0
	corner(sf,14)

	-- Colored top stripe (rarity accent)
	local stripe = Instance.new("Frame",sf)
	stripe.Size             = UDim2.new(1,0,0,6)
	stripe.BackgroundColor3 = Color3.fromRGB(180,180,200)
	stripe.BorderSizePixel  = 0
	Instance.new("UICorner",stripe).CornerRadius = UDim.new(0,14)

	-- Star icon (top-left)
	local starLbl = lbl(sf,"",UDim2.new(0,26,0,18),UDim2.new(0,5,0,8),
		Color3.fromRGB(255,210,30),Enum.Font.GothamBold)

	-- Spirit image
	local img = Instance.new("ImageLabel",sf)
	img.Size             = UDim2.new(0,72,0,72)
	img.Position         = UDim2.new(0.5,-36,0,16)
	img.BackgroundTransparency = 1
	img.Image            = ""
	img.ScaleType        = Enum.ScaleType.Fit

	-- Spirit name
	local nameLbl = lbl(sf,"Empty",UDim2.new(1,-4,0,16),UDim2.new(0,2,1,-30),
		Color3.fromRGB(100,100,120),Enum.Font.Gotham)

	-- Stat (bottom-right — dig speed)
	local statLbl = lbl(sf,"",UDim2.new(0,52,0,18),UDim2.new(1,-54,1,-22),
		Color3.fromRGB(60,60,80),Enum.Font.GothamBold,Enum.TextXAlignment.Right)

	-- Invisible click button
	local btn = Instance.new("TextButton",sf)
	btn.Size             = UDim2.new(1,0,1,0)
	btn.BackgroundTransparency = 1
	btn.Text             = ""
	local capSlot = slot
	btn.MouseButton1Click:Connect(function()
		-- Unequip this slot
		if slotFrames[capSlot] and slotFrames[capSlot].spiritName then
			if ExpEquipSpiritEvent then
				ExpEquipSpiritEvent:FireServer(capSlot,"")
			end
		end
	end)

	slotFrames[slot] = {
		frame    = sf,
		img      = img,
		nameLbl  = nameLbl,
		statLbl  = statLbl,
		starLbl  = starLbl,
		stripe   = stripe,
		spiritName = nil,
	}
	return sf
end

for i = 1, MAX_SLOTS do buildSlot(i) end

-- ─────────────────────────────────────────────────────────────────────────────
-- DIVIDER
-- ─────────────────────────────────────────────────────────────────────────────

local divider = Instance.new("Frame",mainFrame)
divider.Size             = UDim2.new(1,-20,0,2)
divider.Position         = UDim2.new(0,10,0,216)
divider.BackgroundColor3 = Color3.fromRGB(200,200,215)
divider.BorderSizePixel  = 0

-- ─────────────────────────────────────────────────────────────────────────────
-- INVENTORY SCROLL FRAME
-- ─────────────────────────────────────────────────────────────────────────────

local scrollFrame = Instance.new("ScrollingFrame",mainFrame)
scrollFrame.Size                  = UDim2.new(1,-16,1,-226)
scrollFrame.Position              = UDim2.new(0,8,0,222)
scrollFrame.BackgroundTransparency= 1
scrollFrame.ScrollBarThickness    = 5
scrollFrame.ScrollBarImageColor3  = Color3.fromRGB(180,180,200)
scrollFrame.BorderSizePixel       = 0
scrollFrame.CanvasSize            = UDim2.new(0,0,0,0)
scrollFrame.AutomaticCanvasSize   = Enum.AutomaticSize.Y

local gridLayout = Instance.new("UIGridLayout",scrollFrame)
gridLayout.CellSize    = UDim2.new(0,92,0,98)
gridLayout.CellPadding = UDim2.new(0,8,0,8)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
gridLayout.SortOrder   = Enum.SortOrder.LayoutOrder

Instance.new("UIPadding",scrollFrame).PaddingLeft = UDim.new(0,4)

-- ─────────────────────────────────────────────────────────────────────────────
-- EQUIPPED STATE & SLOT REFRESH
-- ─────────────────────────────────────────────────────────────────────────────

local equippedSpirits = {}   -- { ["1"]=name, ["2"]=name, … }

local function countEquipped()
	local n = 0
	for i = 1, MAX_SLOTS do if equippedSpirits[tostring(i)] then n+=1 end end
	return n
end

local function refreshSlots()
	local count = countEquipped()
	equippedLabel.Text = "Equipped ("..count.."/"..MAX_SLOTS..")"

	for slot = 1, MAX_SLOTS do
		local sd   = slotFrames[slot]
		local name = equippedSpirits[tostring(slot)]
		sd.spiritName = name
		if name then
			local rarity = SpiritRNG.GetRarityName(name)
			local color  = RARITY_ACCENT[rarity] or Color3.fromRGB(180,180,200)
			local bgTmpl = getRarityBg(rarity)

			-- Rarity background tint
			sd.frame.BackgroundColor3 = color
			if bgTmpl then
				-- Clone rarity background image if available
				local existing = sd.frame:FindFirstChild("RarityBg")
				if existing then existing:Destroy() end
				local bg      = bgTmpl:Clone()
				bg.Name       = "RarityBg"
				bg.Size       = UDim2.new(1,0,1,0)
				bg.Position   = UDim2.new(0,0,0,0)
				bg.ZIndex     = 1
				bg.Parent     = sd.frame
			end

			sd.stripe.BackgroundColor3 = color:Lerp(Color3.new(1,1,1),0.5)
			sd.img.Image               = SpiritRNG.GetImageId(name)
			sd.img.ZIndex              = 5
			sd.nameLbl.Text            = SpiritRNG.GetDisplayName(name)
			sd.nameLbl.TextColor3      = Color3.fromRGB(255,255,255)
			sd.statLbl.Text            = getDigSpeedStat(name)
			sd.starLbl.Text            = RARITY_STARS[rarity] or "⭐"
		else
			sd.frame.BackgroundColor3 = Color3.fromRGB(215,215,228)
			local existing = sd.frame:FindFirstChild("RarityBg")
			if existing then existing:Destroy() end
			sd.stripe.BackgroundColor3 = Color3.fromRGB(180,180,200)
			sd.img.Image              = ""
			sd.nameLbl.Text           = "Empty"
			sd.nameLbl.TextColor3     = Color3.fromRGB(120,120,145)
			sd.statLbl.Text           = ""
			sd.starLbl.Text           = ""
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CARD CACHE & INVENTORY POPULATION
-- ─────────────────────────────────────────────────────────────────────────────

local cardCache      = {}   -- [spiritName] = Frame
local cardCountBadge = {}   -- [spiritName] = TextLabel
local cachedSorted   = {}

local CARD_SZ = 92

local function makeCard(spiritName, count)
	local rarity   = SpiritRNG.GetRarityName(spiritName)
	local imageId  = SpiritRNG.GetImageId(spiritName)
	local accent   = RARITY_ACCENT[rarity] or Color3.fromRGB(200,200,200)

	local card = Instance.new("Frame",scrollFrame)
	card.Name             = spiritName
	card.Size             = UDim2.new(0,CARD_SZ,0,CARD_SZ+6)
	card.BackgroundColor3 = accent
	card.BorderSizePixel  = 0
	card.Visible          = false
	corner(card,12)

	-- Rarity background image
	local bgTmpl = getRarityBg(rarity)
	if bgTmpl then
		local bg    = bgTmpl:Clone()
		bg.Size     = UDim2.new(1,0,1,0)
		bg.ZIndex   = 1
		bg.Parent   = card
	end

	-- Spirit image
	local img = Instance.new("ImageLabel",card)
	img.Size             = UDim2.new(0,68,0,68)
	img.Position         = UDim2.new(0.5,-34,0,6)
	img.BackgroundTransparency = 1
	img.Image            = imageId
	img.ScaleType        = Enum.ScaleType.Fit
	img.ZIndex           = 3

	-- Rarity star (top-left)
	local starLbl = lbl(card, RARITY_STARS[rarity] or "⭐",
		UDim2.new(0,24,0,18), UDim2.new(0,3,0,3),
		Color3.fromRGB(255,255,255), Enum.Font.GothamBold)
	starLbl.ZIndex = 4

	-- Count badge (top-right)
	local badge = Instance.new("Frame",card)
	badge.Size             = UDim2.new(0,36,0,20)
	badge.Position         = UDim2.new(1,-38,0,3)
	badge.BackgroundColor3 = Color3.fromRGB(0,0,0)
	badge.BackgroundTransparency = 0.30
	badge.BorderSizePixel  = 0
	badge.ZIndex           = 4
	corner(badge,5)

	local badgeLbl = lbl(badge,"x"..count,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),
		Color3.fromRGB(255,255,255),Enum.Font.GothamBold)
	badgeLbl.ZIndex = 5

	-- Stat bar at bottom
	local statBar = Instance.new("Frame",card)
	statBar.Size             = UDim2.new(1,0,0,20)
	statBar.Position         = UDim2.new(0,0,1,-20)
	statBar.BackgroundColor3 = Color3.fromRGB(0,0,0)
	statBar.BackgroundTransparency = 0.35
	statBar.BorderSizePixel  = 0
	Instance.new("UICorner",statBar).CornerRadius = UDim.new(0,12)
	statBar.ZIndex = 3

	local statTxt = lbl(statBar, getDigSpeedStat(spiritName),
		UDim2.new(1,-6,1,0), UDim2.new(0,3,0,0),
		Color3.fromRGB(255,255,255), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
	statTxt.ZIndex = 4

	-- Hover tooltip (reuse existing tooltip or simple approach)
	local hoverBtn = Instance.new("TextButton",card)
	hoverBtn.Size             = UDim2.new(1,0,1,0)
	hoverBtn.BackgroundTransparency = 1
	hoverBtn.Text             = ""
	hoverBtn.ZIndex           = 10

	-- Click to equip
	local capName = spiritName
	hoverBtn.MouseButton1Click:Connect(function()
		if not ExpEquipSpiritEvent then return end
		-- Find first empty slot
		for s = 1, MAX_SLOTS do
			if not equippedSpirits[tostring(s)] then
				ExpEquipSpiritEvent:FireServer(s, capName)
				return
			end
		end
		-- All slots full — equip to slot 1 (replace)
		ExpEquipSpiritEvent:FireServer(1, capName)
	end)

	card.Parent = scrollFrame

	cardCache[spiritName]      = card
	cardCountBadge[spiritName] = badgeLbl
	return card
end

local function refreshCanvasSize(total)
	local cols = math.max(1, math.floor((scrollFrame.AbsoluteSize.X - 8) / (CARD_SZ + 8)))
	local rows = math.ceil(total / cols)
	scrollFrame.CanvasSize = UDim2.new(0,0,0,rows * (CARD_SZ + 14) + 10)
end

local searchFilter = ""

local function populateInventory(data)
	local needsRebuild = false
	for name in pairs(data.inventory) do
		if not cardCache[name] then needsRebuild = true; break end
	end

	if needsRebuild then
		cachedSorted = {}
		for name, count in pairs(data.inventory) do
			table.insert(cachedSorted, { name=name, count=count })
		end
		table.sort(cachedSorted, function(a,b)
			local ra = RARITY_ORDER[SpiritRNG.GetRarityName(a.name)] or 0
			local rb = RARITY_ORDER[SpiritRNG.GetRarityName(b.name)] or 0
			if ra ~= rb then return ra > rb end  -- highest rarity first
			return a.name < b.name
		end)

		for _, c in pairs(cardCache) do c.Visible = false end

		for i, entry in ipairs(cachedSorted) do
			local card = cardCache[entry.name]
			if not card then
				card = makeCard(entry.name, entry.count)
			else
				local badge = cardCountBadge[entry.name]
				if badge then badge.Text = "x"..entry.count end
			end
			-- Search filter
			local show = searchFilter == ""
				or SpiritRNG.GetDisplayName(entry.name):lower():find(searchFilter:lower(), 1, true) ~= nil
			card.LayoutOrder = i
			card.Visible     = show
		end
		refreshCanvasSize(#cachedSorted)
	else
		-- Fast path: update counts only
		for name, count in pairs(data.inventory) do
			local badge = cardCountBadge[name]
			if badge then badge.Text = "x"..count end
		end
		-- Re-apply search filter
		for _, entry in ipairs(cachedSorted) do
			local card = cardCache[entry.name]
			if card then
				local show = searchFilter == ""
					or SpiritRNG.GetDisplayName(entry.name):lower():find(searchFilter:lower(),1,true) ~= nil
				card.Visible = show
			end
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- EQUIP BEST
-- ─────────────────────────────────────────────────────────────────────────────

local function doEquipBest(invData)
	if not ExpEquipSpiritEvent then return end
	-- Sort owned spirits by rarity descending
	local pool = {}
	for name, count in pairs(invData.inventory or {}) do
		if count > 0 then
			table.insert(pool, { name=name, tier=RARITY_ORDER[SpiritRNG.GetRarityName(name)] or 0 })
		end
	end
	table.sort(pool, function(a,b) return a.tier > b.tier end)
	-- Equip top N into slots
	for slot = 1, MAX_SLOTS do
		local entry = pool[slot]
		if entry then
			ExpEquipSpiritEvent:FireServer(slot, entry.name)
		else
			ExpEquipSpiritEvent:FireServer(slot, "")
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- OPEN / CLOSE
-- ─────────────────────────────────────────────────────────────────────────────

local function openInventory()
	isOpen = true
	mainFrame.Size     = UDim2.new(0,0,0,0)
	mainFrame.Position = OPEN_POS
	mainFrame.Visible  = true
	tw(mainFrame,0.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out,{Size=OPEN_SIZE})

	task.spawn(function()
		-- Load inventory
		local data = GetInventoryEvent:InvokeServer()
		populateInventory(data)

		-- Load equipped spirits from expedition system
		if ExpGetDataEvent then
			local ok, expData = pcall(function() return ExpGetDataEvent:InvokeServer() end)
			if ok and expData and expData.equippedSpirits then
				equippedSpirits = expData.equippedSpirits
				refreshSlots()
			end
		end
	end)
end

local function closeInventory()
	isOpen = false
	tw(mainFrame,0.25,Enum.EasingStyle.Back,Enum.EasingDirection.In,{Size=UDim2.new(0,0,0,0)})
	task.delay(0.25,function() mainFrame.Visible=false end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- BUTTON EVENTS
-- ─────────────────────────────────────────────────────────────────────────────

closeBtn.MouseButton1Click:Connect(closeInventory)

equipBestBtn.MouseButton1Click:Connect(function()
	tw(equipBestBtn,0.08,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,
		{Size=UDim2.new(0,112,0,24)})
	task.delay(0.08,function()
		tw(equipBestBtn,0.15,Enum.EasingStyle.Back,Enum.EasingDirection.Out,
			{Size=UDim2.new(0,120,0,26)})
	end)
	task.spawn(function()
		local data = GetInventoryEvent:InvokeServer()
		doEquipBest(data)
	end)
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	searchFilter = searchBox.Text
	if isOpen then
		for _, entry in ipairs(cachedSorted) do
			local card = cardCache[entry.name]
			if card then
				local show = searchFilter == ""
					or SpiritRNG.GetDisplayName(entry.name):lower():find(searchFilter:lower(),1,true) ~= nil
				card.Visible = show
			end
		end
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- EXPEDITION UPDATE SYNC
-- ─────────────────────────────────────────────────────────────────────────────

if ExpUpdateEvent then
	ExpUpdateEvent.OnClientEvent:Connect(function(eventType, data)
		if eventType ~= "equip" then return end
		data = data or {}
		local key = tostring(data.slot)
		if data.spirit and data.spirit ~= "" then
			equippedSpirits[key] = data.spirit
		else
			equippedSpirits[key] = nil
		end
		if isOpen then refreshSlots() end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- TOGGLE & ROLL EVENTS
-- ─────────────────────────────────────────────────────────────────────────────

ToggleInventory.Event:Connect(function()
	if isOpen then closeInventory() else openInventory() end
end)

RollEvent.OnClientEvent:Connect(function()
	if not isOpen then return end
	task.wait(0.4)
	task.spawn(function()
		local data = GetInventoryEvent:InvokeServer()
		populateInventory(data)
	end)
end)
