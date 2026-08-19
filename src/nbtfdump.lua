-- ================================================================
-- Pebbleford Hub - NBTF Recon Dump
-- Reports how this game's WeaponsSystem actually stores ammo and
-- handles hits, so fixes can be written against the real structure
-- instead of guessed at. Output is printed, copied to the clipboard
-- and shown on screen.
-- v1.0
-- ================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local lines = {}
local function out(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	table.insert(lines, ok and msg or tostring(fmt))
end

out("=== NBTF RECON DUMP ===")
out("PlaceId: %s", tostring(game.PlaceId))

-- ---------- 1. WeaponsSystem folder + remotes ----------
local wsFolder = ReplicatedStorage:FindFirstChild("WeaponsSystem")
out("\n--- WeaponsSystem folder ---")
if not wsFolder then
	out("NOT FOUND in ReplicatedStorage")
else
	for _, child in ipairs(wsFolder:GetChildren()) do
		out("  %s (%s)", child.Name, child.ClassName)
	end
	local network = wsFolder:FindFirstChild("Network")
	if network then
		out("\n--- Network remotes ---")
		for _, r in ipairs(network:GetChildren()) do
			out("  %s (%s)", r.Name, r.ClassName)
		end
	end
end

-- ---------- 2. The live module table ----------
out("\n--- require(WeaponsSystem) ---")
local wsModule = nil
if wsFolder then
	local modScript = wsFolder:FindFirstChild("WeaponsSystem")
	if modScript and modScript:IsA("ModuleScript") then
		local ok, res = pcall(require, modScript)
		if ok then
			wsModule = res
			out("required OK, type=%s", type(res))
			if type(res) == "table" then
				for k, v in pairs(res) do
					out("  [%s] = %s", tostring(k), type(v))
				end
			end
		else
			out("require FAILED: %s", tostring(res))
		end
	else
		out("no WeaponsSystem ModuleScript inside the folder")
	end
end

-- ---------- 3. Live weapon objects (where ammo really lives) ----------
-- Any numeric field here is a candidate for the magazine count. Compare the
-- values against what the HUD shows to identify the right one.
out("\n--- live weapon objects ---")
local function dumpWeaponTable(label, weapon)
	out("  %s (type=%s)", label, type(weapon))
	if type(weapon) ~= "table" then return end
	for k, v in pairs(weapon) do
		local t = type(v)
		if t == "number" or t == "boolean" or t == "string" then
			out("      %s = %s (%s)", tostring(k), tostring(v), t)
		elseif t == "function" then
			out("      %s = function", tostring(k))
		elseif t == "userdata" then
			out("      %s = %s", tostring(k), tostring(v))
		else
			out("      %s = %s", tostring(k), t)
		end
	end
end

local found = 0
if type(wsModule) == "table" then
	local weapons = rawget(wsModule, "weapons")
	if type(weapons) == "table" then
		for key, weapon in pairs(weapons) do
			found = found + 1
			dumpWeaponTable("weapons[" .. tostring(key) .. "]", weapon)
		end
	else
		out("  wsModule.weapons is %s, not a table", type(weapons))
	end
end
if found == 0 then
	out("  none via the module; trying getgc")
	if type(getgc) == "function" then
		local hits = 0
		pcall(function()
			for _, obj in pairs(getgc(true)) do
				if type(obj) == "table" and hits < 4 then
					-- Anything carrying an ammo-ish key is likely a weapon object.
					for _, probe in ipairs({"ammoInWeapon", "ammoInReserve", "currentAmmo", "ammo"}) do
						if rawget(obj, probe) ~= nil then
							hits = hits + 1
							dumpWeaponTable("gc table #" .. hits, obj)
							break
						end
					end
				end
			end
		end)
		out("  getgc matches: %d", hits)
	else
		out("  getgc unavailable in this executor")
	end
end

-- ---------- 4. Equipped / carried tools ----------
out("\n--- tools and their Configuration ---")
local function dumpTool(tool, where)
	if not tool:IsA("Tool") then return end
	out("  %s [%s]", tool.Name, where)
	local attrs = tool:GetAttributes()
	if next(attrs) then
		out("    attributes:")
		for k, v in pairs(attrs) do
			out("      %s = %s", tostring(k), tostring(v))
		end
	end
	local config = tool:FindFirstChild("Configuration")
	if config then
		out("    Configuration:")
		for _, val in ipairs(config:GetChildren()) do
			out("      %s = %s (%s)", val.Name, tostring(val.Value), val.ClassName)
		end
	else
		out("    (no Configuration)")
	end
	-- Anything ammo-named living outside Configuration.
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("IntValue") or d:IsA("NumberValue") then
			if d.Name:lower():find("ammo") or d.Name:lower():find("clip") then
				out("      [loose] %s = %s", d:GetFullName(), tostring(d.Value))
			end
		end
	end
end

local char = LocalPlayer.Character
if char then
	for _, t in ipairs(char:GetChildren()) do dumpTool(t, "equipped") end
end
if LocalPlayer:FindFirstChild("Backpack") then
	for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do dumpTool(t, "backpack") end
end

out("\n=== END DUMP ===")

local text = table.concat(lines, "\n")
print(text)
pcall(function() setclipboard(text) end)

-- ---------- On-screen copy ----------
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("NBTFDump")
	if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "NBTFDump"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 560, 0, 420)
frame.Position = UDim2.new(0.5, -280, 0.5, -210)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 34)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "NBTF Recon Dump (copied to clipboard)"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 28, 0, 28)
close.Position = UDim2.new(1, -34, 0, 3)
close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.Font = Enum.Font.GothamBold
close.TextSize = 14
close.BorderSizePixel = 0
close.Parent = frame
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -20, 1, -46)
box.Position = UDim2.new(0, 10, 0, 38)
box.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
box.TextColor3 = Color3.fromRGB(220, 220, 220)
box.TextSize = 11
box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true
box.ClearTextOnFocus = false
box.MultiLine = true
box.Text = text
box.BorderSizePixel = 0
box.Parent = frame
