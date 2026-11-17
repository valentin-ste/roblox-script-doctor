-- Fixture: deprecated API. Expected findings are marked at the end of their lines.
local Players = game:GetService("Players")
local part = workspace:FindFirstChild("Part")
local model = workspace:FindFirstChild("Model")
local humanoid = model:FindFirstChild("Humanoid")

wait(1) --! deprecated-global
spawn(function() end) --! deprecated-global
delay(2, function() end) --! deprecated-global
while wait() do --! deprecated-global
	break
end

part.Touched:connect(function() end) --! deprecated-connect
local connection = part.Touched:Connect(function() end)
connection:disconnect() --! deprecated-connect

local child = part:findFirstChild("Thing") --! deprecated-method
local copy = part:clone() --! deprecated-method
for _, item in pairs(part:children()) do --! deprecated-method
	item:destroy() --! deprecated-method
end
print(game:service("Lighting")) --! deprecated-method

part:Remove() --! deprecated-remove
copy:remove() --! deprecated-remove

local folder = Instance.new("Folder", workspace) --! instance-new-parent
local value = Instance.new("IntValue", folder) --! instance-new-parent
local mover = Instance.new("BodyVelocity") --! deprecated-body-mover
local gyro = Instance.new("BodyGyro", part) --! instance-new-parent, deprecated-body-mover

local track = humanoid:LoadAnimation(script.Animation) --! deprecated-loadanimation
local hit = workspace:FindPartOnRay(Ray.new(Vector3.zero, Vector3.yAxis)) --! deprecated-raycast
local hit2 = workspace:FindPartOnRayWithIgnoreList(Ray.new(Vector3.zero, Vector3.yAxis), {}) --! deprecated-raycast

print(Players, child, value, mover, gyro, track, hit, hit2)
