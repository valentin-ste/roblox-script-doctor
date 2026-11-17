--[[
	The whole interface and its logic, independent of where it is shown.

	App.mount(host) builds the panel inside `host` (the plugin's dock widget, or any
	GUI container — that is how we look at the interface in tests) and returns a
	controller with the same actions the buttons have.

	- click a finding  -> opens the script at that line
	- "Fix"            -> applies the safe replacement for one finding
	- "Fix N safe"     -> asks once more, then applies every safe replacement in the place
	- "Undo fixes"     -> puts back the text replaced by the last fix (press again for the
	                      one before); kept in memory until Studio closes

	All analysis lives in Core/Checker (pure Luau, tested outside Studio).
]]

local RunService = game:GetService("RunService")
local ScriptEditorService = game:GetService("ScriptEditorService")

local Checker = require(script.Parent.Core.Checker)

local App = {}

export type Options = {
	-- the Plugin object, when running as a plugin (only used as a fallback to open scripts)
	plugin: any?,
	-- instances to scan instead of the usual services (tests)
	roots: { Instance }?,
}

export type Controller = {
	scan: () -> (),
	fixAll: () -> (),
	undoFixes: () -> (),
	fixOneAt: (LuaSourceContainer, number) -> (),
	destroy: () -> (),
}

local APP_NAME = "Script Doctor"
local MAX_ROWS = 300
-- how many fix steps "Undo fixes" can take back
local MAX_UNDO_STEPS = 20
-- how long "Fix N safe" waits for the confirming second click, and how soon it may come:
-- a quick double click is one gesture, not a confirmation
local CONFIRM_SECONDS = 6
local CONFIRM_MIN_SECONDS = 1

-- Every service of the place is scanned (backdoors hide in Chat, TextChatService and other
-- odd places), except these: Roblox's own code and plugin internals, not the game's.
local SKIPPED_SERVICES = {
	CoreGui = true,
	CorePackages = true,
	RobloxReplicatedStorage = true,
	RobloxPluginGuiService = true,
	PluginGuiService = true,
	PluginDebugService = true,
}

-- Containers whose ModuleScripts run on the client.
local CLIENT_CONTAINERS = {
	"StarterPlayerScripts",
	"StarterCharacterScripts",
	"StarterGui",
	"StarterPack",
	"ReplicatedFirst",
}
local SERVER_CONTAINERS = { "ServerScriptService", "ServerStorage" }

local SEVERITIES = {
	{ id = "security", label = "Security", color = Color3.fromRGB(214, 69, 69) },
	{ id = "bug", label = "Bugs", color = Color3.fromRGB(214, 126, 36) },
	{ id = "deprecated", label = "Deprecated", color = Color3.fromRGB(163, 137, 26) },
	{ id = "advice", label = "Advice", color = Color3.fromRGB(74, 124, 186) },
}
local SEVERITY_ORDER = {}
local SEVERITY_COLOR = {}
for order, severity in SEVERITIES do
	SEVERITY_ORDER[severity.id] = order
	SEVERITY_COLOR[severity.id] = severity.color
end

local PRIMARY = Color3.fromRGB(0, 116, 204)
local SUCCESS = Color3.fromRGB(46, 140, 82)
local WARNING = Color3.fromRGB(176, 106, 20)
local WHITE = Color3.new(1, 1, 1)

type Result = { script: LuaSourceContainer, finding: Checker.Finding }
type Change = { script: LuaSourceContainer, before: string, after: string, count: number, fixes: { Checker.Fix } }

local function themeColor(style: Enum.StudioStyleGuideColor, fallback: Color3): Color3
	local ok, color = pcall(function()
		return settings().Studio.Theme:GetColor(style)
	end)
	return if ok then color else fallback
end

local function create(className: string, properties: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in properties do
		instance[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	return instance
end

local function corner(radius: number): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function padding(horizontal: number, vertical: number): UIPadding
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, horizontal),
		PaddingRight = UDim.new(0, horizontal),
		PaddingTop = UDim.new(0, vertical),
		PaddingBottom = UDim.new(0, vertical),
	})
end

