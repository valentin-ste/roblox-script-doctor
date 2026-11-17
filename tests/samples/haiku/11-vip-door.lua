-- request: Сделай двери, которые открываются только для игроков с геймпассом VIP.
-- placement: Script внутрь Part-двери в workspace. Вставь свой ID геймпасса в VIP_PASS_ID
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local door = script.Parent
local VIP_PASS_ID = 0 -- вставьте ID своего геймпасса
local OPEN_TIME = 3

local vipCache = {}
local opening = false

local function isVip(player)
	if vipCache[player.UserId] == nil then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_PASS_ID)
		end)
		vipCache[player.UserId] = (ok and owns) or false
	end
	return vipCache[player.UserId]
end

door.Touched:Connect(function(hit)
	if opening then
		return
	end

	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or not isVip(player) then
		return
	end

	opening = true
	door.CanCollide = false
	door.Transparency = 0.7
	task.wait(OPEN_TIME)
	door.CanCollide = true
	door.Transparency = 0
	opening = false
end)
