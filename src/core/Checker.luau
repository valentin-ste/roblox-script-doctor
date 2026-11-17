--!strict
--[[
	Checker core: takes the text of one script, returns a list of findings.

	Pure Luau, no Roblox APIs — the Studio plugin is a thin shell around this
	module, and tests run it under lune.

	Finding = {
		rule: string,        -- rule id, a key of Checker.RULES
		severity: string,    -- "security" | "bug" | "deprecated" | "advice"
		title: string,       -- short English name of the problem
		line: number, col: number,
		message: string,     -- English, shown to the user
		fix: { from: number, to: number, text: string }?,  -- byte range to replace
	}
]]

local Lexer = require("./Lexer")

local Checker = {}

export type Fix = { from: number, to: number, text: string }
export type Finding = {
	rule: string,
	severity: string,
	title: string,
	line: number,
	col: number,
	message: string,
	fix: Fix?,
}
export type Rule = {
	severity: string, -- "security" | "bug" | "deprecated" | "advice"
	title: string,
	message: string, -- string.format pattern
}
export type Options = {
	-- "server" | "client" | "module"; nil when unknown (then guessed from the code)
	scriptKind: string?,
}

Checker.RULES = {
	["remote-client-value"] = {
		severity = "security",
		title = "The client decides a game value",
		message = "The server writes '%s', a value sent by the client, straight into game data. An exploiter can send any number. Compute the amount on the server instead.",
	},
	["remote-unvalidated-args"] = {
		severity = "security",
		title = "Client data used without a check",
		message = "'%s' comes from the client and is used without any check. Validate its type and range on the server before using it.",
	},
	["datastore-no-pcall"] = {
		severity = "bug",
		title = "DataStore call without pcall",
		message = "%s can fail (DataStore outage or limits) and will stop this script with an error. Wrap the call in pcall and handle the failure.",
	},
	["datastore-no-bindtoclose"] = {
		severity = "bug",
		title = "No save when the server shuts down",
		message = "Data is saved on PlayerRemoving, but nothing saves it when the server shuts down. Add game:BindToClose and save all players there (ignore if another script already does).",
	},
	["bindtoclose-fixed-wait"] = {
		severity = "bug",
		title = "Shutdown save can be cut off",
		message = "BindToClose waits a fixed time instead of waiting for the saves to finish. If DataStore is slow, the server closes first and data is lost.",
	},
	["datastore-save-after-failed-load"] = {
		severity = "bug",
		title = "A failed load can wipe saved data",
		message = "If this load fails, the script still saves later and overwrites the player's real data with defaults. Remember whether the load succeeded (for example in a table) and skip saving when it did not.",
	},
	["findfirstchild-unchecked"] = {
		severity = "bug",
		title = "FindFirstChild result used without a check",
		message = "%s returns nil when the object is missing, and this line then stops with an error. Check the result first, or use WaitForChild if the object appears later.",
	},
	["playeradded-no-existing-players"] = {
		severity = "bug",
		title = "Players already in the game are skipped",
		message = "PlayerAdded is connected, but players who joined before this script started are skipped. Also loop over Players:GetPlayers() once.",
	},
	["require-by-id"] = {
		severity = "security",
		title = "Runs code from an external asset",
		message = "require(%s) downloads and runs code from an asset you cannot see here. This is how backdoors get into games. Keep it only if you trust the source.",
	},
	["loadstring"] = {
		severity = "security",
		title = "Runs text as code",
		message = "loadstring runs text as code. Common in backdoors; make sure only trusted, server-side input reaches it.",
	},
	["environment-access"] = {
		severity = "security",
		title = "getfenv / setfenv",
		message = "%s is deprecated, disables Luau optimizations and is often used to hide malicious code.",
	},
	["insert-asset"] = {
		severity = "security",
		title = "Loads an external asset",
		message = "InsertService:LoadAsset brings in an external asset at runtime. Check that the asset id is one you trust.",
	},
	["obfuscated-code"] = {
		severity = "security",
		title = "Hidden (obfuscated) code",
		message = "This looks like hidden text (%s). Obfuscated code in a free model is a common sign of a backdoor.",
	},
	["deprecated-global"] = {
		severity = "deprecated",
		title = "Deprecated wait / spawn / delay",
		message = "%s() is deprecated. Use %s() instead.",
	},
	["deprecated-connect"] = {
		severity = "deprecated",
		title = "Deprecated :connect / :disconnect",
		message = ":%s() is deprecated. Use :%s().",
	},
	["deprecated-method"] = {
		severity = "deprecated",
		title = "Deprecated method name",
		message = ":%s() is deprecated. Use :%s().",
	},
	["deprecated-remove"] = {
		severity = "deprecated",
		title = "Deprecated :Remove()",
		message = ":%s() is deprecated and does not free memory. Use :Destroy().",
	},
	["instance-new-parent"] = {
		severity = "advice",
		title = "Parent passed to Instance.new",
		message = "Instance.new(className, parent) is slow: set properties first, then set Parent last.",
	},
	["deprecated-loadanimation"] = {
		severity = "deprecated",
		title = "Deprecated Humanoid:LoadAnimation",
		message = "Humanoid:LoadAnimation is deprecated. Load the animation through the Animator inside the Humanoid.",
	},
	["deprecated-raycast"] = {
		severity = "deprecated",
		title = "Deprecated raycast method",
		message = ":%s is deprecated. Use workspace:Raycast with RaycastParams.",
	},
	["deprecated-body-mover"] = {
		severity = "deprecated",
		title = "Deprecated body mover",
		message = "%s is deprecated. Use %s.",
	},
} :: { [string]: Rule }

