--[[
	Script Doctor — plugin entry point.

	Creates the toolbar button and the dock widget, then hands the widget to App,
	which builds the interface and does the work.
]]

local App = require(script.App)

local PLUGIN_NAME = "Script Doctor"

local toolbar = plugin:CreateToolbar(PLUGIN_NAME)
local openButton = toolbar:CreateButton(
	"ScriptDoctorOpen",
	"Check every script for unsafe remotes, data-loss bugs and deprecated API",
	"",
	PLUGIN_NAME
)
openButton.ClickableWhenViewportHidden = true

local widget = plugin:CreateDockWidgetPluginGuiAsync(
	"ScriptDoctorWidget",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 440, 560, 320, 240)
)
widget.Title = PLUGIN_NAME
widget.Name = "ScriptDoctorWidget"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local app = App.mount(widget, { plugin = plugin })

openButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
openButton:SetActive(widget.Enabled)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	openButton:SetActive(widget.Enabled)
end)

-- Clean up when the plugin is turned off, updated or Studio closes.
plugin.Unloading:Connect(app.destroy)

-- Only the test build (test.project.json) has this module: commands for automated tests.
local testHooks = script:FindFirstChild("TestHooks")
if testHooks then
	-- never to be confused with the release build
	widget.Title = PLUGIN_NAME .. " (test build)"
	require(testHooks :: ModuleScript)(widget, app)
end
