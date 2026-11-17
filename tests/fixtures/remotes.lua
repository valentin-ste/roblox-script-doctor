-- Fixture: RemoteEvent handlers that trust the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local give = ReplicatedStorage:WaitForChild("Give")
local buy = ReplicatedStorage:WaitForChild("Buy")
local dash = ReplicatedStorage:WaitForChild("Dash")
local hit = ReplicatedStorage:WaitForChild("Hit")
local ask = ReplicatedStorage:WaitForChild("Ask")

local PRICES = { Sword = 100 }

give.OnServerEvent:Connect(function(player, amount)
	player.leaderstats.Coins.Value += amount --! remote-client-value
end)

local function onHit(player, target, damage)
	target.Humanoid:TakeDamage(damage)
	print(player)
end
hit.OnServerEvent:Connect(onHit) --! remote-unvalidated-args

-- Fine: no client arguments at all.
buy.OnServerEvent:Connect(function(player)
	player.leaderstats.Coins.Value -= PRICES.Sword
end)

-- Fine: every argument is checked before use.
dash.OnServerEvent:Connect(function(player, direction, itemName)
	if typeof(direction) ~= "Vector3" then
		return
	end
	local price = PRICES[itemName]
	if not price then
		return
	end
	player.Character.HumanoidRootPart.AssemblyLinearVelocity = direction.Unit * 50
	player.leaderstats.Coins.Value -= price
end)

ask.OnServerInvoke = function(player, question)
	-- Fine: the value never reaches anything sensitive.
	print(player)
	return string.upper(question)
end

local toggle = ReplicatedStorage:WaitForChild("Toggle")
local give2 = ReplicatedStorage:WaitForChild("GiveTool")
local SOUNDS = { Click = true }

-- Fine: a harmless flag, and a name looked up in a table written in this file.
toggle.OnServerEvent:Connect(function(player, visible, soundName)
	player.PlayerGui.Menu.Enabled = visible
	if SOUNDS[soundName] then
		print(soundName)
	end
end)

-- The client picks any object in ServerStorage: indexing a service is not a whitelist.
give2.OnServerEvent:Connect(function(player, toolName) --! remote-unvalidated-args
	game.ServerStorage[toolName]:Clone().Parent = player.Backpack
end)
