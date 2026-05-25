-- RollButton.client.lua (fixed)
-- Changes:
--   • All RenderStepped connections are tracked and cleaned up on
--     character removal so they never leak.
--   • Coin popup is guarded: only one floats at a time during auto-roll,
--     preventing a flood of TextLabel instances.
--   • Viewport is collapsed before a new roll starts if somehow still visible,
--     preventing double-model situations.
--   • Minor: stopAllConnections() helper centralises cleanup.
--   • Everything else is unchanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local SpiritRNG     = require(ReplicatedStorage:WaitForChild("SpiritRNG"))
local RollEvent     = ReplicatedStorage:WaitForChild("RollSpiritEvent")
local GetCoinsEvent = ReplicatedStorage:WaitForChild("GetCoinsEvent")

local screenFrame  = script.Parent.Parent.Parent
local button       = script.Parent
local rollingImage = button:WaitForChild("RollingImage")
local invButton    = screenFrame:WaitForChild("BottomButtons"):WaitForChild("InventoryButton")
local leftButtons  = screenFrame:WaitForChild("LeftButtons")
local coinAmtLabel = leftButtons:WaitForChild("CoinsAmountLabel")

local playerGui         = Players.LocalPlayer:WaitForChild("PlayerGui")
local rngGui            = playerGui:WaitForChild("RNGGui")
local label             = rngGui:WaitForChild("ResultLabel")
local chanceLabel       = rngGui:WaitForChild("ChanceLabel")
local viewport          = rngGui:WaitForChild("RollingFrame")
local hiddenFrame       = rngGui:WaitForChild("HiddenRollingFrame")
local hiddenIcon        = hiddenFrame:WaitForChild("HiddenRollingIcon")
local hiddenResultLabel = hiddenFrame:WaitForChild("ResultLabel")

local autoRollFrame  = rngGui:WaitForChild("AutoRollFrame")
local autoRollBtn    = autoRollFrame:WaitForChild("AutoRollButton")
local hideRollsFrame = rngGui:WaitForChild("HideRollsFrame")
local hideRollsBtn   = hideRollsFrame:WaitForChild("AutoRollButton")

local ToggleInventory = ReplicatedStorage:FindFirstChild("ToggleInventory")
	or Instance.new("BindableEvent", ReplicatedStorage)
ToggleInventory.Name = "ToggleInventory"

invButton.MouseButton1Click:Connect(function()
	ToggleInventory:Fire()
end)

local buttonsGui = screenFrame.Parent
buttonsGui.IgnoreGuiInset = true
rngGui.IgnoreGuiInset     = true

local vpCamera = Instance.new("Camera")
vpCamera.Parent                 = viewport
viewport.CurrentCamera          = vpCamera
viewport.BackgroundTransparency = 1
viewport.AnchorPoint            = Vector2.new(0.5, 0.5)

local VP_SIZE     = UDim2.new(0, 300, 0, 300)
local VP_POS_REST = UDim2.new(0.5, 0, 0.4, 0)

viewport.Size     = VP_SIZE
viewport.Position = VP_POS_REST
viewport.Visible  = false
label.Visible       = false
chanceLabel.Visible = false

rollingImage.Visible  = false
rollingImage.Rotation = 0
hiddenFrame.Visible   = false
hiddenFrame.Size      = UDim2.new(0, 0, 0, 0)

autoRollFrame.Visible  = false
autoRollFrame.Size     = UDim2.new(0, 0, 0, 0)
hideRollsFrame.Visible = false
hideRollsFrame.Size    = UDim2.new(0, 0, 0, 0)

-- ─────────────────────────────────────────────
-- Screen flash overlay
-- ─────────────────────────────────────────────

local flashFrame = Instance.new("Frame")
flashFrame.Size                   = UDim2.new(1, 0, 1, 0)
flashFrame.Position               = UDim2.new(0, 0, 0, 0)
flashFrame.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel        = 0
flashFrame.ZIndex                 = 100
flashFrame.Parent                 = rngGui

