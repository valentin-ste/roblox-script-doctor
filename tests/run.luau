--[[
	Test runner for the checker core. Run from the project root:

		lune run tests/run.luau            -- compare with snapshots
		lune run tests/run.luau update     -- rewrite snapshots after a reviewed change

	1. Fixtures (tests/fixtures/*.lua): every line marked `--! rule-id[, rule-id]` must
	   produce exactly those findings (a rule listed twice means two findings on that line);
	   unmarked lines must produce none. A line `--# scriptKind: client` anywhere in the file
	   passes that option to the checker, the way the plugin does.
	2. Fix fixtures (name.fixed.lua): applying all fixes to name.lua must give that text.
	3. Sample sets: findings are compared with a reviewed snapshot, so any change in behaviour
	   is visible. tests/samples/<set> are scripts written by AI assistants (Claude Sonnet,
	   Claude Haiku, OpenAI Codex) for 20 beginner requests; snapshots in tests/snapshots.
	   Two popular admin frameworks (free-models/_frameworks, 1 390 scripts) are too big for a
	   line-by-line snapshot: their counts per rule are, checked the way the plugin checks a
	   place (with the method names of all of them).
	4. Hand labels (tests/labels.csv): for the AI sample sets, how many labelled problems
	   are caught and missed, and how many findings have no label. A miss or a finding without
	   a label fails: label it (or fix the rule) before updating the snapshots.
	5. Private data (research/, not in the public repository): 407 scripts from popular free
	   models and two popular admin frameworks are other people's code, so they are
	   not published. When research/ is there, they are checked against research/snapshots,
	   and research/labels-free-models.csv (every security and bug finding there read by a
	   person and marked real / unsure / false) prints the precision per rule; a security or
	   bug finding without a verdict fails. Without research/ these steps are skipped.
]]
local fs = require("@lune/fs")
local process = require("@lune/process")

local Checker = require("../src/core/Checker")

local update = process.args[1] == "update"
local failures = 0
local checks = 0

-- A labelled line and a finding of the same rule in the same file count as one match when
-- they are this many lines apart or closer: the label marks the line where a person sees the
-- problem (the save that wipes data), the finding the line the rule anchors to (the load).
local LABEL_LINE_TOLERANCE = 10

local function fail(message: string)
	failures += 1
	print("  FAIL " .. message)
end

local function splitLines(source: string): { string }
	local lines = {}
	for line in string.gmatch(source .. "\n", "(.-)\n") do
		table.insert(lines, line)
	end
	return lines
end

local function sortedFiles(folder: string): { string }
	local files = {}
	for _, name in fs.readDir(folder) do
		if string.match(name, "%.lua$") then
			table.insert(files, name)
		end
	end
	table.sort(files)
	return files
end

-- The kind of script a sample file is, from its name ("03-shop-client.lua"); the plugin
-- knows it from the script class and location.
local function kindFromName(name: string): string?
	if string.find(name, "client", 1, true) then
		return "client"
	elseif string.find(name, "server", 1, true) then
		return "server"
	end
	return nil
end

-- 1 and 2: fixtures -----------------------------------------------------------
print("fixtures")
for _, name in sortedFiles("tests/fixtures") do
	if string.match(name, "%.fixed%.lua$") then
		continue
	end
	local source = fs.readFile("tests/fixtures/" .. name)
	local options: Checker.Options = {}
	local expected: { [string]: number } = {}
	local expectedSeverity: { [string]: string } = {}
	for lineNumber, line in splitLines(source) do
		local marker = string.match(line, "%-%-! (.+)$")
		if marker then
			-- `rule-id` or `rule-id@advice` (the severity is checked too)
			for item in string.gmatch(marker, "[%w%-@]+") do
				local rule, severity = string.match(item, "^([%w%-]+)@?(%a*)$")
				local key = lineNumber .. ":" .. (rule or item)
				expected[key] = (expected[key] or 0) + 1
				if severity and severity ~= "" then
					expectedSeverity[key] = severity
				end
			end
		end
		local kind = string.match(line, "^%-%-# scriptKind: (%a+)")
		if kind then
			options.scriptKind = kind
		end
	end
	local findings = Checker.check(source, options)
	local got: { [string]: number } = {}
	checks += 1
	local before = failures
	for _, finding in findings do
		local key = finding.line .. ":" .. finding.rule
		got[key] = (got[key] or 0) + 1
		if expectedSeverity[key] and expectedSeverity[key] ~= finding.severity then
			fail(`{name}: {key} has severity {finding.severity}, expected {expectedSeverity[key]}`)
		end
	end
	for key, count in expected do
		if (got[key] or 0) < count then
			fail(`{name}: expected {count}, got {got[key] or 0}: {key}`)
		end
	end
	for key, count in got do
		if count > (expected[key] or 0) then
			fail(`{name}: unexpected finding ({count} found, {expected[key] or 0} expected): {key}`)
		end
	end

	local fixedPath = "tests/fixtures/" .. string.gsub(name, "%.lua$", ".fixed.lua")
	if fs.isFile(fixedPath) then
		checks += 1
		local fixed, applied = Checker.applyFixes(source, findings)
		if fixed ~= fs.readFile(fixedPath) then
			fail(name .. ": text after fixes differs from " .. fixedPath)
			fs.writeFile(fixedPath .. ".actual", fixed)
		end
		-- fixed text must not trigger the fixable rules again
		for _, finding in Checker.check(fixed, options) do
			if finding.fix then
				fail(name .. ": fixable finding remains after fixes: " .. finding.line .. ":" .. finding.rule)
			end
		end
		print(string.format("  %-28s fixes applied: %d", name, applied))
	end
	if failures == before then
		print(string.format("  %-28s ok (%d findings)", name, #findings))
	end
end

-- 2b: fixes can be applied one by one and undone ------------------------------------
do
	checks += 1
	local source = fs.readFile("tests/fixtures/deprecated.lua")
	local findings = Checker.check(source)
	local fixes = Checker.orderedFixes(findings)
	local fixed = Checker.applyFixes(source, findings)

	-- positions: line and column of every fix must point at the text being replaced
	local sourceLines = splitLines(source)
	for _, fix in fixes do
		local line, col = Checker.position(source, fix.from)
		local expected = string.sub(source, fix.from, fix.to)
		if string.sub(sourceLines[line], col, col + #expected - 1) ~= expected then
			fail("position: line " .. line .. " col " .. col .. " does not point at '" .. expected .. "'")
		end
	end

	-- undo: reverse fixes applied to the fixed text give the original back
	local restored = fixed
	for _, fix in Checker.reverseFixes(source, fixes) do
		restored = string.sub(restored, 1, fix.from - 1) .. fix.text .. string.sub(restored, fix.to + 1)
	end
	if restored ~= source then
		fail("reverseFixes: undoing the fixes does not give the original text")
	end
	print(
		string.format("fixes: %d ordered, positions and undo %s", #fixes, if restored == source then "ok" else "FAILED")
	)
end

-- 2c: methods defined in other scripts of the place take the button away -------------
do
	checks += 1
	local classModule =
		"local Enemy = {}\nfunction Enemy:takeDamage(n) end\nEnemy.destroy = function(self) end\nreturn Enemy\n"
	local user = "local e = require(script.Parent.Enemy).new()\ne:takeDamage(10)\ne:destroy()\npart:clone()\n"
	local members = Checker.definedMembers(classModule)
	local items = {}
	for _, finding in Checker.check(user, { knownMembers = members }) do
		table.insert(items, `{finding.line}:{finding.rule}:{if finding.fix then "fix" else "nofix"}`)
	end
	-- the finding stays (it may be a Roblox object), only the rename button goes
	local expected = "2:deprecated-method:nofix 3:deprecated-method:nofix 4:deprecated-method:fix"
	local got = table.concat(items, " ")
	if got ~= expected then
		fail("knownMembers: expected " .. expected .. ", got " .. got)
	else
		print("knownMembers: ok")
	end
end

-- 3: sample sets ---------------------------------------------------------------
type Labelled = { file: string, line: number, rule: string, severity: string? }

local function runSet(set: string, folder: string, snapshotPath: string): { Labelled }
	local found: { Labelled } = {}
	if not fs.isDir(folder) then
		print("samples: " .. set .. " — " .. folder .. " not found, skipped")
		return found
	end
	local lines = {}
	local perRule: { [string]: number } = {}
	local total, fileCount, crashed = 0, 0, 0
	for _, name in sortedFiles(folder) do
		fileCount += 1
		local ok, findings =
			pcall(Checker.check, fs.readFile(folder .. "/" .. name), { scriptKind = kindFromName(name) })
		if not ok then
			crashed += 1
			table.insert(lines, name .. ":0 CRASH " .. tostring(findings))
			continue
		end
		for _, finding in findings do
			total += 1
			perRule[finding.rule] = (perRule[finding.rule] or 0) + 1
			table.insert(
				lines,
				string.format("%s:%d:%d %s %s", name, finding.line, finding.col, finding.severity, finding.rule)
			)
			table.insert(
				found,
				{ file = set .. "/" .. name, line = finding.line, rule = finding.rule, severity = finding.severity }
			)
		end
	end
	local text = table.concat(lines, "\n") .. "\n"
	print(string.format("samples: %s — files %d, findings %d, crashes %d", set, fileCount, total, crashed))
	local rules = {}
	for rule in perRule do
		table.insert(rules, rule)
	end
	table.sort(rules, function(a, b)
		if perRule[a] ~= perRule[b] then
			return perRule[a] > perRule[b]
		end
		return a < b
	end)
	for _, rule in rules do
		print(string.format("  %5d  %s", perRule[rule], rule))
	end
	checks += 1
	if crashed > 0 then
		fail(set .. ": checker crashed on " .. crashed .. " files")
	end
	if update or not fs.isFile(snapshotPath) then
		fs.writeFile(snapshotPath, text)
		print("  snapshot written: " .. snapshotPath)
	elseif fs.readFile(snapshotPath) ~= text then
		fs.writeFile(snapshotPath .. ".actual", text)
		fail(set .. ": findings differ from snapshot (see " .. snapshotPath .. ".actual)")
	end
	return found
end

-- 3b: counts per rule on the two admin frameworks, as one place
local function runSummary(folder: string, snapshotPath: string)
	if not fs.isDir(folder) then
		print("summary: " .. folder .. " — folder not found, skipped")
		return
	end
	local sources = {}
	for _, name in sortedFiles(folder) do
		table.insert(sources, fs.readFile(folder .. "/" .. name))
	end
	local members: { [string]: boolean } = {}
	for _, source in sources do
		for name in Checker.definedMembers(source) do
			members[name] = true
		end
	end
	local counts: { [string]: { total: number, fixable: number } } = {}
	local total, crashed = 0, 0
	for _, source in sources do
		local ok, findings = pcall(Checker.check, source, { knownMembers = members })
		if not ok then
			crashed += 1
			continue
		end
		for _, finding in findings do
			local key = finding.severity .. " " .. finding.rule
			counts[key] = counts[key] or { total = 0, fixable = 0 }
			counts[key].total += 1
			total += 1
			if finding.fix then
				counts[key].fixable += 1
			end
		end
	end
	local keys = {}
	for key in counts do
		table.insert(keys, key)
	end
	table.sort(keys)
	local lines = { `scripts {#sources}, findings {total}, crashes {crashed}` }
	for _, key in keys do
		table.insert(lines, string.format("%5d  fixable %4d  %s", counts[key].total, counts[key].fixable, key))
	end
	local text = table.concat(lines, "\n") .. "\n"
	print(`summary: {folder} — scripts {#sources}, findings {total}, crashes {crashed}`)
	checks += 1
	if crashed > 0 then
		fail(folder .. ": checker crashed on " .. crashed .. " files")
	end
	if update or not fs.isFile(snapshotPath) then
		fs.writeFile(snapshotPath, text)
		print("  snapshot written: " .. snapshotPath)
	elseif fs.readFile(snapshotPath) ~= text then
		fs.writeFile(snapshotPath .. ".actual", text)
		fail(folder .. ": counts differ from snapshot (see " .. snapshotPath .. ".actual)")
	end
end

-- 4: hand labels ------------------------------------------------------------------

-- Fields of one CSV line ("a,b,\"c, with comma\",d").
local function csvFields(line: string): { string }
	local fields = {}
	local position = 1
	while position <= #line + 1 do
		if string.sub(line, position, position) == '"' then
			local value = ""
			local cursor = position + 1
			while cursor <= #line do
				local char = string.sub(line, cursor, cursor)
				if char == '"' and string.sub(line, cursor + 1, cursor + 1) == '"' then
					value ..= '"'
					cursor += 2
				elseif char == '"' then
					cursor += 1
					break
				else
					value ..= char
					cursor += 1
				end
			end
			table.insert(fields, value)
			position = cursor + 1
		else
			local comma = string.find(line, ",", position, true) or (#line + 1)
			table.insert(fields, string.sub(line, position, comma - 1))
			position = comma + 1
		end
	end
	return fields
end

local function compareWithLabels(sets: { string }, foundBySet: { [string]: { Labelled } })
	local labelPath = "tests/labels.csv"
	if not fs.isFile(labelPath) then
		print("labels: " .. labelPath .. " not found, skipped")
		return
	end
	local labels: { [string]: { Labelled } } = {}
	local outOfScope: { [string]: number } = {}
	for index, line in splitLines(fs.readFile(labelPath)) do
		if index == 1 or line == "" then
			continue
		end
		local fields = csvFields(line)
		local file, lineNumber, category = fields[1], tonumber(fields[2]), fields[3]
		local set = string.match(file, "^([^/]+)/")
		if not set or category == "clean" then
			continue
		end
		labels[set] = labels[set] or {}
		if Checker.RULES[category] then
			table.insert(labels[set], { file = file, line = lineNumber or 0, rule = category })
		else
			outOfScope[set] = (outOfScope[set] or 0) + 1
		end
	end

	print("labels (tests/labels.csv, problems a person marked in AI code)")
	for _, set in sets do
		local found = foundBySet[set] or {}
		local used: { [number]: boolean } = {}
		local caught, missed = 0, {}
		for _, label in labels[set] or {} do
			local best, bestDistance = nil, math.huge
			for index, finding in found do
				local distance = math.abs(finding.line - label.line)
				if
					not used[index]
					and finding.file == label.file
					and finding.rule == label.rule
					and distance <= LABEL_LINE_TOLERANCE
					and distance < bestDistance
				then
					best, bestDistance = index, distance
				end
			end
			if best then
				used[best] = true
				caught += 1
			else
				table.insert(missed, `{label.file}:{label.line} {label.rule}`)
			end
		end
		local unlabelled = {}
		for index, finding in found do
			if not used[index] then
				table.insert(unlabelled, `{finding.file}:{finding.line} {finding.rule}`)
			end
		end
		print(
			string.format(
				"  %-8s caught %d, missed %d, findings without a label %d; %d labelled problems are outside our rules",
				set,
				caught,
				#missed,
				#unlabelled,
				outOfScope[set] or 0
			)
		)
		for _, item in missed do
			print("    missed     " .. item)
		end
		for _, item in unlabelled do
			print("    no label   " .. item)
		end
		checks += 1
		if #missed > 0 or #unlabelled > 0 then
			fail(`{set}: {#missed} labelled problems missed, {#unlabelled} findings without a label`)
		end
	end
end

-- 5: verdicts on free models ---------------------------------------------------------
local function compareWithVerdicts(found: { Labelled })
	local path = "research/labels-free-models.csv"
	if not fs.isFile(path) or #found == 0 then
		print("verdicts: " .. path .. " or the free models not found, skipped")
		return
	end
	-- "file:line:rule" -> verdicts (one per finding; a line can have two findings)
	local verdicts: { [string]: { string } } = {}
	for index, line in splitLines(fs.readFile(path)) do
		if index == 1 or line == "" then
			continue
		end
		local fields = csvFields(line)
		local key = `free-models/{fields[1]}:{fields[2]}:{fields[3]}`
		verdicts[key] = verdicts[key] or {}
		table.insert(verdicts[key], fields[4])
	end
	local perRule: { [string]: { [string]: number } } = {}
	local missing = {}
	for _, finding in found do
		if finding.severity ~= "security" and finding.severity ~= "bug" then
			continue
		end
		local key = `{finding.file}:{finding.line}:{finding.rule}`
		local list = verdicts[key]
		local verdict = if list and #list > 0 then table.remove(list, 1) else nil
		if not verdict then
			table.insert(missing, key)
			continue
		end
		perRule[finding.rule] = perRule[finding.rule] or { real = 0, unsure = 0, wrong = 0 }
		-- "false" is a keyword in Luau, so the count is kept as "wrong"
		local bucket = if verdict == "false" then "wrong" else verdict
		perRule[finding.rule][bucket] = (perRule[finding.rule][bucket] or 0) + 1
	end
	print("verdicts (research/labels-free-models.csv, security and bug findings on free models)")
	local rules = {}
	for rule in perRule do
		table.insert(rules, rule)
	end
	table.sort(rules)
	local real, unsure, wrong = 0, 0, 0
	for _, rule in rules do
		local counts = perRule[rule]
		real += counts.real
		unsure += counts.unsure
		wrong += counts.wrong
		print(string.format("  %-34s real %2d, unsure %2d, false %2d", rule, counts.real, counts.unsure, counts.wrong))
	end
	print(
		string.format(
			"  total: real %d, unsure %d, false %d; precision %.0f%% of the decided ones",
			real,
			unsure,
			wrong,
			100 * real / math.max(1, real + wrong)
		)
	)
	-- verdicts left over belong to findings that are gone (fixed rule or lost finding)
	for key, list in verdicts do
		for _, verdict in list do
			print(`    gone ({verdict}) {key}`)
		end
	end
	checks += 1
	for _, key in missing do
		print("    no verdict " .. key)
	end
	if #missing > 0 then
		fail(`free-models: {#missing} security/bug findings without a verdict in {path}`)
	end
end

local foundBySet = {}
for _, set in { "sonnet", "haiku", "codex" } do
	foundBySet[set] = runSet(set, "tests/samples/" .. set, "tests/snapshots/" .. set .. ".txt")
end
-- private: other people's code, kept in research/ (see 5 above)
local freeModels = runSet("free-models", "research/samples/free-models", "research/snapshots/free-models.txt")
runSummary("research/samples/free-models/_frameworks", "research/snapshots/frameworks-summary.txt")
compareWithLabels({ "sonnet", "haiku", "codex" }, foundBySet)
compareWithVerdicts(freeModels)

print(string.format("\n%d checks, %d failures", checks, failures))
process.exit(if failures > 0 then 1 else 0)
