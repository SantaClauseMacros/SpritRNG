-- ExpeditionClient.lua
-- LocalScript → StarterPlayerScripts
-- Thin client: references YOUR Studio-built MinigameFrame UI.
-- Creates NO UI of its own.
--
-- REQUIRED UI HIERARCHY (build this in StarterGui):
--   StarterGui > ExpeditionGui (ScreenGui)
--     > MinigameFrame (Frame, Visible=false)
--       > Title (TextLabel)
--       > StageLabel (TextLabel)
--       > Bar (Frame)
--         > GreenZone (Frame)
--         > Pointer (Frame)
--       > ResultLabel (TextLabel)
--       > ClickButton (TextButton)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local StarterGui        = game:GetService("StarterGui")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local ExpStartMinigame  = ReplicatedStorage:WaitForChild("ExpStartMinigame", 15)
local ExpMinigameResult = ReplicatedStorage:WaitForChild("ExpMinigameResult", 15)
local ExpMinigameEnd    = ReplicatedStorage:WaitForChild("ExpMinigameEnd", 15)
local ExpNotifyEvent    = ReplicatedStorage:WaitForChild("ExpNotifyEvent", 15)
local ExpAnnounceEvent  = ReplicatedStorage:WaitForChild("ExpAnnounceEvent", 15)

-- UI references (you built these in Studio)
local gui            = playerGui:WaitForChild("ExpeditionGui")
local minigameFrame  = gui:WaitForChild("MinigameFrame")
local titleLbl       = minigameFrame:WaitForChild("Title")
local stageLbl       = minigameFrame:WaitForChild("StageLabel")
local barFrame       = minigameFrame:WaitForChild("Bar")
local greenZone      = barFrame:WaitForChild("GreenZone")
local pointer        = barFrame:WaitForChild("Pointer")
local resultLbl      = minigameFrame:WaitForChild("ResultLabel")
local clickBtn       = minigameFrame:WaitForChild("ClickButton")

minigameFrame.Visible = false

-- ─────────────────────────────────────────────────────────────────────────────
-- MINIGAME STATE
-- ─────────────────────────────────────────────────────────────────────────────

local activeStage   = 0      -- 1..3 while minigame is running
local greenPos      = 0      -- 0..1
local greenSize     = 0.2    -- 0..1 (fraction of bar)
local pointerSpeed  = 0.5    -- cycles per second
local pointerStart  = 0      -- tick() when this stage began
local renderConn    = nil
local clickArmed    = false

-- ─────────────────────────────────────────────────────────────────────────────
-- POINTER ANIMATION  (ping-pongs across the bar)
-- ─────────────────────────────────────────────────────────────────────────────

local function startPointerAnim()
	if renderConn then renderConn:Disconnect() end
	pointerStart = tick()
	renderConn = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - pointerStart
		-- Position oscillates 0..1..0 using triangle wave
		local phase = (elapsed * pointerSpeed) % 1   -- 0..1
		local pos   = (phase < 0.5) and (phase * 2) or (2 - phase * 2)  -- triangle
		pointer.Position = UDim2.new(pos, 0, 0, 0)
	end)
end

local function stopPointerAnim()
	if renderConn then renderConn:Disconnect(); renderConn = nil end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- STAGE START  (server → client)
-- ─────────────────────────────────────────────────────────────────────────────

ExpStartMinigame.OnClientEvent:Connect(function(stageData)
	activeStage   = stageData.stage
	greenPos      = stageData.greenPos
	greenSize     = stageData.greenSize
	pointerSpeed  = stageData.speed

	-- Apply visuals to YOUR UI
	greenZone.Position = UDim2.new(greenPos, 0, 0, 0)
	greenZone.Size     = UDim2.new(greenSize, 0, 1, 0)

	stageLbl.Text  = "Stage " .. activeStage .. "/3"
	resultLbl.Text = ""

	minigameFrame.Visible = true
	clickArmed = true
	startPointerAnim()
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- PLAYER CLICK
-- ─────────────────────────────────────────────────────────────────────────────

clickBtn.MouseButton1Click:Connect(function()
	if not clickArmed or activeStage == 0 then return end
	clickArmed = false
	stopPointerAnim()

	-- Determine current pointer position
	local elapsed = tick() - pointerStart
	local phase   = (elapsed * pointerSpeed) % 1
	local pos     = (phase < 0.5) and (phase * 2) or (2 - phase * 2)
	pointer.Position = UDim2.new(pos, 0, 0, 0)

	-- Hit if pointer center is inside green zone bounds
	local hit = pos >= greenPos and pos <= (greenPos + greenSize)
	resultLbl.Text       = hit and "✅ HIT!" or "❌ MISS"
	resultLbl.TextColor3 = hit and Color3.fromRGB(80, 220, 100) or Color3.fromRGB(220, 80, 80)

	-- Brief pause for feedback, then send result to server
	task.wait(0.7)
	ExpMinigameResult:FireServer(activeStage, hit)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- MINIGAME END  (server → client, after 3 stages)
-- ─────────────────────────────────────────────────────────────────────────────

ExpMinigameEnd.OnClientEvent:Connect(function(result)
	stopPointerAnim()
	activeStage = 0
	clickArmed  = false

	-- Show final reward in resultLbl
	local lines = { ("🪙 +%d coins  (%d/3 hits)"):format(result.coins or 0, result.hits or 0) }
	if result.scroll then table.insert(lines, "📜 " .. result.scroll.DisplayName) end
	if result.rare   then table.insert(lines, result.rare.Emoji .. " " .. result.rare.DisplayName .. "!") end
	resultLbl.Text       = table.concat(lines, "  •  ")
	resultLbl.TextColor3 = result.rare and Color3.fromRGB(255,160,255)
		or (result.hits and result.hits > 0 and Color3.fromRGB(255,220,80)
			or Color3.fromRGB(200,200,200))

	task.wait(2.5)
	minigameFrame.Visible = false
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- NOTIFICATIONS  (server → client, chat-style)
-- ─────────────────────────────────────────────────────────────────────────────

ExpNotifyEvent.OnClientEvent:Connect(function(message)
	-- Use Roblox's chat system so no extra UI is needed
	pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text     = message,
			Color    = Color3.fromRGB(255, 220, 80),
			Font     = Enum.Font.GothamBold,
			TextSize = 18,
		})
	end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- SERVER-WIDE RARE FIND ANNOUNCEMENT
-- ─────────────────────────────────────────────────────────────────────────────

ExpAnnounceEvent.OnClientEvent:Connect(function(eventType, data)
	if eventType ~= "rareFind" then return end
	pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text     = ("🌟 %s found %s %s in %s!"):format(
				data.player or "?", data.emoji or "", data.item or "?", data.site or "?"),
			Color    = Color3.fromRGB(200, 120, 255),
			Font     = Enum.Font.GothamBold,
			TextSize = 20,
		})
	end)
end)
