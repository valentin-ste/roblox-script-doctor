-- request: Сделай двери, которые открываются только для игроков с геймпассом VIP.
-- placement: Script внутри Part (двери) в Workspace. Замените GAMEPASS_ID на ID вашего геймпасса.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local GAMEPASS_ID = 0 -- вставьте ID геймпасса VIP

local door = script.Parent
local OPEN_TIME = 3

local isOpen = false
local ownsCache = {}

local function ownsPass(player)
	if ownsCache[player.UserId] ~= nil then
		return ownsCache[player.UserId]
	end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID)
	end)
	if ok then
		ownsCache[player.UserId] = result
		return result
	end
	warn("Не удалось проверить геймпасс: " .. tostring(result))
	return false
end

door.Touched:Connect(function(hit)
	if isOpen then
		return
	end

	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then
		return
	end

	if not ownsPass(player) then
		-- предлагаем купить
		MarketplaceService:PromptGamePassPurchase(player, GAMEPASS_ID)
		return
	end

	isOpen = true
	door.CanCollide = false
	door.Transparency = 0.7
	task.wait(OPEN_TIME)
	door.CanCollide = true
	door.Transparency = 0
	isOpen = false
end)

-- обновляем кэш после покупки
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if passId == GAMEPASS_ID and purchased then
		ownsCache[player.UserId] = true
	end
end)

Players.PlayerRemoving:Connect(function(player)
	ownsCache[player.UserId] = nil
end)
