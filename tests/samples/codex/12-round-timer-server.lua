-- request: 12. Сделай таймер на экране, который показывает время до конца раунда всем игрокам.
-- placement: Script в ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local roundTime = ReplicatedStorage:FindFirstChild("RoundTime")
if not roundTime then
	roundTime = Instance.new("IntValue")
	roundTime.Name = "RoundTime"
	roundTime.Parent = ReplicatedStorage
end

while true do
	for secondsLeft = 120, 0, -1 do
		roundTime.Value = secondsLeft
		task.wait(1)
	end
end