local DEPRECATED_GLOBALS = { wait = "task.wait", spawn = "task.spawn", delay = "task.delay" }

local SIGNAL_METHODS = { connect = "Connect", disconnect = "Disconnect" }

-- Old camelCase aliases of Instance methods.
local METHOD_CASE = {
	findFirstChild = "FindFirstChild",
	children = "GetChildren",
	getChildren = "GetChildren",
	clone = "Clone",
	destroy = "Destroy",
	isA = "IsA",
	isDescendantOf = "IsDescendantOf",
	getService = "GetService",
	service = "GetService",
	getPlayers = "GetPlayers",
	playerFromCharacter = "GetPlayerFromCharacter",
	getPlayerFromCharacter = "GetPlayerFromCharacter",
	moveTo = "MoveTo",
	takeDamage = "TakeDamage",
	loadAnimation = "LoadAnimation",
	breakJoints = "BreakJoints",
	makeJoints = "MakeJoints",
	getMass = "GetMass",
}

local BODY_MOVERS = {
	BodyVelocity = "LinearVelocity",
	BodyGyro = "AlignOrientation",
	BodyPosition = "AlignPosition",
	BodyAngularVelocity = "AngularVelocity",
	BodyForce = "VectorForce",
	BodyThrust = "VectorForce",
	RocketPropulsion = "LinearVelocity and AlignOrientation",
}

local DATASTORE_METHODS = {
	GetAsync = true,
	SetAsync = true,
	UpdateAsync = true,
	IncrementAsync = true,
	RemoveAsync = true,
	GetSortedAsync = true,
}

-- Methods that return nil when nothing is found.
local FIND_METHODS = {
	FindFirstChild = true,
	FindFirstChildOfClass = true,
	FindFirstChildWhichIsA = true,
	FindFirstAncestor = true,
	FindFirstAncestorOfClass = true,
	FindFirstAncestorWhichIsA = true,
}

local DATASTORE_GETTERS = { "GetDataStore", "GetOrderedDataStore", "GetGlobalDataStore" }

-- A function passed to a call whose name contains one of these counts as error-protected.
local PROTECTING_CALLEES = { "pcall", "retry", "try", "promise", "safe", "attempt", "protect" }

-- Tokens after which an `if` starts an if-expression, not an if-statement.
local EXPRESSION_LEADERS = {}
for _, text in
	{
		"=",
		"(",
		",",
		"{",
		"[",
		"return",
		"and",
		"or",
		"not",
		"+",
		"-",
		"*",
		"/",
		"//",
		"%",
		"^",
		"..",
		"==",
		"~=",
		"<",
		">",
		"<=",
		">=",
		"+=",
		"-=",
		"*=",
		"/=",
		"//=",
		"%=",
		"^=",
		"..=",
		"in",
		"#",
	}
do
	EXPRESSION_LEADERS[text] = true
end

-- How far the rules look around a token. All counts are tokens, not lines.
-- An earlier `x:FindFirstChild("A")` (not chained) this close before a chained one is its check:
-- covers an `if`/`while` header and a few statements of its body.
local FIND_GUARD_LOOKBACK = 80
-- `for _, p in Players:GetPlayers()`: `in` is at most this far before GetPlayers
-- (`in ipairs(game:GetService("Players"):GetPlayers())` is 11 tokens).
local LOOP_HEADER_LOOKBACK = 12
-- A client value counts as checked when it sits inside a validating call that opens this
-- close before it: `math.clamp(tonumber(amount) or 0, 1, 10)`.
local VALIDATOR_LOOKBACK = 16
-- `leaderstats.Coins.Value += amount * 2` on one line: the "=" is this close before the value.
local VALUE_WRITE_LOOKBACK = 10
-- A string literal this long with this many numeric escapes ("\104\116...") is hidden text.
local ENCODED_STRING_MIN_LENGTH = 36
local ENCODED_STRING_MIN_ESCAPES = 12

-- Calls that only log a value: passing the load result to them does not remember it.
local QUIET_CALLEES = { warn = true, print = true, tostring = true, error = true, assert = true, pcall = true }

local COMPARISONS = { ["=="] = true, ["~="] = true, ["<"] = true, [">"] = true, ["<="] = true, [">="] = true }

-- Calls that count as "the value was checked or cleaned up".
local VALIDATORS = {
	typeof = true,
	type = true,
	tonumber = true,
	IsA = true,
	FindFirstChild = true,
	FindFirstChildOfClass = true,
	WaitForChild = true,
	find = true,
	clamp = true,
	min = true,
	max = true,
	floor = true,
	abs = true,
	assert = true,
}

-- Places where a value chosen by the client does real damage: health, stats, cloning,
-- moving or removing things, saving. A client value that only reaches harmless code
-- (a UI flag, a sound toggle) is not reported.
local SENSITIVE_SINKS = {
	TakeDamage = true,
	Health = true,
	MaxHealth = true,
	Value = true,
	Kick = true,
	Clone = true,
	Destroy = true,
	Parent = true,
	CFrame = true,
	Position = true,
	PivotTo = true,
	MoveTo = true,
	WalkSpeed = true,
	JumpPower = true,
	JumpHeight = true,
	AssemblyLinearVelocity = true,
	Velocity = true,
	LoadCharacter = true,
	Teleport = true,
	TeleportAsync = true,
	SetAsync = true,
	UpdateAsync = true,
	IncrementAsync = true,
	RemoveAsync = true,
	new = true,
	FireAllClients = true,
}