-- "client" / "server" from the script class, and for a ModuleScript from where it lives;
-- nil for a ModuleScript in a shared place (ReplicatedStorage), the checker then guesses.
local function scriptKindOf(container: LuaSourceContainer): string?
	if container:IsA("LocalScript") then
		return "client"
	elseif container:IsA("Script") then
		return if (container :: Script).RunContext == Enum.RunContext.Client then "client" else "server"
	end
	for _, className in CLIENT_CONTAINERS do
		if container:FindFirstAncestorWhichIsA(className) then
			return "client"
		end
	end
	for _, className in SERVER_CONTAINERS do
		if container:FindFirstAncestorWhichIsA(className) then
			return "server"
		end
	end
	return nil
end

local function readSource(container: LuaSourceContainer): string?
	local ok, source = pcall(function()
		return ScriptEditorService:GetEditorSource(container)
	end)
	return if ok then source else nil
end

-- Changes the text of a script from `source` to `newSource`; `fixes` are the edits that make
-- that change (in apply order, end of text first).
--
-- A script open in the editor gets each edit applied on its own, so the cursor and the scroll
-- position stay where they are (replacing the whole text makes the editor jump to the last
-- line). A closed script is changed through Source.
local function writeChange(
	container: LuaSourceContainer,
	source: string,
	newSource: string,
	fixes: { Checker.Fix }
): boolean
	local document = nil
	pcall(function()
		document = ScriptEditorService:FindScriptDocument(container)
	end)
	if not document then
		-- a closed script: UpdateSourceAsync is the way Roblox asks plugins to change scripts
		-- (it keeps Team Create collaborative editing in sync); no cursor to keep here
		local ok, message = pcall(function()
			ScriptEditorService:UpdateSourceAsync(container, function(current: string): string?
				-- changed by someone since we read it: leave it alone
				return if current == source then newSource else nil
			end)
		end)
		if ok then
			return readSource(container) == newSource
		end
		-- the API refused: write Source directly, but only over the text we read
		if readSource(container) == source then
			ok, message = pcall(function()
				(container :: any).Source = newSource
			end)
		end
		if not ok then
			warn(`[{APP_NAME}] could not change {container:GetFullName()}: {message}`)
		end
		return ok and readSource(container) == newSource
	end

	local selection = { pcall(document.GetSelection, document) }
	pcall(function()
		for _, fix in fixes do
			local startLine, startCol = Checker.position(source, fix.from)
			local endLine, endCol = Checker.position(source, fix.to + 1)
			document:EditTextAsync(fix.text, startLine, startCol, endLine, endCol)
		end
	end)
	if readSource(container) ~= newSource then
		-- the edits did not land as expected: set the whole text instead
		local ok, message = pcall(function()
			ScriptEditorService:UpdateSourceAsync(container, function()
				return newSource
			end)
		end)
		if not ok then
			warn(`[{APP_NAME}] could not change {container:GetFullName()}: {message}`)
			return false
		end
	end
	-- put the cursor back where the user had it
	if selection[1] and typeof(selection[2]) == "number" and typeof(selection[3]) == "number" then
		pcall(function()
			document:RequestSetSelectionAsync(selection[2], selection[3])
		end)
	end
	return true
end

local function plural(count: number, word: string): string
	return `{count} {word}{if count == 1 then "" else "s"}`
end

