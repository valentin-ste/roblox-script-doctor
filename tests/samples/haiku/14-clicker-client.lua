-- request: Сделай кликер: каждый клик по кнопке даёт монету, есть улучшение «+1 за клик» за 50 монет.
-- placement: LocalScript внутрь TextButton "ClickButton" в ScreenGui (StarterGui). Там же должна быть TextButton "UpgradeButton"
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local clickEvent = ReplicatedStorage:WaitForChild("ClickCoin")
local upgradeEvent = ReplicatedStorage:WaitForChild("BuyClickUpgrade")

local clickButton = script.Parent
local upgradeButton = clickButton.Parent:WaitForChild("UpgradeButton")

clickButton.Activated:Connect(function()
	clickEvent:FireServer()
end)

upgradeButton.Activated:Connect(function()
	upgradeEvent:FireServer()
end)
