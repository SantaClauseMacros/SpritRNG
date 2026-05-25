-- DataManager.server.lua (with SkillTree patch applied)

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpiritRNG = require(ReplicatedStorage:WaitForChild("SpiritRNG"))
local DataStore = DataStoreService:GetDataStore("SpiritRNG_v2")

local RollEvent = ReplicatedStorage:WaitForChild("RollSpiritEvent")

local GetInventoryEvent = Instance.new("RemoteFunction")
GetInventoryEvent.Name   = "GetInventoryEvent"
GetInventoryEvent.Parent = ReplicatedStorage

local GetCoinsEvent = Instance.new("RemoteFunction")
GetCoinsEvent.Name   = "GetCoinsEvent"
GetCoinsEvent.Parent = ReplicatedStorage

-- ── SkillTree bridge ──────────────────────────────────────────────────────────
-- These are created by SkillTreeServer.server.lua; WaitForChild lets it boot first.
local CoinsChangedBind    = ReplicatedStorage:WaitForChild("CoinsChangedBind",    10)
local DeductCoinsBind     = ReplicatedStorage:WaitForChild("DeductCoinsBind",     10)
local GetSkillEffectsBind = ReplicatedStorage:WaitForChild("GetSkillEffectsBind", 10)
-- ─────────────────────────────────────────────────────────────────────────────

-- Rarity tier used to decide which coin multipliers apply on a roll.
local RARITY_TIER = {
	Common=0, Uncommon=1, Rare=2, Epic=3, Legendary=4, Mythic=5, Divine=6, Celestial=7,
}

-- ─────────────────────────────────────────────
-- Data
-- ─────────────────────────────────────────────

local playerData = {}   -- [player] = { inventory, totalRolls, coins }
local dirtyFlags = {}   -- [player] = bool
local cooldowns  = {}   -- [player] = tick()

local DEFAULT_DATA = {
	inventory  = {},
	totalRolls = 0,
	coins      = 0,
}

local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = (type(v) == "table") and deepCopy(v) or v
	end
	return copy
end

-- ─────────────────────────────────────────────
-- Load / Save
-- ─────────────────────────────────────────────

local function loadData(player)
	local ok, result = pcall(function()
		return DataStore:GetAsync("player_" .. player.UserId)
	end)

	if ok and type(result) == "table" then
		local merged = deepCopy(DEFAULT_DATA)
		for k, v in pairs(result) do merged[k] = v end
		playerData[player] = merged
	else
		if not ok then
			warn(("[DataManager] Failed to load %s: %s"):format(player.Name, tostring(result)))
		end
		playerData[player] = deepCopy(DEFAULT_DATA)
	end

	dirtyFlags[player] = false
	print(("[DataManager] Loaded data for %s"):format(player.Name))

	-- Seed SkillTree's coin mirror with the real loaded total.
	-- Without this, SkillTree starts at 0 until the first roll fires.
	if CoinsChangedBind then
		CoinsChangedBind:Fire(player, playerData[player].coins)
	end
end

local function saveData(player)
	if not dirtyFlags[player] then return end   -- nothing changed

	local data = playerData[player]
	if not data then return end

	local ok, err = pcall(function()
		DataStore:UpdateAsync("player_" .. player.UserId, function(old)
			if type(old) ~= "table" then return data end

			-- Merge: for numeric fields take the higher value so a race between
			-- two servers never silently erases progress.
			return {
				inventory  = data.inventory,
				totalRolls = math.max(old.totalRolls or 0, data.totalRolls or 0),
				coins      = math.max(old.coins      or 0, data.coins      or 0),
			}
		end)
	end)

	if ok then
		dirtyFlags[player] = false
		print(("[DataManager] Saved %s"):format(player.Name))
	else
		warn(("[DataManager] Failed to save %s: %s"):format(player.Name, tostring(err)))
	end
end

-- ─────────────────────────────────────────────
-- Roll handler
-- ─────────────────────────────────────────────

local COOLDOWN = 1.5

