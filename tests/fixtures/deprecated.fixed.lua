-- Fixture: deprecated API. Expected findings are marked at the end of their lines.
local Players = game:GetService("Players")
local part = workspace:FindFirstChild("Part")
local model = workspace:FindFirstChild("Model")
local humanoid = model:FindFirstChild("Humanoid")

task.wait(1) --! deprecated-global
task.defer(function() end) --! deprecated-global
task.delay(2, function() end) --! deprecated-global
while task.wait() do --! deprecated-global
	break
end

part.Touched:Connect(function() end) --! deprecated-connect
local connection = part.Touched:Connect(function() end)
connection:Disconnect() --! deprecated-connect

local child = part:FindFirstChild("Thing") --! deprecated-method
local copy = part:Clone() --! deprecated-method
for _, item in pairs(part:GetChildren()) do --! deprecated-method
	item:Destroy() --! deprecated-method
end
print(game:GetService("Lighting")) --! deprecated-method

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
