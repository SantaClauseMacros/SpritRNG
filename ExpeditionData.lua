-- ExpeditionData.lua
-- ModuleScript → ReplicatedStorage
-- All static data and formulas for the Expedition System.
-- No external dependencies (SpiritRNG passed as arg into ComputeTeamStats).

local ExpeditionData = {}

-- ════════════════════════════════════════════════════════════════════════════
-- BASE EXPEDITION STATS BY RARITY
-- DigSpeed:     dig time multiplier (higher = faster excavation)
-- Detection:    treasure zones revealed at expedition start
-- Luck:         reward rarity bias (0–1, additive)
-- MaxEndurance: pool of stamina (drains per dig; 0 = exhausted)
-- Recovery:     cooldown multiplier after expedition (lower = ready sooner)
-- TreasureSense:clue accuracy multiplier
-- ════════════════════════════════════════════════════════════════════════════

ExpeditionData.RarityStats = {
	Common    = { DigSpeed=1.0, Detection=1,  Luck=0.00, MaxEndurance=60,  Recovery=1.00, TreasureSense=1.0 },
	Uncommon  = { DigSpeed=1.2, Detection=2,  Luck=0.05, MaxEndurance=90,  Recovery=0.90, TreasureSense=1.1 },
	Rare      = { DigSpeed=1.5, Detection=3,  Luck=0.10, MaxEndurance=120, Recovery=0.80, TreasureSense=1.3 },
	Epic      = { DigSpeed=2.0, Detection=4,  Luck=0.18, MaxEndurance=180, Recovery=0.65, TreasureSense=1.6 },
	Legendary = { DigSpeed=2.8, Detection=5,  Luck=0.28, MaxEndurance=240, Recovery=0.50, TreasureSense=2.0 },
	Mythic    = { DigSpeed=4.0, Detection=7,  Luck=0.42, MaxEndurance=360, Recovery=0.35, TreasureSense=2.8 },
	Divine    = { DigSpeed=5.5, Detection=9,  Luck=0.60, MaxEndurance=480, Recovery=0.20, TreasureSense=3.8 },
	Celestial = { DigSpeed=8.0, Detection=12, Luck=0.85, MaxEndurance=720, Recovery=0.10, TreasureSense=5.5 },
}

-- ════════════════════════════════════════════════════════════════════════════
-- SPIRIT TRAITS  (45 unique traits)
-- Each spirit name gets 1 trait when first equipped for expedition.
-- Effect table keys:
--   dig_speed_mult, detection_add, luck_add, endurance_mult, recovery_mult,
--   endurance_drain_mult, clue_accuracy, coin_mult, scroll_mult,
--   artifact_mult, trap_reduce, trap_add, collapse_survive, jackpot_chance,
--   void_access, deep_reward_mult, deep_threshold, all_stats,
--   clue_boost (string = specific clue Id made 100% accurate)
-- ════════════════════════════════════════════════════════════════════════════

