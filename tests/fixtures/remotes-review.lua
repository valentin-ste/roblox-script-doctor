-- Fixture: RemoteEvent handlers from the review of 16.11.2026.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MAX_GIFT = 100

-- A handler kept in a variable is found too.
local onGive = function(player, amount)
	player.leaderstats.Coins.Value += amount --! remote-client-value
end
ReplicatedStorage.Give.OnServerEvent:Connect(onGive)

-- A sign check is not a limit: the client can still send 1e9.
ReplicatedStorage.Give2.OnServerEvent:Connect(function(player, amount)
	if amount > 0 then
		player.leaderstats.Coins.Value += amount --! remote-client-value
	end
end)

-- A type check is not a limit either.
ReplicatedStorage.Give3.OnServerEvent:Connect(function(player, amount)
	if typeof(amount) ~= "number" or not amount then
		return
	end
	player.leaderstats.Coins.Value += amount --! remote-client-value
end)

-- Fine: an upper limit.
ReplicatedStorage.Give4.OnServerEvent:Connect(function(player, amount)
	if typeof(amount) ~= "number" or amount <= 0 or amount > MAX_GIFT then
		return
	end
	player.leaderstats.Coins.Value += amount
end)

-- Fine: clamped, even around another call.
ReplicatedStorage.Give5.OnServerEvent:Connect(function(player, amount)
	player.leaderstats.Coins.Value += math.clamp(tonumber(amount) or 0, 0, MAX_GIFT)
end)

-- `repeat ... until` does not turn the rest of the handler into a condition.
ReplicatedStorage.Hit.OnServerEvent:Connect(function(player, target, damage)
	repeat
		task.wait()
	until player.Character
	target.Humanoid:TakeDamage(damage) --! remote-unvalidated-args, remote-unvalidated-args
end)

-- Fine: the value is the `until` condition itself.
ReplicatedStorage.Wait.OnServerEvent:Connect(function(player, target)
	repeat
		task.wait()
	until typeof(target) == "Instance" and target.Parent
	target:Destroy()
	print(player)
end)
