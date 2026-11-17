-- request: 4. Сделай систему раундов: лобби 20 секунд, раунд 2 минуты, потом снова лобби.
-- placement: Script в ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local roundStatus = ReplicatedStorage:FindFirstChild("RoundStatus")
if not roundStatus then
	roundStatus = Instance.new("StringValue")
	roundStatus.Name = "RoundStatus"
	roundStatus.Parent = ReplicatedStorage
end

local roundTime = ReplicatedStorage:FindFirstChild("RoundTime")
if not roundTime then
	roundTime = Instance.new("IntValue")
	roundTime.Name = "RoundTime"
	roundTime.Parent = ReplicatedStorage
end

local function runTimer(status, seconds)
	roundStatus.Value = status

	for remaining = seconds, 0, -1 do
		roundTime.Value = remaining
		task.wait(1)
	end
end

while true do
	runTimer("Лобби", 20)
	runTimer("Раунд", 120)
end