ExpeditionData.Traits = {
	-- ── Common positive ──────────────────────────────────────────────────────
	{ Id="Lucky",          DisplayName="Lucky",          Category="positive", Rarity="Common",
		Description="+15% expedition luck.",
		Effect={ luck_add=0.15 } },
	{ Id="Swift",          DisplayName="Swift",          Category="positive", Rarity="Common",
		Description="Digs 20% faster.",
		Effect={ dig_speed_mult=1.20 } },
	{ Id="Rugged",         DisplayName="Rugged",         Category="positive", Rarity="Common",
		Description="Endurance pool +40%.",
		Effect={ endurance_mult=1.40 } },
	{ Id="Prospector",     DisplayName="Prospector",     Category="positive", Rarity="Common",
		Description="Detects 1 extra treasure zone.",
		Effect={ detection_add=1 } },
	{ Id="Careful",        DisplayName="Careful",        Category="positive", Rarity="Common",
		Description="Trap chance -30%.",
		Effect={ trap_reduce=0.30 } },
	{ Id="CoinMagnet",     DisplayName="Coin Magnet",    Category="positive", Rarity="Common",
		Description="+20% expedition coin earnings.",
		Effect={ coin_mult=1.20 } },
	-- ── Uncommon positive ────────────────────────────────────────────────────
	{ Id="Excavator",      DisplayName="Excavator",      Category="positive", Rarity="Uncommon",
		Description="Digs 30% faster.",
		Effect={ dig_speed_mult=1.30 } },
	{ Id="MarathonRunner", DisplayName="Marathon Runner",Category="positive", Rarity="Uncommon",
		Description="Endurance drains 40% slower.",
		Effect={ endurance_drain_mult=0.60 } },
	{ Id="RuneReader",     DisplayName="Rune Reader",    Category="positive", Rarity="Uncommon",
		Description="Clue accuracy +40%.",
		Effect={ clue_accuracy=0.40 } },
	{ Id="TimeTouched",    DisplayName="Time Touched",   Category="positive", Rarity="Uncommon",
		Description="Recovery speed +30%.",
		Effect={ recovery_mult=0.70 } },
	{ Id="ScrollSeeker",   DisplayName="Scroll Seeker",  Category="positive", Rarity="Uncommon",
		Description="Spirit Scroll drop chance +25%.",
		Effect={ scroll_mult=1.25 } },
	{ Id="ArtifactSense",  DisplayName="Artifact Sense", Category="positive", Rarity="Uncommon",
		Description="Artifact find chance +30%.",
		Effect={ artifact_mult=1.30 } },
	{ Id="Speedy",         DisplayName="Speedy",         Category="positive", Rarity="Uncommon",
		Description="Dig speed +15%.",
		Effect={ dig_speed_mult=1.15 } },
	{ Id="Botanist",       DisplayName="Botanist",       Category="positive", Rarity="Uncommon",
		Description="Wildlife clues always accurate.",
		Effect={ clue_boost="WildlifeBehavior" } },
	{ Id="EchoSense",      DisplayName="Echo Sense",     Category="positive", Rarity="Uncommon",
		Description="Ground vibration clues always accurate.",
		Effect={ clue_boost="GroundVibrations" } },
	-- ── Rare positive ────────────────────────────────────────────────────────
	{ Id="Ancient",        DisplayName="Ancient",        Category="positive", Rarity="Rare",
		Description="Reveals 1 extra hidden treasure zone.",
		Effect={ detection_add=1 } },
	{ Id="DeepDelver",     DisplayName="Deep Delver",    Category="positive", Rarity="Rare",
		Description="Rewards at depth 3+ are worth 50% more.",
		Effect={ deep_reward_mult=1.50, deep_threshold=3 } },
	{ Id="TreasureHunter", DisplayName="Treasure Hunter",Category="positive", Rarity="Rare",
		Description="+10% luck.",
		Effect={ luck_add=0.10 } },
	{ Id="Pathfinder",     DisplayName="Pathfinder",     Category="positive", Rarity="Rare",
		Description="Hidden passage discovery +60%.",
		Effect={ passage_chance=0.60 } },
	{ Id="Historian",      DisplayName="Historian",      Category="positive", Rarity="Rare",
		Description="Ancient symbol clues always accurate.",
		Effect={ clue_boost="AncientSymbols" } },
	{ Id="Geologist",      DisplayName="Geologist",      Category="positive", Rarity="Rare",
		Description="Crystal growth clues always accurate.",
		Effect={ clue_boost="CrystalGrowth" } },
	{ Id="Resilient",      DisplayName="Resilient",      Category="positive", Rarity="Rare",
		Description="20% chance to survive a tunnel collapse.",
		Effect={ collapse_survive=0.20 } },
	{ Id="ThermalSense",   DisplayName="Thermal Sense",  Category="positive", Rarity="Rare",
		Description="Temperature clues always accurate.",
		Effect={ clue_boost="TemperatureChanges" } },
	-- ── Epic positive ────────────────────────────────────────────────────────
	{ Id="Brilliant",      DisplayName="Brilliant",      Category="positive", Rarity="Epic",
		Description="All clue accuracy +25%.",
		Effect={ clue_accuracy=0.25 } },
	{ Id="DeepSight",      DisplayName="Deep Sight",     Category="positive", Rarity="Epic",
		Description="Detection +50% at depth 2+.",
		Effect={ deep_detection_mult=1.50, deep_threshold=2 } },
	{ Id="RelicHunter",    DisplayName="Relic Hunter",   Category="positive", Rarity="Epic",
		Description="Rare discovery chance +20%.",
		Effect={ artifact_mult=1.20 } },
	{ Id="JackpotSpirit",  DisplayName="Jackpot Spirit", Category="positive", Rarity="Epic",
		Description="5% chance to find double treasure.",
		Effect={ jackpot_chance=0.05 } },
	{ Id="Tenacious",      DisplayName="Tenacious",      Category="positive", Rarity="Epic",
		Description="Can excavate 1 extra layer before exhaustion.",
		Effect={ endurance_mult=1.15 } },
	{ Id="Seasoned",       DisplayName="Seasoned",       Category="positive", Rarity="Epic",
		Description="+10% to all earnings and artifact chance.",
		Effect={ all_stats=0.10 } },
	{ Id="Astrologer",     DisplayName="Astrologer",     Category="positive", Rarity="Epic",
		Description="Celestial light clues always accurate.",
		Effect={ clue_boost="CelestialBeams" } },
	-- ── Legendary positive ───────────────────────────────────────────────────
	{ Id="VoidWalker",     DisplayName="Void Walker",    Category="positive", Rarity="Legendary",
		Description="Bonus rewards in Void Corruption zones.",
		Effect={ void_access=true, coin_mult=1.50 } },
	{ Id="VoidTouched",    DisplayName="Void-Touched",   Category="positive", Rarity="Legendary",
		Description="Detects hidden void treasures.",
		Effect={ void_detection=true, detection_add=1 } },
	{ Id="CelestialTouched",DisplayName="Celestial-Touched",Category="positive",Rarity="Legendary",
		Description="+25% luck at deep depths.",
		Effect={ luck_add=0.25 } },
	{ Id="Underseer",      DisplayName="Underseer",      Category="positive", Rarity="Legendary",
		Description="Immune to false positive clues.",
		Effect={ false_positive_immune=true } },
	{ Id="LuckyStrike",    DisplayName="Lucky Strike",   Category="positive", Rarity="Legendary",
		Description="3% chance to instantly finish a dig.",
		Effect={ instant_dig=0.03 } },
	-- ── Mythic positive ──────────────────────────────────────────────────────
	{ Id="Corrupted",      DisplayName="Corrupted",      Category="positive", Rarity="Mythic",
		Description="Void treasures worth 50% more.",
		Effect={ coin_mult=1.50 } },
	{ Id="Crystallized",   DisplayName="Crystallized",   Category="positive", Rarity="Mythic",
		Description="Crystal site finds worth 40% more.",
		Effect={ coin_mult=1.40 } },
	{ Id="Infernal",       DisplayName="Infernal",       Category="positive", Rarity="Mythic",
		Description="+30% rewards at the Void Crater.",
		Effect={ coin_mult=1.30 } },
	{ Id="Frostborn",      DisplayName="Frostborn",      Category="positive", Rarity="Mythic",
		Description="+30% rewards at Frozen Wastes.",
		Effect={ coin_mult=1.30 } },
	-- ── Divine positive ──────────────────────────────────────────────────────
	{ Id="Mystic",         DisplayName="Mystic",         Category="positive", Rarity="Divine",
		Description="Spirit Fossils appear twice as often.",
		Effect={ scroll_mult=2.00 } },
	{ Id="CelestialBond",  DisplayName="Celestial Bond", Category="positive", Rarity="Divine",
		Description="+30% rewards at Celestial Temple.",
		Effect={ coin_mult=1.30 } },
	{ Id="Underminer",     DisplayName="Underminer",     Category="positive", Rarity="Divine",
		Description="Dig speed +20% per depth level descended.",
		Effect={ dig_speed_mult=1.20 } },
	-- ── Negative traits ──────────────────────────────────────────────────────
	{ Id="Clumsy",         DisplayName="Clumsy",         Category="negative", Rarity="Common",
		Description="Dig speed -10%.",
		Effect={ dig_speed_mult=0.90 } },
	{ Id="Fragile",        DisplayName="Fragile",        Category="negative", Rarity="Common",
		Description="Endurance -20%.",
		Effect={ endurance_mult=0.80 } },
	{ Id="Distracted",     DisplayName="Distracted",     Category="negative", Rarity="Common",
		Description="Clue accuracy -20%.",
		Effect={ clue_accuracy=-0.20 } },
	{ Id="Impatient",      DisplayName="Impatient",      Category="negative", Rarity="Common",
		Description="Endurance drains 15% faster.",
		Effect={ endurance_drain_mult=1.15 } },
	{ Id="Careless",       DisplayName="Careless",       Category="negative", Rarity="Common",
		Description="Trap chance +10%.",
		Effect={ trap_add=0.10 } },
	-- ── Neutral trait ────────────────────────────────────────────────────────
	{ Id="Bold",           DisplayName="Bold",           Category="neutral",  Rarity="Common",
		Description="+10% coins but +10% trap chance.",
		Effect={ coin_mult=1.10, trap_add=0.10 } },
}

