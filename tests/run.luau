--[[
	Test runner for the checker core. Run from the project root:

		lune run tests/run.luau            -- compare with snapshots
		lune run tests/run.luau update     -- rewrite snapshots after a reviewed change

	1. Fixtures (tests/fixtures/*.lua): every line marked `--! rule-id[, rule-id]` must
	   produce exactly those findings; unmarked lines must produce none.
	2. Fix fixtures (name.fixed.lua): applying all fixes to name.lua must give that text.
	3. Sample sets (research/samples/<set>): findings are compared with a reviewed
	   snapshot in tests/snapshots/<set>.txt, so any change in behaviour is visible.
]]
local fs = require("@lune/fs")
local process = require("@lune/process")

local Checker = require("../src/core/Checker")

local update = process.args[1] == "update"
local failures = 0
local checks = 0

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

-- 1 and 2: fixtures -----------------------------------------------------------
print("fixtures")
for _, name in sortedFiles("tests/fixtures") do
	if string.match(name, "%.fixed%.lua$") then
		continue
	end
	local source = fs.readFile("tests/fixtures/" .. name)
	local expected: { [string]: boolean } = {}
	for lineNumber, line in splitLines(source) do
		local marker = string.match(line, "%-%-! (.+)$")
		if marker then
			for rule in string.gmatch(marker, "[%w%-]+") do
				expected[lineNumber .. ":" .. rule] = true
			end
		end
	end
	local findings = Checker.check(source)
	local got: { [string]: boolean } = {}
	for _, finding in findings do
		got[finding.line .. ":" .. finding.rule] = true
	end
	checks += 1
	local before = failures
	for key in expected do
		if not got[key] then
			fail(name .. ": expected but missing " .. key)
		end
	end
	for key in got do
		if not expected[key] then
			fail(name .. ": unexpected finding " .. key)
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
		for _, finding in Checker.check(fixed) do
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

-- 3: sample sets ---------------------------------------------------------------
local function runSet(set: string, mustMatch: boolean)
	local folder = "research/samples/" .. set
	if not fs.isDir(folder) then
		print("samples: " .. set .. " — folder not found, skipped")
		return
	end
	local lines = {}
	local perRule: { [string]: number } = {}
	local total, fileCount, crashed = 0, 0, 0
	for _, name in sortedFiles(folder) do
		fileCount += 1
		local ok, findings = pcall(Checker.check, fs.readFile(folder .. "/" .. name))
		if not ok then
			crashed += 1
			table.insert(lines, name .. ":0 CRASH " .. tostring(findings))
			continue
		end
		for _, finding in findings do
			total += 1
			perRule[finding.rule] = (perRule[finding.rule] or 0) + 1
			table.insert(lines, string.format("%s:%d:%d %s", name, finding.line, finding.col, finding.rule))
		end
	end
	local text = table.concat(lines, "\n") .. "\n"
	local snapshotPath = "tests/snapshots/" .. set .. ".txt"
	print(string.format("samples: %s — files %d, findings %d, crashes %d", set, fileCount, total, crashed))
	local rules = {}
	for rule in perRule do
		table.insert(rules, rule)
	end
	table.sort(rules, function(a, b)
		return perRule[a] > perRule[b]
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
	elseif mustMatch and fs.readFile(snapshotPath) ~= text then
		fs.writeFile(snapshotPath .. ".actual", text)
		fail(set .. ": findings differ from snapshot (see " .. snapshotPath .. ".actual)")
	end
end

runSet("sonnet", true)
runSet("haiku", true)
runSet("codex", true)
runSet("free-models", true)

print(string.format("\n%d checks, %d failures", checks, failures))
process.exit(if failures > 0 then 1 else 0)
