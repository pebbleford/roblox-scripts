-- ================================================================
-- Pebbleford Hub - WindUI Preview
-- A sample of the real NBTF controls rendered in WindUI, so the look
-- and feel can be compared against Rayfield before committing to a
-- port of every script. Nothing here touches the game.
--
-- Note: WindUI's own maintainers describe it as Beta and warn that
-- bugs and unstable features may occur.
-- ================================================================

local ok, WindUI = pcall(function()
	return loadstring(game:HttpGet(
		"https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if not ok or not WindUI then
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "WindUI Preview",
			Text = "Library failed to load: " .. tostring(WindUI),
			Duration = 8,
		})
	end)
	return
end

local Window = WindUI:CreateWindow({
	Title = "Pebbleford Hub - NBTF",
	Author = "WindUI preview - controls do nothing",
	Folder = "PebblefordHubPreview",
	Size = UDim2.fromOffset(580, 460),
	HideSearchBar = false,
	OpenButton = {
		Title = "NBTF",
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
	},
})

local function noop() end

local AimTab = Window:Tab({Title = "Aim"})
local CombatTab = Window:Tab({Title = "Combat"})
local MoveTab = Window:Tab({Title = "Movement"})
local VisualTab = Window:Tab({Title = "Visuals"})
local PlayerTab = Window:Tab({Title = "Players"})

-- ---------- Aim ----------
AimTab:Toggle({Title = "Silent Aim", Callback = noop})
AimTab:Toggle({Title = "Aimbot (Right-Click Lock)", Callback = noop})
AimTab:Slider({
	Title = "Aim FOV", Desc = "Radius the aim will search in",
	Step = 1, Value = {Min = 20, Max = 500, Default = 150}, Callback = noop,
})
AimTab:Slider({
	Title = "Aim Smoothing", Step = 1,
	Value = {Min = 1, Max = 20, Default = 2}, Callback = noop,
})
AimTab:Dropdown({
	Title = "Selected Weapon",
	Values = {"Auto", "MP5", "XM1014", "M4A1", "AK74", "M24 Sniper"},
	Value = "Auto", Callback = noop,
})

-- ---------- Combat ----------
CombatTab:Toggle({Title = "Unlimited Ammo", Callback = noop})
CombatTab:Toggle({Title = "Instant Reload", Callback = noop})
CombatTab:Toggle({Title = "No Recoil", Callback = noop})
CombatTab:Toggle({Title = "Kill Aura", Callback = noop})
CombatTab:Slider({
	Title = "Kill Aura Range (studs)", Step = 1,
	Value = {Min = 10, Max = 100, Default = 50}, Callback = noop,
})
CombatTab:Button({Title = "Kill All", Desc = "Fires at every enemy", Callback = noop})

-- ---------- Movement ----------
MoveTab:Toggle({Title = "Fly (WASD + Space/Shift)", Callback = noop})
MoveTab:Slider({
	Title = "Fly Speed", Step = 1,
	Value = {Min = 10, Max = 300, Default = 80}, Callback = noop,
})
MoveTab:Toggle({Title = "Noclip (Walk Through Walls)", Callback = noop})
MoveTab:Toggle({Title = "Vehicle Fly (Sit First)", Callback = noop})
MoveTab:Toggle({Title = "Car Fling (Sit First)", Callback = noop})
MoveTab:Slider({
	Title = "Jump Power", Step = 1,
	Value = {Min = 50, Max = 400, Default = 50}, Callback = noop,
})

-- ---------- Visuals ----------
VisualTab:Toggle({Title = "Player ESP (Names/Health/Distance)", Callback = noop})
VisualTab:Toggle({Title = "Chams (See Players Through Walls)", Callback = noop})
VisualTab:Toggle({Title = "X-Ray (See Through Walls)", Callback = noop})
VisualTab:Slider({
	Title = "Field of View", Step = 1,
	Value = {Min = 40, Max = 120, Default = 70}, Callback = noop,
})
VisualTab:Paragraph({
	Title = "Note",
	Desc = "This is a preview build. None of these controls affect the game.",
})

-- ---------- Players ----------
PlayerTab:Dropdown({
	Title = "Target Player",
	Values = {"(refresh first)"},
	Value = "(refresh first)", Callback = noop,
})
PlayerTab:Button({Title = "Kill Target", Callback = noop})
PlayerTab:Button({Title = "Bring Target", Callback = noop})
PlayerTab:Button({Title = "Teleport To Target", Callback = noop})
PlayerTab:Input({
	Title = "Chat Message", Placeholder = "Type chat message...", Callback = noop,
})

WindUI:Notify({
	Title = "WindUI Preview",
	Content = "This is WindUI. Compare against Rayfield, then pick.",
	Duration = 6,
})