-- Build fast lookups at require time
local TraitLookup = {}
for _, t in ipairs(ExpeditionData.Traits) do TraitLookup[t.Id] = t end
ExpeditionData.TraitLookup = TraitLookup

ExpeditionData.TraitRarityWeights = {
	Common=500, Uncommon=200, Rare=80, Epic=25, Legendary=8, Mythic=2, Divine=0.5,
}
ExpeditionData.NegativeTraitChance = 0.15

-- ════════════════════════════════════════════════════════════════════════════
-- DIG SITES  (6 sites, unlocked progressively)
-- Sites are free walk-in zones (like PS99 worlds — no entry prompt needed).
-- In Roblox Studio, create:
--   Workspace > DigSites > [SiteId] > Boundary (large invisible Part — the walk-in area)
--      • Anchored = true, CanCollide = false, Transparency = 1
--      • Size = e.g. 300 x 100 x 300 (covers the full site area)
--   Workspace > DigSites > [SiteId] > TreasureSpawns > SP1, SP2… (optional spawn Parts)
-- Walk into the Boundary → expedition auto-starts. Walk out → auto-extracts.
-- ════════════════════════════════════════════════════════════════════════════

ExpeditionData.DigSites = {
	{
		Id                = "Desert",
		DisplayName       = "Desert",
		Description       = "Hot sandy ground. A good place to start digging.",
		UnlockCost        = 0,
		RecommendedRarity = "Common",
		BaseCoins         = 500,
		Color             = Color3.fromRGB(240, 200, 100),
		Emoji             = "🏜️",
	},
	{
		Id                = "Cave",
		DisplayName       = "Cave",
		Description       = "Dark underground caves full of shiny crystals.",
		UnlockCost        = 5000,
		RecommendedRarity = "Uncommon",
		BaseCoins         = 1400,
		Color             = Color3.fromRGB(100, 200, 255),
		Emoji             = "💎",
	},
	{
		Id                = "Snow",
		DisplayName       = "Snow",
		Description       = "Frozen ground with fossils buried in the ice.",
		UnlockCost        = 15000,
		RecommendedRarity = "Rare",
		BaseCoins         = 3200,
		Color             = Color3.fromRGB(180, 240, 255),
		Emoji             = "❄️",
	},
	{
		Id                = "Void",
		DisplayName       = "Void",
		Description       = "A dark crater full of strange void energy. Pays well.",
		UnlockCost        = 45000,
		RecommendedRarity = "Epic",
		BaseCoins         = 8000,
		Color             = Color3.fromRGB(80, 40, 140),
		Emoji             = "🌑",
	},
	{
		Id                = "Jungle",
		DisplayName       = "Jungle",
		Description       = "Old temple ruins covered in glowing plants.",
		UnlockCost        = 110000,
		RecommendedRarity = "Legendary",
		BaseCoins         = 22000,
		Color             = Color3.fromRGB(180, 255, 140),
		Emoji             = "🌿",
	},
	{
		Id                = "Mines",
		DisplayName       = "Mines",
		Description       = "Deep dark mines. The best loot in the game.",
		UnlockCost        = 500000,
		RecommendedRarity = "Mythic",
		BaseCoins         = 80000,
		Color             = Color3.fromRGB(20, 20, 40),
		Emoji             = "🕳️",
	},
}