local function screenFlash(color, intensity)
	intensity = intensity or 0.55
	flashFrame.BackgroundColor3       = color
	flashFrame.BackgroundTransparency = 1 - intensity
	TweenService:Create(flashFrame, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

-- ─────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────

local spinning       = false
local autoRolling    = false
local hideRolls      = false
local uiHidden       = false
local currentModel   = nil
local angle          = 0

-- Connection handles — all tracked so we can clean up on character removal
local spinConnection   = nil
local imgSpinConn      = nil
local autoRollBtnConn  = nil

local imgAngle         = 0
local autoRollBtnAngle = 0

local spirits    = SpiritRNG.GetAllSpirits()
local spiritData = {}
for _, name in ipairs(spirits) do
	table.insert(spiritData, {
		name    = name,
		display = SpiritRNG.GetDisplayName(name),
		image   = SpiritRNG.GetImageId(name),
		color   = SpiritRNG.GetRarityColor(name),
	})
end

local RARE_RARITIES = { Legendary = true, Mythic = true, Epic = true, Celestial = true }

-- ─────────────────────────────────────────────
-- Connection cleanup — called on character removal
-- ─────────────────────────────────────────────

local function stopAllConnections()
	if spinConnection  then spinConnection:Disconnect();  spinConnection  = nil end
	if imgSpinConn     then imgSpinConn:Disconnect();     imgSpinConn     = nil end
	if autoRollBtnConn then autoRollBtnConn:Disconnect(); autoRollBtnConn = nil end
end

Players.LocalPlayer.CharacterRemoving:Connect(stopAllConnections)

-- ─────────────────────────────────────────────
-- Spin indicators
-- ─────────────────────────────────────────────

local function startImageSpin()
	if imgSpinConn then return end
	rollingImage.Visible = true
	imgSpinConn = RunService.RenderStepped:Connect(function(dt)
		imgAngle = (imgAngle + dt * 360) % 360
		rollingImage.Rotation = imgAngle
	end)
end

local function stopImageSpin()
	if imgSpinConn then imgSpinConn:Disconnect(); imgSpinConn = nil end
	TweenService:Create(rollingImage, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = 0,
	}):Play()
	task.delay(0.3, function()
		if not imgSpinConn then rollingImage.Visible = false end
	end)
end

local function startAutoRollBtnSpin()
	if autoRollBtnConn then return end
	autoRollBtnConn = RunService.RenderStepped:Connect(function(dt)
		autoRollBtnAngle = (autoRollBtnAngle + dt * 300) % 360
		autoRollBtn.Rotation = autoRollBtnAngle
	end)
end

local function stopAutoRollBtnSpin()
	if autoRollBtnConn then autoRollBtnConn:Disconnect(); autoRollBtnConn = nil end
	TweenService:Create(autoRollBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = 0,
	}):Play()
end

-- ─────────────────────────────────────────────
-- Individual button show / hide
-- ─────────────────────────────────────────────

local function showAutoRollBtn()
	autoRollFrame.Size    = UDim2.new(0, 0, 0, 0)
	autoRollFrame.Visible = true
	TweenService:Create(autoRollFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 100, 0, 100),
	}):Play()
end

local function hideAutoRollBtn(callback)
	TweenService:Create(autoRollFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
	}):Play()
	task.delay(0.2, function()
		autoRollFrame.Visible = false
		if callback then callback() end
	end)
end

local function showHideRollsBtn()
	hideRollsFrame.Size    = UDim2.new(0, 0, 0, 0)
	hideRollsFrame.Visible = true
	TweenService:Create(hideRollsFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 100, 0, 100),
	}):Play()
end

local function hideHideRollsBtn(callback)
	TweenService:Create(hideRollsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
	}):Play()
	task.delay(0.2, function()
		hideRollsFrame.Visible = false
		if callback then callback() end
	end)
end

-- ─────────────────────────────────────────────
-- Other-UI hide / show
-- ─────────────────────────────────────────────

local function hideOtherUI()
	if uiHidden then return end
	uiHidden = true
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui ~= rngGui then gui.Enabled = false end
	end
	showAutoRollBtn()
	if autoRolling then showHideRollsBtn() end
end

local function showOtherUI()
	if not uiHidden then return end
	uiHidden = false
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui ~= rngGui then gui.Enabled = true end
	end
	hideAutoRollBtn()
	hideHideRollsBtn()
end

-- ─────────────────────────────────────────────
-- Press animation
-- ─────────────────────────────────────────────

local function pressAnim(btn)
	local orig = btn.Size
	TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(orig.X.Scale * 0.88, orig.X.Offset * 0.88,
			orig.Y.Scale * 0.88, orig.Y.Offset * 0.88),
	}):Play()
	task.delay(0.08, function()
		TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = orig,
		}):Play()
	end)
