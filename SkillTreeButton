-- SkillTreeButton.client.lua  (LocalScript inside the skill tree button)
-- Fires ToggleSkillTree when clicked. No changes needed from your original.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local button = script.Parent

local ToggleSkillTree = ReplicatedStorage:FindFirstChild("ToggleSkillTree")
if not ToggleSkillTree then
	ToggleSkillTree = Instance.new("BindableEvent")
	ToggleSkillTree.Name   = "ToggleSkillTree"
	ToggleSkillTree.Parent = ReplicatedStorage
end

button.MouseButton1Click:Connect(function()
	ToggleSkillTree:Fire()
end)
