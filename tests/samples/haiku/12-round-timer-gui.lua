-- request: Сделай таймер на экране, который показывает время до конца раунда всем игрокам.
-- placement: LocalScript внутрь TextLabel в ScreenGui (ScreenGui в StarterGui). Работает вместе со скриптом раундов из задания 4
local label = script.Parent

local function update()
	local state = workspace:GetAttribute("RoundState") or "Ожидание"
	local timeLeft = workspace:GetAttribute("TimeLeft") or 0
	local minutes = math.floor(timeLeft / 60)
	local seconds = timeLeft % 60
	label.Text = string.format("%s: %d:%02d", state, minutes, seconds)
end

while true do
	update()
	task.wait(0.2)
end