end

-- ─────────────────────────────────────────────
-- Coin display
-- ─────────────────────────────────────────────

local function formatCoins(n)
	n = n or 0
	if     n >= 1000000 then return string.format("%.1fM", n / 1000000)
	elseif n >= 1000    then return string.format("%.1fK", n / 1000)
	end
	return tostring(n)
end

local function updateCoinDisplay(amount)
	coinAmtLabel.Text = formatCoins(amount)
end

-- Guard: only one coin popup floats at a time to prevent instance floods
-- during auto-roll.
local coinPopupActive = false

local function showCoinPopup(amount)
	if coinPopupActive then return end
	coinPopupActive = true

	local popup = Instance.new("TextLabel")
	popup.Size                   = UDim2.new(0, 140, 0, 28)
	popup.AnchorPoint            = Vector2.new(0.5, 1)
	popup.Position               = UDim2.new(leftButtons.Position.X.Scale + 0.07, 0, leftButtons.Position.Y.Scale, 0)
	popup.BackgroundTransparency = 1
	popup.Text                   = "🪙 +" .. amount
	popup.TextColor3             = Color3.fromRGB(255, 220, 80)
	popup.TextScaled             = true
	popup.Font                   = Enum.Font.GothamBold
	popup.ZIndex                 = 10
	popup.Parent                 = rngGui

	TweenService:Create(popup, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position         = UDim2.new(leftButtons.Position.X.Scale + 0.07, 0, leftButtons.Position.Y.Scale - 0.08, 0),
		TextTransparency = 1,
	}):Play()

	task.delay(1.4, function()
		popup:Destroy()
		coinPopupActive = false
	end)
end

task.spawn(function()
	local coins = GetCoinsEvent:InvokeServer()
	coinAmtLabel.Text = formatCoins(coins)
end)

-- ─────────────────────────────────────────────
-- Viewport / pet helpers
-- ─────────────────────────────────────────────

local function tw(obj, t, style, dir, props)
	style = style or Enum.EasingStyle.Quad
	dir   = dir   or Enum.EasingDirection.Out
	TweenService:Create(obj, TweenInfo.new(t, style, dir), props):Play()
end

local function startPetRotation(fast)
	if spinConnection then spinConnection:Disconnect() end
	spinConnection = RunService.RenderStepped:Connect(function(dt)
		angle += dt * (fast and 320 or 80)
		if currentModel then
			local cf = currentModel:GetBoundingBox()
			currentModel:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, math.rad(angle), 0))
		end
	end)
end

local function stopPetRotation()
	if spinConnection then spinConnection:Disconnect(); spinConnection = nil end
end

local function clearModel()
	if currentModel then currentModel:Destroy(); currentModel = nil end
end

local function loadPet(spiritName)
	clearModel()
	currentModel           = SpiritRNG.LoadPetIntoViewport(spiritName, viewport, vpCamera)
	label.Text             = SpiritRNG.GetDisplayName(spiritName)
	chanceLabel.Text       = SpiritRNG.GetChanceDisplay(spiritName)
	chanceLabel.TextColor3 = SpiritRNG.GetRarityColor(spiritName)
end

local function collapseViewport()
	viewport.Visible             = false
	viewport.Rotation            = 0
	viewport.Size                = VP_SIZE
	viewport.Position            = VP_POS_REST
	label.Visible                = false
	label.TextTransparency       = 0
	label.TextColor3             = Color3.fromRGB(255, 255, 255)
	chanceLabel.Visible          = false
	chanceLabel.TextTransparency = 0
	clearModel()
	stopPetRotation()
end

-- ─────────────────────────────────────────────
-- Hidden frame helpers
-- ─────────────────────────────────────────────

local function spiritEntryFor(name)
	for _, d in ipairs(spiritData) do
		if d.name == name then return d end
	end
end

local function setHiddenEntry(entry)
	if entry.image ~= "" then hiddenIcon.Image = entry.image end
	hiddenResultLabel.Text       = entry.display
	hiddenResultLabel.TextColor3 = entry.color
end

local function showHiddenFrame()
	hiddenFrame.Size    = UDim2.new(0, 0, 0, 0)
	hiddenFrame.Visible = true
	TweenService:Create(hiddenFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 100, 0, 100),
	}):Play()
end