local SiteLookup = {}
for _, s in ipairs(ExpeditionData.DigSites) do SiteLookup[s.Id] = s end
ExpeditionData.SiteLookup = SiteLookup

-- ════════════════════════════════════════════════════════════════════════════
-- CLUES  (16 types)
-- AccuracyBase: baseline probability the clue marks a real treasure
-- ════════════════════════════════════════════════════════════════════════════

ExpeditionData.Clues = {
	{ Id="AncientSymbols",     DisplayName="Ancient Symbols",      Emoji="🔣", AccuracyBase=0.75,
		Description="Carved runes pulse with faint energy." },
	{ Id="SpiritEnergyTrails", DisplayName="Spirit Energy Trail",  Emoji="✨", AccuracyBase=0.80,
		Description="A shimmering trail seeps from the earth." },
	{ Id="CrystalGrowth",      DisplayName="Crystal Cluster",      Emoji="💠", AccuracyBase=0.70,
		Description="Crystals grow unnaturally dense here." },
	{ Id="GlowingParticles",   DisplayName="Glowing Particles",    Emoji="🌟", AccuracyBase=0.65,
		Description="Strange light seeps from the ground." },
	{ Id="Footprints",         DisplayName="Ancient Footprints",   Emoji="👣", AccuracyBase=0.60,
		Description="Fossilized tracks circle this area." },
	{ Id="GroundVibrations",   DisplayName="Ground Vibrations",    Emoji="〰️", AccuracyBase=0.70,
		Description="The earth trembles faintly beneath you." },
	{ Id="VoidCorruption",     DisplayName="Void Corruption",      Emoji="🌑", AccuracyBase=0.72,
		Description="The ground is tainted with dark energy." },
	{ Id="FossilMarkings",     DisplayName="Fossil Markings",      Emoji="🦕", AccuracyBase=0.68,
		Description="Ancient bones protrude from the earth." },
	{ Id="EchoSounds",         DisplayName="Strange Echoes",       Emoji="🔊", AccuracyBase=0.65,
		Description="Hollow sounds suggest a chamber below." },
	{ Id="TemperatureChanges", DisplayName="Temperature Shift",    Emoji="🌡️", AccuracyBase=0.72,
		Description="The air grows unnaturally warm or cold." },
	{ Id="RuneActivity",       DisplayName="Active Runes",         Emoji="🔆", AccuracyBase=0.80,
		Description="Glowing runes form a pattern on the ground." },
	{ Id="CelestialBeams",     DisplayName="Celestial Light Beam", Emoji="☀️", AccuracyBase=0.85,
		Description="A beam of light illuminates a patch of earth." },
	{ Id="FloatingDebris",     DisplayName="Floating Debris",      Emoji="🌀", AccuracyBase=0.78,
		Description="Dirt and stones float weightlessly here." },
	{ Id="WildlifeBehavior",   DisplayName="Wildlife Behavior",    Emoji="🦊", AccuracyBase=0.62,
		Description="Animals gather or flee from this spot." },
	{ Id="FrozenFootprints",   DisplayName="Frozen Footprints",    Emoji="🧊", AccuracyBase=0.65,
		Description="Perfectly preserved tracks in the ice." },
	{ Id="EnergyTrails",       DisplayName="Energy Trails",        Emoji="⚡", AccuracyBase=0.73,
		Description="Sparks of energy arc across the ground." },
}

