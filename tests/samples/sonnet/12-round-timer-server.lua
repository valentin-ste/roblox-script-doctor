-- request: Сделай таймер на экране, который показывает время до конца раунда всем игрокам.
-- placement: Script в ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ROUND_TIME = 120
local INTERMISSION = 15

local timeLeft = Instance.new("IntValue")
timeLeft.Name = "RoundTimeLeft"
timeLeft.Parent = ReplicatedStorage

local state = Instance.new("StringValue")
state.Name = "RoundState"
state.Value = "Intermission"
state.Parent = ReplicatedStorage

while true do
	state.Value = "Intermission"
	for i = INTERMISSION, 1, -1 do
		timeLeft.Value = i
		task.wait(1)
	end

	state.Value = "Round"
	for i = ROUND_TIME, 1, -1 do
		timeLeft.Value = i
		task.wait(1)
	end
end
