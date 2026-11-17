--!strict
--[[
	Small Luau tokenizer.

	Splits source text into tokens so rules never mistake text inside strings or
	comments for code. Comments are dropped. Pure Luau: no Roblox APIs, runs
	under lune for tests.

	Token = { kind, text, line, col, from, to }
	  kind: "name" | "keyword" | "number" | "string" | "symbol"
	  text: for strings, the contents without quotes
	  line, col: 1-based position of the first character
	  from, to: 1-based byte offsets in the source (inclusive)
]]

local Lexer = {}

export type Token = {
	kind: string,
	text: string,
	line: number,
	col: number,
	from: number,
	to: number,
}

local KEYWORDS = {}
for _, word in
	{
		"and",
		"break",
		"continue",
		"do",
		"else",
		"elseif",
		"end",
		"false",
		"for",
		"function",
		"if",
		"in",
		"local",
		"nil",
		"not",
		"or",
		"repeat",
		"return",
		"then",
		"true",
		"until",
		"while",
	}
do
	KEYWORDS[word] = true
end

-- Longest first, so "..=" wins over "..".
local SYMBOLS =
	{ "...", "..=", "//=", "==", "~=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "^=", "..", "//", "::", "->" }

-- Returns the length of a long-bracket opener ("[[", "[==[") at `pos`, or nil.
local function longBracketLevel(source: string, pos: number): number?
	local equals = string.match(source, "^%[(=*)%[", pos)
	if equals then
		return #equals
	end
	return nil
end

function Lexer.tokenize(source: string): { Token }
	local tokens: { Token } = {}
	local pos = 1
	local length = #source
	local line = 1
	local lineStart = 1

	local function push(kind: string, text: string, from: number, to: number, startLine: number, startCol: number)
		table.insert(tokens, { kind = kind, text = text, line = startLine, col = startCol, from = from, to = to })
	end

	-- Moves `pos` to `newPos`, keeping the line counter in sync.
	local function advanceTo(newPos: number)
		local searchFrom = pos
		while true do
			local newline = string.find(source, "\n", searchFrom, true)
			if not newline or newline >= newPos then
				break
			end
			line += 1
			lineStart = newline + 1
			searchFrom = newline + 1
		end
		pos = newPos
	end

	while pos <= length do
		local char = string.sub(source, pos, pos)
		local startLine, startCol = line, pos - lineStart + 1

		if char == "\n" then
			line += 1
			lineStart = pos + 1
			pos += 1
		elseif char == " " or char == "\t" or char == "\r" then
			pos += 1
		elseif string.sub(source, pos, pos + 1) == "--" then
			local level = longBracketLevel(source, pos + 2)
			if level then
				local close = "]" .. string.rep("=", level) .. "]"
				local _, closeEnd = string.find(source, close, pos + 4 + level, true)
				advanceTo((closeEnd or length) + 1)
			else
				local newline = string.find(source, "\n", pos, true)
				pos = newline or (length + 1)
			end
		elseif char == '"' or char == "'" or char == "`" then
			local cursor = pos + 1
			while cursor <= length do
				local c = string.sub(source, cursor, cursor)
				if c == "\\" then
					cursor += 2
				elseif c == char or (c == "\n" and char ~= "`") then
					break
				else
					cursor += 1
				end
			end
			local stop = math.min(cursor, length)
			push("string", string.sub(source, pos + 1, cursor - 1), pos, stop, startLine, startCol)
			advanceTo(stop + 1)
		elseif char == "[" and longBracketLevel(source, pos) then
			local level = longBracketLevel(source, pos) :: number
			local close = "]" .. string.rep("=", level) .. "]"
			local closeStart, closeEnd = string.find(source, close, pos + 2 + level, true)
			local stop = closeEnd or length
			push(
				"string",
				string.sub(source, pos + 2 + level, (closeStart or (length + 1)) - 1),
				pos,
				stop,
				startLine,
				startCol
			)
			advanceTo(stop + 1)
		elseif string.find(char, "^[%a_]") then
			local _, wordEnd = string.find(source, "^[%w_]+", pos)
			local word = string.sub(source, pos, wordEnd)
			push(if KEYWORDS[word] then "keyword" else "name", word, pos, wordEnd :: number, startLine, startCol)
			pos = (wordEnd :: number) + 1
		elseif string.find(char, "^%d") or (char == "." and string.find(source, "^%d", pos + 1)) then
			local _, numberEnd = string.find(source, "^0[xX][%x_]+", pos)
			if not numberEnd then
				_, numberEnd = string.find(source, "^0[bB][01_]+", pos)
			end
			if not numberEnd then
				_, numberEnd = string.find(source, "^[%d_]*%.?[%d_]*", pos)
				local _, exponentEnd = string.find(source, "^[eE][+-]?%d+", (numberEnd :: number) + 1)
				numberEnd = exponentEnd or numberEnd
			end
			local stop = math.max(numberEnd :: number, pos)
			push("number", string.sub(source, pos, stop), pos, stop, startLine, startCol)
			pos = stop + 1
		else
			local symbol = char
			for _, candidate in SYMBOLS do
				if string.sub(source, pos, pos + #candidate - 1) == candidate then
					symbol = candidate
					break
				end
			end
			push("symbol", symbol, pos, pos + #symbol - 1, startLine, startCol)
			pos += #symbol
		end
	end

	return tokens
end

return Lexer
