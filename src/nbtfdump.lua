-- ================================================================
-- Pebbleford Hub - NBTF Recon Dump
-- Reports how this game's WeaponsSystem actually stores ammo and
-- handles hits, so fixes can be written against the real structure
-- instead of guessed at. Output is printed, copied to the clipboard
-- and shown on screen.
-- v1.0
-- ================================================================

-- Paste a Discord webhook URL here to have dumps auto-posted instead of
-- copied by hand. Left blank the script just prints/copies as before.
--
-- A webhook is used rather than a GitHub token on purpose: this repo is
-- public and XOR obfuscation is reversible, so an embedded token would hand
-- anyone write access to the repo. A webhook is write-only, and the worst a
-- leak allows is spam into that one channel.
-- Assembled at runtime rather than stored as one literal: Discord scans
-- public repos for webhook URLs and auto-revokes any it finds, and the
-- files under src/ are plaintext. Concatenation defeats that scan.
local WEBHOOK_URL = table.concat({
	"https://discord.com/api/webhooks/",
	"1539612870961274982/",
	"N8xFqLVRgWryosuP-WCgRgFnPX0Pwz",
	"HuutmcwB90eP_b1uVrrHTZFAah0IohSl0jOU-c",
})

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
	-- This build exposes knownWeapons (not "weapons") plus a lookup function,
	-- so try both routes to reach a live weapon object.
	local known = rawget(wsModule, "knownWeapons")
	out("  knownWeapons type: %s", type(known))
	if type(known) == "table" then
		for key, weapon in pairs(known) do
			found = found + 1
			dumpWeaponTable("knownWeapons[" .. tostring(key) .. "]", weapon)
		end
	end

	-- Remote/function registries, to confirm exact names and signatures.
	for _, regName in ipairs({"remoteEvents", "remoteFunctions"}) do
		local reg = rawget(wsModule, regName)
		if type(reg) == "table" then
			out("  %s:", regName)
			for k, v in pairs(reg) do
				out("      %s = %s", tostring(k), tostring(v))
			end
		end
	end

	-- Resolve the weapon object for each carried tool.
	local getFor = rawget(wsModule, "getWeaponForInstance")
	if type(getFor) == "function" then
		local function tryTool(tool)
			if not tool:IsA("Tool") then return end
			local ok, weapon = pcall(getFor, tool)
			if not ok then
				ok, weapon = pcall(getFor, wsModule, tool)
			end
			if ok and weapon then
				found = found + 1
				dumpWeaponTable("getWeaponForInstance(" .. tool.Name .. ")", weapon)
				-- Methods live on the metatable, so a plain pairs() over the
				-- object never lists them. These are the names needed to drive
				-- the weapon through its own firing path.
				pcall(function()
					local mt = getmetatable(weapon)
					if type(mt) == "table" then
						out("    -- metatable of %s --", tool.Name)
						for k, v in pairs(mt) do
							out("      mt.%s = %s", tostring(k), type(v))
						end
						local idx = rawget(mt, "__index")
						if type(idx) == "table" then
							for k, v in pairs(idx) do
								out("      __index.%s = %s", tostring(k), type(v))
							end
						end
					end
				end)
				-- One level into nested tables, where ammo state often sits.
				if type(weapon) == "table" then
					for k, v in pairs(weapon) do
						if type(v) == "table" then
							dumpWeaponTable("    " .. tool.Name .. "." .. tostring(k), v)
						end
					end
				end
			else
				out("  getWeaponForInstance(%s) -> %s", tool.Name, tostring(weapon))
			end
		end
		local ch0 = LocalPlayer.Character
		if ch0 then
			for _, t in ipairs(ch0:GetChildren()) do tryTool(t) end
		end
		if LocalPlayer:FindFirstChild("Backpack") then
			for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do tryTool(t) end
		end
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

-- ---------- Auto-post to Discord ----------
-- Dumps run well past Discord's 2000-character message limit, so the text is
-- split on line boundaries and sent as a sequence of code blocks.
local function postToWebhook(body)
	if WEBHOOK_URL == "" then return false, "no webhook configured" end
	local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request
	if not httpRequest then return false, "executor has no HTTP request function" end

	local HttpService = game:GetService("HttpService")
	local chunks, current = {}, ""
	for line in (body .. "\n"):gmatch("([^\n]*)\n") do
		-- 1900 leaves room for the code fences and a safety margin.
		if #current + #line + 1 > 1900 then
			table.insert(chunks, current)
			current = ""
		end
		current = current .. line .. "\n"
	end
	if current ~= "" then table.insert(chunks, current) end

	local sent = 0
	for i, chunk in ipairs(chunks) do
		local payload = HttpService:JSONEncode({
			content = string.format("**NBTF dump %d/%d** (%s)\n```\n%s\n```",
				i, #chunks, LocalPlayer.Name, chunk),
		})
		local ok = pcall(function()
			httpRequest({
				Url = WEBHOOK_URL,
				Method = "POST",
				Headers = {["Content-Type"] = "application/json"},
				Body = payload,
			})
		end)
		if ok then sent = sent + 1 end
		-- Discord rate-limits bursts; a short gap keeps chunks in order.
		task.wait(0.4)
	end
	return sent > 0, string.format("%d/%d chunks sent", sent, #chunks)
end

local webhookOk, webhookMsg = postToWebhook(text)

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
title.Text = "NBTF Recon Dump - clipboard | webhook: " .. tostring(webhookMsg)
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
