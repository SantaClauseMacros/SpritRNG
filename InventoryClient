-- InventoryHandler.client.lua (fixed)
-- Changes:
--   • Card cache: cards are built once and reused. On subsequent opens/rolls
--     only the count badge text is updated — no more destroy+rebuild every time.
--   • ViewportFrame branch is kept but only triggers when ImageId is truly
--     missing (currently none, so it never runs).
--   • Canvas height recalculation moved into a helper that only fires when
--     the card set actually changes size.
--   • Everything else is unchanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local SpiritRNG         = require(ReplicatedStorage:WaitForChild("SpiritRNG"))
local GetInventoryEvent = ReplicatedStorage:WaitForChild("GetInventoryEvent")
local RollEvent         = ReplicatedStorage:WaitForChild("RollSpiritEvent")

local ToggleInventory = ReplicatedStorage:FindFirstChild("ToggleInventory")
	or Instance.new("BindableEvent", ReplicatedStorage)
ToggleInventory.Name = "ToggleInventory"

local InventoryStuff = ReplicatedStorage:WaitForChild("Inventory Stuff")

local gui         = script.Parent
local mainFrame   = gui:WaitForChild("MainFrame")
local topBar      = mainFrame:WaitForChild("TopBar")
local closeButton = topBar:WaitForChild("CloseButton")
local scrollFrame = mainFrame:WaitForChild("ScrollingFrame")

mainFrame.Visible     = false
mainFrame.Size        = UDim2.new(0, 0, 0, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)

local OPEN_SIZE = UDim2.new(0.542891443, 0, 0.839863718, 0)
local OPEN_POS  = UDim2.new(0.499700069, 0, 0.49914825, 0)
local CARD_SIZE = 130

local isOpen = false

local rarityOrder = {
	Celestial = 0,
	Mythic    = 1,
	Legendary = 2,
	Epic      = 3,
	Rare      = 4,
	Uncommon  = 5,
	Common    = 6,
}

-- ─────────────────────────────────────────────
-- Card cache  (spiritName -> Frame)
-- Cards are never destroyed while the player is in-session; only count
-- badges are updated. This removes the main per-roll GC spike.
-- ─────────────────────────────────────────────

local cardCache      = {}   -- [spiritName] = Frame
local cardCountBadge = {}   -- [spiritName] = TextLabel  (the "xN" badge)
local cachedSorted   = {}   -- last sorted order; rebuilt only when new spirits appear

-- ─────────────────────────────────────────────
-- Tooltip
-- ─────────────────────────────────────────────

local tooltip = Instance.new("Frame")
tooltip.Name                   = "HoverTooltip"
tooltip.Size                   = UDim2.new(0, 170, 0, 62)
tooltip.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
tooltip.BackgroundTransparency = 0
tooltip.BorderSizePixel        = 0
tooltip.Visible                = false
tooltip.ZIndex                 = 20
tooltip.AnchorPoint            = Vector2.new(0.5, 1)
Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", tooltip)
stroke.Color     = Color3.fromRGB(0, 0, 0)
stroke.Thickness = 2.5

local tooltipName = Instance.new("TextLabel", tooltip)
tooltipName.Size                   = UDim2.new(1, -8, 0, 24)
tooltipName.Position               = UDim2.new(0, 4, 0, 4)
tooltipName.BackgroundTransparency = 1
tooltipName.TextColor3             = Color3.fromRGB(30, 30, 30)
tooltipName.Font                   = Enum.Font.FredokaOne
tooltipName.TextSize               = 16
tooltipName.TextXAlignment         = Enum.TextXAlignment.Center
tooltipName.ZIndex                 = 21

local tooltipRarity = nil

local tooltipChance = Instance.new("TextLabel", tooltip)
tooltipChance.Size                   = UDim2.new(1, -8, 0, 14)
tooltipChance.Position               = UDim2.new(0, 4, 0, 44)
tooltipChance.BackgroundTransparency = 1
tooltipChance.TextColor3             = Color3.fromRGB(80, 80, 80)
tooltipChance.Font                   = Enum.Font.FredokaOne
tooltipChance.TextSize               = 11
tooltipChance.TextXAlignment         = Enum.TextXAlignment.Center
tooltipChance.ZIndex                 = 21

tooltip.Parent = mainFrame