local ClueLookup = {}
for _, c in ipairs(ExpeditionData.Clues) do ClueLookup[c.Id] = c end
ExpeditionData.ClueLookup = ClueLookup

-- ════════════════════════════════════════════════════════════════════════════
-- SPIRIT SCROLLS  (dropped during expeditions, improve future rolls)
-- ════════════════════════════════════════════════════════════════════════════

ExpeditionData.Scrolls = {
	{ Id="RareScroll",      DisplayName="Rare Scroll",      Rarity="Rare",
		LuckBonus=0.002,  DropWeight=100, Emoji="📜" },
	{ Id="EpicScroll",      DisplayName="Epic Scroll",      Rarity="Epic",
		LuckBonus=0.005,  DropWeight=40,  Emoji="📜" },
	{ Id="LegendaryScroll", DisplayName="Legendary Scroll", Rarity="Legendary",
		LuckBonus=0.012,  DropWeight=12,  Emoji="📜" },
	{ Id="MythicScroll",    DisplayName="Mythic Scroll",    Rarity="Mythic",
		LuckBonus=0.028,  DropWeight=3,   Emoji="📜" },
	{ Id="DivineScroll",    DisplayName="Divine Scroll",    Rarity="Divine",
		LuckBonus=0.060,  DropWeight=0.8, Emoji="📜" },
	{ Id="CelestialScroll", DisplayName="Celestial Scroll", Rarity="Celestial",
		LuckBonus=0.150,  DropWeight=0.1, Emoji="📜" },
}