type Block = {
	kind: string, -- "function" | "do" | "if" | "repeat" | "exprif"
	start: number,
	finish: number?,
	parent: Block?,
	protected: boolean?,
	loop: string?, -- "while" | "for" for do-blocks of loops
	remote: boolean?, -- the function is a RemoteEvent / RemoteFunction handler
	name: string?,
}

-- Builds the block structure. Returns blockAt[i] = innermost block that token i sits in.
local function buildBlocks(tokens: { Lexer.Token }): ({ Block? }, { Block })
	local blockAt: { Block? } = {}
	local allBlocks: { Block } = {}
	local top: Block? = nil
	local pendingThen: { string } = {}
	local pendingLoop: string? = nil
	local expressionElse: { [number]: boolean } = {}

	local function push(block: Block)
		block.parent = top
		top = block
		table.insert(allBlocks, block)
	end

	local function pop(index: number)
		if top then
			top.finish = index
			top = top.parent
		end
	end

	for index, token in tokens do
		if token.kind == "keyword" then
			local text = token.text
			local previous = tokens[index - 1]
			if text == "if" then
				local isExpression = false
				if previous then
					if previous.kind == "keyword" and (previous.text == "then" or previous.text == "else") then
						isExpression = (top ~= nil and top.kind == "exprif") or expressionElse[index - 1] == true
					elseif EXPRESSION_LEADERS[previous.text] and previous.kind ~= "string" then
						isExpression = true
					end
				end
				if isExpression then
					push({ kind = "exprif", start = index })
					table.insert(pendingThen, "expression")
				else
					table.insert(pendingThen, "statement")
				end
			elseif text == "elseif" then
				table.insert(pendingThen, "elseif")
			elseif text == "then" then
				local owner = table.remove(pendingThen)
				if owner == "statement" then
					push({ kind = "if", start = index })
				end
			elseif text == "else" then
				if top and top.kind == "exprif" then
					pop(index)
					expressionElse[index] = true
				end
			elseif text == "while" or text == "for" then
				pendingLoop = text
			elseif text == "do" then
				push({ kind = "do", start = index, loop = pendingLoop })
				pendingLoop = nil
			elseif text == "repeat" then
				push({ kind = "repeat", start = index })
			elseif text == "function" then
				local block: Block = { kind = "function", start = index }
				local nextToken = tokens[index + 1]
				if nextToken and nextToken.kind == "name" then
					-- `function a.b:c()` -> the last name before "("
					local cursor = index + 1
					local name = nextToken.text
					while
						tokens[cursor + 1]
						and (tokens[cursor + 1].text == "." or tokens[cursor + 1].text == ":")
						and tokens[cursor + 2]
					do
						cursor += 2
						name = tokens[cursor].text
					end
					block.name = name
				end
				push(block)
			elseif text == "end" then
				while top and top.kind == "exprif" do
					pop(index)
				end
				pop(index)
			elseif text == "until" then
				while top and top.kind ~= "repeat" do
					pop(index)
				end
				pop(index)
			end
		end
		blockAt[index] = top
	end

	return blockAt, allBlocks
end

local function lowerContains(text: string, needles: { string }): boolean
	local lowered = string.lower(text)
	for _, needle in needles do
		if string.find(lowered, needle, 1, true) then
			return true
		end
	end
	return false
end

