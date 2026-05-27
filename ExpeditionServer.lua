-- ExpeditionServer.lua
-- Script → ServerScriptService
-- Simplified Expedition System (PS99-style worlds + 3-stage minigame).
--
-- HOW IT WORKS:
--   • Player walks into a Workspace/DigSites/[Site]/Boundary
--   • Server picks fossil templates from ReplicatedStorage/Fossils/[Site]/
--     and clones them at random spots inside FossilArea (or Boundary as fallback),
--     raycasting to ground so they sit on the terrain
--   • Each fossil keeps the ProximityPrompt YOU put in the template
--   • Player triggers prompt → server validates → fires minigame to client
--   • Client runs 3-stage timing minigame, sends back hit count
--   • Server grants coins = baseCoins × spiritCount × hits × (1 + luck)
--   • Fossil despawns, respawns ~5s later
--
-- DOORS (site unlock):
--   • Workspace/DigSites/[Site]/Door  must have a ProximityPrompt inside
--   • Triggering it pays UnlockCost and unlocks the site (deletes the Door)

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local SpiritRNG      = require(ReplicatedStorage:WaitForChild("SpiritRNG"))
local ExpeditionData = require(ReplicatedStorage:WaitForChild("ExpeditionData"))

local ExpDS = DataStoreService:GetDataStore("Expedition_v1")

-- ── DataManager bridges ───────────────────────────────────────────────────────
local CoinsChangedBind = ReplicatedStorage:WaitForChild("CoinsChangedBind", 10)
local DeductCoinsBind  = ReplicatedStorage:WaitForChild("DeductCoinsBind",  10)

local AddCoinsBind = Instance.new("BindableEvent")
AddCoinsBind.Name   = "AddCoinsBind"
AddCoinsBind.Parent = ReplicatedStorage

-- ── Remotes ───────────────────────────────────────────────────────────────────
local function remote(class, name)
	local r = Instance.new(class); r.Name = name; r.Parent = ReplicatedStorage; return r
end

local ExpGetDataEvent      = remote("RemoteFunction", "ExpGetDataEvent")
local ExpEquipSpiritEvent  = remote("RemoteEvent",    "ExpEquipSpiritEvent")
local ExpUpdateEvent       = remote("RemoteEvent",    "ExpUpdateEvent")        -- server → one client (equip, unlock, etc)
local ExpStartMinigame     = remote("RemoteEvent",    "ExpStartMinigame")      -- server → client (begin a stage)
local ExpMinigameResult    = remote("RemoteEvent",    "ExpMinigameResult")     -- client → server (stage hit/miss)
local ExpMinigameEnd       = remote("RemoteEvent",    "ExpMinigameEnd")        -- server → client (final reward)
local ExpNotifyEvent       = remote("RemoteEvent",    "ExpNotifyEvent")        -- server → client (chat-style messages)
local ExpAnnounceEvent     = remote("RemoteEvent",    "ExpAnnounceEvent")      -- server → ALL clients (rare finds)

-- ── Per-player data ───────────────────────────────────────────────────────────
local playerData  = {}
local dirtyFlags  = {}
local coinMirror  = {}
local activeMinigame = {}   -- [player] = { siteId, stage, hits, teamStats, fossilModel, stageStartTime }

local DEFAULT_DATA = {
	unlockedSites   = { Desert = true },
	equippedSpirits = {},
	traits          = {},
	scrolls         = {},
	stats = {
		totalDigs     = 0,
		coinsEarned   = 0,
		raresFound    = 0,
	},
}

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}; for k, v in pairs(t) do c[k] = deepCopy(v) end; return c
end

