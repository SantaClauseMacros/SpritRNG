-- SkillTreeClient.client.lua  (Hex-grid layout)
-- Skill tree rendered as flat-top hexagons that touch face-to-face on the grid.
--   • Hexagons are black with a white outline
--   • No connector lines — adjacent hexes share edges instead
--   • Background is fully black
--   • LMB drag pans the canvas, scroll wheel zooms toward the cursor
--   • Tree auto-centres on screen when opened
--
-- Requires a hexagon decal in ReplicatedStorage:
--   Upload a flat-top hexagon image (transparent background, white silhouette)
--   and either:
--     (a) paste the asset id into HEX_IMAGE_FALLBACK below, or
--     (b) place an ImageLabel (or StringValue) named "HexagonImage" in
--         ReplicatedStorage whose Image / Value holds the asset id.
--   Recommended aspect ratio: 2 : √3  (e.g. 256×222 or 512×443) so the hex
--   exactly fills its bounding box. A square image also works but leaves a
--   thin transparent strip above and below the hex.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")

local SkillTree = require(ReplicatedStorage:WaitForChild("SkillTree"))

-- ── Remotes ──────────────────────────────────────────────────────────────────
local GetSkillsEvent     = ReplicatedStorage:WaitForChild("GetSkillsEvent")
local BuySkillEvent      = ReplicatedStorage:WaitForChild("BuySkillEvent")
local SkillUnlockedEvent = ReplicatedStorage:WaitForChild("SkillUnlockedEvent")
local CoinsUpdateEvent   = ReplicatedStorage:WaitForChild("SkillCoinsUpdateEvent")

local ToggleSkillTree = ReplicatedStorage:FindFirstChild("ToggleSkillTree")
if not ToggleSkillTree then
	ToggleSkillTree        = Instance.new("BindableEvent")
	ToggleSkillTree.Name   = "ToggleSkillTree"
	ToggleSkillTree.Parent = ReplicatedStorage
end

-- ── Hex image ────────────────────────────────────────────────────────────────
local HEX_IMAGE_FALLBACK = "rbxassetid://0" -- TODO: replace with your hex image id
local function resolveHexImage()
	local node = ReplicatedStorage:FindFirstChild("HexagonImage")
	if node then
		if node:IsA("ImageLabel") or node:IsA("ImageButton") or node:IsA("Decal") then
			if node.Image and node.Image ~= "" then return node.Image end
		elseif node:IsA("StringValue") then
			if node.Value and node.Value ~= "" then return node.Value end
		end
	end
	return HEX_IMAGE_FALLBACK
end
local HEX_IMAGE   = resolveHexImage()
local HAS_HEX_IMG = HEX_IMAGE ~= nil and HEX_IMAGE ~= "" and HEX_IMAGE ~= "rbxassetid://0"

-- ── GUI references ───────────────────────────────────────────────────────────
local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")
local skillGui   = playerGui:WaitForChild("SkillTreeGui")
local mainFrame  = skillGui:WaitForChild("MainFrame")
local topBar     = mainFrame:WaitForChild("TopBar")
local closeBtn   = topBar:WaitForChild("CloseButton")
local coinsLbl   = topBar:WaitForChild("CoinsLabel")
local nodesFrame = mainFrame:WaitForChild("NodesFrame")

-- ── Hex grid (flat-top hexagons) ─────────────────────────────────────────────
-- Flat-top hex with circumradius R:
--   width  = 2R
--   height = √3 · R
-- Column step (horizontal): 1.5 · R     (so adjacent columns share their slanted edges)
-- Row step (vertical):     √3 · R      (so same-column rows share their flat top/bottom edges)
-- Odd columns shift DOWN by ½ row so they nestle between even-column rows.
local HEX_R     = 90
local HEX_W     = HEX_R * 2
local HEX_H     = HEX_R * math.sqrt(3)
local STEP_X    = HEX_R * 1.5
local STEP_Y    = HEX_H
local OUTLINE_W = 5

local CANVAS_HALF      = 3500
local MIN_ZOOM         = 0.3
local MAX_ZOOM         = 2.5
local LABEL_HIDE_ZOOM  = 0.70   -- below this zoom level, name text is hidden (icon only)

-- ── Runtime state ────────────────────────────────────────────────────────────
local isOpen         = false
local currentCoins   = 0
local unlockedSkills = {}
local nodeFrames     = {}
local tooltip        = nil

local canvas      = nil
local uiScaleInst = nil

