-- Fixture: ways external or hidden code gets into a game.
local InsertService = game:GetService("InsertService")
local a = require(1234567) --! require-by-id
local b = require(0x11F0A3B2C) --! require-by-id
loadstring("print('x')")() --! loadstring
local env = getfenv() --! environment-access
setfenv(1, {}) --! environment-access
local s = string.reverse(")987654321(eriuqer") --! obfuscated-code
local c = string.char(114, 101, 113, 117, 105, 114, 101) --! obfuscated-code
local d = "\104\116\116\112\115\58\47\47\101\120\97\109\112\108\101\46\99\111\109" --! obfuscated-code
InsertService:LoadAsset(123456789).Parent = workspace --! insert-asset

-- Fine: ordinary requires and a single character code.
local Module = require(script.Parent.Module)
local Other = require(script:WaitForChild("Other"))
local letter = string.char(65)
print(a, b, env, s, c, d, Module, Other, letter)
