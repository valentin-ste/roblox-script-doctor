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

-- Automation hook used by our own tests: setting the widget attribute "Command" to "scan",
-- "fixall" or "undo" does the same as pressing the button. "Done" counts finished commands.
local COMMANDS = { scan = app.scan, fixall = app.fixAll, undo = app.undoFixes }
widget:GetAttributeChangedSignal("Command"):Connect(function()
	local command = widget:GetAttribute("Command")
	if command == nil then
		return
	end
	widget:SetAttribute("Command", nil)
	task.spawn(function()
		local action = COMMANDS[command]
		if action then
			action()
		end
		widget:SetAttribute("Done", (widget:GetAttribute("Done") or 0) + 1)
	end)
end)