-- ════════════════════════════════════════════════════════════════════════════
-- RARE DISCOVERIES  (ultra-rare items found at higher depths)
-- ════════════════════════════════════════════════════════════════════════════

ExpeditionData.RareDiscoveries = {
	{ Id="AncientRelic",      DisplayName="Ancient Relic",       Emoji="🏺",
		BaseChance=0.0050, CoinValue=50000,   MinDepth=1,
		Description="A relic from a forgotten civilization." },
	{ Id="SpiritFossil",      DisplayName="Spirit Fossil",        Emoji="🦴",
		BaseChance=0.0030, CoinValue=80000,   MinDepth=2,
		Description="A fossilized spirit, perfectly preserved." },
	{ Id="CelestialFragment", DisplayName="Celestial Fragment",   Emoji="⭐",
		BaseChance=0.0020, CoinValue=120000,  MinDepth=3,
		Description="A fragment of pure celestial energy." },
	{ Id="VoidCrystal",       DisplayName="Void Crystal",         Emoji="🔮",
		BaseChance=0.0015, CoinValue=150000,  MinDepth=3,
		Description="A crystal infused with void energy." },
	{ Id="ForgottenCrown",    DisplayName="Forgotten Crown",      Emoji="👑",
		BaseChance=0.0010, CoinValue=200000,  MinDepth=4,
		Description="A crown worn by ancient royalty." },
	{ Id="DimensionalKey",    DisplayName="Dimensional Key",      Emoji="🗝️",
		BaseChance=0.0008, CoinValue=300000,  MinDepth=5,
		Description="Opens pathways between dimensions." },
	{ Id="LostSpiritEgg",     DisplayName="Lost Spirit Egg",      Emoji="🥚",
		BaseChance=0.0005, CoinValue=500000,  MinDepth=5,
		Description="A dormant spirit waiting to hatch." },
	{ Id="AbyssalRelic",      DisplayName="Abyssal Relic",        Emoji="🌑",
		BaseChance=0.0002, CoinValue=1000000, MinDepth=6,
		Description="From the deepest abyss. Impossibly rare." },
}

-- ════════════════════════════════════════════════════════════════════════════
-- DEEP DIG SCALING FORMULAS
-- ════════════════════════════════════════════════════════════════════════════

function ExpeditionData.GetDepthCoinMult(depth)
	return 1.5 ^ (depth - 1)
end

function ExpeditionData.GetDepthScrollChanceMult(depth)
	return 1.3 ^ (depth - 1)
end

function ExpeditionData.GetDepthArtifactMult(depth)
	return 1 + 0.4 * (depth - 1)
end

function ExpeditionData.GetDepthRareDiscoveryMult(depth)
	return 1 + 0.8 * (depth - 1)
end

-- Returns the endurance cost multiplier per dig at a given depth
function ExpeditionData.GetDepthEnduranceDrainMult(depth)
	return 1 + 0.30 * (depth - 1)
end

-- Returns the trap chance for a site at a given depth
function ExpeditionData.GetDepthTrapChance(depth, baseTrapChance)
	return math.min(0.85, baseTrapChance * (1 + 0.35 * (depth - 1)))
end

-- Returns collapse chance (only starts at depth 3)
function ExpeditionData.GetDepthCollapseChance(depth)
	if depth < 3 then return 0 end
	return math.min(0.50, 0.05 * (depth - 2))
end

