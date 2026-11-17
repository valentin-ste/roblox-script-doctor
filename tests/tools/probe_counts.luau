-- Prints findings per file for a folder: name, findings, fixable. Used to compare lune with Studio.
-- Run from the project root: lune run tests/tools/probe_counts.luau research/samples/probe
local fs = require("@lune/fs")
local process = require("@lune/process")
local Checker = require("../../src/core/Checker")

local folder = process.args[1]
local names = fs.readDir(folder)
table.sort(names)
for _, name in names do
	if string.match(name, "%.lua$") then
		local findings = Checker.check(fs.readFile(folder .. "/" .. name))
		local fixable = 0
		for _, finding in findings do
			if finding.fix then
				fixable += 1
			end
		end
		print(name, #findings, fixable)
	end
end