local canvasPos    = Vector2.new(0, 0)
local canvasZoom   = 1.0
local isDragging   = false
local dragStart    = Vector2.new(0, 0)
local dragOrigin   = Vector2.new(0, 0)
local dragDistance = 0

-- Forward declaration — defined later but called inside applyTransform
local updateLabelVisibility

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function formatCoins(n)
	n = n or 0
	if     n >= 1000000 then return string.format("%.1fM", n / 1000000)
	elseif n >= 1000    then return string.format("%.1fK", n / 1000)
	end
	return tostring(math.floor(n))
end

-- True modulo (works for negative ints, e.g. -1 % 2 → 1)
local function imod(a, b) return ((a % b) + b) % b end

-- Canvas-pixel centre of a node, using flat-top hex grid spacing.
local function nodePos(skill)
	local cx = CANVAS_HALF + skill.Col * STEP_X
	local cy = CANVAS_HALF + skill.Row * STEP_Y
	if imod(skill.Col, 2) == 1 then
		cy = cy + STEP_Y / 2
	end
	return cx, cy
end

-- ── Canvas ───────────────────────────────────────────────────────────────────

local function createCanvas()
	if canvas and canvas.Parent then canvas:Destroy() end

	canvas = Instance.new("Frame")
	canvas.Name                   = "SkillCanvas"
	canvas.Size                   = UDim2.new(0, CANVAS_HALF * 2, 0, CANVAS_HALF * 2)
	canvas.Position               = UDim2.new(0, 0, 0, 0)
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel        = 0
	canvas.ClipsDescendants       = false
	canvas.ZIndex                 = 1
	canvas.Parent                 = nodesFrame

	uiScaleInst       = Instance.new("UIScale", canvas)
	uiScaleInst.Scale = canvasZoom
end

local function applyTransform()
	if not canvas or not uiScaleInst then return end
	uiScaleInst.Scale = canvasZoom
	canvas.Position   = UDim2.new(0, canvasPos.X, 0, canvasPos.Y)
	updateLabelVisibility()
end

local function treeCenter()
	local sumX, sumY, n = 0, 0, 0
	for _, skill in ipairs(SkillTree.Skills) do
		local px, py = nodePos(skill)
		sumX += px; sumY += py; n += 1
	end
	if n == 0 then return CANVAS_HALF, CANVAS_HALF end
	return sumX / n, sumY / n
end

local function centreView()
	task.wait()
	local sf       = nodesFrame.AbsoluteSize
	local tcx, tcy = treeCenter()
	canvasPos = Vector2.new(
		sf.X / 2 - tcx * canvasZoom,
		sf.Y / 2 - tcy * canvasZoom
	)
	applyTransform()
end

-- ── Pan & Zoom ───────────────────────────────────────────────────────────────

local function doZoom(factor, localMouse)
	local newZoom = math.clamp(canvasZoom * factor, MIN_ZOOM, MAX_ZOOM)
	if newZoom == canvasZoom then return end
	local ratio = newZoom / canvasZoom
	canvasPos  = localMouse - (localMouse - canvasPos) * ratio
	canvasZoom = newZoom
	applyTransform()
end

local inputWired = false

local function wireInput()
	if inputWired then return end
	inputWired = true

	UserInputService.InputBegan:Connect(function(input)
		if not isOpen then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		isDragging   = true
		dragDistance = 0
		dragStart    = Vector2.new(input.Position.X, input.Position.Y)
		dragOrigin   = canvasPos
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not isOpen then return end

		if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
			local pos    = Vector2.new(input.Position.X, input.Position.Y)
			local delta  = pos - dragStart
			dragDistance = delta.Magnitude
			if dragDistance > 4 then
				canvasPos = dragOrigin + delta
				applyTransform()
			end
		end

		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local mouseScreen = UserInputService:GetMouseLocation()
			local nfAbs       = nodesFrame.AbsolutePosition
			local localMouse  = mouseScreen - nfAbs
			local factor      = input.Position.Z > 0 and 1.12 or (1 / 1.12)
			doZoom(factor, localMouse)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = false
		end
	end)
end

-- ── Tooltip ──────────────────────────────────────────────────────────────────

