-- SpiritRNG.lua (fixed)
-- Changes:
--   • RollSpirit now uses a proper weighted-pool so odds are correct and
--     rarer spirits can't shadow common ones.
--   • Pre-computed total weight at require-time (zero cost per roll).
--   • Everything else is unchanged.

local SpiritRNG = {}

local Spirits = {
	-- Common
	{ Name = "EarthSpiritPet",    DisplayName = "Earth Spirit",    Rarity = "Common",    Chance = 10,    Coins = 100,    ImageId = "rbxassetid://94494042045268" },
	{ Name = "MudSpiritPet",      DisplayName = "Mud Spirit",      Rarity = "Common",    Chance = 15,    Coins = 150,    ImageId = "rbxassetid://115927493763806" },
	{ Name = "WaterSpiritPet",    DisplayName = "Water Spirit",    Rarity = "Common",    Chance = 20,    Coins = 200,    ImageId = "rbxassetid://99470945550400" },
	{ Name = "WindSpiritPet",     DisplayName = "Wind Spirit",     Rarity = "Common",    Chance = 30,    Coins = 300,    ImageId = "rbxassetid://114705811007652" },

	-- Uncommon
	{ Name = "FireSpiritPet",     DisplayName = "Fire Spirit",     Rarity = "Uncommon",  Chance = 50,    Coins = 500,    ImageId = "rbxassetid://121212110830171" },
	{ Name = "IceSpiritPet",      DisplayName = "Ice Spirit",      Rarity = "Uncommon",  Chance = 75,    Coins = 750,    ImageId = "rbxassetid://93725976636418" },

	-- Rare
	{ Name = "LightSpiritPet",    DisplayName = "Light Spirit",    Rarity = "Rare",      Chance = 150,   Coins = 1500,   ImageId = "rbxassetid://133639396285655" },
	{ Name = "ElectricSpiritPet", DisplayName = "Electric Spirit", Rarity = "Rare",      Chance = 200,   Coins = 2000,   ImageId = "rbxassetid://126022420358037" },
	{ Name = "TornadoSpiritPet",  DisplayName = "Tornado Spirit",  Rarity = "Rare",      Chance = 250,   Coins = 2500,   ImageId = "rbxassetid://72967745964859" },

	-- Epic
	{ Name = "SunSpiritPet",      DisplayName = "Sun Spirit",      Rarity = "Epic",      Chance = 500,   Coins = 5000,   ImageId = "rbxassetid://113345290587542" },
	{ Name = "MoltenSpiritPet",   DisplayName = "Molten Spirit",   Rarity = "Epic",      Chance = 650,   Coins = 6500,   ImageId = "rbxassetid://97323656768486" },
	{ Name = "VolcanoSpiritPet",  DisplayName = "Volcano Spirit",  Rarity = "Epic",      Chance = 800,   Coins = 8000,   ImageId = "rbxassetid://139940387777226" },
	{ Name = "DemonSpiritPet",    DisplayName = "Demon Spirit",    Rarity = "Epic",      Chance = 1000,  Coins = 10000,  ImageId = "rbxassetid://128865567531328" },
	{ Name = "DarkSpiritPet",     DisplayName = "Dark Spirit",     Rarity = "Epic",      Chance = 1200,  Coins = 12000,  ImageId = "rbxassetid://79449276582270" },

	-- Legendary
	{ Name = "MoonSpiritPet",     DisplayName = "Moon Spirit",     Rarity = "Legendary", Chance = 2500,  Coins = 25000,  ImageId = "rbxassetid://133222219155351" },
	{ Name = "VoidSpiritPet",     DisplayName = "Void Spirit",     Rarity = "Legendary", Chance = 3000,  Coins = 30000,  ImageId = "rbxassetid://129407044742273" },

	-- Mythic
	{ Name = "AngelSpiritPet",    DisplayName = "Angel Spirit",    Rarity = "Mythic",    Chance = 5000,  Coins = 50000,  ImageId = "rbxassetid://83151551225773" },
	{ Name = "CosmicSpiritPet",   DisplayName = "Cosmic Spirit",   Rarity = "Mythic",    Chance = 7500,  Coins = 75000,  ImageId = "rbxassetid://96427476529116" },

	-- Divine
	{ Name = "EclipseSpiritPet",  DisplayName = "Eclipse Spirit",  Rarity = "Divine",    Chance = 15000, Coins = 150000, ImageId = "rbxassetid://88996285724689" },

	-- Celestial
	{ Name = "GalaxySpiritPet",   DisplayName = "Galaxy Spirit",   Rarity = "Celestial", Chance = 50000, Coins = 500000, ImageId = "rbxassetid://86866335533618" },
}

local RarityColors = {
	CosmicSpiritPet   = Color3.fromRGB(170, 120, 255), -- Cosmic Purple
	VoidSpiritPet     = Color3.fromRGB(90, 70, 180),   -- Deep Void
	DarkSpiritPet     = Color3.fromRGB(120, 60, 160),  -- Dark Purple
	SunSpiritPet      = Color3.fromRGB(255, 210, 80),  -- Sun Gold
	ElectricSpiritPet = Color3.fromRGB(80, 220, 255),  -- Electric Blue
	LightSpiritPet    = Color3.fromRGB(255, 245, 180), -- Bright Light
	IceSpiritPet      = Color3.fromRGB(170, 240, 255), -- Ice Blue
	FireSpiritPet     = Color3.fromRGB(255, 120, 80),  -- Fire Orange
	WindSpiritPet     = Color3.fromRGB(180, 255, 220), -- Wind Mint
	WaterSpiritPet    = Color3.fromRGB(100, 180, 255), -- Water Blue
	EarthSpiritPet    = Color3.fromRGB(120, 200, 120), -- Earth Green
	MoonSpiritPet     = Color3.fromRGB(210, 220, 255), -- Moon Silver
	AngelSpiritPet    = Color3.fromRGB(255, 250, 220), -- Angel White
	DemonSpiritPet    = Color3.fromRGB(255, 70, 70),   -- Demon Red
	GalaxySpiritPet   = Color3.fromRGB(190, 120, 255), -- Galaxy Purple
	SandSpiritPet     = Color3.fromRGB(240, 220, 140), -- Sand Tan
	VolcanoSpiritPet  = Color3.fromRGB(255, 90, 40),   -- Volcano Lava
	MudSpiritPet      = Color3.fromRGB(145, 105, 70),  -- Mud Brown
	TornadoSpiritPet  = Color3.fromRGB(180, 255, 245), -- Stormy Cyan
	MoltenSpiritPet   = Color3.fromRGB(255, 130, 20),  -- Molten Orange
	EclipseSpiritPet  = Color3.fromRGB(80, 40, 140),   -- Eclipse Purple
}