local function showTooltip(card, spiritName)
	tooltipName.Text   = SpiritRNG.GetDisplayName(spiritName)
	tooltipChance.Text = "Has a " .. SpiritRNG.GetChanceDisplay(spiritName) .. " chance of being rolled"

	if tooltipRarity then tooltipRarity:Destroy(); tooltipRarity = nil end
	local rarity       = SpiritRNG.GetRarityName(spiritName)
	local rarityFolder = InventoryStuff:FindFirstChild(rarity)
	if rarityFolder then
		local template = rarityFolder:FindFirstChild("RarityLabel")
		if template then
			tooltipRarity                = template:Clone()
			tooltipRarity.Size           = UDim2.new(1, -8, 0, 20)
			tooltipRarity.AnchorPoint    = Vector2.new(0.5, 0)
			tooltipRarity.Position       = UDim2.new(0.5, 0, 0, 26)
			tooltipRarity.TextXAlignment = Enum.TextXAlignment.Center
			tooltipRarity.TextYAlignment = Enum.TextYAlignment.Center
			tooltipRarity.ZIndex         = 21
			tooltipRarity.Parent         = tooltip
		end
	end

	local absPos   = card.AbsolutePosition
	local absSize  = card.AbsoluteSize
	local mainPos  = mainFrame.AbsolutePosition
	local mainSize = mainFrame.AbsoluteSize
	local cx = absPos.X + absSize.X / 2 - mainPos.X
	local cy = absPos.Y - mainPos.Y - 6
	local halfW = 85
	cx = math.clamp(cx, halfW + 4, mainSize.X - halfW - 4)
	tooltip.Position = UDim2.new(0, cx, 0, cy)
	tooltip.Visible  = true
end

local function hideTooltip()
	tooltip.Visible = false
end

-- ─────────────────────────────────────────────
-- Card builder  (called at most once per spirit)
-- ─────────────────────────────────────────────

local function makeCard(spiritName, count)
	local chanceDisplay = SpiritRNG.GetChanceDisplay(spiritName)
	local rarity        = SpiritRNG.GetRarityName(spiritName)
	local imageId       = SpiritRNG.GetImageId(spiritName)

	local card = Instance.new("Frame")
	card.Size                   = UDim2.new(0, CARD_SIZE, 0, CARD_SIZE)
	card.BackgroundTransparency = 1
	card.BorderSizePixel        = 0
	card.Name                   = spiritName
	card.ClipsDescendants       = true
	card.Visible                = false   -- hidden until placed in sorted order

	local uiAspect = Instance.new("UIAspectRatioConstraint", card)
	uiAspect.AspectRatio = 1
	uiAspect.AspectType  = Enum.AspectType.FitWithinMaxSize

	-- Rarity background
	local rarityFolder = InventoryStuff:FindFirstChild(rarity)
	if rarityFolder then
		local bgTemplate = rarityFolder:FindFirstChild("Background")
		if bgTemplate then
			local bg      = bgTemplate:Clone()
			bg.Size       = UDim2.new(1, 0, 1, 0)
			bg.Position   = UDim2.new(0, 0, 0, 0)
			bg.ZIndex     = 1
			bg.Parent     = card
		end
	end

	-- Pet icon (ImageLabel preferred; ViewportFrame only if no ImageId)
	if imageId ~= "" then
		local img = Instance.new("ImageLabel", card)
		img.Size                   = UDim2.new(1, 0, 1, 0)
		img.Position               = UDim2.new(0, 0, 0, 0)
		img.BackgroundTransparency = 1
		img.BorderSizePixel        = 0
		img.Image                  = imageId
		img.ScaleType              = Enum.ScaleType.Fit
		img.ZIndex                 = 2
	else
		-- Fallback: 3-D viewport (expensive — ensure all spirits have ImageId)
		local vp = Instance.new("ViewportFrame", card)
		vp.Size                   = UDim2.new(1, 0, 1, 0)
		vp.Position               = UDim2.new(0, 0, 0, 0)
		vp.BackgroundTransparency = 1
		vp.BorderSizePixel        = 0
		vp.ZIndex                 = 2
		local cam   = Instance.new("Camera", vp)
		local clone = SpiritRNG.LoadPetIntoViewport(spiritName, vp, cam)
		if clone then
			local cf, size   = clone:GetBoundingBox()
			local maxDim     = math.max(size.X, size.Y, size.Z)
			local distance   = ((maxDim / 2) / math.tan(math.rad(cam.FieldOfView / 2))) * 2.0
			local lookTarget = cf.Position + Vector3.new(0, size.Y * 0.1, 0)
			cam.CFrame       = CFrame.new(lookTarget + Vector3.new(0, size.Y * 0.1, -distance), lookTarget)
			local hl = Instance.new("Highlight")
			hl.Adornee             = clone
			hl.OutlineColor        = Color3.fromRGB(0, 0, 0)
			hl.OutlineTransparency = 0
			hl.FillTransparency    = 1
			hl.Parent              = vp
		end
	end

	-- Count badge (top-right)
	local countBadge = Instance.new("TextLabel", card)
	countBadge.Name                   = "CountBadge"
	countBadge.Size                   = UDim2.new(0, 44, 0, 24)
	countBadge.Position               = UDim2.new(1, -48, 0, 6)
	countBadge.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	countBadge.BackgroundTransparency = 0.35
	countBadge.Text                   = "x" .. count
	countBadge.TextColor3             = Color3.fromRGB(255, 255, 255)
	countBadge.TextScaled             = true
	countBadge.Font                   = Enum.Font.FredokaOne
	countBadge.BorderSizePixel        = 0
	countBadge.ZIndex                 = 3
	Instance.new("UICorner", countBadge).CornerRadius = UDim.new(0, 6)

	-- Chance badge (bottom-right)
	local chanceBadge = Instance.new("TextLabel", card)
	chanceBadge.Size                   = UDim2.new(0, 60, 0, 24)
	chanceBadge.Position               = UDim2.new(1, -64, 1, -28)
	chanceBadge.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	chanceBadge.BackgroundTransparency = 0.35
	chanceBadge.Text                   = chanceDisplay
	chanceBadge.TextColor3             = Color3.fromRGB(255, 255, 255)
	chanceBadge.TextScaled             = true
	chanceBadge.Font                   = Enum.Font.FredokaOne
	chanceBadge.BorderSizePixel        = 0
	chanceBadge.ZIndex                 = 3
	Instance.new("UICorner", chanceBadge).CornerRadius = UDim.new(0, 6)

	-- Invisible hover button on top
	local hoverBtn = Instance.new("TextButton", card)
	hoverBtn.Size                   = UDim2.new(1, 0, 1, 0)
	hoverBtn.BackgroundTransparency = 1
	hoverBtn.Text                   = ""
	hoverBtn.ZIndex                 = 10
	hoverBtn.MouseEnter:Connect(function() showTooltip(card, spiritName) end)
	hoverBtn.MouseLeave:Connect(function() hideTooltip() end)

	card.Parent = scrollFrame

	-- Store in cache
	cardCache[spiritName]      = card
	cardCountBadge[spiritName] = countBadge

	return card