local function buildTooltip()
	local t = Instance.new("Frame")
	t.Name                   = "SkillTooltip"
	t.Size                   = UDim2.new(0, 220, 0, 118)
	t.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	t.BackgroundTransparency = 0
	t.BorderSizePixel        = 0
	t.Visible                = false
	t.ZIndex                 = 50
	t.AnchorPoint            = Vector2.new(0.5, 1)
	t.Parent                 = mainFrame
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 8)
	local st = Instance.new("UIStroke", t)
	st.Color     = Color3.fromRGB(255, 255, 255)
	st.Thickness = 1.5

	local function lbl(name, posY, h, sz, col, wrap)
		local l                  = Instance.new("TextLabel", t)
		l.Name                   = name
		l.Size                   = UDim2.new(1, -12, 0, h)
		l.Position               = UDim2.new(0, 6, 0, posY)
		l.BackgroundTransparency = 1
		l.TextColor3             = col
		l.Font                   = Enum.Font.FredokaOne
		l.TextSize               = sz
		l.TextXAlignment         = Enum.TextXAlignment.Center
		l.TextWrapped            = wrap or false
		l.ZIndex                 = 51
		return l
	end

	lbl("TitleLabel",    6,  22, 16, Color3.fromRGB(255, 255, 255))
	lbl("DescLabel",    30,  40, 12, Color3.fromRGB(200, 200, 215), true)
	lbl("RequiresLabel",74,  16, 11, Color3.fromRGB(160, 200, 255))
	lbl("CostLabel",    94,  18, 13, Color3.fromRGB(255, 220, 80))
	return t
end

local function showTooltip(node, skill)
	if not tooltip then return end
	tooltip:FindFirstChild("TitleLabel").Text = skill.DisplayName
	tooltip:FindFirstChild("DescLabel").Text  = skill.Description

	-- Build "Requires: X, Y" line
	local reqNames = {}
	for _, reqId in ipairs(skill.Requires) do
		local s = SkillTree.GetSkill(reqId)
		if s then table.insert(reqNames, s.DisplayName) end
	end
	local reqLbl = tooltip:FindFirstChild("RequiresLabel")
	if reqLbl then
		reqLbl.Text = #reqNames > 0 and ("Requires: " .. table.concat(reqNames, ", ")) or ""
	end

	tooltip:FindFirstChild("CostLabel").Text  =
		skill.Cost == 0 and "FREE"
		or ("Cost: " .. formatCoins(skill.Cost) .. " coins")

	local absPos  = node.AbsolutePosition
	local mainPos = mainFrame.AbsolutePosition
	local halfW   = 110
	local cx = math.clamp(
		absPos.X + node.AbsoluteSize.X / 2 - mainPos.X,
		halfW + 4,
		mainFrame.AbsoluteSize.X - halfW - 4
	)
	local cy = absPos.Y - mainPos.Y - 6
	-- If the tooltip would clip off the top of the screen, drop it below the node.
	if cy < 110 then
		cy = absPos.Y + node.AbsoluteSize.Y - mainPos.Y + 110
		tooltip.AnchorPoint = Vector2.new(0.5, 1)
	else
		tooltip.AnchorPoint = Vector2.new(0.5, 1)
	end
	tooltip.Position = UDim2.new(0, cx, 0, cy)
	tooltip.Visible  = true
end

local function hideTooltip()
	if tooltip then tooltip.Visible = false end
end

-- Forward declaration — defined later but called in click handler
local updateNodeVisual

-- ── Node construction ────────────────────────────────────────────────────────

local function makeHexLayer(parent, color, sizeUDim, posUDim, zIndex)
	local hex
	if HAS_HEX_IMG then
		hex             = Instance.new("ImageLabel")
		hex.Image       = HEX_IMAGE
		hex.ImageColor3 = color
		hex.ScaleType   = Enum.ScaleType.Fit
		hex.BackgroundTransparency = 1
	else
		-- Fallback while the hex image hasn't been uploaded yet:
		-- a coloured rounded rectangle so the layout is still visible.
		hex = Instance.new("Frame")
		hex.BackgroundColor3 = color
		Instance.new("UICorner", hex).CornerRadius = UDim.new(0, 10)
	end
	hex.BorderSizePixel = 0
	hex.Size            = sizeUDim
	hex.Position        = posUDim
	hex.ZIndex          = zIndex
	hex.Parent          = parent
	return hex
end

local function setHexColor(hex, color)
	if hex:IsA("ImageLabel") then
		hex.ImageColor3 = color
	else
		hex.BackgroundColor3 = color
	end
end

