-- request: 14. Сделай кликер: каждый клик по кнопке даёт монету, есть улучшение «+1 за клик» за 50 монет.
-- placement: LocalScript внутри ScreenGui в StarterGui; создайте TextButton ClickButton, TextButton UpgradeButton и TextLabel InfoLabel
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local clickerEvent = ReplicatedStorage:WaitForChild("ClickerEvent")

local gui = script.Parent
local clickButton = gui:WaitForChild("ClickButton")
local upgradeButton = gui:WaitForChild("UpgradeButton")
local infoLabel = gui:WaitForChild("InfoLabel")

clickButton.Text = "Клик!"
upgradeButton.Text = "Улучшить за 50 монет"

local function updateInfo()
	local clickPower = player:GetAttribute("ClickPower") or 1
	infoLabel.Text = "+" .. clickPower .. " монет за клик"
end

clickButton.MouseButton1Click:Connect(function()
	clickerEvent:FireServer("Click")
end)

upgradeButton.MouseButton1Click:Connect(function()
	clickerEvent:FireServer("Upgrade")
end)

player:GetAttributeChangedSignal("ClickPower"):Connect(updateInfo)
updateInfo()
