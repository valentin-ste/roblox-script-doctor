-- request: 12. Сделай таймер на экране, который показывает время до конца раунда всем игрокам.
-- placement: LocalScript внутри TextLabel в ScreenGui в StarterGui
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local roundTime = ReplicatedStorage:WaitForChild("RoundTime")
local label = script.Parent

local function updateTimer()
	local minutes = math.floor(roundTime.Value / 60)
	local seconds = roundTime.Value % 60

	label.Text = string.format("До конца раунда: %02d:%02d", minutes, seconds)
end

roundTime:GetPropertyChangedSignal("Value"):Connect(updateTimer)
updateTimer()