local function buildNode(skill, onClick)
	local cx, cy = nodePos(skill)

	local node = Instance.new("Frame")
	node.Name                   = skill.Id
	node.Size                   = UDim2.new(0, HEX_W, 0, HEX_H)
	node.Position               = UDim2.new(0, cx - HEX_W / 2, 0, cy - HEX_H / 2)
	node.BackgroundTransparency = 1
	node.BorderSizePixel        = 0
	node.ZIndex                 = 5
	node.ClipsDescendants       = false

	-- Border hex — always white (colour overwritten by updateNodeVisual)
	local outline = makeHexLayer(node,
		Color3.fromRGB(255, 255, 255),
		UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0),
		5)
	outline.Name = "Outline"

	-- Green fill hex (slightly inset)
	local fill = makeHexLayer(node,
		Color3.fromRGB(30, 160, 60),
		UDim2.new(1, -OUTLINE_W * 2, 1, -OUTLINE_W * 2),
		UDim2.new(0, OUTLINE_W, 0, OUTLINE_W),
		6)
	fill.Name = "Fill"

	-- Icon — fixed pixel size so emojis render consistently across all nodes
	if skill.Icon ~= "" then
		local iconLbl = Instance.new("TextLabel", node)
		iconLbl.Name                   = "IconLabel"
		iconLbl.Size                   = UDim2.new(0.70, 0, 0.44, 0)
		iconLbl.Position               = UDim2.new(0.15, 0, 0.05, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Text                   = skill.Icon
		iconLbl.TextScaled             = false
		iconLbl.TextSize               = 38           -- fixed px — keeps all emojis the same size
		iconLbl.Font                   = Enum.Font.GothamBold
		iconLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
		iconLbl.TextXAlignment         = Enum.TextXAlignment.Center
		iconLbl.TextYAlignment         = Enum.TextYAlignment.Center
		iconLbl.ZIndex                 = 8
	end

	-- Name label — TextScaled but clamped so long names stay readable
	-- and short names don't balloon.  UITextSizeConstraint works alongside TextScaled.
	local nameLbl = Instance.new("TextLabel", node)
	nameLbl.Name                   = "NameLabel"
	nameLbl.Size                   = UDim2.new(0.90, 0, 0.42, 0)
	nameLbl.Position               = UDim2.new(0.05, 0, 0.50, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text                   = skill.DisplayName
	nameLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
	nameLbl.TextScaled             = true
	nameLbl.Font                   = Enum.Font.FredokaOne
	nameLbl.TextXAlignment         = Enum.TextXAlignment.Center
	nameLbl.TextYAlignment         = Enum.TextYAlignment.Center
	nameLbl.TextWrapped            = true
	nameLbl.ZIndex                 = 8
	local sizeConstraint = Instance.new("UITextSizeConstraint", nameLbl)
	sizeConstraint.MinTextSize = 9
	sizeConstraint.MaxTextSize = 17

	-- Invisible click button
	local btn = Instance.new("TextButton", node)
	btn.Size                   = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text                   = ""
	btn.ZIndex                 = 10
	btn.MouseButton1Click:Connect(function() onClick(skill) end)
	btn.MouseEnter:Connect(function() showTooltip(node, skill) end)
	btn.MouseLeave:Connect(function() hideTooltip() end)

	node.Parent          = canvas
	nodeFrames[skill.Id] = node
end

-- ── Node visual state ────────────────────────────────────────────────────────

-- fill color, outline color, text alpha (1 = faded)
-- owned     → green  / white outline
-- available → blue   / white outline  (prereqs met AND can afford)
-- poor      → grey   / white outline  (prereqs met, can't afford yet)
-- locked    → dark grey / white outline (prereqs not met)
local WHITE = Color3.fromRGB(255, 255, 255)
local STATE = {
	owned     = { fill = Color3.fromRGB(40,  190,  80), outline = WHITE, alpha = 0   },
	available = { fill = Color3.fromRGB(60,  130, 255), outline = WHITE, alpha = 0   },
	poor      = { fill = Color3.fromRGB(75,   75,  88), outline = WHITE, alpha = 0   },
	locked    = { fill = Color3.fromRGB(38,   38,  46), outline = WHITE, alpha = 0.5 },
}

function updateNodeVisual(skill)
	local node = nodeFrames[skill.Id]
	if not node then return end

	local outline = node:FindFirstChild("Outline")
	local fill    = node:FindFirstChild("Fill")
	local nameLbl = node:FindFirstChild("NameLabel")
	local iconLbl = node:FindFirstChild("IconLabel")
	if not outline or not fill then return end

	local owned      = unlockedSkills[skill.Id]
	local prereqsMet = SkillTree.CanUnlock(skill.Id, unlockedSkills)
	local canAfford  = currentCoins >= skill.Cost

	local s
	if owned then
		s = STATE.owned
	elseif prereqsMet and canAfford then
		s = STATE.available
	elseif prereqsMet then
		s = STATE.poor
	else
		s = STATE.locked
	end

	setHexColor(outline, s.outline)
	setHexColor(fill,    s.fill)
	if nameLbl then nameLbl.TextTransparency = s.alpha end
	if iconLbl then iconLbl.TextTransparency = s.alpha end
end

-- Show/hide name labels based on zoom level — zoomed out = icon only
updateLabelVisibility = function()
	local show = canvasZoom >= LABEL_HIDE_ZOOM
	for _, node in pairs(nodeFrames) do
		local lbl = node:FindFirstChild("NameLabel")
		if lbl then lbl.Visible = show end
	end
end

local function updateAllNodes()
	for _, skill in ipairs(SkillTree.Skills) do
		updateNodeVisual(skill)
	end
end

-- ── Click handler ────────────────────────────────────────────────────────────

local function onNodeClicked(skill)
	if dragDistance > 6 then return end
	if unlockedSkills[skill.Id] then return end

	local node = nodeFrames[skill.Id]

	if not SkillTree.CanUnlock(skill.Id, unlockedSkills) then
		if node then
			task.spawn(function()
				for _, r in ipairs({ -8, 8, -6, 6, -3, 3, 0 }) do
					node.Rotation = r; task.wait(0.03)
				end
				node.Rotation = 0
			end)
		end
		return
	end

	if currentCoins < skill.Cost then
		if node then
			local fill = node:FindFirstChild("Fill")
			if fill then
				setHexColor(fill, Color3.fromRGB(200, 30, 30))
				task.delay(0.6, function()
					if fill and fill.Parent then updateNodeVisual(skill) end
				end)
			end
		end
		return
	end

	if node then
		TweenService:Create(node,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, HEX_W * 1.12, 0, HEX_H * 1.12) }):Play()
		task.delay(0.1, function()
			TweenService:Create(node,
				TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0, HEX_W, 0, HEX_H) }):Play()
		end)
	end

	BuySkillEvent:FireServer(skill.Id)
