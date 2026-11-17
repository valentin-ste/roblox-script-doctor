-- request: 11. Сделай двери, которые открываются только для игроков с геймпассом VIP.
-- placement: Script внутри Part-двери в Workspace; замените VIP_GAMEPASS_ID на ID своего VIP-геймпасса
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local door = script.Parent
local VIP_GAMEPASS_ID = 123456789
local cooldowns = {}

door.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)

	if not player or cooldowns[player.UserId] then
		return
	end

	cooldowns[player.UserId] = true

	local success, ownsPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
	end)

	if success and ownsPass then
		door.CanCollide = false
		door.Transparency = 0.65

		task.wait(3)

		door.CanCollide = true
		door.Transparency = 0
	end

	task.wait(1)
	cooldowns[player.UserId] = nil
end)