-- ─────────────────────────────────────────────
-- Pre-build lookup and weighted-roll table once at require time.
-- Each spirit's "weight" = 1 / Chance, scaled to avoid tiny floats.
-- ─────────────────────────────────────────────

local SpiritLookup   = {}
local weightedPool   = {}   -- { name, cumulative } sorted ascending
local totalWeight    = 0

for _, spirit in ipairs(Spirits) do
	SpiritLookup[spirit.Name] = spirit

	-- Use 1 000 000 / Chance so everything stays integer-like
	local w = 1000000 / spirit.Chance
	totalWeight += w
	table.insert(weightedPool, { name = spirit.Name, cumulative = totalWeight })
end

-- ─────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────

local RARITY_TIER = {
	Common    = 0,
	Uncommon  = 1,
	Rare      = 2,
	Epic      = 3,
	Legendary = 4,
	Mythic    = 5,
	Divine    = 6,
	Celestial = 7,
}
local LUCK_SCALE = 50  -- each luck_add point × tier × LUCK_SCALE boosts that spirit's weight

-- Correct weighted roll: one random number, binary-search the pool.
function SpiritRNG.RollSpirit()
	local roll = math.random() * totalWeight
	for _, entry in ipairs(weightedPool) do
		if roll <= entry.cumulative then
			return entry.name
		end
	end
	return "EarthSpiritPet"   -- fallback (should never trigger)
end

-- Luck-adjusted roll: rarer spirits get a weight boost proportional to luck_add.
-- With max luck (~0.009) and LUCK_SCALE=50, Celestial weight is ~4x, Common stays 1x.
function SpiritRNG.RollSpiritWithLuck(luckBonus)
	if not luckBonus or luckBonus <= 0 then
		return SpiritRNG.RollSpirit()
	end
	local adjTotal = 0
	local adjPool  = {}
	for _, spirit in ipairs(Spirits) do
		local tier = RARITY_TIER[spirit.Rarity] or 0
		local w    = (1000000 / spirit.Chance) * (1 + luckBonus * tier * LUCK_SCALE)
		adjTotal  += w
		table.insert(adjPool, { name = spirit.Name, cumulative = adjTotal })
	end
	local roll = math.random() * adjTotal
	for _, entry in ipairs(adjPool) do
		if roll <= entry.cumulative then return entry.name end
	end
	return "EarthSpiritPet"
end

function SpiritRNG.GetAllSpirits()
	local list = {}
	for _, spirit in ipairs(Spirits) do
		table.insert(list, spirit.Name)
	end
	return list
end

function SpiritRNG.GetSpiritData()
	return Spirits
end

function SpiritRNG.GetRarityColor(spiritName)
	return RarityColors[spiritName] or Color3.fromRGB(255, 255, 255)
end

function SpiritRNG.GetDisplayName(spiritName)
	local s = SpiritLookup[spiritName]
	return s and s.DisplayName or spiritName
end

function SpiritRNG.GetRarityName(spiritName)
	local s = SpiritLookup[spiritName]
	return s and s.Rarity or "Common"
end

function SpiritRNG.GetBaseCoinValue(spiritName)
	local s = SpiritLookup[spiritName]
	return s and s.Coins or 200
end

function SpiritRNG.GetChanceDisplay(spiritName)
	local s = SpiritLookup[spiritName]
	if not s then return "1/???" end
	return "1/" .. tostring(s.Chance)
end

function SpiritRNG.GetImageId(spiritName)
	local s = SpiritLookup[spiritName]
	return s and s.ImageId or ""
end

function SpiritRNG.HasImage(spiritName)
	return SpiritRNG.GetImageId(spiritName) ~= ""
end

-- Loads a 3D pet model into a ViewportFrame.
-- Only called when a spirit has NO ImageId (none currently, but kept for safety).
function SpiritRNG.LoadPetIntoViewport(spiritName, viewport, camera)
	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("Model") then child:Destroy() end
	end
	local PetsFolder = game:GetService("Workspace"):FindFirstChild("Pets")
	if not PetsFolder then return false end
	local petModel = PetsFolder:FindFirstChild(spiritName)
	if not petModel then return false end
	local clone = petModel:Clone()
	clone.Parent = viewport
	local cf, size = clone:GetBoundingBox()
	local maxDim   = math.max(size.X, size.Y, size.Z)
	local fov      = camera.FieldOfView
	local distance = ((maxDim / 2) / math.tan(math.rad(fov / 2))) * 2.2
	local lookTarget = cf.Position + Vector3.new(0, size.Y * 0.1, 0)
	camera.CFrame      = CFrame.new(lookTarget + Vector3.new(0, size.Y * 0.1, distance), lookTarget)
	viewport.CurrentCamera = camera
	return clone
end

return SpiritRNG