local function hideHiddenFrame()
	TweenService:Create(hiddenFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
	}):Play()
	task.delay(0.2, function() hiddenFrame.Visible = false end)
end

local function hiddenFrameLand(color, rarity)
	local orig = hiddenFrame.BackgroundColor3
	hiddenFrame.BackgroundColor3 = color
	tw(hiddenFrame, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = UDim2.new(0, 118, 0, 118) })
	task.wait(0.12)
	tw(hiddenFrame, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Size = UDim2.new(0, 100, 0, 100) })
	TweenService:Create(hiddenFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = orig,
	}):Play()
	if RARE_RARITIES[rarity] then screenFlash(color, 0.45) end
end

-- ─────────────────────────────────────────────
-- Roll animation helpers
-- ─────────────────────────────────────────────

local function slotDelay(i, total)
	return 0.02 + (i / total) ^ 2.5 * 0.35
end

local function popIn()
	viewport.Size                = UDim2.new(0, 0, 0, 0)
	viewport.Position            = VP_POS_REST
	viewport.Visible             = true
	label.TextTransparency       = 1
	label.Visible                = true
	chanceLabel.TextTransparency = 1
	chanceLabel.Visible          = true
	tw(viewport,    0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Size = VP_SIZE })
	tw(label,       0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { TextTransparency = 0 })
	tw(chanceLabel, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { TextTransparency = 0 })
end

local function landingBurst(spiritName)
	local rarity = SpiritRNG.GetRarityName(spiritName)
	local color  = SpiritRNG.GetRarityColor(spiritName)

	screenFlash(color, RARE_RARITIES[rarity] and 0.65 or 0.35)

	tw(viewport, 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = UDim2.new(0, 370, 0, 370) })
	task.wait(0.09)
	tw(viewport, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Size = VP_SIZE })

	label.TextColor3 = color
	label.TextSize   = 34
	tw(label, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { TextSize = 18 })
	chanceLabel.TextSize = 28
	tw(chanceLabel, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { TextSize = 14 })

	task.spawn(function()
		local shakeAmts = RARE_RARITIES[rarity]
			and { -12, 12, -9, 9, -6, 6, -3, 3, -1, 1, 0 }
			or  { -5, 5, -3, 3, -1, 1, 0 }
		for _, r in ipairs(shakeAmts) do
			viewport.Rotation = r
			task.wait(0.035)
		end
		viewport.Rotation = 0
	end)
end

local function popOut(callback)
	viewport.Rotation = 0
	tw(viewport, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
		Size     = UDim2.new(0, 200, 0, 200),
		Position = UDim2.new(0.5, 0, 0.22, 0),
	})
	tw(label,       0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { TextTransparency = 0.5 })
	tw(chanceLabel, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { TextTransparency = 0.5 })
	task.wait(0.45)
	tw(viewport, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In, {
		Size     = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 1.15, 0),
	})
	tw(label,       0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { TextTransparency = 1 })
	tw(chanceLabel, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { TextTransparency = 1 })
	task.delay(0.4, function()
		collapseViewport()
		if callback then callback() end
	end)
end

local function wobbleButton()
	local orig = button.Rotation
	for _, r in ipairs({ -7, 7, -5, 5, -3, 3, -1, 1, 0 }) do
		button.Rotation = orig + r
		task.wait(0.035)
	end
	button.Rotation = orig
end

-- ─────────────────────────────────────────────
-- Main spin animation
-- ─────────────────────────────────────────────