function Checker.check(source: string, options: Options?): { Finding }
	local tokens = Lexer.tokenize(source)
	local count = #tokens
	local blockAt, allBlocks = buildBlocks(tokens)
	local findings: { Finding } = {}
	local scriptKind = options and options.scriptKind

	---------------------------------------------------------------------------
	-- Token helpers
	---------------------------------------------------------------------------

	local function text(index: number): string
		local token = tokens[index]
		return if token then token.text else ""
	end

	local function kind(index: number): string
		local token = tokens[index]
		return if token then token.kind else ""
	end

	local function isName(index: number, value: string?): boolean
		local token = tokens[index]
		return token ~= nil and token.kind == "name" and (value == nil or token.text == value)
	end

	local function isSymbol(index: number, value: string): boolean
		local token = tokens[index]
		return token ~= nil and token.kind == "symbol" and token.text == value
	end

	local function isKeyword(index: number, value: string): boolean
		local token = tokens[index]
		return token ~= nil and token.kind == "keyword" and token.text == value
	end

	local function add(rule: string, index: number, fix: Fix?, ...: any)
		local token = tokens[index]
		local info = Checker.RULES[rule]
		table.insert(findings, {
			rule = rule,
			severity = info.severity,
			title = info.title,
			line = token.line,
			col = token.col,
			message = string.format(info.message, ...),
			fix = fix,
		})
	end

	local function replaceToken(index: number, newText: string): Fix
		return { from = tokens[index].from, to = tokens[index].to, text = newText }
	end

	-- Index of the ")" matching the "(" at `open`.
	local function matchingParen(open: number): number
		local depth = 0
		for index = open, count do
			if isSymbol(index, "(") then
				depth += 1
			elseif isSymbol(index, ")") then
				depth -= 1
				if depth == 0 then
					return index
				end
			end
		end
		return count
	end

	---------------------------------------------------------------------------
	-- Facts about the whole file
	---------------------------------------------------------------------------

	local names: { [string]: boolean } = {}
	local localNames: { [string]: boolean } = {}
	local protectedNames: { [string]: boolean } = {}
	local functionsByName: { [string]: Block } = {}
	-- methods and fields this file defines itself (`function Signal:connect()`, `obj.destroy = function`):
	-- a lowercase call with such a name is the author's own API, not a deprecated Roblox alias
	local definedMembers: { [string]: boolean } = {}
	-- tables written out in this file (`local PRICES = { ... }`): looking a client value up in
	-- one of them is a whitelist check
	local localTables: { [string]: boolean } = {}

	for index, token in tokens do
		if token.kind == "name" then
			names[token.text] = true
			if
				(isSymbol(index - 1, ".") or isSymbol(index - 1, ":"))
				and isSymbol(index + 1, "=")
				and isKeyword(index + 2, "function")
			then
				definedMembers[token.text] = true
			end
			-- pcall(saveAll) / xpcall(saveAll, handler): the named function runs protected
			if (token.text == "pcall" or token.text == "xpcall") and isSymbol(index + 1, "(") and isName(index + 2) then
				if isSymbol(index + 3, ")") or isSymbol(index + 3, ",") then
					protectedNames[text(index + 2)] = true
				end
			end
		elseif token.kind == "keyword" and token.text == "local" then
			if isName(index + 1) and isSymbol(index + 2, "=") and isSymbol(index + 3, "{") then
				localTables[text(index + 1)] = true
			end
			if isKeyword(index + 1, "function") and isName(index + 2) then
				localNames[text(index + 2)] = true
			else
				local cursor = index + 1
				while isName(cursor) do
					localNames[text(cursor)] = true
					if isSymbol(cursor + 1, ",") then
						cursor += 2
					else
						break
					end
				end
			end
		elseif
			token.kind == "keyword"
			and token.text == "function"
			and isName(index + 1)
			and not isSymbol(index + 2, ".")
			and not isSymbol(index + 2, ":")
		then
			localNames[text(index + 1)] = true
		end
	end

	for _, block in allBlocks do
		if block.kind == "function" then
			if block.name then
				functionsByName[block.name] = block
				if isSymbol(block.start + 2, ".") or isSymbol(block.start + 2, ":") then
					definedMembers[block.name] = true
				end
			end
			-- anonymous function passed to pcall(...) or a retry/promise helper
			local before = block.start - 1
			if isSymbol(before, "(") or isSymbol(before, ",") then
				local depth, cursor = 0, before
				while cursor >= 1 do
					if isSymbol(cursor, ")") then
						depth += 1
					elseif isSymbol(cursor, "(") then
						if depth == 0 then
							break
						end
						depth -= 1
					end
					cursor -= 1
				end
				if cursor >= 2 and isName(cursor - 1) and lowerContains(text(cursor - 1), PROTECTING_CALLEES) then
					block.protected = true
				end
			end
		end
	end
	for name in protectedNames do
		if functionsByName[name] then
			functionsByName[name].protected = true
		end
	end

	local function insideKind(index: number, wanted: (Block) -> boolean): boolean
		local block = blockAt[index]
		while block do
			if wanted(block) then
				return true
			end
			block = block.parent
		end
		return false
	end

	local function insideProtected(index: number): boolean
		return insideKind(index, function(block)
			return block.protected == true
		end)
	end

	local function enclosingFunction(index: number): Block?
		local block = blockAt[index]
		while block do
			if block.kind == "function" then
				return block
			end
			block = block.parent
		end
		return nil
	end

	-- Parameter names of the function block (annotations skipped).
	local function parameters(block: Block): { string }
		local result = {}
		local open = block.start + 1
		while open <= count and not isSymbol(open, "(") do
			open += 1
		end
		local close = matchingParen(open)
		local depth = 0
		for index = open, close do
			if isSymbol(index, "(") or isSymbol(index, "{") or isSymbol(index, "<") then
				depth += 1
			elseif isSymbol(index, ")") or isSymbol(index, "}") or isSymbol(index, ">") then
				depth -= 1
			elseif depth == 1 and isName(index) and (isSymbol(index - 1, "(") or isSymbol(index - 1, ",")) then
				table.insert(result, text(index))
			end
		end
		return result
	end

	-- The function block used as a callback at `index`: `function` literal or a named function.
	local function callbackAt(index: number): Block?
		if isKeyword(index, "function") then
			for _, block in allBlocks do
				if block.kind == "function" and block.start == index then
					return block
				end
			end
		elseif isName(index) and (isSymbol(index + 1, ")") or isSymbol(index + 1, ",")) then
			return functionsByName[text(index)]
		end
		return nil
	end

	local usesDataStore = false
	for _, getter in DATASTORE_GETTERS do
		if names[getter] then
			usesDataStore = true
		end
	end

	local isClient = scriptKind == "client" or (scriptKind == nil and names.LocalPlayer == true)

	-- What the token rules learn on the way, for the whole-file rules at the end.
	local playerAddedConnect: number? = nil
	local playerRemoving: number? = nil
	local handlesExistingPlayers = false
	local savesData = false
	local loadCalls: { number } = {}
	local saveCalls: { number } = {}

	---------------------------------------------------------------------------
	-- Rules that look at one name token. Each one returns early only for itself.
	---------------------------------------------------------------------------

	-- wait() / spawn() / delay(), loadstring / getfenv / setfenv, require(<number>)
	local function checkGlobalCalls(index: number, name: string)
		if not isSymbol(index + 1, "(") or isSymbol(index - 1, ".") or isSymbol(index - 1, ":") or localNames[name] then
			return
		end
		if DEPRECATED_GLOBALS[name] and not isKeyword(index - 1, "function") then
			add(
				"deprecated-global",
				index,
				replaceToken(index, DEPRECATED_GLOBALS[name]),
				name,
				DEPRECATED_GLOBALS[name]
			)
		end
		if name == "loadstring" then
			add("loadstring", index)
		elseif name == "getfenv" or name == "setfenv" then
			add("environment-access", index, nil, name)
		elseif name == "require" and kind(index + 2) == "number" and isSymbol(index + 3, ")") then
			add("require-by-id", index, nil, text(index + 2))
		end
	end

	-- part:FindFirstChild("X"):Destroy() / part:FindFirstChild("X").Value
	local function checkFindFirstChild(index: number, name: string)
		local close = matchingParen(index + 1)
		if not ((isSymbol(close + 1, ".") or isSymbol(close + 1, ":")) and isName(close + 2)) then
			return
		end
		-- `while x:FindFirstChild("A") do x:FindFirstChild("A"):Destroy() end`:
		-- the same lookup a little earlier, not chained, is the check
		local arguments = {}
		for cursor = index + 2, close - 1 do
			table.insert(arguments, text(cursor))
		end
		local wanted = table.concat(arguments, " ")
		for back = index - 1, math.max(1, index - FIND_GUARD_LOOKBACK), -1 do
			if isName(back, name) and isSymbol(back + 1, "(") then
				local backClose = matchingParen(back + 1)
				local backArguments = {}
				for cursor = back + 2, backClose - 1 do
					table.insert(backArguments, text(cursor))
				end
				local chained = isSymbol(backClose + 1, ".") or isSymbol(backClose + 1, ":")
				if not chained and table.concat(backArguments, " ") == wanted then
					return
				end
			end
		end
		add("findfirstchild-unchecked", index, nil, name)
	end

	-- obj:method(...) with a deprecated or risky Roblox method name
	local function checkMethodCall(index: number, name: string)
		if SIGNAL_METHODS[name] then
			add("deprecated-connect", index, replaceToken(index, SIGNAL_METHODS[name]), name, SIGNAL_METHODS[name])
		elseif METHOD_CASE[name] then
			add("deprecated-method", index, replaceToken(index, METHOD_CASE[name]), name, METHOD_CASE[name])
		elseif (name == "Remove" or name == "remove") and isSymbol(index + 2, ")") then
			add("deprecated-remove", index, replaceToken(index, "Destroy"), name)
		elseif string.sub(name, 1, 13) == "FindPartOnRay" then
			add("deprecated-raycast", index, nil, name)
		elseif name == "LoadAnimation" and isName(index - 2) and lowerContains(text(index - 2), { "hum" }) then
			add("deprecated-loadanimation", index)
		elseif name == "LoadAsset" and names.InsertService then
			add("insert-asset", index)
		elseif DATASTORE_METHODS[name] and usesDataStore then
			local receiver = text(index - 2)
			if lowerContains(receiver, { "http" }) then
				return
			end
			if name == "SetAsync" or name == "UpdateAsync" then
				savesData = true
				table.insert(saveCalls, index)
			elseif name == "GetAsync" then
				table.insert(loadCalls, index)
			end
			if not insideProtected(index) then
				add("datastore-no-pcall", index, nil, receiver .. ":" .. name .. "()")
			end
		end
	end

	-- Instance.new("Class", parent) and deprecated body movers
	local function checkInstanceNew(index: number)
		if not (isSymbol(index + 1, ".") and isName(index + 2, "new") and isSymbol(index + 3, "(")) then
			return
		end
		if kind(index + 4) ~= "string" then
			return
		end
		local className = text(index + 4)
		if isSymbol(index + 5, ",") then
			add("instance-new-parent", index)
		end
		if BODY_MOVERS[className] then
			add("deprecated-body-mover", index, nil, className, BODY_MOVERS[className])
		end
	end

	-- string.reverse / string.char(1, 2, 3, ...)
	local function checkStringLibrary(index: number)
		if not isSymbol(index + 1, ".") then
			return
		end
		if isName(index + 2, "reverse") then
			add("obfuscated-code", index, nil, "string.reverse")
		elseif
			isName(index + 2, "char")
			and kind(index + 4) == "number"
			and isSymbol(index + 5, ",")
			and kind(index + 6) == "number"
			and isSymbol(index + 7, ",")
		then
			add("obfuscated-code", index, nil, "text built from character codes")
		end
	end

	-- Players.PlayerAdded:Connect / PlayerRemoving / a loop over Players:GetPlayers()
	local function trackPlayers(index: number, name: string)
		if
			name == "PlayerAdded"
			and isSymbol(index + 1, ":")
			and (isName(index + 2, "Connect") or isName(index + 2, "connect"))
		then
			playerAddedConnect = playerAddedConnect or index
		end
		if name == "PlayerRemoving" then
			playerRemoving = playerRemoving or index
		end
		if name ~= "GetPlayers" or not isSymbol(index + 1, "(") then
			return
		end
		-- counts as "handles players already in the game" when it feeds a for-loop
		-- that is not inside a while-loop or a BindToClose callback
		local inLoopHeader = false
		for back = index - 1, math.max(1, index - LOOP_HEADER_LOOKBACK), -1 do
			if isKeyword(back, "in") then
				inLoopHeader = true
				break
			elseif isKeyword(back, "do") or isKeyword(back, "then") or isKeyword(back, "end") then
				break
			end
		end
		local inRepeating = insideKind(index, function(block)
			return block.loop == "while" or block.kind == "repeat"
		end)
		local inShutdown = insideKind(index, function(block)
			return block.kind == "function" and isName(block.start - 2, "BindToClose")
		end)
		if inLoopHeader and not inRepeating and not inShutdown then
			handlesExistingPlayers = true
		end
	end

	-- game:BindToClose(function() ... task.wait(3) end)
	local function checkBindToClose(index: number)
		local callback = callbackAt(index + 2)
		if not (callback and callback.finish) then
			return
		end
		local finish = callback.finish :: number
		local spawns, fixedWait = false, nil
		for inner = callback.start + 1, finish - 1 do
			if isName(inner) then
				local innerName = text(inner)
				if innerName == "spawn" or innerName == "defer" or innerName == "wrap" then
					spawns = true
				elseif
					innerName == "wait"
					and isSymbol(inner + 1, "(")
					and kind(inner + 2) == "number"
					and isSymbol(inner + 3, ")")
				then
					if
						enclosingFunction(inner) == callback
						and not insideKind(inner, function(block)
							return block.loop ~= nil and block.start > callback.start
						end)
					then
						fixedWait = inner
					end
				end
			end
		end
		local hasSaveCall = false
		for inner = callback.start + 1, finish - 1 do
			if isName(inner) then
				local innerName = text(inner)
				local isPlainCall = isSymbol(inner + 1, "(")
					and not isSymbol(inner - 1, ".")
					and innerName ~= "wait"
					and innerName ~= "ipairs"
					and innerName ~= "pairs"
				if isPlainCall or DATASTORE_METHODS[innerName] then
					hasSaveCall = true
				end
			end
		end
		if fixedWait and (spawns or not hasSaveCall) then
			add("bindtoclose-fixed-wait", fixedWait)
		end
	end

	-- RemoteEvent.OnServerEvent:Connect(function(player, ...)) / .OnServerInvoke = function
	local function checkRemoteHandler(index: number, name: string)
		local callback: Block? = nil
		if name == "OnServerEvent" and isSymbol(index + 1, ":") and isSymbol(index + 3, "(") then
			callback = callbackAt(index + 4)
		elseif name == "OnServerInvoke" and isSymbol(index + 1, "=") then
			callback = callbackAt(index + 2)
			if not callback and isName(index + 2) then
				callback = functionsByName[text(index + 2)]
			end
		end
		if not (callback and callback.finish) then
			return
		end
		local finish = callback.finish :: number
		callback.remote = true
		local params = parameters(callback)
		local open = callback.start + 1
		while open <= count and not isSymbol(open, "(") do
			open += 1
		end
		local bodyStart = matchingParen(open) + 1
		-- the first parameter is the player, filled in by Roblox
		for position = 2, #params do
			local param = params[position]
			local checked, valueWrite, sensitiveUse = false, nil, false
			local inCondition = false
			for inner = bodyStart, finish - 1 do
				if
					isKeyword(inner, "if")
					or isKeyword(inner, "elseif")
					or isKeyword(inner, "while")
					or isKeyword(inner, "until")
				then
					inCondition = true
				elseif isKeyword(inner, "then") or isKeyword(inner, "do") then
					inCondition = false
				end
				if not isName(inner, param) or isSymbol(inner - 1, ".") or isSymbol(inner - 1, ":") then
					continue
				end
				-- condition, comparison, table key or a validating call
				local isCompared = COMPARISONS[text(inner - 1)] or COMPARISONS[text(inner + 1)]
				local isTableKey = isSymbol(inner - 1, "[")
					and isSymbol(inner + 1, "]")
					and localTables[text(inner - 2)] == true
				if inCondition or isCompared or isTableKey then
					checked = true
				else
					local depth = 0
					for back = inner - 1, math.max(bodyStart, inner - VALIDATOR_LOOKBACK), -1 do
						if isSymbol(back, ")") then
							depth += 1
						elseif isSymbol(back, "(") then
							if depth == 0 then
								if isName(back - 1) and VALIDATORS[text(back - 1)] then
									checked = true
								end
								break
							end
							depth -= 1
						end
					end
				end
				-- used as an object (`target.Humanoid`, `target:Destroy()`) or on a line that
				-- touches something sensitive
				if isSymbol(inner + 1, ".") or isSymbol(inner + 1, ":") then
					sensitiveUse = true
				else
					local line = tokens[inner].line
					local cursor = inner - 1
					while cursor >= bodyStart and tokens[cursor].line == line do
						cursor -= 1
					end
					cursor += 1
					while cursor < finish and tokens[cursor].line == line do
						if isName(cursor) and SENSITIVE_SINKS[text(cursor)] then
							sensitiveUse = true
						end
						cursor += 1
					end
				end
				-- `something.Value = / += / -= ... param` on one line
				for back = inner - 1, math.max(bodyStart, inner - VALUE_WRITE_LOOKBACK), -1 do
					if tokens[back].line ~= tokens[inner].line then
						break
					end
					if
						(isSymbol(back, "=") or isSymbol(back, "+=") or isSymbol(back, "-="))
						and isName(back - 1, "Value")
					then
						valueWrite = valueWrite or inner
					end
				end
			end
			if not checked then
				if valueWrite then
					add("remote-client-value", valueWrite, nil, param)
				elseif sensitiveUse then
					add("remote-unvalidated-args", index, nil, param)
				end
			end
		end
	end

	-- "\104\116\116\112..." : a long run of numeric escapes
	local function checkEncodedString(index: number)
		local value = text(index)
		if #value < ENCODED_STRING_MIN_LENGTH then
			return
		end
		local escapes = select(2, string.gsub(value, "\\%d%d?%d?", ""))
		local hexEscapes = select(2, string.gsub(value, "\\x%x%x", ""))
		if escapes >= ENCODED_STRING_MIN_ESCAPES or hexEscapes >= ENCODED_STRING_MIN_ESCAPES then
			add("obfuscated-code", index, nil, "a string written as character codes")
		end
	end

	for index, token in tokens do
		if token.kind == "name" then
			local name = token.text
			local isMethodCall = isSymbol(index - 1, ":") and isSymbol(index + 1, "(")
			local isPlain = not isSymbol(index - 1, ".") and not isSymbol(index - 1, ":")

			checkGlobalCalls(index, name)
			-- the file's own method with a Roblox-like name (`function Signal:connect()`) is
			-- its own API: the method rules leave it alone, all other rules still run
			if isMethodCall and not definedMembers[name] then
				if FIND_METHODS[name] then
					checkFindFirstChild(index, name)
				end
				checkMethodCall(index, name)
			end
			if name == "Instance" then
				checkInstanceNew(index)
			end
			if name == "string" and isPlain then
				checkStringLibrary(index)
			end
			trackPlayers(index, name)
			if name == "BindToClose" and isSymbol(index + 1, "(") then
				checkBindToClose(index)
			end
			if name == "OnServerEvent" or name == "OnServerInvoke" then
				checkRemoteHandler(index, name)
			end
		elseif token.kind == "string" then
			checkEncodedString(index)
		end
	end

	---------------------------------------------------------------------------
	-- Whole-file rules
	---------------------------------------------------------------------------

	-- Load in one function, save in another: is a failed load remembered anywhere?
	-- The function around a call, skipping the anonymous function handed to pcall.
	local function outerFunction(index: number): Block?
		local block = enclosingFunction(index)
		while block and block.protected and not block.name do
			block = enclosingFunction(block.start - 1)
		end
		return block
	end

	-- The string literals in the key argument of store:GetAsync(key) / store:SetAsync(key, ...),
	-- joined: "Inv_" for `"Inv_" .. player.UserId`, "" when the key has no literal part.
	local function keyLiterals(methodIndex: number): string
		local parts = {}
		local depth = 0
		for cursor = methodIndex + 1, count do
			if isSymbol(cursor, "(") or isSymbol(cursor, "{") or isSymbol(cursor, "[") then
				depth += 1
			elseif isSymbol(cursor, ")") or isSymbol(cursor, "}") or isSymbol(cursor, "]") then
				depth -= 1
				if depth == 0 then
					break
				end
			elseif isSymbol(cursor, ",") and depth == 1 then
				break
			elseif kind(cursor) == "string" then
				table.insert(parts, text(cursor))
			end
		end
		return table.concat(parts, "|")
	end

	-- Is the success flag of this load (`local ok, data = pcall(function`) used anywhere
	-- before the end of `loadFunction`, so a failed load can stop the later save?
	local function failedLoadRemembered(wrapper: Block, loadFunction: Block?): boolean
		-- `local ok, data = pcall(function` -> "ok"; nil when the result is thrown away
		local successName: string? = nil
		local pcallIndex = wrapper.start - 2
		if isSymbol(pcallIndex - 1, "=") then
			local cursor = pcallIndex - 2
			while isName(cursor) and isSymbol(cursor - 1, ",") do
				cursor -= 2
			end
			if isName(cursor) then
				successName = text(cursor)
			end
		end
		if not successName then
			return false
		end
		local wrapperEnd = wrapper.finish :: number
		local scopeEnd = if loadFunction and loadFunction.finish then loadFunction.finish else count

		for cursor = wrapperEnd + 1, scopeEnd do
			if not isName(cursor, successName) or isSymbol(cursor - 1, ".") or isSymbol(cursor - 1, ":") then
				continue
			end
			local nextToken = tokens[cursor + 1]
			local endsStatement = nextToken == nil
				or nextToken.line > tokens[cursor].line
				or nextToken.text == ")"
				or nextToken.text == ","
				or (nextToken.kind == "keyword" and nextToken.text ~= "and" and nextToken.text ~= "or")
			if (isSymbol(cursor - 1, "=") and endsStatement) or isKeyword(cursor - 1, "return") then
				-- `loaded[player] = ok` or `return ok`
				return true
			elseif
				(isSymbol(cursor - 1, "(") or isSymbol(cursor - 1, ","))
				and (isSymbol(cursor + 1, ")") or isSymbol(cursor + 1, ","))
			then
				-- player:SetAttribute("Loaded", ok) — any call except logging
				local depth, back = 0, cursor - 1
				while back >= 1 do
					if isSymbol(back, ")") then
						depth += 1
					elseif isSymbol(back, "(") then
						if depth == 0 then
							break
						end
						depth -= 1
					end
					back -= 1
				end
				if not (isName(back - 1) and QUIET_CALLEES[text(back - 1)]) then
					return true
				end
			end
		end

		-- `if ok then loaded[id] = true else loaded[id] = false end`, a kick on failure,
		-- or leaving before the data holders are created
		for cursor = wrapperEnd + 1, scopeEnd do
			if not (isKeyword(cursor, "if") or isKeyword(cursor, "elseif")) then
				continue
			end
			local thenIndex = cursor + 1
			local mentions = false
			while thenIndex <= scopeEnd and not isKeyword(thenIndex, "then") do
				if isName(thenIndex, successName) and not isSymbol(thenIndex - 1, ".") then
					mentions = true
				end
				thenIndex += 1
			end
			local body = blockAt[thenIndex]
			if not mentions or not body or body.kind ~= "if" or not body.finish then
				continue
			end
			local bodyEnd = body.finish :: number
			local leaves = false
			for inner = thenIndex + 1, bodyEnd do
				if isSymbol(inner, "=") and (isKeyword(inner + 1, "true") or isKeyword(inner + 1, "false")) then
					local after = tokens[inner + 2]
					local target = tokens[inner - 1]
					local literalOnly = after == nil or after.line > tokens[inner + 1].line or after.kind == "keyword"
					local fieldTarget = target.text == "]" or isSymbol(inner - 2, ".")
					if literalOnly and fieldTarget then
						return true
					end
				elseif isName(inner, "Kick") or isName(inner, "SetAttribute") then
					return true
				elseif isKeyword(inner, "return") then
					leaves = true
				end
			end
			if leaves then
				for later = bodyEnd + 1, scopeEnd do
					if isName(later, "Instance") and isSymbol(later + 1, ".") and isName(later + 2, "new") then
						return true
					end
				end
			end
		end
		return false
	end

	local function checkFailedLoads()
		for _, loadIndex in loadCalls do
			local wrapper = enclosingFunction(loadIndex)
			-- only the plain `pcall(function() ... GetAsync ... end)` form
			if not (wrapper and not wrapper.name and wrapper.finish and isName(wrapper.start - 2, "pcall")) then
				continue
			end
			local loadFunction = outerFunction(loadIndex)
			-- a load at the top level is a one-off (settings, a global key), not player data;
			-- a function that both loads and saves is one self-contained step (a daily reward);
			-- a save into another store or under another key name is unrelated data
			local savedElsewhere, savedHere = false, false
			local loadStore, loadKey = text(loadIndex - 2), keyLiterals(loadIndex)
			for _, saveIndex in saveCalls do
				-- a save made on a player's request (inside a remote handler) writes one new
				-- value on purpose; it is not the "save everything on leave" that wipes data
				if insideKind(saveIndex, function(block)
					return block.remote == true
				end) then
					continue
				end
				local saveKey = keyLiterals(saveIndex)
				local sameData = text(saveIndex - 2) == loadStore
					and (loadKey == "" or saveKey == "" or loadKey == saveKey)
				if sameData then
					if outerFunction(saveIndex) == loadFunction then
						savedHere = true
					else
						savedElsewhere = true
					end
				end
			end
			if loadFunction == nil or savedHere or not savedElsewhere then
				continue
			end
			if not failedLoadRemembered(wrapper, loadFunction) then
				add("datastore-save-after-failed-load", loadIndex)
			end
		end
	end

	checkFailedLoads()

	if playerAddedConnect and not handlesExistingPlayers and not isClient then
		add("playeradded-no-existing-players", playerAddedConnect)
	end

	if savesData and playerRemoving and not names.BindToClose then
		add("datastore-no-bindtoclose", playerRemoving)
	end

	table.sort(findings, function(a: Finding, b: Finding): boolean
		if a.line ~= b.line then
			return a.line < b.line
		end
		if a.col ~= b.col then
			return a.col < b.col
		end
		return a.rule < b.rule
	end)

	return findings
