-- Fixture: the result of FindFirstChild used straight away, without a nil check.
local tool = script.Parent
local Players = game:GetService("Players")

tool:FindFirstChild("ThumbnailCamera"):Destroy() --! findfirstchild-unchecked
local speed = tool:FindFirstChild("Config").Speed.Value --! findfirstchild-unchecked

tool.Handle.Touched:Connect(function(hit)
	if hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid").Health > 0 then --! findfirstchild-unchecked
		print(speed)
	end
end)

-- Fine: checked first, in different ways.
local camera = tool:FindFirstChild("ThumbnailCamera")
if camera then
	camera:Destroy()
end

local humanoid = tool.Parent and tool.Parent:FindFirstChildOfClass("Humanoid")
print(humanoid)

while tool:FindFirstChild("creator") do
	tool:FindFirstChild("creator"):Destroy()
end

if tool:FindFirstChild("Config") then
	print(tool:FindFirstChild("Config").Name)
end

-- Fine: WaitForChild does not return nil without a timeout.
tool:WaitForChild("Handle").Anchored = false
print(Players)

-- Fine: the script's own children come with it; inside pcall a missing object stops nothing.
script:FindFirstChild("Config"):Destroy()
pcall(function()
	workspace:FindFirstChild("ThumbnailCamera"):Destroy()
end)