local function spinAnimation(finalResult, coinsEarned, totalCoins)
	spinning = true

	-- Safety: collapse any leftover viewport from a previous roll
	if viewport.Visible then collapseViewport() end

	startImageSpin()
	if autoRolling then startAutoRollBtnSpin() end

	local FRAMES = 28

	if hideRolls then
		showHiddenFrame()
	else
		popIn()
		startPetRotation(true)
	end

	local wasHidden = hideRolls

	for i = 1, FRAMES do
		local sp    = spirits[math.random(1, #spirits)]
		local entry = spiritEntryFor(sp)

		if hideRolls then
			if not wasHidden then
				collapseViewport()
				if not hiddenFrame.Visible then showHiddenFrame() end
				wasHidden = true
			end
			if entry then setHiddenEntry(entry) end
		else
			wasHidden = false
			loadPet(sp)
			label.TextColor3       = Color3.fromRGB(255, 255, 255)
			label.TextTransparency = 0
			tw(label,       0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { TextTransparency = 0.25 })
			tw(chanceLabel, 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { TextTransparency = 0.4 })
		end

		task.wait(slotDelay(i, FRAMES))
	end

	-- Landing
	local finalEntry = spiritEntryFor(finalResult)

	if hideRolls then
		if viewport.Visible then collapseViewport() end
		if not hiddenFrame.Visible then showHiddenFrame() end

		if finalEntry then
			setHiddenEntry(finalEntry)
			hiddenFrameLand(finalEntry.color, SpiritRNG.GetRarityName(finalResult))
		end

		task.wait(0.4)
		updateCoinDisplay(totalCoins)
		showCoinPopup(coinsEarned)
		task.wait(2.6)

		hideHiddenFrame()
		task.wait(0.2)

		spinning = false
		stopImageSpin()

		if autoRolling then
			RollEvent:FireServer()
		else
			stopAutoRollBtnSpin()
		end

	else
		if not viewport.Visible then
			popIn()
			startPetRotation(true)
			task.wait(0.15)
		end

		viewport.Position = VP_POS_REST
		startPetRotation(false)

		loadPet(finalResult)
		label.TextColor3             = Color3.fromRGB(255, 255, 255)
		label.TextTransparency       = 0
		chanceLabel.TextTransparency = 0

		landingBurst(finalResult)

		task.wait(0.5)
		updateCoinDisplay(totalCoins)
		showCoinPopup(coinsEarned)
		task.wait(2.5)

		popOut(function()
			spinning = false
			stopImageSpin()
			if autoRolling then
				task.wait(0.1)
				RollEvent:FireServer()
			else
				stopAutoRollBtnSpin()
				showOtherUI()
			end
		end)
	end
end

-- ─────────────────────────────────────────────
-- Toggle visuals
-- ─────────────────────────────────────────────

local function setAutoRollVisual(active)
	TweenService:Create(autoRollFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
		BackgroundColor3 = active and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(40, 40, 50),
	}):Play()
end

local function setHideRollsVisual(active)
	TweenService:Create(hideRollsFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
		BackgroundColor3 = active and Color3.fromRGB(80, 150, 255) or Color3.fromRGB(40, 40, 50),
	}):Play()
end

-- ─────────────────────────────────────────────
-- Button handlers
-- ─────────────────────────────────────────────

autoRollBtn.MouseButton1Click:Connect(function()
	pressAnim(autoRollBtn)
	autoRolling = not autoRolling
	setAutoRollVisual(autoRolling)

	if autoRolling then
		showHideRollsBtn()
		if not spinning then RollEvent:FireServer() end
	else
		hideHideRollsBtn()
		stopAutoRollBtnSpin()

		if hideRolls then
			hideRolls = false
			setHideRollsVisual(false)
			hideHiddenFrame()
		end

		if not spinning then showOtherUI() end
	end
end)

hideRollsBtn.MouseButton1Click:Connect(function()
	if not autoRolling then return end

	pressAnim(hideRollsBtn)
	hideRolls = not hideRolls
	setHideRollsVisual(hideRolls)

	if hideRolls then
		hideAutoRollBtn()
		hideHideRollsBtn()

		if uiHidden then
			uiHidden = false
			for _, gui in ipairs(playerGui:GetChildren()) do
				if gui:IsA("ScreenGui") and gui ~= rngGui then gui.Enabled = true end
			end
		end

		stopAutoRollBtnSpin()
	else
		hideHiddenFrame()
		showAutoRollBtn()
		showHideRollsBtn()
		setHideRollsVisual(false)

		if autoRolling then
			hideOtherUI()
			startAutoRollBtnSpin()
		end
	end
end)

hiddenFrame.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if not hideRolls then return end

	hideRolls = false
	setHideRollsVisual(false)
	hideHiddenFrame()
	showAutoRollBtn()
	showHideRollsBtn()

	if autoRolling then
		hideOtherUI()
		startAutoRollBtnSpin()
	end
end)

button.MouseButton1Click:Connect(function()
	if spinning then return end
	pressAnim(button)
	task.spawn(wobbleButton)
	hideOtherUI()
	RollEvent:FireServer()
end)

RollEvent.OnClientEvent:Connect(function(result, coinsEarned, totalCoins)
	spinAnimation(result, coinsEarned, totalCoins)
end)
