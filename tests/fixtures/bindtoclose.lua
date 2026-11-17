-- Fixture: BindToClose that waits a fixed time.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("Fixture")

local function save(player)
	pcall(function()
		store:SetAsync(player.UserId, 5)
	end)
end

Players.PlayerRemoving:Connect(save)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(save, player)
	end
	task.wait(3) --! bindtoclose-fixed-wait
end)

game:BindToClose(function()
	wait(5) --! bindtoclose-fixed-wait, deprecated-global
end)

-- Fine: saves one by one, so the callback returns when the work is done.
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

-- Fine: waits until every save has finished.
game:BindToClose(function()
	local pending = 0
	for _, player in ipairs(Players:GetPlayers()) do
		pending += 1
		task.spawn(function()
			save(player)
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait(0.1)
	end
end)
