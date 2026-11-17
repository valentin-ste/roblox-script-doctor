-- request: 3. Сделай магазин: кнопка в интерфейсе покупает меч за 100 монет.
-- placement: LocalScript внутри TextButton в StarterGui
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local buySwordEvent = ReplicatedStorage:WaitForChild("BuySword")
local button = script.Parent

button.Text = "Купить меч за 100 монет"

button.MouseButton1Click:Connect(function()
	buySwordEvent:FireServer()
end)
