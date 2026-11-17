-- Prints "file:line rule" for every finding in a folder. Run from the project root:
-- lune run tests/tools/findings_lines.luau research/samples/probe
local fs = require("@lune/fs")
local process = require("@lune/process")
local Checker = require("../../src/core/Checker")
local folder = process.args[1]
local names = fs.readDir(folder)
table.sort(names)
for _, name in names do
	if string.match(name, "%.lua$") then
		for _, finding in Checker.check(fs.readFile(folder .. "/" .. name)) do
			print(name .. ":" .. finding.line .. " " .. finding.rule)
		end
	end
end
