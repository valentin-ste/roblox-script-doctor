-- request: Сделай кликер: каждый клик по кнопке даёт монету, есть улучшение «+1 за клик» за 50 монет.
-- placement: LocalScript в StarterGui > ScreenGui. В ScreenGui нужны две кнопки: ClickButton и UpgradeButton.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent
local clickButton = gui:WaitForChild("ClickButton")
local upgradeButton = gui:WaitForChild("UpgradeButton")

local clickEvent = ReplicatedStorage:WaitForChild("ClickEvent")
local upgradeEvent = ReplicatedStorage:WaitForChild("UpgradeEvent")

local function updateText()
	local power = player:GetAttribute("ClickPower") or 1
	clickButton.Text = "Клик! (+" .. power .. ")"
	upgradeButton.Text = "+1 за клик (50 монет)"
end

player:GetAttributeChangedSignal("ClickPower"):Connect(updateText)
updateText()

clickButton.MouseButton1Click:Connect(function()
	clickEvent:FireServer()
end)

upgradeButton.MouseButton1Click:Connect(function()
	upgradeEvent:FireServer()
end)
