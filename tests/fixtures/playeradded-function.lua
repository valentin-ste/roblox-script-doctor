-- Fixture: the connection is made inside a function, which may run long after players joined.
local Players = game:GetService("Players")
local Service = {}

function Service:Start()
	Players.PlayerAdded:Connect(function(player) --! playeradded-no-existing-players@bug
		print(player)
	end)
end

Service:Start()