end

-- The fixes of the given findings in the order they must be applied: from the end of the
-- text to the start, so earlier positions stay valid. Overlapping fixes are dropped.
function Checker.orderedFixes(findings: { Finding }): { Fix }
	local fixes: { Fix } = {}
	for _, finding in findings do
		if finding.fix then
			table.insert(fixes, finding.fix)
		end
	end
	table.sort(fixes, function(a: Fix, b: Fix): boolean
		return a.from > b.from
	end)
	local ordered: { Fix } = {}
	local lowestTouched = math.huge
	for _, fix in fixes do
		if fix.to < lowestTouched then
			table.insert(ordered, fix)
			lowestTouched = fix.from
		end
	end
	return ordered
end

-- Applies the fixes of the given findings. Returns the new source and the number applied.
function Checker.applyFixes(source: string, findings: { Finding }): (string, number)
	local ordered = Checker.orderedFixes(findings)
	for _, fix in ordered do
		source = string.sub(source, 1, fix.from - 1) .. fix.text .. string.sub(source, fix.to + 1)
	end
	return source, #ordered
end

-- Line and column (1-based, column in bytes) of a byte offset in the source.
function Checker.position(source: string, offset: number): (number, number)
	local line, lineStart, searchFrom = 1, 1, 1
	while true do
		local newline = string.find(source, "\n", searchFrom, true)
		if not newline or newline >= offset then
			break
		end
		line += 1
		lineStart = newline + 1
		searchFrom = newline + 1
	end
	return line, offset - lineStart + 1
end

-- The fixes that turn the fixed text back into `before`. `fixes` are the ones that were
-- applied to `before`. Returned in apply order (end of text first).
function Checker.reverseFixes(before: string, fixes: { Fix }): { Fix }
	local ascending = table.clone(fixes)
	table.sort(ascending, function(a: Fix, b: Fix): boolean
		return a.from < b.from
	end)
	local reversed: { Fix } = {}
	local shift = 0
	for _, fix in ascending do
		local from = fix.from + shift
		table.insert(reversed, 1, {
			from = from,
			to = from + #fix.text - 1,
			text = string.sub(before, fix.from, fix.to),
		})
		shift += #fix.text - (fix.to - fix.from + 1)
	end
	return reversed
end

return Checker
