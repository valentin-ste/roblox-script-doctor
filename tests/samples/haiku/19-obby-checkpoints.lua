-- request: Сделай чекпоинты для обби с сохранением последнего чекпоинта.
-- placement: Script в ServerScriptService. Чекпоинты — Part в папке workspace.Checkpoints, у каждого атрибут Index (1, 2, 3...)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("Checkpoints_v1")

local checkpoints = {}
for _, part in ipairs(workspace:WaitForChild("Checkpoints"):GetChildren()) do
	local index = part:GetAttribute("Index")
	if part:IsA("BasePart") and index then
		checkpoints[index] = part
	end
end

local progress = {} -- player -> номер последнего чекпоинта

local function savePlayer(player)
	local index = progress[player]
	if not index then
		return
	end
	pcall(function()
		store:SetAsync("CP_" .. player.UserId, index)
	end)
end

Players.PlayerAdded:Connect(function(player)
	local ok, saved = pcall(function()
		return store:GetAsync("CP_" .. player.UserId)
	end)
	progress[player] = (ok and tonumber(saved)) or 0

	player.CharacterAdded:Connect(function(character)
		-- ждём, пока загрузится сохранённый прогресс
		repeat
			task.wait()
		until progress[player] ~= nil

		local index = progress[player]
		local part = checkpoints[index]
		if part and index > 0 then
			character:WaitForChild("HumanoidRootPart")
			character:PivotTo(part.CFrame + Vector3.new(0, 5, 0))
		end
	end)
end)

for index, part in pairs(checkpoints) do
	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or progress[player] == nil then
			return
		end
		if progress[player] < index then
			progress[player] = index
			savePlayer(player)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	progress[player] = nil
end)

game:BindToClose(function()
	for player in pairs(progress) do
		savePlayer(player)
	end
end)