-- ── Trait rolling ─────────────────────────────────────────────────────────────
local function rollTrait()
	local isNeg = math.random() < ExpeditionData.NegativeTraitChance
	local pool, total = {}, 0
	for _, t in ipairs(ExpeditionData.Traits) do
		if (isNeg and t.Category == "negative") or (not isNeg and t.Category ~= "negative") then
			local w = ExpeditionData.TraitRarityWeights[t.Rarity] or 10
			total += w
			table.insert(pool, { id = t.Id, cum = total })
		end
	end
	if total == 0 then return "Lucky" end
	local roll = math.random() * total
	for _, e in ipairs(pool) do
		if roll <= e.cum then return e.id end
	end
	return pool[#pool].id
end

-- ── Load / Save ───────────────────────────────────────────────────────────────
local function loadData(player)
	local ok, result = pcall(function() return ExpDS:GetAsync("exp_" .. player.UserId) end)
	local data = deepCopy(DEFAULT_DATA)
	if ok and type(result) == "table" then
		for k, v in pairs(result) do
			if data[k] ~= nil and type(v) == type(data[k]) then
				if type(v) == "table" then
					for k2, v2 in pairs(v) do data[k][k2] = v2 end
				else
					data[k] = v
				end
			end
		end
	end
	playerData[player] = data
	dirtyFlags[player] = false
	coinMirror[player] = 0
end

local function saveData(player)
	if not dirtyFlags[player] then return end
	local data = playerData[player]
	if not data then return end
	local ok, err = pcall(function()
		ExpDS:SetAsync("exp_" .. player.UserId, {
			unlockedSites   = data.unlockedSites,
			equippedSpirits = data.equippedSpirits,
			traits          = data.traits,
			scrolls         = data.scrolls,
			stats           = data.stats,
		})
	end)
	if ok then dirtyFlags[player] = false end
end

if CoinsChangedBind then
	CoinsChangedBind.Event:Connect(function(player, total)
		coinMirror[player] = total
	end)
end

-- ── Remotes: get data, equip ──────────────────────────────────────────────────

ExpGetDataEvent.OnServerInvoke = function(player)
	local data = playerData[player]
	if not data then return {} end
	return {
		unlockedSites   = deepCopy(data.unlockedSites),
		equippedSpirits = deepCopy(data.equippedSpirits),
		traits          = deepCopy(data.traits),
		scrolls         = deepCopy(data.scrolls),
		stats           = deepCopy(data.stats),
		coins           = coinMirror[player] or 0,
	}
end

ExpEquipSpiritEvent.OnServerEvent:Connect(function(player, slot, spiritName)
	local data = playerData[player]
	if not data then return end
	if typeof(slot) ~= "number" or slot < 1 or slot > 3 then return end
	if typeof(spiritName) ~= "string" then return end

	local key = tostring(slot)
	if spiritName == "" then
		data.equippedSpirits[key] = nil
	else
		if not data.traits[spiritName] then
			data.traits[spiritName] = rollTrait()
		end
		data.equippedSpirits[key] = spiritName
	end
	dirtyFlags[player] = true

	ExpUpdateEvent:FireClient(player, "equip", {
		slot    = slot,
		spirit  = spiritName ~= "" and spiritName or nil,
		traitId = spiritName ~= "" and data.traits[spiritName] or nil,
	})
end)

-- ── Spirit team helpers ───────────────────────────────────────────────────────

local function buildSpiritList(data)
	local list = {}
	for slot = 1, 3 do
		local n = data.equippedSpirits[tostring(slot)]
		if n then
			if not data.traits[n] then data.traits[n] = rollTrait(); dirtyFlags[_G.__placeholder] = nil end
			table.insert(list, { name = n, rarity = SpiritRNG.GetRarityName(n), traitId = data.traits[n] })
		end
	end
	return list
end

local function countEquipped(data)
	local n = 0
	for slot = 1, 3 do
		if data.equippedSpirits[tostring(slot)] then n += 1 end
	end
	return n
end

-- ── Fossil spawning ───────────────────────────────────────────────────────────

local activeFossils = {}   -- [siteId] = { fossilModel = true, … } (set of currently-spawned fossils)
local FOSSILS_PER_SITE = 5
local FOSSIL_RESPAWN_DELAY = 4

local function findGroundY(x, z, refPart)
	-- Raycast down from above the spawn area
	local top    = refPart.Position.Y + refPart.Size.Y / 2 + 5
	local result = Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -200, 0))
	return result and (result.Position.Y + 0.5) or refPart.Position.Y
end