RollEvent.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then return end

	-- Fetch live skill effects (reads in-memory data from SkillTreeServer — fast)
	local effects = {}
	if GetSkillEffectsBind then
		local ok, res = pcall(function() return GetSkillEffectsBind:Invoke(player) end)
		if ok and type(res) == "table" then effects = res end
	end

	-- Rate limiting with auto_delay skill factored in (0.35x at max = ~0.5 s cooldown)
	local now = tick()
	local effectiveCooldown = COOLDOWN * (effects.auto_delay or 1)
	if cooldowns[player] and (now - cooldowns[player]) < effectiveCooldown then return end
	cooldowns[player] = now

	-- Roll with luck (rarer spirits get a weight boost based on luck_add total)
	local result = SpiritRNG.RollSpiritWithLuck(effects.luck_add or 0)
	local rarity = SpiritRNG.GetRarityName(result)

	-- Rarity-specific coin multipliers stack upward through tiers:
	--   rare_mult      applies to Rare+      (tier ≥ 2)
	--   epic_mult      applies to Epic+      (tier ≥ 3)
	--   mythic_mult    applies to Mythic+    (tier ≥ 5)
	--   divine_mult    applies to Divine+    (tier ≥ 6)
	--   celestial_mult applies to Celestial  (tier ≥ 7)
	local tier       = RARITY_TIER[rarity] or 0
	local rarityMult = 1
	if tier >= 2 then rarityMult *= (effects.rare_mult      or 1) end
	if tier >= 3 then rarityMult *= (effects.epic_mult      or 1) end
	if tier >= 5 then rarityMult *= (effects.mythic_mult    or 1) end
	if tier >= 6 then rarityMult *= (effects.divine_mult    or 1) end
	if tier >= 7 then rarityMult *= (effects.celestial_mult or 1) end

	local coinsEarned = math.floor(
		SpiritRNG.GetBaseCoinValue(result) * (effects.coins_mult or 1) * rarityMult
	)

	-- Coin Rain: flat % chance to double the payout on any roll
	local coinRainChance = effects.coin_rain or 0
	if coinRainChance > 0 and math.random() < coinRainChance then
		coinsEarned = coinsEarned * 2
	end

	data.inventory[result]  = (data.inventory[result] or 0) + 1
	data.totalRolls        += 1
	data.coins             += coinsEarned
	dirtyFlags[player]      = true

	if CoinsChangedBind then
		CoinsChangedBind:Fire(player, data.coins)
	end

	print(("[DataManager] %s rolled %s (%s) | +%d coins | total: %d"):format(
		player.Name, result, rarity, coinsEarned, data.coins
	))

	RollEvent:FireClient(player, result, coinsEarned, data.coins)

	-- Bonus Roll: chance to fire a second spirit automatically
	local doubleChance = effects.double_roll or 0
	if doubleChance > 0 and math.random() < doubleChance then
		local result2 = SpiritRNG.RollSpiritWithLuck(effects.luck_add or 0)
		local rarity2 = SpiritRNG.GetRarityName(result2)
		local tier2   = RARITY_TIER[rarity2] or 0
		local mult2   = 1
		if tier2 >= 2 then mult2 *= (effects.rare_mult      or 1) end
		if tier2 >= 3 then mult2 *= (effects.epic_mult      or 1) end
		if tier2 >= 5 then mult2 *= (effects.mythic_mult    or 1) end
		if tier2 >= 6 then mult2 *= (effects.divine_mult    or 1) end
		if tier2 >= 7 then mult2 *= (effects.celestial_mult or 1) end
		local coins2 = math.floor(SpiritRNG.GetBaseCoinValue(result2) * (effects.coins_mult or 1) * mult2)
		if coinRainChance > 0 and math.random() < coinRainChance then coins2 = coins2 * 2 end

		data.inventory[result2] = (data.inventory[result2] or 0) + 1
		data.totalRolls        += 1
		data.coins             += coins2
		dirtyFlags[player]      = true

		if CoinsChangedBind then CoinsChangedBind:Fire(player, data.coins) end
		RollEvent:FireClient(player, result2, coins2, data.coins)
	end
end)

-- ─────────────────────────────────────────────
-- SkillTree coin deduction listener
-- Fires when a player buys a skill. Deducts from the canonical coin total
-- here in DataManager and then re-syncs the SkillTree mirror.
-- ─────────────────────────────────────────────

if DeductCoinsBind then
	DeductCoinsBind.Event:Connect(function(player, amount)
		local data = playerData[player]
		if not data then return end

		data.coins         = math.max(0, data.coins - amount)
		dirtyFlags[player] = true

		-- Re-sync SkillTree mirror with the post-deduction total.
		-- SkillTreeServer's CoinsChangedBind handler pushes the new total to the
		-- client via SkillCoinsUpdateEvent — no separate RollEvent needed here.
		if CoinsChangedBind then
			CoinsChangedBind:Fire(player, data.coins)
		end
	end)
end

-- ─────────────────────────────────────────────
-- Remote functions
-- ─────────────────────────────────────────────

GetInventoryEvent.OnServerInvoke = function(player)
	local data = playerData[player]
	if not data then return { inventory = {}, totalRolls = 0, coins = 0 } end
	return { inventory = data.inventory, totalRolls = data.totalRolls, coins = data.coins }
end

GetCoinsEvent.OnServerInvoke = function(player)
	local data = playerData[player]
	return data and data.coins or 0
end

-- ─────────────────────────────────────────────
-- Periodic save — staggered so all players don't
-- hit the DataStore at the exact same tick.
-- ─────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(60)
		local list = Players:GetPlayers()
		for i, player in ipairs(list) do
			saveData(player)
			if i < #list then task.wait(0.5) end
		end
	end
end)

-- ─────────────────────────────────────────────
-- Player lifecycle
-- ─────────────────────────────────────────────

Players.PlayerAdded:Connect(loadData)

-- Handle players who were already in the server when this script started
-- (e.g. on a server-restart hot reload). PlayerAdded does NOT fire for them.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadData, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player] = nil
	cooldowns[player]  = nil
	dirtyFlags[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		if dirtyFlags[player] then task.spawn(saveData, player) end
	end
	task.wait(2)
end)
