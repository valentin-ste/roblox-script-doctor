--[[
	Automation hook for our own Studio tests. Only the test build includes it:

		rojo build test.project.json -o build/ScriptDoctor-test.rbxm

	Setting the widget attribute "Command" to "scan", "fixall" or "undo" does the same as
	pressing the button (without the confirming second click). "Done" counts finished commands.
]]
return function(widget: DockWidgetPluginGui, app: any)
	local commands = { scan = app.scan, fixall = app.fixAll, undo = app.undoFixes }
	widget:GetAttributeChangedSignal("Command"):Connect(function()
		local command = widget:GetAttribute("Command")
		if command == nil then
			return
		end
		-- the signal fires for every write and handlers read the latest value: reset at once
		widget:SetAttribute("Command", nil)
		task.spawn(function()
			local action = commands[command]
			if action then
				action()
			end
			widget:SetAttribute("Done", ((widget:GetAttribute("Done") :: number?) or 0) + 1)
		end)
	end)
end
