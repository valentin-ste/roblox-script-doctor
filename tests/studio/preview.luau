--[[
	Preview of the plugin panel inside the Studio viewport, for looking at the interface
	without reinstalling the plugin (Studio only reloads local plugins on restart).

	Not run by lune. Paste into the Studio MCP "execute_luau" tool (Edit mode) after starting
	a local file server in the project root:

		python3 -I -m http.server --bind 127.0.0.1 48235 -d <project root>

	It builds App/Core modules from the current sources, puts the panel on a part 200 studs
	up and scans `ServerStorage._test` (insert test scripts there first). Then take a picture
	with screen_capture: camera_position [0, 200, -9.2], look_at_position [0, 200, 0].
	A flat ScreenGui does not show up in screen_capture, a SurfaceGui does.
	Buttons can be driven through _G.__ScriptDoctorPreview (scan / fixAll / undoFixes).
	Clean up: destroy workspace._ScriptDoctorPreview and ServerStorage._ui_dev.
]]
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local BASE = "http://127.0.0.1:48235/"

local function get(path)
	local response = HttpService:RequestAsync({ Url = BASE .. path, Method = "GET" })
	assert(response.StatusCode == 200, "could not fetch " .. path)
	return response.Body
end

for _, name in { "_ui_dev" } do
	local old = ServerStorage:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local oldPart = workspace:FindFirstChild("_ScriptDoctorPreview")
if oldPart then
	oldPart:Destroy()
end

local dev = Instance.new("Folder")
dev.Name = "_ui_dev"
local app = Instance.new("ModuleScript")
app.Name = "App"
app.Source = get("src/plugin/App.luau")
app.Parent = dev
local core = Instance.new("Folder")
core.Name = "Core"
core.Parent = dev
for _, name in { "Lexer", "Checker" } do
	local module = Instance.new("ModuleScript")
	module.Name = name
	module.Source = get("src/core/" .. name .. ".luau")
	module.Parent = core
end
dev.Parent = ServerStorage

local part = Instance.new("Part")
part.Name = "_ScriptDoctorPreview"
part.Anchored = true
part.CanCollide = false
part.Size = Vector3.new(8.8, 11.2, 0.2)
part.Position = Vector3.new(0, 200, 0)
part.Parent = workspace

local gui = Instance.new("SurfaceGui")
gui.Name = "Panel"
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
gui.CanvasSize = Vector2.new(440, 560)
gui.LightInfluence = 0
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = part

local App = require(app)
local controller = App.mount(gui, { roots = { ServerStorage:FindFirstChild("_test") } })
_G.__ScriptDoctorPreview = controller
controller.scan()
return gui:FindFirstChild("Status", true).Text
