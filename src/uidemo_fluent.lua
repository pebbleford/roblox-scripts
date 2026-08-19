-- ================================================================
-- Pebbleford Hub - Fluent UI Preview
-- A sample of the real NBTF controls rendered in Fluent, so the look
-- and feel can be compared against Rayfield before committing to a
-- port of every script. Nothing here touches the game.
-- ================================================================

local ok, Fluent = pcall(function()
	return loadstring(game:HttpGet(
		"https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not ok or not Fluent then
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Fluent Preview",
			Text = "Library failed to load: " .. tostring(Fluent),
			Duration = 8,
		})
	end)
	return
end

local Window = Fluent:CreateWindow({
	Title = "Pebbleford Hub - NBTF (Fluent preview)",
	SubTitle = "UI preview only - controls do nothing",
	TabWidth = 160,
	Size = UDim2.fromOffset(580, 460),
	-- Acrylic is the frosted blur behind the window. It looks good but is
	-- more detectable and costs performance on weaker phones.
	Acrylic = false,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.RightShift,
})

local Tabs = {
	Aim = Window:AddTab({Title = "Aim", Icon = "crosshair"}),
	Combat = Window:AddTab({Title = "Combat", Icon = "swords"}),
	Movement = Window:AddTab({Title = "Movement", Icon = "footprints"}),
	Visuals = Window:AddTab({Title = "Visuals", Icon = "eye"}),
	Players = Window:AddTab({Title = "Players", Icon = "users"}),
}

local function noop() end

-- ---------- Aim ----------
Tabs.Aim:AddToggle("Silent", {Title = "Silent Aim", Default = false, Callback = noop})
Tabs.Aim:AddToggle("Aimbot", {Title = "Aimbot (Right-Click Lock)", Default = false, Callback = noop})
Tabs.Aim:AddSlider("Fov", {
	Title = "Aim FOV", Description = "Radius the aim will search in",
	Default = 150, Min = 20, Max = 500, Rounding = 0, Callback = noop,
})
Tabs.Aim:AddSlider("Smooth", {
	Title = "Aim Smoothing", Default = 2, Min = 1, Max = 20, Rounding = 0, Callback = noop,
})
Tabs.Aim:AddDropdown("Weapon", {
	Title = "Selected Weapon",
	Values = {"Auto", "MP5", "XM1014", "M4A1", "AK74", "M24 Sniper"},
	Multi = false, Default = 1, Callback = noop,
})

-- ---------- Combat ----------
Tabs.Combat:AddToggle("Ammo", {Title = "Unlimited Ammo", Default = false, Callback = noop})
Tabs.Combat:AddToggle("Reload", {Title = "Instant Reload", Default = false, Callback = noop})
Tabs.Combat:AddToggle("Recoil", {Title = "No Recoil", Default = false, Callback = noop})
Tabs.Combat:AddToggle("Aura", {Title = "Kill Aura", Default = false, Callback = noop})
Tabs.Combat:AddSlider("AuraRange", {
	Title = "Kill Aura Range (studs)", Default = 50, Min = 10, Max = 100, Rounding = 0, Callback = noop,
})
Tabs.Combat:AddButton({Title = "Kill All", Description = "Fires at every enemy", Callback = noop})

-- ---------- Movement ----------
Tabs.Movement:AddToggle("Fly", {Title = "Fly (WASD + Space/Shift)", Default = false, Callback = noop})
Tabs.Movement:AddSlider("FlySpeed", {
	Title = "Fly Speed", Default = 80, Min = 10, Max = 300, Rounding = 0, Callback = noop,
})
Tabs.Movement:AddToggle("Noclip", {Title = "Noclip (Walk Through Walls)", Default = false, Callback = noop})
Tabs.Movement:AddToggle("VFly", {Title = "Vehicle Fly (Sit First)", Default = false, Callback = noop})
Tabs.Movement:AddToggle("CarFling", {Title = "Car Fling (Sit First)", Default = false, Callback = noop})
Tabs.Movement:AddSlider("Jump", {
	Title = "Jump Power", Default = 50, Min = 50, Max = 400, Rounding = 0, Callback = noop,
})

-- ---------- Visuals ----------
Tabs.Visuals:AddToggle("ESP", {Title = "Player ESP (Names/Health/Distance)", Default = false, Callback = noop})
Tabs.Visuals:AddToggle("Chams", {Title = "Chams (See Players Through Walls)", Default = false, Callback = noop})
Tabs.Visuals:AddToggle("Xray", {Title = "X-Ray (See Through Walls)", Default = false, Callback = noop})
Tabs.Visuals:AddSlider("FOV", {
	Title = "Field of View", Default = 70, Min = 40, Max = 120, Rounding = 0, Callback = noop,
})
Tabs.Visuals:AddParagraph({
	Title = "Note",
	Content = "This is a preview build. None of these controls affect the game.",
})

-- ---------- Players ----------
Tabs.Players:AddDropdown("Target", {
	Title = "Target Player",
	Values = {"(refresh first)"},
	Multi = false, Default = 1, Callback = noop,
})
Tabs.Players:AddButton({Title = "Kill Target", Callback = noop})
Tabs.Players:AddButton({Title = "Bring Target", Callback = noop})
Tabs.Players:AddButton({Title = "Teleport To Target", Callback = noop})
Tabs.Players:AddInput("Chat", {
	Title = "Chat Message", Default = "", Placeholder = "Type chat message...",
	Numeric = false, Finished = false, Callback = noop,
})

Window:SelectTab(1)

Fluent:Notify({
	Title = "Fluent Preview",
	Content = "This is Fluent. Compare against Rayfield, then pick.",
	Duration = 6,
})
