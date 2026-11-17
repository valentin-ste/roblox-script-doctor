-- Fixture: names, stores and obfuscation cases from the review of 16.11.2026.
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local store = DataStoreService:GetDataStore("Main")
local map = MemoryStoreService:GetSortedMap("Queue")

local function telemetry(callback)
	return callback()
end
local function runUnsafe(callback)
	return callback()
end
local function retryAsync(callback)
	return callback()
end

-- Whole words of the name count: "telemetry" is not "try", "runUnsafe" is not "safe".
telemetry(function()
	store:GetAsync("a") --! datastore-no-pcall
end)
runUnsafe(function()
	store:GetAsync("b") --! datastore-no-pcall
end)
retryAsync(function()
	store:GetAsync("c")
end)

-- A function kept in a variable and run through pcall is protected.
local load = function(key)
	return store:GetAsync(key)
end
print(pcall(load, "d"))

print(DataStoreService:GetDataStore("Other"):GetAsync("e")) --! datastore-no-pcall
map:SetAsync("f", 1, 60) --! memorystore-no-pcall
pcall(function()
	map:GetAsync("g")
end)

-- "thumbnail" is not a humanoid.
local thumbnail = workspace.Thumbnail
thumbnail:LoadAnimation(script.Animation)
workspace.Humanoid:LoadAnimation(script.Animation) --! deprecated-loadanimation

-- string.reverse on a variable is ordinary; on text written in the code it hides it.
print(string.reverse(tostring(1000000)))
print(string.reverse("eriuqer")) --! obfuscated-code
print(("gnirtsdaol"):reverse()) --! obfuscated-code

-- Joint methods are deprecated in every spelling.
workspace.Model:MakeJoints() --! deprecated-joints
workspace.Model:breakJoints() --! deprecated-joints

-- Handed to pcall once but also called plainly: a failure still stops the script.
local refresh = function()
	return store:GetAsync("top") --! datastore-no-pcall
end
pcall(refresh)
refresh()

-- Called only inside protected code: protected.
local function loadProfile(key)
	return store:GetAsync(key)
end
pcall(function()
	loadProfile("h")
end)