end

-- ─────────────────────────────────────────────
-- Canvas height helper
-- ─────────────────────────────────────────────

local function refreshCanvasSize(totalCards)
	local cols = math.max(1, math.floor(scrollFrame.AbsoluteSize.X / (CARD_SIZE + 15)))
	local rows = math.ceil(totalCards / cols)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, rows * (CARD_SIZE + 15) + 12)
end

-- ─────────────────────────────────────────────
-- Populate — reuse cached cards, only create new ones
-- ─────────────────────────────────────────────

local function populateInventory(data)
	hideTooltip()

	-- Detect whether the sorted list needs rebuilding
	-- (a new spirit appeared that wasn't owned before)
	local needsRebuild = false
	for spiritName in pairs(data.inventory) do
		if not cardCache[spiritName] then
			needsRebuild = true
			break
		end
	end

	if needsRebuild then
		-- Build sorted order
		cachedSorted = {}
		for spiritName, count in pairs(data.inventory) do
			table.insert(cachedSorted, { name = spiritName, count = count })
		end
		table.sort(cachedSorted, function(a, b)
			local ra = rarityOrder[SpiritRNG.GetRarityName(a.name)] or 99
			local rb = rarityOrder[SpiritRNG.GetRarityName(b.name)] or 99
			if ra ~= rb then return ra < rb end
			return a.name < b.name
		end)

		-- Hide all cached cards (some may no longer be in sorted set)
		for _, card in pairs(cardCache) do card.Visible = false end

		-- Create missing cards and show existing ones in order
		for i, entry in ipairs(cachedSorted) do
			local card = cardCache[entry.name]
			if not card then
				card = makeCard(entry.name, entry.count)
			else
				-- Update count text in case it changed
				local badge = cardCountBadge[entry.name]
				if badge then badge.Text = "x" .. entry.count end
			end
			card.LayoutOrder = i
			card.Visible     = true
		end

		refreshCanvasSize(#cachedSorted)
	else
		-- Fast path: just update count badges on already-visible cards
		for spiritName, count in pairs(data.inventory) do
			local badge = cardCountBadge[spiritName]
			if badge then badge.Text = "x" .. count end
		end
	end
end

-- ─────────────────────────────────────────────
-- Open / close
-- ─────────────────────────────────────────────

local function openInventory()
	isOpen = true
	mainFrame.Size     = UDim2.new(0, 0, 0, 0)
	mainFrame.Position = OPEN_POS
	mainFrame.Visible  = true
	TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = OPEN_SIZE,
	}):Play()
	task.spawn(function()
		local data = GetInventoryEvent:InvokeServer()
		populateInventory(data)
	end)
end

local function closeInventory()
	isOpen = false
	hideTooltip()
	TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
	}):Play()
	task.delay(0.25, function()
		mainFrame.Visible = false
	end)
end

-- ─────────────────────────────────────────────
-- Events
-- ─────────────────────────────────────────────

ToggleInventory.Event:Connect(function()
	if isOpen then closeInventory() else openInventory() end
end)

closeButton.MouseButton1Click:Connect(closeInventory)

RollEvent.OnClientEvent:Connect(function()
	if isOpen then
		task.wait(0.5)
		task.spawn(function()
			local data = GetInventoryEvent:InvokeServer()
			populateInventory(data)
		end)
	end
end)
