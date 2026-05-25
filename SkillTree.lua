-- SkillTree.lua  (ModuleScript in ReplicatedStorage)
-- Auto Roll sits at the centre (Col=0, Row=0).
-- Six branches radiate outward:
--   UP    → Roll Luck path (prerequisites that unlock Auto Roll)
--   DOWN  → Speed upgrades (Faster/Turbo/Daily)
--   LEFT  → Coin upgrades
--   FAR-LEFT sub-branch → Farming/Random bonus
--   RIGHT → Settings/Items upgrades

local SkillTree = {}

SkillTree.Skills = {

	-- ── CENTER HUB ───────────────────────────────────────────────────────────
	-- Every branch physically touches this hex on the grid.
	{
		Id          = "AutoRoll",
		DisplayName = "Auto Roll",
		Description = "Unlocks the auto-roll feature. The hub all other upgrades branch from.",
		Icon        = "🔄",
		NodeColor   = Color3.fromRGB(100, 200, 255),
		Col = 0, Row = 0,
		Requires    = { "RollLuck2" },
		Cost        = 5000,
		Effect      = "none",
		Value       = 0,
	},

	-- ── UP branch — Roll Luck path (prerequisites that lead INTO Auto Roll) ────
	-- (0,-1) is the direct upper neighbour of (0,0)
	{
		Id          = "RollLuck2",
		DisplayName = "Luckier",
		Description = "Your luck improves even further.",
		Icon        = "✨",
		NodeColor   = Color3.fromRGB(100, 180, 255),
		Col = 0, Row = -1,
		Requires    = { "RollLuck1" },
		Cost        = 2000,
		Effect      = "luck_add",
		Value       = 0.0005,
	},
	-- (0,-2) is directly above (0,-1)
	{
		Id          = "RollLuck1",
		DisplayName = "Roll Luck",
		Description = "Your first step. Slightly improves your odds on every roll.",
		Icon        = "🍀",
		NodeColor   = Color3.fromRGB(255, 255, 255),
		Col = 0, Row = -2,
		Requires    = {},
		Cost        = 0,
		Effect      = "luck_add",
		Value       = 0.0002,
	},
	-- (0,-3) directly above RollLuck1
	{
		Id          = "Fortune",
		DisplayName = "Fortune",
		Description = "Your luck grows considerably stronger.",
		Icon        = "☘️",
		NodeColor   = Color3.fromRGB(100, 220, 100),
		Col = 0, Row = -3,
		Requires    = { "RollLuck1" },
		Cost        = 15000,
		Effect      = "luck_add",
		Value       = 0.002,
	},
	-- (0,-4) directly above Fortune
	{
		Id          = "Destiny",
		DisplayName = "Destiny",
		Description = "The pinnacle of luck — the rarest spirits become reachable.",
		Icon        = "⭐",
		NodeColor   = Color3.fromRGB(255, 240, 80),
		Col = 0, Row = -4,
		Requires    = { "Fortune" },
		Cost        = 60000,
		Effect      = "luck_add",
		Value       = 0.005,
	},


	-- ── DOWN branch — speed upgrades ──────────────────────────────────────────
	-- (0,1) touches (0,0) below; each step goes one hex further down
	{
		Id          = "FasterAuto",
		DisplayName = "Faster Auto",
		Description = "Auto-roll fires 30% faster.",
		Icon        = "⚡",
		NodeColor   = Color3.fromRGB(100, 180, 255),
		Col = 0, Row = 1,
		Requires    = { "AutoRoll" },
		Cost        = 12000,
		Effect      = "auto_delay",
		Value       = 0.7,
	},
	{
		Id          = "TurboAuto",
		DisplayName = "Turbo Auto",
		Description = "Auto-roll fires 50% faster (stacks with Faster Auto).",
		Icon        = "🚀",
		NodeColor   = Color3.fromRGB(100, 180, 255),
		Col = 0, Row = 2,
		Requires    = { "FasterAuto" },
		Cost        = 30000,
		Effect      = "auto_delay",
		Value       = 0.5,
	},
	{
		Id          = "UltraAuto",
		DisplayName = "Ultra Auto",
		Description = "Auto-roll reaches peak speed — as fast as it gets.",
		Icon        = "⚡",
		NodeColor   = Color3.fromRGB(60, 140, 255),
		Col = 0, Row = 3,
		Requires    = { "TurboAuto" },
		Cost        = 80000,
		Effect      = "auto_delay",
		Value       = 0.4,
	},

	-- ── UPPER-LEFT branch — coin upgrades ────────────────────────────────────
	-- (-1,-1) is the upper-left neighbour of (0,0)
	-- Each step continues the adjacent chain going left then down
	{
		Id          = "CoinBoost1",
		DisplayName = "Coin Boost",
		Description = "Earn 20% more coins on every roll.",
		Icon        = "🪙",
		NodeColor   = Color3.fromRGB(255, 200, 50),
		Col = -1, Row = -1,
		Requires    = { "AutoRoll" },
		Cost        = 0,
		Effect      = "coins_mult",
		Value       = 1.2,
	},
	-- (-2,-1) is the upper-left neighbour of (-1,-1)
	{
		Id          = "CoinBoost2",
		DisplayName = "Bigger Coins",
		Description = "Earn 50% more coins on every roll.",
		Icon        = "💰",
		NodeColor   = Color3.fromRGB(255, 200, 50),
		Col = -2, Row = -1,
		Requires    = { "CoinBoost1" },
		Cost        = 3000,
		Effect      = "coins_mult",
		Value       = 1.5,
	},
	-- (-2,0) is directly below (-2,-1)
	{
		Id          = "RareBonus",
		DisplayName = "Rare Bonus",
		Description = "Rare and above spirits give 1.5x coins.",
		Icon        = "💎",
		NodeColor   = Color3.fromRGB(255, 200, 50),
		Col = -2, Row = 0,
		Requires    = { "CoinBoost2" },
		Cost        = 8000,
		Effect      = "rare_mult",
		Value       = 1.5,
	},
	-- (-2,1) is directly below (-2,0)
	{
		Id          = "EpicBonus",
		DisplayName = "Epic Bonus",
		Description = "Epic and above spirits give 2x coins.",
		Icon        = "👑",
		NodeColor   = Color3.fromRGB(255, 180, 30),
		Col = -2, Row = 1,
		Requires    = { "RareBonus" },
		Cost        = 20000,
		Effect      = "epic_mult",
		Value       = 2.0,
	},
	-- (-2,2) is directly below (-2,1)
	{
		Id          = "MythicBonus",
		DisplayName = "Mythic Bonus",
		Description = "Mythic spirits give 5x coins.",
		Icon        = "🌟",
		NodeColor   = Color3.fromRGB(255, 140, 20),
		Col = -2, Row = 2,
		Requires    = { "EpicBonus" },
		Cost        = 80000,
		Effect      = "mythic_mult",
		Value       = 5.0,
	},
	-- (-2,3) directly below MythicBonus — continues the rare-tier chain
	{
		Id          = "DivineMult",
		DisplayName = "Divine Bonus",
		Description = "Divine spirits give 10x coins.",
		Icon        = "😇",
		NodeColor   = Color3.fromRGB(200, 160, 255),
		Col = -2, Row = 3,
		Requires    = { "MythicBonus" },
		Cost        = 200000,
		Effect      = "divine_mult",
		Value       = 10.0,
	},
	-- (-2,4) directly below DivineMult
	{
		Id          = "CelestialMult",
		DisplayName = "Celestial Bonus",
		Description = "Celestial spirits give 25x coins.",
		Icon        = "🌠",
		NodeColor   = Color3.fromRGB(160, 120, 255),
		Col = -2, Row = 4,
		Requires    = { "DivineMult" },
		Cost        = 500000,
		Effect      = "celestial_mult",
		Value       = 25.0,
	},
	-- sub-branch: (-3,1) is the lower-left neighbour of (-2,1) EpicBonus
	{
		Id          = "FarmingGold",
		DisplayName = "Gold Fever",
		Description = "All coin earnings from every roll are doubled.",
		Icon        = "🌾",
		NodeColor   = Color3.fromRGB(255, 200, 50),
		Col = -3, Row = 1,
		Requires    = { "EpicBonus" },
		Cost        = 40000,
		Effect      = "coins_mult",
		Value       = 2.0,
	},
	-- (-3,2) is directly below (-3,1)
	{
		Id          = "RandomBonus",
		DisplayName = "Random Bonus",
		Description = "Random 2x-5x coin multiplier on any roll.",
		Icon        = "🎲",
		NodeColor   = Color3.fromRGB(255, 200, 50),
		Col = -3, Row = 2,
		Requires    = { "FarmingGold" },
		Cost        = 90000,
		Effect      = "coins_mult",
		Value       = 3.0,
	},
	-- (-4,2) is the upper-left neighbour of RandomBonus (-3,2) — extends far-left
	{
		Id          = "CoinRain",
		DisplayName = "Coin Rain",
		Description = "10% chance to earn double coins on any roll.",
		Icon        = "💸",
		NodeColor   = Color3.fromRGB(255, 220, 60),
		Col = -4, Row = 2,
		Requires    = { "RandomBonus" },
		Cost        = 120000,
		Effect      = "coin_rain",
		Value       = 0.1,
	},

	-- ── RIGHT branch — bonus rolls & luck ────────────────────────────────────
	-- (1,0) is the right neighbour of AutoRoll (0,0)
	{
		Id          = "BonusRoll",
		DisplayName = "Bonus Roll",
		Description = "5% chance to automatically fire a second roll for free.",
		Icon        = "🎰",
		NodeColor   = Color3.fromRGB(220, 120, 50),
		Col = 1, Row = 0,
		Requires    = { "AutoRoll" },
		Cost        = 12000,
		Effect      = "double_roll",
		Value       = 0.05,
	},
	-- (2,0) adjacent to BonusRoll (1,0)
	{
		Id          = "HotStreak",
		DisplayName = "Hot Streak",
		Description = "+8% more double-roll chance. Lucky runs get luckier.",
		Icon        = "🔥",
		NodeColor   = Color3.fromRGB(210, 90, 30),
		Col = 2, Row = 0,
		Requires    = { "BonusRoll" },
		Cost        = 45000,
		Effect      = "double_roll",
		Value       = 0.08,
	},
	-- (3,0) adjacent to HotStreak (2,0)
	{
		Id          = "Jackpot",
		DisplayName = "Jackpot",
		Description = "+12% double-roll — nearly 1 in 4 rolls pays out twice.",
		Icon        = "🃏",
		NodeColor   = Color3.fromRGB(200, 70, 15),
		Col = 3, Row = 0,
		Requires    = { "HotStreak" },
		Cost        = 130000,
		Effect      = "double_roll",
		Value       = 0.12,
	},
	-- (2,1) adjacent to BonusRoll (1,0) — luck sub-branch
	{
		Id          = "LuckySpin",
		DisplayName = "Lucky Spin",
		Description = "Fortune favours the bold. Improves all roll odds.",
		Icon        = "🌀",
		NodeColor   = Color3.fromRGB(100, 160, 255),
		Col = 2, Row = 1,
		Requires    = { "BonusRoll" },
		Cost        = 20000,
		Effect      = "luck_add",
		Value       = 0.002,
	},
	-- (3,1) adjacent to LuckySpin (2,1)
	{
		Id          = "EpicLuck",
		DisplayName = "Epic Luck",
		Description = "Rarer spirits become noticeably more common.",
		Icon        = "💫",
		NodeColor   = Color3.fromRGB(80, 130, 255),
		Col = 3, Row = 1,
		Requires    = { "LuckySpin" },
		Cost        = 65000,
		Effect      = "luck_add",
		Value       = 0.004,
	},
}

-- ─────────────────────────────────────────────
-- Lookup (built once at require-time)
-- ─────────────────────────────────────────────

local lookup = {}
for _, skill in ipairs(SkillTree.Skills) do
	lookup[skill.Id] = skill
end

function SkillTree.GetSkill(id)
	return lookup[id]
end

function SkillTree.CanUnlock(skillId, unlockedSet)
	local skill = lookup[skillId]
	if not skill then return false end
	for _, req in ipairs(skill.Requires) do
		if not unlockedSet[req] then return false end
	end
	return true
end

local MULTIPLICATIVE = {
	coins_mult     = true, auto_delay     = true,
	rare_mult      = true, epic_mult      = true, mythic_mult    = true,
	divine_mult    = true, celestial_mult = true,
}

function SkillTree.GetEffectValue(effectKey, unlockedSet)
	local result = MULTIPLICATIVE[effectKey] and 1 or 0
	for id in pairs(unlockedSet) do
		local skill = lookup[id]
		if skill and skill.Effect == effectKey then
			if MULTIPLICATIVE[effectKey] then
				result *= skill.Value
			else
				result += skill.Value
			end
		end
	end
	return result
end

return SkillTree
