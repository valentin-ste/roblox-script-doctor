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

-- A lower limit only, in either form: the client can still send 1e9.
ReplicatedStorage.Give6.OnServerEvent:Connect(function(player, amount)
	if amount >= 5 then
		player.leaderstats.Coins.Value += amount --! remote-client-value
	end
end)
ReplicatedStorage.Give7.OnServerEvent:Connect(function(player, amount)
	if amount < 5 then
		return
	end
	player.leaderstats.Coins.Value += amount --! remote-client-value
end)

-- Spending: a limit by the balance is not enough, a negative number adds coins.
ReplicatedStorage.Spend.OnServerEvent:Connect(function(player, amount)
	local coins = player.leaderstats.Coins
	if amount <= coins.Value then
		coins.Value -= amount --! remote-client-value
	end
end)

-- Fine: spending checked from both sides.
ReplicatedStorage.Spend2.OnServerEvent:Connect(function(player, amount)
	local coins = player.leaderstats.Coins
	if typeof(amount) ~= "number" or amount <= 0 or amount > coins.Value then
		return
	end
	coins.Value -= amount
end)

-- A handler kept in a table and connected through it.
local Handlers = {}
Handlers.give = function(player, amount)
	player.leaderstats.Coins.Value += amount --! remote-client-value
end
ReplicatedStorage.Give8.OnServerEvent:Connect(Handlers.give)

-- Fine: capped by an assignment in the branch.
ReplicatedStorage.Give9.OnServerEvent:Connect(function(player, amount)
	if typeof(amount) ~= "number" or amount < 0 then
		return
	end
	if amount > MAX_GIFT then
		amount = MAX_GIFT
	end
	player.leaderstats.Coins.Value += amount
end)

-- The limit is skipped for some players: no limit.
ReplicatedStorage.Give10.OnServerEvent:Connect(function(player, amount, isVip)
	if amount > MAX_GIFT and not isVip then
		return
	end
	player.leaderstats.Coins.Value += amount --! remote-client-value
end)

-- A guard joined with `or` does not limit the write inside it.
ReplicatedStorage.Give11.OnServerEvent:Connect(function(player, amount)
	if amount <= MAX_GIFT or player.UserId == game.CreatorId then
		player.leaderstats.Coins.Value += amount --! remote-client-value
	end
end)

-- Fine: checked to be a colour, not a number; there is nothing to limit.
ReplicatedStorage.Paint.OnServerEvent:Connect(function(player, color)
	if typeof(color) == "Color3" then
		player.Settings.Color.Value = color
	end
end)

-- Fine: only a colour gets past the check.
ReplicatedStorage.Paint2.OnServerEvent:Connect(function(player, color)
	if typeof(color) ~= "Color3" then
		return
	end
	player.Settings.Color.Value = color
end)

-- A type check that lets numbers through: no limit.
ReplicatedStorage.Give12.OnServerEvent:Connect(function(player, amount)
	if typeof(amount) == "string" then
		return
	end
	player.leaderstats.Coins.Value += amount --! remote-client-value
end)
ReplicatedStorage.Give13.OnServerEvent:Connect(function(player, amount)
	if type(amount) ~= "table" then
		player.leaderstats.Coins.Value += amount --! remote-client-value
	end
end)

-- An assignment made from the old value limits nothing.
ReplicatedStorage.Give14.OnServerEvent:Connect(function(player, amount)
	if amount > MAX_GIFT then
		amount = amount * 2
	end
	player.leaderstats.Coins.Value += amount --! remote-client-value
end)

-- `== 5 then return` leaves every other number.
ReplicatedStorage.Give15.OnServerEvent:Connect(function(player, amount)
	if amount == 5 then
		return
	end
	player.leaderstats.Coins.Value += amount --! remote-client-value
end)

-- Fine: limited from both sides on one line.
ReplicatedStorage.Give16.OnServerEvent:Connect(function(player, amount)
	if amount > MAX_GIFT then amount = MAX_GIFT elseif amount < 0 then amount = 0 end
	player.leaderstats.Coins.Value += amount
end)

-- Fine: only one value gets past the check.
ReplicatedStorage.Give17.OnServerEvent:Connect(function(player, amount)
	if amount ~= 5 then
		return
	end
	player.leaderstats.Coins.Value += amount
end)

-- `~= 5` where the write happens leaves every other number.
ReplicatedStorage.Give18.OnServerEvent:Connect(function(player, amount)
	if amount ~= 5 then
		player.leaderstats.Coins.Value += amount --! remote-client-value
	end
end)