function App.mount(host: Instance, options: Options?): Controller
	local pluginObject = options and options.plugin
	local customRoots = options and options.roots

	----------------------------------------------------------------------------
	-- State
	----------------------------------------------------------------------------

	local results: { Result } = {}
	local scannedScripts = 0
	local hasScanned = false
	-- a scan, fix or undo is running; every other action waits for it to finish (an edit of an
	-- open script yields, and a second click would otherwise fix half-changed text)
	local busy = false
	local progress: string? = nil
	local enabledSeverity = { security = true, bug = true, deprecated = true, advice = true }
	-- Studio's own undo (Ctrl+Z) does not bring back script text changed by a plugin, so we
	-- remember the text we replaced and offer our own "Undo fixes", one step per press.
	local undoSteps: { { Change } } = {}
	-- method names defined by any script of the place (see Checker.definedMembers), and a
	-- cache of them per script so a scan after a fix does not parse every script again
	local knownMembers: { [string]: boolean } = {}
	local memberCache: { [LuaSourceContainer]: { source: string, members: { [string]: boolean } } } = setmetatable(
		{},
		{ __mode = "k" }
	) :: any
	-- what the last fix or undo did, shown in the banner until the next scan
	local notice: string? = nil
	local noticeColor = SUCCESS
	-- "Fix N safe" was clicked once at confirmFrom; a second click after
	-- confirmFrom + CONFIRM_MIN_SECONDS and before confirmUntil applies the fixes
	local confirmFrom = 0
	local confirmUntil = 0
	local connections: { RBXScriptConnection } = {}
	local destroyed = false

	----------------------------------------------------------------------------
	-- Layout
	----------------------------------------------------------------------------

	local root = create("Frame", {
		Name = "ScriptDoctor",
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Parent = host,
	})

	local header = create("Frame", {
		Name = "Header",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		padding(12, 12),
		create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local buttonRow = create("Frame", {
		Name = "Buttons",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = header,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local function makeButton(name: string, label: string, order: number): (TextButton, UIStroke)
		local stroke = create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1 })
		local button = create("TextButton", {
			Name = name,
			Text = label,
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 15,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 32),
			AutoButtonColor = true,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = buttonRow,
		}, { corner(6), padding(14, 0), stroke })
		return button, stroke
	end

	local scanButton, scanStroke = makeButton("Scan", "Scan place", 1)
	local fixAllButton, fixAllStroke = makeButton("FixAll", "Fix safe issues", 2)
	local undoButton, undoStroke = makeButton("Undo", "Undo fixes", 3)
	fixAllButton.Visible = false
	undoButton.Visible = false

	local noticeLabel = create("TextLabel", {
		Name = "Notice",
		Text = "",
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = SUCCESS,
		BorderSizePixel = 0,
		Visible = false,
		LayoutOrder = 2,
		Parent = header,
	}, { corner(6), padding(10, 8) })

	local statusLabel = create("TextLabel", {
		Name = "Status",
		Text = "",
		Font = Enum.Font.BuilderSans,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = header,
	})

	local filterRow = create("Frame", {
		Name = "Filters",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = header,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local list = create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = root,
	}, {
		padding(12, 4),
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local function layoutList()
		local top = header.AbsoluteSize.Y
		list.Position = UDim2.fromOffset(0, top)
		list.Size = UDim2.new(1, 0, 1, -top)
	end
	table.insert(connections, header:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutList))
	layoutList()

	local filterButtons: { [string]: TextButton } = {}
	local render: () -> ()

	-- Fixes change the scripts of this DataModel. During a test (Play / Run) that is a copy
	-- thrown away on Stop, so fixing is switched off there.
	local function canEdit(): boolean
		local ok, isEdit = pcall(function()
			return RunService:IsEdit()
		end)
		return not ok or isEdit
	end

	----------------------------------------------------------------------------
	-- Scanning and fixing
	----------------------------------------------------------------------------

	local function collectScripts(): { LuaSourceContainer }
		local scripts = {}
		local roots: { Instance } = {}
		if customRoots then
			roots = customRoots
		else
			for _, service in game:GetChildren() do
				if not SKIPPED_SERVICES[service.ClassName] then
					table.insert(roots, service)
				end
			end
		end
		for _, scanRoot in roots do
			-- some services refuse plugins; skip them instead of stopping the scan
			local ok, descendants = pcall(scanRoot.GetDescendants, scanRoot)
			if not ok then
				continue
			end
			for _, descendant in descendants do
				if descendant:IsA("LuaSourceContainer") then
					table.insert(scripts, descendant)
				end
			end
		end
		return scripts
	end

	local function checkOptions(container: LuaSourceContainer): Checker.Options
		return { scriptKind = scriptKindOf(container), knownMembers = knownMembers }
	end

	local function setProgress(text: string?)
		progress = text
		if text then
			statusLabel.Text = text
		end
	end

	local function runScan()
		local scripts = collectScripts()
		-- 1. the method names every script defines, so that a `:destroy()` on a class from
		--    another ModuleScript is not offered for renaming
		local sources: { [LuaSourceContainer]: string } = {}
		local members: { [string]: boolean } = {}
		for index, container in scripts do
			local source = readSource(container)
			if source then
				sources[container] = source
				local cached = memberCache[container]
				if not cached or cached.source ~= source then
					local ok, defined = pcall(Checker.definedMembers, source)
					cached = { source = source, members = if ok then defined else {} }
					memberCache[container] = cached
				end
				for name in (cached :: any).members do
					members[name] = true
				end
			end
			if index % 50 == 0 then
				setProgress(`Reading… {index} / {#scripts} scripts`)
				task.wait()
			end
		end
		knownMembers = members
		-- 2. the findings
		local fresh: { Result } = {}
		for index, container in scripts do
			local source = sources[container]
			if source then
				local ok, findings = pcall(Checker.check, source, checkOptions(container))
				if ok then
					for _, finding in findings do
						table.insert(fresh, { script = container, finding = finding })
					end
				else
					warn(`[{APP_NAME}] could not check {container:GetFullName()}: {findings}`)
				end
			end
			if index % 25 == 0 then
				setProgress(`Scanning… {index} / {#scripts} scripts`)
				task.wait()
			end
		end
		setProgress(nil)
		results = fresh
		scannedScripts = #scripts
		hasScanned = true
	end

	-- Runs one action at a time: a click during a scan, fix or undo does nothing. An error
	-- inside the action is reported in the banner instead of leaving the panel stuck.
	local function exclusive(action: () -> ())
		if busy or destroyed then
			return
		end
		busy = true
		confirmUntil = 0
		render()
		local ok, message = pcall(action)
		busy = false
		setProgress(nil)
		if not ok then
			warn(`[{APP_NAME}] {message}`)
			notice = `Something went wrong: {message}`
			noticeColor = WARNING
		end
		if not destroyed then
			render()
		end
	end

	-- Rewrites one script. `pick` chooses which current findings to fix. A failure in one
	-- script is reported and the others go on, so every change made is kept for undo.
	local function fixScript(container: LuaSourceContainer, pick: (Checker.Finding) -> boolean, changes: { Change })
		local ok, message = pcall(function()
			local source = readSource(container)
			if not source then
				return
			end
			local chosen = {}
			for _, finding in Checker.check(source, checkOptions(container)) do
				if finding.fix and pick(finding) then
					table.insert(chosen, finding)
				end
			end
			local fixes = Checker.orderedFixes(chosen)
			local newSource, applied = Checker.applyFixes(source, chosen)
			if applied > 0 and writeChange(container, source, newSource, fixes) then
				table.insert(
					changes,
					{ script = container, before = source, after = newSource, count = applied, fixes = fixes }
				)
			end
		end)
		if not ok then
			warn(`[{APP_NAME}] could not fix {container:GetFullName()}: {message}`)
		end
	end

	-- Opens the script with the new text of one fix selected, so the change is in plain view.
	local function reveal(change: Change)
		local fix = change.fixes[1]
		if not fix then
			return
		end
		local line, col = Checker.position(change.before, fix.from)
		task.spawn(function()
			pcall(function()
				ScriptEditorService:OpenScriptDocumentAsync(change.script)
				local document = ScriptEditorService:FindScriptDocument(change.script)
				if document then
					document:ForceSetSelectionAsync(line, col + #fix.text, line, col)
				end
			end)
		end)
	end

	-- "Fixed 13 places in 5 scripts: a, b, c and 2 more."
	local function describe(changes: { Change }): string
		local total = 0
		local names = {}
		for index, change in changes do
			total += change.count
			if index <= 3 then
				table.insert(names, change.script.Name)
			end
		end
		local more = if #changes > 3 then ` and {#changes - 3} more` else ""
		return `Fixed {plural(total, "place")} in {plural(#changes, "script")}: {table.concat(names, ", ")}{more}.`
	end

	local function finishFix(changes: { Change })
		noticeColor = SUCCESS
		if #changes == 0 then
			notice = "Nothing was changed: these scripts no longer have that issue. Scanned again."
		else
			table.insert(undoSteps, changes)
			if #undoSteps > MAX_UNDO_STEPS then
				table.remove(undoSteps, 1)
			end
			notice = describe(changes)
				.. " Ctrl+Z does not undo this; “Undo fixes” here does, until Studio is closed."
		end
		runScan()
	end

	local function scan()
		exclusive(function()
			notice = nil
			runScan()
		end)
	end

	local function fixAll()
		exclusive(function()
			if not canEdit() then
				return
			end
			local touched: { [LuaSourceContainer]: boolean } = {}
			for _, result in results do
				if result.finding.fix then
					touched[result.script] = true
				end
			end
			local changes: { Change } = {}
			local done = 0
			for container in touched do
				fixScript(container, function()
					return true
				end, changes)
				done += 1
				setProgress(`Fixing… {done} scripts`)
			end
			finishFix(changes)
		end)
	end

	local function fixOne(result: Result)
		local changes: { Change } = {}
		exclusive(function()
			if not canEdit() then
				return
			end
			local finding = result.finding
			fixScript(result.script, function(candidate)
				return candidate.rule == finding.rule
					and candidate.line == finding.line
					and candidate.col == finding.col
			end, changes)
			finishFix(changes)
		end)
		if changes[1] then
			reveal(changes[1])
		end
	end

	-- Same as pressing "Fix" on the finding at this line (used by tests).
	local function fixOneAt(container: LuaSourceContainer, line: number)
		for _, result in results do
			if result.script == container and result.finding.line == line and result.finding.fix then
				fixOne(result)
				return
			end
		end
	end

	-- Takes back the last fix step: every script it changed gets its old text, unless the
	-- script was edited after the fix.
	local function undoFixes()
		exclusive(function()
			if #undoSteps == 0 or not canEdit() then
				return
			end
			local step = table.remove(undoSteps) :: { Change }
			local restored, skipped = 0, 0
			for _, change in step do
				local ok, done = pcall(function()
					local stillOurs = change.script.Parent ~= nil and readSource(change.script) == change.after
					local undoing = Checker.reverseFixes(change.before, change.fixes)
					return stillOurs and writeChange(change.script, change.after, change.before, undoing)
				end)
				if ok and done then
					restored += 1
				else
					skipped += 1
				end
			end
			local text = `Put the old text back in {plural(restored, "script")}.`
			if skipped > 0 then
				text ..= ` {plural(skipped, "script")} changed after the fix and were left alone.`
			end
			if #undoSteps > 0 then
				text ..= ` Press “Undo fixes” again to take back the fix before that ({#undoSteps} left).`
			end
			notice = text
			noticeColor = SUCCESS
			runScan()
		end)
	end

	local function openAt(container: LuaSourceContainer, line: number, col: number)
		task.spawn(function()
			local ok = pcall(function()
				ScriptEditorService:OpenScriptDocumentAsync(container)
				local document = ScriptEditorService:FindScriptDocument(container)
				if document then
					document:RequestSetSelectionAsync(line, col)
				end
			end)
			if not ok and pluginObject then
				pcall(function()
					pluginObject:OpenScript(container, line)
				end)
			end
		end)
	end

	----------------------------------------------------------------------------
	-- Rendering
	----------------------------------------------------------------------------

	local function applyTheme()
		local buttonColor = themeColor(Enum.StudioStyleGuideColor.Button, Color3.fromRGB(240, 240, 240))
		local buttonText = themeColor(Enum.StudioStyleGuideColor.ButtonText, Color3.fromRGB(30, 30, 30))
		local border = themeColor(Enum.StudioStyleGuideColor.Border, Color3.fromRGB(180, 180, 180))
		root.BackgroundColor3 = themeColor(Enum.StudioStyleGuideColor.MainBackground, WHITE)
		statusLabel.TextColor3 = themeColor(Enum.StudioStyleGuideColor.MainText, Color3.fromRGB(30, 30, 30))
		list.ScrollBarImageColor3 = themeColor(Enum.StudioStyleGuideColor.ScrollBar, Color3.fromRGB(150, 150, 150))
		scanButton.BackgroundColor3 = PRIMARY
		scanButton.TextColor3 = WHITE
		scanStroke.Color = PRIMARY
		for _, pair in { { fixAllButton, fixAllStroke }, { undoButton, undoStroke } } do
			pair[1].BackgroundColor3 = buttonColor
			pair[1].TextColor3 = buttonText
			pair[2].Color = border
		end
	end

	-- Buttons look pressed-out while an action runs; clicks are ignored then anyway.
	local function setEnabled(button: TextButton, enabled: boolean)
		button.AutoButtonColor = enabled
		button.BackgroundTransparency = if enabled then 0 else 0.5
		button.TextTransparency = if enabled then 0 else 0.5
	end

	local function makeRow(result: Result, order: number)
		local finding = result.finding
		local color = SEVERITY_COLOR[finding.severity]
		local row = create("TextButton", {
			Name = "Finding",
			Text = "",
			AutoButtonColor = true,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = themeColor(Enum.StudioStyleGuideColor.Item, Color3.fromRGB(246, 246, 246)),
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = list,
		}, {
			corner(6),
			create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
				Color = themeColor(Enum.StudioStyleGuideColor.Border, Color3.fromRGB(200, 200, 200)),
			}),
			create("Frame", {
				Name = "Stripe",
				Size = UDim2.new(0, 4, 1, 0),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			}, { corner(2) }),
		})

		local body = create("Frame", {
			Name = "Body",
			Position = UDim2.fromOffset(4, 0),
			Size = UDim2.new(1, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = row,
		}, {
			padding(10, 8),
			create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		})

		create("TextLabel", {
			Name = "Title",
			Text = finding.title,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = themeColor(Enum.StudioStyleGuideColor.MainText, Color3.fromRGB(30, 30, 30)),
			Size = UDim2.new(1, if finding.fix then -60 else 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = body,
		})

		create("TextLabel", {
			Name = "Message",
			Text = finding.message,
			Font = Enum.Font.BuilderSans,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = themeColor(Enum.StudioStyleGuideColor.MainText, Color3.fromRGB(30, 30, 30)),
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = body,
		})

		-- the line number goes first so a long script name can never push it out of view
		create("TextLabel", {
			Name = "Where",
			Text = `line {finding.line}  ·  {result.script.Name}`,
			Font = Enum.Font.BuilderSans,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = themeColor(Enum.StudioStyleGuideColor.MainText, Color3.fromRGB(30, 30, 30)),
			TextTransparency = 0.35,
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Parent = body,
		})

		row.MouseButton1Click:Connect(function()
			openAt(result.script, finding.line, finding.col)
		end)

		if finding.fix and canEdit() then
			local fixButton = create("TextButton", {
				Name = "Fix",
				Text = "Fix",
				Font = Enum.Font.BuilderSansMedium,
				TextSize = 13,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 8),
				Size = UDim2.fromOffset(48, 22),
				BackgroundColor3 = PRIMARY,
				TextColor3 = WHITE,
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = row,
			}, { corner(5) })
			setEnabled(fixButton, not busy)
			fixButton.MouseButton1Click:Connect(function()
				task.spawn(fixOne, result)
			end)
		end
	end

	local function makeEmptyRow(text: string)
		create("TextLabel", {
			Name = "Empty",
			Text = text,
			Font = Enum.Font.BuilderSans,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = themeColor(Enum.StudioStyleGuideColor.DimmedText, Color3.fromRGB(110, 110, 110)),
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = list,
		})
	end

	function render()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		table.sort(results, function(a, b)
			local orderA, orderB = SEVERITY_ORDER[a.finding.severity], SEVERITY_ORDER[b.finding.severity]
			if orderA ~= orderB then
				return orderA < orderB
			end
			local pathA, pathB = a.script:GetFullName(), b.script:GetFullName()
			if pathA ~= pathB then
				return pathA < pathB
			end
			return a.finding.line < b.finding.line
		end)

		local counts = { security = 0, bug = 0, deprecated = 0, advice = 0 }
		local fixable, shown, visibleTotal = 0, 0, 0
		for _, result in results do
			local severity = result.finding.severity
			counts[severity] += 1
			if result.finding.fix then
				fixable += 1
			end
			if enabledSeverity[severity] then
				visibleTotal += 1
				if shown < MAX_ROWS then
					shown += 1
					makeRow(result, shown)
				end
			end
		end

		for _, severity in SEVERITIES do
			local button = filterButtons[severity.id]
			local isOn = enabledSeverity[severity.id]
			button.Text = `{severity.label}  {counts[severity.id]}`
			button.BackgroundColor3 = severity.color
			button.BackgroundTransparency = if isOn then 0 else 0.8
			button.TextColor3 = if isOn then WHITE else severity.color
		end
		filterRow.Visible = hasScanned and #results > 0

		local editable = canEdit()
		local confirming = os.clock() < confirmUntil
		local fixScripts: { [LuaSourceContainer]: boolean } = {}
		local fixScriptCount = 0
		for _, result in results do
			if result.finding.fix and not fixScripts[result.script] then
				fixScripts[result.script] = true
				fixScriptCount += 1
			end
		end

		if confirming then
			noticeLabel.Text = `This changes {plural(fixable, "place")} in {plural(fixScriptCount, "script")}. `
				.. "Ctrl+Z will not undo it; “Undo fixes” in this panel will, until Studio is closed. "
				.. "Click the button again to go ahead."
			noticeLabel.BackgroundColor3 = WARNING
		else
			noticeLabel.Text = notice or ""
			noticeLabel.BackgroundColor3 = noticeColor
		end
		noticeLabel.Visible = confirming or notice ~= nil

		if busy and progress then
			statusLabel.Text = progress
		elseif busy then
			statusLabel.Text = "Working…"
		elseif not hasScanned then
			statusLabel.Text = "Checks every script in this place: free models you inserted, old code and new code."
			makeEmptyRow("Press “Scan place” to start. Nothing is changed until you press a Fix button.")
		elseif scannedScripts == 0 then
			statusLabel.Text = "No scripts found in this place."
		elseif #results == 0 then
			statusLabel.Text = `Checked {plural(scannedScripts, "script")}. Nothing to fix.`
		else
			local manual = #results - fixable
			local text = `Checked {plural(scannedScripts, "script")}: {plural(#results, "finding")}.`
			if fixable > 0 then
				text ..= ` {fixable} can be fixed with a button, {manual} need a manual change.`
			else
				text ..= " None can be fixed automatically: click one to open the code and read what to change."
			end
			if visibleTotal > shown then
				text ..= ` Showing the first {shown}.`
			end
			if not editable then
				text ..= " The game is running: fixes are off until you stop it (changes now would be lost)."
			end
			statusLabel.Text = text
			if visibleTotal == 0 then
				makeEmptyRow("All findings are hidden by the filters above. Click a filter to show it again.")
			end
		end

		fixAllButton.Text = if confirming then `Yes, fix {fixable}` else `Fix {fixable} safe`
		fixAllButton.Visible = fixable > 0 and editable
		undoButton.Visible = #undoSteps > 0 and editable
		for _, button in { scanButton, fixAllButton, undoButton } do
			setEnabled(button, not busy)
		end
	end

	for order, severity in SEVERITIES do
		local filterButton = create("TextButton", {
			Name = severity.id,
			Text = severity.label,
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 13,
			TextColor3 = WHITE,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			BackgroundColor3 = severity.color,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = filterRow,
		}, { corner(12), padding(10, 0) })
		filterButtons[severity.id] = filterButton
		filterButton.MouseButton1Click:Connect(function()
			enabledSeverity[severity.id] = not enabledSeverity[severity.id]
			render()
		end)
	end

	scanButton.MouseButton1Click:Connect(function()
		task.spawn(scan)
	end)
	-- the first click asks, the second (after a second, within a few) fixes
	fixAllButton.MouseButton1Click:Connect(function()
		if busy then
			return
		end
		local now = os.clock()
		if now < confirmUntil then
			if now - confirmFrom >= CONFIRM_MIN_SECONDS then
				task.spawn(fixAll)
			end
			return
		end
		confirmFrom = now
		confirmUntil = now + CONFIRM_SECONDS
		render()
		task.delay(CONFIRM_SECONDS, function()
			if not destroyed and not busy and confirmUntil ~= 0 and os.clock() >= confirmUntil then
				confirmUntil = 0
				render()
			end
		end)
	end)
	undoButton.MouseButton1Click:Connect(function()
		task.spawn(undoFixes)
	end)

	pcall(function()
		table.insert(
			connections,
			settings().Studio.ThemeChanged:Connect(function()
				applyTheme()
				render()
			end)
		)
	end)

	applyTheme()
	render()

	return {
		scan = scan,
		fixAll = fixAll,
		undoFixes = undoFixes,
		fixOneAt = fixOneAt,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			for _, connection in connections do
				connection:Disconnect()
			end
			root:Destroy()
		end,
	}
end

return App