-- ════════════════════════════════════════════════════════════════════════════
-- TEAM STAT COMPUTATION
-- spiritList = { { name=string, rarity=string, traitId=string }, … }
-- SpiritRNG module passed as second arg to avoid circular require
-- ════════════════════════════════════════════════════════════════════════════

function ExpeditionData.ComputeTeamStats(spiritList, SpiritRNG)
	local count = #spiritList
	if count == 0 then
		return {
			DigSpeed=0, Detection=0, Luck=0, MaxEndurance=0,
			TreasureSense=1, Recovery=1, Traits={},
			CoinMult=1, ScrollMult=1, ArtifactMult=1,
			TrapReduce=0, ClueAccuracy=0, CollapseResist=0,
		}
	end

	local totDigSpeed = 0; local totDetection = 0; local totLuck = 0
	local totEndurance = 0; local totSense = 0;   local totRecovery = 0
	local allTraits = {}

	for _, spirit in ipairs(spiritList) do
		local rarity = SpiritRNG.GetRarityName(spirit.name)
		local base   = ExpeditionData.RarityStats[rarity] or ExpeditionData.RarityStats.Common
		local trait  = TraitLookup[spirit.traitId]
		local eff    = trait and trait.Effect or {}

		totDigSpeed   = totDigSpeed   + base.DigSpeed    * (eff.dig_speed_mult or 1)
		totDetection  = totDetection  + base.Detection   + (eff.detection_add or 0)
		totLuck       = totLuck       + base.Luck        + (eff.luck_add or 0)
		totEndurance  = totEndurance  + base.MaxEndurance * (eff.endurance_mult or 1)
		totSense      = totSense      + base.TreasureSense
		totRecovery   = totRecovery   + base.Recovery    * (eff.recovery_mult or 1)

		if trait then table.insert(allTraits, trait) end
	end

	-- Aggregate trait modifiers
	local coinMult = 1; local scrollMult = 1; local artifactMult = 1
	local trapReduce = 0; local clueAccuracy = 0; local collapseResist = 0
	local clueBoosts = {}

	for _, trait in ipairs(allTraits) do
		local eff = trait.Effect
		if eff.coin_mult        then coinMult       = coinMult * eff.coin_mult end
		if eff.scroll_mult      then scrollMult     = scrollMult * eff.scroll_mult end
		if eff.artifact_mult    then artifactMult   = artifactMult * eff.artifact_mult end
		if eff.trap_reduce      then trapReduce     = trapReduce + eff.trap_reduce end
		if eff.trap_add         then trapReduce     = trapReduce - eff.trap_add end
		if eff.clue_accuracy    then clueAccuracy   = clueAccuracy + eff.clue_accuracy end
		if eff.collapse_survive then collapseResist = math.max(collapseResist, eff.collapse_survive) end
		if eff.clue_boost       then clueBoosts[eff.clue_boost] = true end
		if eff.all_stats        then
			coinMult     = coinMult * (1 + eff.all_stats)
			artifactMult = artifactMult * (1 + eff.all_stats)
			scrollMult   = scrollMult * (1 + eff.all_stats)
		end
	end

	return {
		DigSpeed      = totDigSpeed,
		Detection     = math.min(15, math.floor(totDetection)),
		Luck          = math.min(1.0, totLuck),
		MaxEndurance  = totEndurance,
		TreasureSense = totSense / count,
		Recovery      = totRecovery / count,
		Traits        = allTraits,
		ClueBoosts    = clueBoosts,
		CoinMult      = coinMult,
		ScrollMult    = scrollMult,
		ArtifactMult  = artifactMult,
		TrapReduce    = math.clamp(trapReduce, -0.5, 0.80),
		ClueAccuracy  = clueAccuracy,
		CollapseResist= collapseResist,
	}
end

-- Base dig duration in seconds (divided by DigSpeed, clamped 2–15 s)
ExpeditionData.BaseDuration     = 30
-- Endurance cost per dig at depth 1 (multiplied by depth drain multiplier)
ExpeditionData.BaseEnduranceCost = 10
-- Max spirit slots (base + upgrades elsewhere)
ExpeditionData.BaseSlots = 3
ExpeditionData.MaxSlots  = 6

return ExpeditionData