end

-- ── Connectors ───────────────────────────────────────────────────────────────

local CONNECTOR_W     = 6
local CONNECTOR_COLOR = Color3.fromRGB(20, 60, 20)

local BRANCH_COLORS = {
	-- UP path (blue — luck path into Auto Roll)
	RollLuck1   = Color3.fromRGB(80,  150, 255),
	RollLuck2   = Color3.fromRGB(80,  150, 255),
	AutoRoll    = Color3.fromRGB(80,  150, 255),
	Fortune     = Color3.fromRGB(80,  180, 255),
	Destiny     = Color3.fromRGB(60,  210, 255),
	-- DOWN branch (cyan — speed)
	FasterAuto  = Color3.fromRGB(50,  200, 220),
	TurboAuto   = Color3.fromRGB(40,  185, 220),
	UltraAuto   = Color3.fromRGB(30,  170, 220),
	-- LEFT branch (gold — coins)
	CoinBoost1    = Color3.fromRGB(200, 150, 20),
	CoinBoost2    = Color3.fromRGB(200, 150, 20),
	RareBonus     = Color3.fromRGB(200, 150, 20),
	EpicBonus     = Color3.fromRGB(200, 140, 15),
	MythicBonus   = Color3.fromRGB(200, 120, 10),
	DivineMult    = Color3.fromRGB(180, 100, 10),
	CelestialMult = Color3.fromRGB(160,  80, 10),
	FarmingGold   = Color3.fromRGB(200, 150, 20),
	RandomBonus   = Color3.fromRGB(200, 150, 20),
	CoinRain      = Color3.fromRGB(220, 170, 30),
	-- RIGHT branch (orange-red — bonus rolls & luck)
	BonusRoll  = Color3.fromRGB(220, 100, 40),
	HotStreak  = Color3.fromRGB(210,  80, 20),
	Jackpot    = Color3.fromRGB(200,  60, 10),
	LuckySpin  = Color3.fromRGB(100, 160, 255),
	EpicLuck   = Color3.fromRGB(80,  130, 255),
}