local function randomPointInArea(areaPart)
	local size = areaPart.Size
	local hx = size.X / 2 - 5
	local hz = size.Z / 2 - 5
	local lx = math.random() * (hx * 2) - hx
	local lz = math.random() * (hz * 2) - hz
	local world = areaPart.CFrame * CFrame.new(lx, 0, lz)
	return world.Position
end

-- Returns the part that defines where fossils SPAWN.
-- Prefers a dedicated "FossilArea" part; falls back to "Boundary" if missing.
local function getFossilAreaPart(siteFolder)
	return siteFolder:FindFirstChild("FossilArea") or siteFolder:FindFirstChild("Boundary")
end

local function pickFossilTemplate(siteId)
	local fossilsFolder = ReplicatedStorage:FindFirstChild("Fossils")
	if not fossilsFolder then return nil end
	local siteFolder = fossilsFolder:FindFirstChild(siteId)
	if not siteFolder then return nil end
	local children = siteFolder:GetChildren()
	if #children == 0 then return nil end
	return children[math.random(1, #children)]
end

-- forward declarations
local startMinigameStage
local spawnFossilForSite

local function onFossilTriggered(player, fossil, siteId, prompt)
	local data = playerData[player]
	if not data then return end

	if not data.unlockedSites[siteId] then
		ExpNotifyEvent:FireClient(player, "🔒 This site is locked!")
		return
	end

	if countEquipped(data) == 0 then
		ExpNotifyEvent:FireClient(player, "⚠️ Equip at least 1 spirit first!")
		return
	end

	if activeMinigame[player] then return end

	-- Compute team stats
	local teamStats = ExpeditionData.ComputeTeamStats(buildSpiritList(data), SpiritRNG)

	-- Mark fossil claimed: destroy and schedule respawn
	if fossil and fossil.Parent then
		activeFossils[siteId] = activeFossils[siteId] or {}
		activeFossils[siteId][fossil] = nil
		fossil:Destroy()
	end
	task.delay(FOSSIL_RESPAWN_DELAY, function() spawnFossilForSite(siteId) end)

	-- Begin minigame stage 1
	activeMinigame[player] = {
		siteId    = siteId,
		stage     = 1,
		hits      = 0,
		teamStats = teamStats,
		startTime = tick(),
	}
	startMinigameStage(player)
end

function spawnFossilForSite(siteId)
	local sitesFolder = Workspace:FindFirstChild("DigSites")
	local siteFolder  = sitesFolder and sitesFolder:FindFirstChild(siteId)
	if not siteFolder then return end
	local area = getFossilAreaPart(siteFolder)
	if not area then return end

	local template = pickFossilTemplate(siteId)
	if not template then return end

	local clone = template:Clone()

	-- Position inside the FossilArea (or Boundary fallback), on the ground
	local pos      = randomPointInArea(area)
	local groundY  = findGroundY(pos.X, pos.Z, area)
	local finalPos = Vector3.new(pos.X, groundY, pos.Z)

	if clone:IsA("Model") then
		if clone.PrimaryPart then
			clone:PivotTo(CFrame.new(finalPos))
		else
			-- Try to use first part as anchor
			local first = clone:FindFirstChildWhichIsA("BasePart")
			if first then
				clone:PivotTo(CFrame.new(finalPos))
			end
		end
	elseif clone:IsA("BasePart") then
		clone.Position = finalPos
		clone.Anchored = true
	end

	clone.Parent = siteFolder

	-- Find the ProximityPrompt the user put in the template
	local prompt = clone:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		-- Auto-add one if user forgot
		local hostPart = clone:IsA("BasePart") and clone
			or (clone:IsA("Model") and (clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")))
		if hostPart then
			prompt = Instance.new("ProximityPrompt")
			prompt.ActionText            = "Excavate"
			prompt.HoldDuration          = 0
			prompt.MaxActivationDistance = 12
			prompt.Parent = hostPart
		end
	end

	activeFossils[siteId] = activeFossils[siteId] or {}
	activeFossils[siteId][clone] = true

	if prompt then
		prompt.Triggered:Connect(function(player)
			onFossilTriggered(player, clone, siteId, prompt)
		end)
	end
end

local function countActiveFossilsInSite(siteId)
	local set = activeFossils[siteId]
	if not set then return 0 end
	local n = 0
	for fossil in pairs(set) do
		if fossil and fossil.Parent then n += 1 else set[fossil] = nil end
	end
	return n
end

-- Spawn initial fossils in every site
task.spawn(function()
	task.wait(2)  -- let workspace settle
	local sitesFolder = Workspace:FindFirstChild("DigSites")
	if not sitesFolder then return end
	for _, siteFolder in ipairs(sitesFolder:GetChildren()) do
		local siteId = siteFolder.Name
		if siteFolder:FindFirstChild("Boundary") then
			for _ = 1, FOSSILS_PER_SITE do
				spawnFossilForSite(siteId)
			end
		end
	end
end)

-- Top-up loop: keep each site at FOSSILS_PER_SITE
task.spawn(function()
	while true do
		task.wait(8)
		local sitesFolder = Workspace:FindFirstChild("DigSites")
		if sitesFolder then
			for _, siteFolder in ipairs(sitesFolder:GetChildren()) do
				local siteId  = siteFolder.Name
				local current = countActiveFossilsInSite(siteId)
				for _ = current + 1, FOSSILS_PER_SITE do
					spawnFossilForSite(siteId)
				end
			end
		end
	end
end)

-- ── Minigame logic ────────────────────────────────────────────────────────────

function startMinigameStage(player)
	local mg = activeMinigame[player]
	if not mg then return end
	mg.stageStartTime = tick()

	-- Difficulty scales with stage
	local stage      = mg.stage
	-- Green zone size: bigger with luck, smaller per stage
	local baseGreen  = 0.35 - 0.08 * (stage - 1)   -- stage 1=0.35, 2=0.27, 3=0.19
	local luckBonus  = mg.teamStats.Luck * 0.20    -- up to +0.20
	local greenSize  = math.clamp(baseGreen + luckBonus, 0.08, 0.55)
	local greenPos   = math.random() * (1 - greenSize)
	-- Pointer speed: slower with high DigSpeed
	local baseSpeed  = 0.5 + 0.25 * (stage - 1)    -- s1=0.5, s2=0.75, s3=1.0 cycles/sec
	local digSpeed   = math.max(0.5, mg.teamStats.DigSpeed)
	local speed      = baseSpeed / math.sqrt(digSpeed)

	ExpStartMinigame:FireClient(player, {
		stage     = stage,
		greenPos  = greenPos,
		greenSize = greenSize,
		speed     = speed,
	})
end

local function rollRareDiscovery(teamStats)
	for _, disc in ipairs(ExpeditionData.RareDiscoveries) do
		local chance = disc.BaseChance * (teamStats.ArtifactMult or 1) * (1 + teamStats.Luck)
		if math.random() < chance then return disc end
	end
end

local function rollScroll(teamStats)
	if math.random() > 0.10 * (teamStats.ScrollMult or 1) then return nil end
	local total, pool = 0, {}
	for _, s in ipairs(ExpeditionData.Scrolls) do
		total += s.DropWeight
		table.insert(pool, { scroll = s, cum = total })
	end
	local r = math.random() * total
	for _, e in ipairs(pool) do
		if r <= e.cum then return e.scroll end
	end
end

ExpMinigameResult.OnServerEvent:Connect(function(player, stage, hit)
	local mg = activeMinigame[player]
	if not mg then return end
	if mg.stage ~= stage then return end
	-- anti-spam
	if mg.stageStartTime and tick() - mg.stageStartTime < 0.20 then return end

	if hit then mg.hits += 1 end

	if mg.stage < 3 then
		mg.stage += 1
		startMinigameStage(player)
		return
	end

	-- All 3 stages done — grant rewards
	local data         = playerData[player]
	local site         = ExpeditionData.SiteLookup[mg.siteId]
	local spiritCount  = data and countEquipped(data) or 1
	local baseCoins    = (site and site.BaseCoins or 500)
	local coinMult     = mg.teamStats.CoinMult or 1
	local coins        = math.floor(baseCoins * spiritCount * mg.hits * (1 + mg.teamStats.Luck) * coinMult)

	local scroll = rollScroll(mg.teamStats)
	local rare   = rollRareDiscovery(mg.teamStats)

	if coins > 0 then AddCoinsBind:Fire(player, coins) end

	if data then
		data.stats.totalDigs   = (data.stats.totalDigs or 0) + 1
		data.stats.coinsEarned = (data.stats.coinsEarned or 0) + coins
		if scroll then
			data.scrolls[scroll.Id] = (data.scrolls[scroll.Id] or 0) + 1
		end
		if rare then
			data.stats.raresFound = (data.stats.raresFound or 0) + 1
		end
		dirtyFlags[player] = true
	end

	if rare then
		ExpAnnounceEvent:FireAllClients("rareFind", {
			player = player.Name, item = rare.DisplayName,
			emoji = rare.Emoji,    site = mg.siteId,
		})
	end

	ExpMinigameEnd:FireClient(player, {
		hits   = mg.hits,
		coins  = coins,
		scroll = scroll,
		rare   = rare,
	})

	activeMinigame[player] = nil
end)

-- ── Door (unlock) setup ───────────────────────────────────────────────────────

local function wireDoor(siteFolder, door)
	local siteId = siteFolder.Name
	local site   = ExpeditionData.SiteLookup[siteId]
	if not site then return end

	local prompt = door:IsA("BasePart")
		and door:FindFirstChildWhichIsA("ProximityPrompt")
		or door:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		warn("[Expedition] Door for " .. siteId .. " is missing a ProximityPrompt. Add one to make it clickable.")
		return
	end

	-- Update the prompt's text with the cost
	prompt.ActionText = ("Unlock %s — %d coins"):format(site.DisplayName, site.UnlockCost)

	prompt.Triggered:Connect(function(player)
		local data = playerData[player]
		if not data then return end
		if data.unlockedSites[siteId] then
			-- Already unlocked for this player; hide the door for them only is complex,
			-- so we just remove globally on unlock. (Multiple players share doors.)
			return
		end
		if (coinMirror[player] or 0) < site.UnlockCost then
			ExpNotifyEvent:FireClient(player,
				("💸 Need %d more coins to unlock %s"):format(
					site.UnlockCost - (coinMirror[player] or 0), site.DisplayName))
			return
		end
		DeductCoinsBind:Fire(player, site.UnlockCost)
		data.unlockedSites[siteId] = true
		dirtyFlags[player] = true
		ExpNotifyEvent:FireClient(player, ("🔓 Unlocked %s!"):format(site.DisplayName))
		-- Visually open the door
		if door:IsA("BasePart") then
			door.CanCollide   = false
			door.Transparency = 1
		elseif door:IsA("Model") then
			for _, part in ipairs(door:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide   = false
					part.Transparency = 1
				end
			end
		end
		ExpUpdateEvent:FireClient(player, "unlocked", { siteId = siteId })
	end)
end

task.spawn(function()
	task.wait(2)
	local sitesFolder = Workspace:FindFirstChild("DigSites")
	if not sitesFolder then return end
	for _, siteFolder in ipairs(sitesFolder:GetChildren()) do
		local door = siteFolder:FindFirstChild("Door")
		if door then wireDoor(siteFolder, door) end
	end
end)

-- ── Periodic save ─────────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(60)
		for _, p in ipairs(Players:GetPlayers()) do
			saveData(p)
			task.wait(0.5)
		end
	end
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(loadData)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(loadData, p) end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player]     = nil
	dirtyFlags[player]     = nil
	coinMirror[player]     = nil
	activeMinigame[player] = nil
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		if dirtyFlags[p] then task.spawn(saveData, p) end
	end
	task.wait(2)
end)

--[[
═══════════════════════════════════════════════════════════════════════════════
DATAMANAGER PATCH (already applied, but here's the snippet for reference)

    local AddCoinsBind = ReplicatedStorage:WaitForChild("AddCoinsBind", 10)
    if AddCoinsBind then
        AddCoinsBind.Event:Connect(function(player, amount)
            local data = playerData[player]
            if not data then return end
            data.coins         = data.coins + math.floor(amount)
            dirtyFlags[player] = true
            if CoinsChangedBind then CoinsChangedBind:Fire(player, data.coins) end
        end)
    end
═══════════════════════════════════════════════════════════════════════════════
]]
