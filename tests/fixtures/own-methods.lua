-- Fixture: the file's own methods with Roblox-like names are left alone.
local Signal = {}
Signal.__index = Signal
function Signal:Connect(callback)
	return callback
end
-- an alias defines the name too
Signal.connect = Signal.Connect

local Thing = {
	destroy = function(self)
		return self
	end,
}

local signal = setmetatable({}, Signal)
signal:connect(print)
Thing:destroy()
workspace.Part:clone() --! deprecated-method