local function drawConnector(x1, y1, x2, y2, color)
	local dx     = x2 - x1
	local dy     = y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 1 then return end

	local line = Instance.new("Frame")
	line.Name                   = "Connector"
	line.AnchorPoint            = Vector2.new(0, 0.5)
	line.Size                   = UDim2.new(0, length, 0, CONNECTOR_W)
	line.Position               = UDim2.new(0, x1, 0, y1)
	line.Rotation               = math.deg(math.atan2(dy, dx))
	line.BackgroundColor3       = color or CONNECTOR_COLOR
	line.BorderSizePixel        = 0
	line.ZIndex                 = 3
	line.Parent                 = canvas
end

local function drawConnectors()
	for _, skill in ipairs(SkillTree.Skills) do
		local cx, cy  = nodePos(skill)
		local lineCol = BRANCH_COLORS[skill.Id] or CONNECTOR_COLOR
		for _, reqId in ipairs(skill.Requires) do
			local reqSkill = SkillTree.GetSkill(reqId)
			if reqSkill then
				local rx, ry = nodePos(reqSkill)
				drawConnector(rx, ry, cx, cy, lineCol)
			end
		end
	end
end

-- ── Build the full tree ──────────────────────────────────────────────────────

local function buildTree()
	for _, child in ipairs(canvas:GetChildren()) do
		if not child:IsA("UIScale") then child:Destroy() end
	end
	nodeFrames = {}

	for _, skill in ipairs(SkillTree.Skills) do
		buildNode(skill, onNodeClicked)
	end

	updateAllNodes()
	updateLabelVisibility()
end

-- ── Open / Close ─────────────────────────────────────────────────────────────

local function openTree()
	if isOpen then return end
	isOpen     = true
	canvasZoom = 1.0

	mainFrame.BackgroundTransparency = 1
	mainFrame.Visible                = true

	TweenService:Create(mainFrame,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }):Play()

	task.spawn(function()
		local data     = GetSkillsEvent:InvokeServer()
		unlockedSkills = data.unlocked or {}
		currentCoins   = data.coins    or 0
		coinsLbl.Text  = "🪙 " .. formatCoins(currentCoins)

		createCanvas()
		buildTree()
		centreView()
	end)
end

local function closeTree()
	if not isOpen then return end
	isOpen     = false
	isDragging = false
	hideTooltip()

	TweenService:Create(mainFrame,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }):Play()

	task.delay(0.18, function()
		mainFrame.Visible = false
		if canvas then
			canvas:Destroy()
			canvas      = nil
			uiScaleInst = nil
		end
		nodeFrames = {}
	end)
end

-- ── Initialise frames & GUI ──────────────────────────────────────────────────

skillGui.IgnoreGuiInset = true

mainFrame.Visible                = false
mainFrame.AnchorPoint            = Vector2.new(0, 0)
mainFrame.Size                   = UDim2.new(1, 0, 1, 0)
mainFrame.Position               = UDim2.new(0, 0, 0, 0)
mainFrame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel        = 0

nodesFrame.AnchorPoint            = Vector2.new(0, 0)
nodesFrame.Size                   = UDim2.new(1, 0, 1, 0)
nodesFrame.Position               = UDim2.new(0, 0, 0, 0)
nodesFrame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
nodesFrame.BackgroundTransparency = 0
nodesFrame.ClipsDescendants       = true
nodesFrame.BorderSizePixel        = 0

topBar.ZIndex = 20
for _, child in ipairs(topBar:GetDescendants()) do
	if child:IsA("GuiObject") then child.ZIndex = 21 end
end

tooltip = buildTooltip()
wireInput()

-- ── Remote handlers ──────────────────────────────────────────────────────────

ToggleSkillTree.Event:Connect(function()
	if isOpen then closeTree() else openTree() end
end)

closeBtn.MouseButton1Click:Connect(closeTree)

SkillUnlockedEvent.OnClientEvent:Connect(function(skillId, newCoins)
	unlockedSkills[skillId] = true
	currentCoins  = newCoins
	coinsLbl.Text = "🪙 " .. formatCoins(currentCoins)

	local node = nodeFrames[skillId]
	if node then
		TweenService:Create(node,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, HEX_W * 1.2, 0, HEX_H * 1.2) }):Play()
		task.delay(0.15, function()
			TweenService:Create(node,
				TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0, HEX_W, 0, HEX_H) }):Play()
		end)
	end
	updateAllNodes()
end)

CoinsUpdateEvent.OnClientEvent:Connect(function(newCoins)
	currentCoins  = newCoins
	coinsLbl.Text = "🪙 " .. formatCoins(currentCoins)
	if isOpen then updateAllNodes() end
end)
