-- request: Сделай таймер на экране, который показывает время до конца раунда всем игрокам.
-- placement: LocalScript внутри TextLabel (ScreenGui > TextLabel) в StarterGui
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local label = script.Parent
local timeLeft = ReplicatedStorage:WaitForChild("RoundTimeLeft")
local state = ReplicatedStorage:WaitForChild("RoundState")

local function update()
	local seconds = timeLeft.Value
	local text = string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
	if state.Value == "Round" then
		label.Text = "До конца раунда: " .. text
	else
		label.Text = "Следующий раунд через: " .. text
	end
end

timeLeft.Changed:Connect(update)
state.Changed:Connect(update)
update()
