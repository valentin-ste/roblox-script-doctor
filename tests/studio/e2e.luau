--[[
	Repeatable Studio test of the plugin panel: scan, fix, a double click, undo, unload.

	Not run by lune. Start a local file server in the project root, then paste this file into
	the Studio MCP "execute_luau" tool (Edit mode):

		python3 -I -m http.server --bind 127.0.0.1 48235 -d <project root>

	It builds App/Core from the current sources, makes a few disabled test scripts in
	ServerStorage, drives the panel through its controller (the same functions the buttons
	call; the confirming second click of "Fix N safe" is a button detail and is not covered)
	and compares every number and every script text with what the core computes directly.
	Returns "N passed, M failed" and one line per check. Removes everything it created.
]]
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ScriptEditorService = game:GetService("ScriptEditorService")
local BASE = "http://127.0.0.1:48235/"

local function get(path: string): string
	local response = HttpService:RequestAsync({ Url = BASE .. path, Method = "GET" })
	assert(response.StatusCode == 200, "could not fetch " .. path)
	return response.Body
end

local report: { string } = {}
local passed, failed = 0, 0
local function check(name: string, ok: boolean, detail: any?)
	if ok then
		passed += 1
		table.insert(report, "PASS " .. name)
	else
		failed += 1
		table.insert(report, "FAIL " .. name .. (if detail ~= nil then ": " .. tostring(detail) else ""))
	end
end

local function editorSource(container: LuaSourceContainer): string
	return ScriptEditorService:GetEditorSource(container)
end

for _, name in { "_e2e_dev", "_e2e_scripts", "_e2e_host" } do
	local old = ServerStorage:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- the plugin modules, from the current sources
local dev = Instance.new("Folder")
dev.Name = "_e2e_dev"
local appModule = Instance.new("ModuleScript")
appModule.Name = "App"
appModule.Source = get("src/plugin/App.luau")
appModule.Parent = dev
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

-- test scripts: disabled, so nothing runs
local scripts = Instance.new("Folder")
scripts.Name = "_e2e_scripts"
local function addScript(className: string, name: string, source: string): LuaSourceContainer
	local container = Instance.new(className) :: any
	container.Name = name
	container.Source = source
	if container:IsA("BaseScript") then
		container.Enabled = false
	end
	container.Parent = scripts
	return container
end
local deprecated = addScript("Script", "Deprecated", get("tests/fixtures/deprecated.lua"))
addScript("Script", "Remotes", get("tests/fixtures/remotes.lua"))
-- a class in one script, used in another: its lowercase method must not be renamed
addScript("ModuleScript", "Enemy", "local Enemy = {}\nfunction Enemy:takeDamage(n)\n\treturn n\nend\nreturn Enemy\n")
local user = addScript(
	"Script",
	"User",
	"local e = require(script.Parent.Enemy)\ne:takeDamage(10)\nworkspace.Baseplate:clone()\n"
)
scripts.Parent = ServerStorage

local Checker = require(core:FindFirstChild("Checker") :: ModuleScript) :: any
local App = require(appModule) :: any

-- what the panel must show, computed with the core directly (everything in ServerStorage
-- is a server script for the plugin)
local originals: { [LuaSourceContainer]: string } = {}
local members: { [string]: boolean } = {}
for _, container in scripts:GetChildren() do
	originals[container] = container.Source
	for name in Checker.definedMembers(container.Source) do
		members[name] = true
	end
end
local options = { scriptKind = "server", knownMembers = members }
local expectedFindings, expectedFixable = 0, 0
local expectedFixed: { [LuaSourceContainer]: string } = {}
for container, source in originals do
	local findings = Checker.check(source, options)
	expectedFindings += #findings
	for _, finding in findings do
		if finding.fix then
			expectedFixable += 1
		end
	end
	expectedFixed[container] = Checker.applyFixes(source, findings)
end

local host = Instance.new("Folder")
host.Name = "_e2e_host"
host.Parent = ServerStorage
local controller = App.mount(host, { roots = { scripts } })
local status = host:FindFirstChild("Status", true) :: TextLabel
local undoButton = host:FindFirstChild("Undo", true) :: TextButton

-- 1. scan
controller.scan()
check(
	"scan shows the core's numbers",
	string.find(status.Text, `{expectedFindings} finding`, 1, true) ~= nil
		and string.find(status.Text, `{expectedFixable} can be fixed`, 1, true) ~= nil,
	`{status.Text} (expected {expectedFindings} / {expectedFixable})`
)

-- 2. "Fix all" pressed twice at once while one script is open in the editor (its edits go
--    through EditTextAsync and yield): the second press must do nothing
pcall(function()
	ScriptEditorService:OpenScriptDocumentAsync(deprecated)
end)
check("a script is open in the editor", ScriptEditorService:FindScriptDocument(deprecated) ~= nil)
local finished = 0
for _ = 1, 2 do
	task.spawn(function()
		controller.fixAll()
		finished += 1
	end)
end
-- the first press is still editing the open script (it yields); the second has returned
check("the second press came while the first was working", finished == 1, finished)
local deadline = os.clock() + 30
while finished < 2 and os.clock() < deadline do
	task.wait()
end
check("both presses returned", finished == 2, finished)
for container, fixed in expectedFixed do
	check(`text after fix: {container.Name}`, editorSource(container) == fixed, editorSource(container))
end
check(
	"a method of a class from another script is not renamed",
	string.find(editorSource(user), "e:takeDamage(10)", 1, true) ~= nil
		and string.find(editorSource(user), "Baseplate:Clone()", 1, true) ~= nil,
	editorSource(user)
)
check("Undo fixes is offered", undoButton.Visible)

-- 3. one undo step puts every script back, and there is no second step left over from the
--    ignored press
controller.undoFixes()
for container, source in originals do
	check(`undo restores {container.Name}`, editorSource(container) == source)
end
check("the double press made one undo step", not undoButton.Visible)

-- 4. Fix on one finding, then undo it
controller.scan()
local firstFix = nil
for _, finding in Checker.check(originals[deprecated], options) do
	if finding.fix then
		firstFix = finding
		break
	end
end
if firstFix then
	controller.fixOneAt(deprecated, firstFix.line)
	local expectedOne = Checker.applyFixes(originals[deprecated], { firstFix })
	check("Fix on one finding changes only it", editorSource(deprecated) == expectedOne, editorSource(deprecated))
	controller.undoFixes()
	check("undo of one fix", editorSource(deprecated) == originals[deprecated])
else
	check("the test script has a fixable finding", false)
end

-- 5. after unloading, the panel is gone and actions do nothing
controller.destroy()
local ok = pcall(controller.scan)
check("destroyed panel ignores actions", ok and host:FindFirstChild("ScriptDoctor") == nil)

-- clean up
pcall(function()
	local document = ScriptEditorService:FindScriptDocument(deprecated)
	if document then
		document:CloseAsync()
	end
end)
for _, item in { dev, scripts, host } do
	item:Destroy()
end

return `{passed} passed, {failed} failed\n` .. table.concat(report, "\n")
