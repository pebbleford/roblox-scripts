-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate("elected") then return end

-- ================================================================
-- Pebbleford Hub - Elected Admin Hub v1.3
-- Tool-Based Mining | Admin Commands | Building | Sign Editor
-- Player Control | Teleports | ESP | Anti-Jail | Remote Spy
-- Game uses Red networking (ReliableRedEvent) + ReplicaService
-- ================================================================

print("[SX Elected v1.3] Script loaded - EditSign remote discovery")

-- Cleanup old instance
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("SXElected")
	if old then old:Destroy() end
end)
pcall(function()
	local old = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if old then
		local o2 = old:FindFirstChild("SXElected")
		if o2 then o2:Destroy() end
	end
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===================== REMOTES =====================
-- This game uses Red networking library (ReliableRedEvent) for all game actions
-- and ReplicaService for state replication. There are NO individual MineEvent/BuildEvent/EditSignEvent remotes.
local RedEvent = nil -- ReplicatedStorage.ReliableRedEvent (main networking)
local ChatRemote = nil

-- Find the Red networking event
pcall(function()
	RedEvent = ReplicatedStorage:FindFirstChild("ReliableRedEvent")
end)

pcall(function()
	local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
	if chatEvents then ChatRemote = chatEvents:FindFirstChild("SayMessageRequest") end
end)

-- ===================== REMOTE SPY =====================
local remoteSpyActive = false
local remoteSpyHooks = {}

-- Deep print a table recursively for spy output
local function deepPrint(val, indent, visited)
	indent = indent or "  "
	visited = visited or {}

	if type(val) ~= "table" then
		if typeof(val) == "Instance" then
			return val.ClassName .. " '" .. val:GetFullName() .. "'"
		elseif type(val) == "string" then
			return '"' .. val:sub(1, 100) .. '"'
		else
			return tostring(val)
		end
	end

	-- Avoid infinite recursion
	if visited[val] then return "{...circular...}" end
	visited[val] = true

	local parts = {}
	local count = 0
	for k, v in pairs(val) do
		count = count + 1
		if count > 20 then
			table.insert(parts, indent .. "  ... (" .. count .. "+ entries)")
			break
		end
		local keyStr = type(k) == "number" and "[" .. k .. "]" or tostring(k)
		local valStr = deepPrint(v, indent .. "  ", visited)
		table.insert(parts, indent .. "  " .. keyStr .. " = " .. valStr)
	end

	if #parts == 0 then return "{}" end
	return "{\n" .. table.concat(parts, "\n") .. "\n" .. indent .. "}"
end

local function startRemoteSpy()
	remoteSpyActive = true
	print("[SX Elected] === REMOTE SPY STARTED ===")
	print("[SX Elected] Perform actions in-game and watch F9")

	-- Try multiple hooking methods in order of preference
	local hooked = false

	-- Method 1: hookmetamethod (best - catches all outgoing)
	pcall(function()
		if hookmetamethod and getnamecallmethod then
			local oldNamecall
			oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
				local method = getnamecallmethod()
				if remoteSpyActive and (method == "FireServer" or method == "InvokeServer") then
					print("[SPY-OUT] " .. method .. " -> " .. self:GetFullName())
					local args = {...}
					for i, arg in ipairs(args) do
						print("  arg" .. i .. " (" .. typeof(arg) .. "): " .. deepPrint(arg))
					end
				end
				return oldNamecall(self, ...)
			end)
			hooked = true
			print("[SX Elected] Spy: hookmetamethod active (full outgoing spy)")
		end
	end)

	-- Method 2: hookfunction on ReliableRedEvent.FireServer specifically
	if not hooked then
		pcall(function()
			if hookfunction and newcclosure and RedEvent then
				local oldFire = RedEvent.FireServer
				hookfunction(RedEvent.FireServer, newcclosure(function(self, ...)
					if remoteSpyActive then
						print("[SPY-OUT] ReliableRedEvent:FireServer()")
						local args = {...}
						for i, arg in ipairs(args) do
							print("  arg" .. i .. " (" .. typeof(arg) .. "): " .. deepPrint(arg))
						end
					end
					return oldFire(self, ...)
				end))
				hooked = true
				print("[SX Elected] Spy: hookfunction active (RedEvent outgoing spy)")
			end
		end)
	end

	-- Method 3: Listen to incoming events + deep print tables
	if not hooked then
		warn("[SX Elected] No outgoing hook available - incoming spy only")
		print("[SX Elected] TIP: Manually edit a sign and check what incoming data changes")
	end

	-- Always listen to incoming events with deep table printing
	pcall(function()
		if RedEvent then
			local conn = RedEvent.OnClientEvent:Connect(function(...)
				if remoteSpyActive then
					local args = {...}
					print("[SPY-IN] ReliableRedEvent received: " .. #args .. " args")
					for i, arg in ipairs(args) do
						print("  arg" .. i .. " (" .. typeof(arg) .. "): " .. deepPrint(arg))
					end
				end
			end)
			table.insert(remoteSpyHooks, function() conn:Disconnect() end)
		end
	end)

	-- Also spy on all other known remotes
	pcall(function()
		local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
		if remoteEvents then
			for _, remote in ipairs(remoteEvents:GetChildren()) do
				if remote:IsA("RemoteEvent") then
					local conn = remote.OnClientEvent:Connect(function(...)
						if remoteSpyActive then
							local args = {...}
							print("[SPY-IN] " .. remote.Name .. " received: " .. #args .. " args")
							for i, arg in ipairs(args) do
								print("  arg" .. i .. " (" .. typeof(arg) .. "): " .. deepPrint(arg))
							end
						end
					end)
					table.insert(remoteSpyHooks, function() conn:Disconnect() end)
				end
			end
		end
	end)
end

local function stopRemoteSpy()
	remoteSpyActive = false
	for _, cleanup in ipairs(remoteSpyHooks) do pcall(cleanup) end
	remoteSpyHooks = {}
	print("[SX Elected] === REMOTE SPY STOPPED ===")
end

-- TextChatService for modern chat
local TextChatService = nil
pcall(function() TextChatService = game:GetService("TextChatService") end)

-- ===================== CLICK SIMULATION =====================
local function mouse1click()
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
	task.wait(0.05)
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- ===================== COLOR PALETTE (Adminium Purple Theme) =====================
local COLORS = {
	bg = Color3.fromRGB(18, 14, 24),
	bgSecondary = Color3.fromRGB(26, 20, 34),
	panel = Color3.fromRGB(40, 32, 52),
	accent = Color3.fromRGB(160, 80, 255),
	accentHover = Color3.fromRGB(185, 120, 255),
	textPrimary = Color3.fromRGB(245, 240, 255),
	textSecondary = Color3.fromRGB(160, 150, 180),
	textDim = Color3.fromRGB(110, 100, 130),
	border = Color3.fromRGB(55, 42, 70),
	toggleOn = Color3.fromRGB(160, 80, 255),
	toggleOff = Color3.fromRGB(70, 60, 80),
	error = Color3.fromRGB(255, 68, 68),
	success = Color3.fromRGB(68, 255, 68),
	warning = Color3.fromRGB(255, 200, 60),
	admin = Color3.fromRGB(255, 215, 0),
}

-- ===================== STATE =====================
local autoMineActive = false
local autoUpgradeActive = false
local flyActive = false
local noclipActive = false
local speedBoostActive = false
local infJumpActive = false
local godModeActive = false
local espActive = false
local antiJailActive = false
local antiFlingActive = false
local antiAfkActive = false
local fullbrightActive = false
local autoCommandActive = false
local chatSpamActive = false
local signSpamActive = false

local flySpeed = 60
local speedValue = 50
local mineSpeed = 0.1
local windowVisible = true
local activeTab = "Mining"

-- Connections
local flyConnection = nil
local flyBV = nil
local flyBG = nil
local noclipConnection = nil
local speedBV = nil
local speedConnection = nil
local godModeConnection = nil
local antiJailConnection = nil
local antiFlingConnection = nil
local espHighlights = {}

-- Track last jail position to detect jailing
local lastKnownPos = nil

-- ===================== HELPERS =====================
local function getRoot()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function notify(title, msg)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = msg, Duration = 3})
	end)
end

local function getItemPosition(obj)
	if obj:IsA("Model") then
		local ok, cf = pcall(function() return obj:GetPivot() end)
		if ok and cf then return cf.Position end
		local part = obj:FindFirstChildWhichIsA("BasePart")
		if part then return part.Position end
	elseif obj:IsA("BasePart") then
		return obj.Position
	end
	return nil
end

local function getItemCFrame(obj)
	if obj:IsA("Model") then
		local ok, cf = pcall(function() return obj:GetPivot() end)
		if ok and cf then return cf end
		local part = obj:FindFirstChildWhichIsA("BasePart")
		if part then return part.CFrame end
	elseif obj:IsA("BasePart") then
		return obj.CFrame
	end
	return nil
end

-- Fire all ProximityPrompts on an object
local function fireAllPrompts(obj)
	local targets = {}
	pcall(function()
		if obj:IsA("ProximityPrompt") then table.insert(targets, obj) end
	end)
	pcall(function()
		for _, child in ipairs(obj:GetDescendants()) do
			if child:IsA("ProximityPrompt") then table.insert(targets, child) end
		end
	end)
	for _, prompt in ipairs(targets) do
		pcall(function()
			local oldHold = prompt.HoldDuration
			local oldDist = prompt.MaxActivationDistance
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 9999
			pcall(function() if fireproximityprompt then fireproximityprompt(prompt) end end)
			pcall(function() prompt:InputHoldBegin() task.wait(0.05) prompt:InputHoldEnd() end)
			prompt.HoldDuration = oldHold
			prompt.MaxActivationDistance = oldDist
		end)
	end
end

-- Send a chat message (used for admin commands)
local function sendChat(text)
	local sent = false
	-- Try modern TextChatService first
	pcall(function()
		if TextChatService then
			local channel = TextChatService:FindFirstChild("TextChannels")
			if channel then
				local rbxGeneral = channel:FindFirstChild("RBXGeneral")
				if rbxGeneral then
					rbxGeneral:SendAsync(text)
					sent = true
				end
			end
		end
	end)
	-- Fallback to legacy chat remote
	if not sent then
		pcall(function()
			if ChatRemote then
				ChatRemote:FireServer(text, "All")
				sent = true
			end
		end)
	end
	if not sent then
		warn("[SX Elected] Could not send chat: no chat system found")
	end
end

-- Send admin command (prepends ; if needed)
local function sendAdminCmd(cmd)
	if cmd:sub(1, 1) ~= ";" then
		cmd = ";" .. cmd
	end
	sendChat(cmd)
end

-- ===================== AUTO MINE =====================
-- Tool-based mining: equips pickaxe, TPs to Adminium, activates tool rapidly
-- The game uses Red networking (ReliableRedEvent) - mining goes through the tool's LocalScript
-- which fires the proper Red event when the tool is activated near Adminium

local function findMiningTool()
	-- Search backpack for any pickaxe/mining tool
	local char = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local searchNames = {"pickaxe", "pick", "mine", "axe", "hammer", "drill", "tool"}

	-- Check equipped tools first
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then
				local n = tool.Name:lower()
				for _, keyword in ipairs(searchNames) do
					if n:find(keyword) then return tool end
				end
			end
		end
	end

	-- Check backpack
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local n = tool.Name:lower()
				for _, keyword in ipairs(searchNames) do
					if n:find(keyword) then return tool end
				end
			end
		end
	end

	-- If no named mining tool found, return any tool from backpack
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then return tool end
		end
	end
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then return tool end
		end
	end

	return nil
end

local function equipTool(tool)
	if not tool then return end
	local char = LocalPlayer.Character
	local hum = getHumanoid()
	if not char or not hum then return end

	-- If tool is in backpack, equip it
	if tool.Parent == LocalPlayer:FindFirstChild("Backpack") then
		hum:EquipTool(tool)
		task.wait(0.1)
	end
end

local function findAdminium()
	-- Search workspace for Adminium
	local adminium = workspace:FindFirstChild("Adminium")
	if adminium then return adminium end

	-- Deep search
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name:lower():find("adminium") and (obj:IsA("Model") or obj:IsA("BasePart")) then
			return obj
		end
	end
	return nil
end

local function startAutoMine()
	autoMineActive = true

	task.spawn(function()
		local tool = findMiningTool()
		if tool then
			equipTool(tool)
			print("[SX Elected] Mining with tool: " .. tool.Name)
			notify("Auto Mine", "Mining with " .. tool.Name)
		else
			print("[SX Elected] No mining tool found - using click + ProximityPrompt only")
			notify("Auto Mine", "No tool found - using prompts + clicks")
		end

		-- Find Adminium
		local adminium = findAdminium()
		if adminium then
			print("[SX Elected] Found Adminium: " .. adminium:GetFullName())
		else
			print("[SX Elected] Adminium not found in workspace")
		end

		while autoMineActive do
			pcall(function()
				local char = LocalPlayer.Character
				local hrp = getRoot()
				local hum = getHumanoid()
				if not char or not hrp or not hum then return end

				-- Re-find adminium if needed
				if not adminium or not adminium.Parent then
					adminium = findAdminium()
				end

				-- Re-equip tool if it got unequipped
				tool = findMiningTool()
				if tool then equipTool(tool) end

				-- Fire ProximityPrompts on Adminium (works from any distance with fireproximityprompt)
				if adminium then
					fireAllPrompts(adminium)
				end

				-- Activate the tool (triggers the tool's LocalScript mining logic)
				if tool and tool.Parent == char then
					pcall(function() tool:Activate() end)
				end

				-- Also simulate a click
				mouse1click()
			end)
			task.wait(mineSpeed)
		end
	end)
end

local function stopAutoMine()
	autoMineActive = false
	notify("Auto Mine", "Stopped")
end

-- ===================== AUTO UPGRADE =====================
-- Automatically upgrades Adminium level when possible
-- Clicks upgrade buttons in the Adminium GUI

local function startAutoUpgrade()
	autoUpgradeActive = true
	task.spawn(function()
		while autoUpgradeActive do
			pcall(function()
				-- Search player GUI for upgrade buttons
				local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
				if playerGui then
					for _, gui in ipairs(playerGui:GetDescendants()) do
						if gui:IsA("TextButton") then
							local text = gui.Text:lower()
							if text:find("upgrade") or text:find("level up") then
								pcall(function()
									-- Simulate click on upgrade button
									firesignal(gui.MouseButton1Click)
								end)
							end
						end
					end
				end
			end)
			task.wait(2)
		end
	end)
	notify("Auto Upgrade", "Upgrading when possible!")
end

local function stopAutoUpgrade()
	autoUpgradeActive = false
end

-- ===================== ADMIN COMMAND HELPERS =====================
-- These fire admin commands via chat. Only work if you ARE the elected admin.

local function adminKill(target) sendAdminCmd(";kill " .. target) end
local function adminFly(target) sendAdminCmd(";fly " .. target) end
local function adminBtools(target) sendAdminCmd(";btools " .. target) end
local function adminSpeed(target, val) sendAdminCmd(";speed " .. target .. " " .. tostring(val or 100)) end
local function adminJumpPower(target, val) sendAdminCmd(";jumppower " .. target .. " " .. tostring(val or 200)) end
local function adminGod(target) sendAdminCmd(";god " .. target) end
local function adminBring(target) sendAdminCmd(";bring " .. target) end
local function adminGoto(target) sendAdminCmd(";goto " .. target) end
local function adminTeleport(p1, p2) sendAdminCmd(";teleport " .. p1 .. " " .. p2) end
local function adminFling(target) sendAdminCmd(";fling " .. target) end
local function adminJail(target) sendAdminCmd(";jail " .. target) end
local function adminKick(target) sendAdminCmd(";kick " .. target) end
local function adminRespawn(target) sendAdminCmd(";respawn " .. target) end
local function adminNoclip(target) sendAdminCmd(";noclip " .. target) end
local function adminGun(target) sendAdminCmd(";gun " .. target) end
local function adminSword(target) sendAdminCmd(";sword " .. target) end
local function adminMissile(target) sendAdminCmd(";missile " .. target) end
local function adminAirstrike(target) sendAdminCmd(";airstrike " .. target) end
local function adminMute(target) sendAdminCmd(";mute " .. target) end
local function adminCar(target) sendAdminCmd(";car " .. target) end
local function adminPlane(target) sendAdminCmd(";plane " .. target) end
local function adminDrone(target) sendAdminCmd(";drone " .. target) end

-- ===================== SIGN EDITOR =====================
-- Signs in Elected use the Red networking library
-- From BlockController: Network.Event("EditSign"):Client():Fire(signBlock, text)
-- No need to click signs or open GUIs - just fire the remote directly

local function findSigns(ownerOnly)
	local signs = {}
	local blocks = workspace:FindFirstChild("Blocks")
	if not blocks then return signs end

	local myId = LocalPlayer.UserId
	for _, block in ipairs(blocks:GetChildren()) do
		pcall(function()
			-- Check if this block has a SignTextBox (that's what makes it a sign)
			local hasST = false
			pcall(function()
				-- Signs have: Part > SignMesh > SurfaceGui > SignTextBox
				-- or: Part > SurfaceGui > SignTextBox
				for _, desc in ipairs(block:GetDescendants()) do
					if desc.Name == "SignTextBox" then
						hasST = true
						return
					end
				end
			end)
			if not hasST then return end

			if ownerOnly then
				local builtBy = nil
				pcall(function() builtBy = block:GetAttribute("BuiltBy") end)
				if builtBy == myId then
					table.insert(signs, block)
				end
			else
				table.insert(signs, block)
			end
		end)
	end
	return signs
end

-- Find the SignTextBox inside a sign block
-- Signs structure: Model > Part > SignMesh > SurfaceGui > SignTextBox
-- or: Model > Part > SurfaceGui > SignTextBox
local function findSignTextBox(sign)
	for _, desc in ipairs(sign:GetDescendants()) do
		if desc.Name == "SignTextBox" and desc:IsA("TextBox") then
			return desc
		end
	end
	return nil
end

-- Find the ClickDetector inside a sign block
local function findSignClickDetector(sign)
	for _, desc in ipairs(sign:GetDescendants()) do
		if desc:IsA("ClickDetector") then
			return desc
		end
	end
	return nil
end

-- EditSign via direct Red protocol (same as BuildBlock approach)
-- Identifiers stored as attributes on ReliableRedEvent
local editSignEvent = nil

local function getEditSignEvent(stb)
	if editSignEvent then return editSignEvent end

	local redEvent = ReplicatedStorage:FindFirstChild("ReliableRedEvent")
	if not redEvent then return nil end

	local editSignId = redEvent:GetAttribute("EditSign")
	if editSignId then
		editSignEvent = {
			Id = editSignId,
			Fire = function(self, ...)
				redEvent:FireServer({[self.Id] = {table.pack(...)}}, {})
			end
		}
		print("[SX Elected] EditSign event ready (direct fire, Id=" .. tostring(editSignId) .. ")")
		return editSignEvent
	end

	-- Fallback: original getconnections approach
	pcall(function()
		if not getconnections or not getupvalues then return end
		local conns = getconnections(stb.FocusLost)
		if #conns == 0 then return end
		local func = conns[1].Function
		if not func then return end
		local upvals = getupvalues(func)
		for i, v in pairs(upvals) do
			if typeof(v) == "table" and v.Fire then
				editSignEvent = v
				print("[SX Elected] EditSign event from FocusLost upvalues")
				break
			end
		end
	end)

	return editSignEvent
end

-- Edit a single sign using the extracted Red client event
-- From BlockController: EditSignClient:Fire(signBlock, text)
local function editSignText(sign, newText)
	local stb = findSignTextBox(sign)
	if not stb then
		print("[SX Elected] No SignTextBox in: " .. sign:GetFullName())
		return false
	end

	-- Get the inner part that BlockController uses as the sign reference
	-- Signs: Model > Part > SignMesh > SurfaceGui > SignTextBox
	-- The handler passes the Part (parent of SignMesh or SurfaceGui) to Fire()
	local signPart = stb.Parent -- SurfaceGui
	if signPart then signPart = signPart.Parent end -- SignMesh or Part
	if signPart and signPart:IsA("MeshPart") then signPart = signPart.Parent end -- Part
	if not signPart then signPart = sign end

	-- Method 1: Use extracted EditSign client event
	local evt = getEditSignEvent(stb)
	if evt and evt.Fire then
		local ok, err = pcall(function()
			evt:Fire(signPart, newText)
		end)
		if ok then
			stb.Text = newText -- update local display too
			print("[SX Elected] Method 1 OK: evt:Fire for " .. sign.Name .. " part=" .. signPart:GetFullName())
			return true
		else
			print("[SX Elected] Method 1 FAIL: " .. tostring(err))
		end
	end

	-- Method 2: Try with the outer Model instead
	if evt and evt.Fire and signPart ~= sign then
		local ok, err = pcall(function()
			evt:Fire(sign, newText)
		end)
		if ok then
			stb.Text = newText
			print("[SX Elected] Method 2 OK: evt:Fire with model for " .. sign.Name)
			return true
		else
			print("[SX Elected] Method 2 FAIL: " .. tostring(err))
		end
	end

	-- Method 3: CaptureFocus -> set text -> ReleaseFocus (triggers real FocusLost signal)
	local method3OK = false
	pcall(function()
		stb:CaptureFocus()
		task.wait(0.15)
		stb.Text = newText
		task.wait(0.15)
		stb:ReleaseFocus(true)
		method3OK = (stb.Text == newText)
		print("[SX Elected] Method 3: CaptureFocus -> ReleaseFocus for " .. sign.Name)
	end)

	return method3OK
end

-- Decompile the Network/Red modules to find event identifier mapping
local function decompileNetworkModule()
	print("[SX Elected] === DECOMPILE NETWORK MODULE ===")
	local log = {}
	local function L(t) table.insert(log, t) print(t) end

	-- Try to decompile ReplicatedStorage.Shared.Network
	local locations = {
		{ReplicatedStorage, "Shared", "Network"},
		{ReplicatedStorage, "Shared", "Red"},
		{game:GetService("ReplicatedFirst"), "Shared", "Network"},
		{game:GetService("ReplicatedFirst"), "Shared", "Red"},
	}

	for _, path in ipairs(locations) do
		pcall(function()
			local current = path[1]
			for i = 2, #path do
				current = current:FindFirstChild(path[i])
				if not current then return end
			end
			if current and current:IsA("ModuleScript") and decompile then
				L("\n--- " .. current:GetFullName() .. " ---")
				local src = decompile(current)
				if src then
					local lines = 0
					for line in src:gmatch("[^\n]+") do
						lines = lines + 1
						if lines <= 100 then
							L(line)
						end
					end
					if lines > 100 then L("... (" .. lines .. " total lines)") end
				else
					L("  decompile returned nil")
				end
			end
		end)
	end

	-- Also decompile BlockController to see full sign edit code
	pcall(function()
		local bc = game:GetService("ReplicatedFirst"):FindFirstChild("Controllers")
		if bc then bc = bc:FindFirstChild("BlockController") end
		if bc and bc:IsA("ModuleScript") and decompile then
			L("\n--- BlockController (first 150 lines) ---")
			local src = decompile(bc)
			if src then
				local lines = 0
				for line in src:gmatch("[^\n]+") do
					lines = lines + 1
					if lines <= 150 then L(line) end
				end
				if lines > 150 then L("... (" .. lines .. " total lines)") end
			end
		end
	end)

	pcall(function()
		local output = table.concat(log, "\n")
		writefile("SXNetworkDecompile.txt", output)
		L("\nSaved to workspace/SXNetworkDecompile.txt")
		notify("Decompile", "Saved to SXNetworkDecompile.txt")
	end)
end

-- Edit all signs (own or all)
local function editAllSigns(newText, ownerOnly)
	local signs = findSigns(ownerOnly or false)
	if #signs == 0 then
		notify("Signs", "No signs found")
		return
	end

	notify("Signs", "Editing " .. #signs .. " signs...")
	local count = 0
	for i, sign in ipairs(signs) do
		pcall(function()
			if editSignText(sign, newText) then
				count = count + 1
			end
		end)
		if i < #signs then task.wait(0.3) end
	end
	notify("Signs", "Edited " .. count .. "/" .. #signs .. " signs")
end

-- Edit slogan via Red network event "UpdateSlogan" (separate from sign text)
-- Red library fires via: ReliableRedEvent:FireServer({["UpdateSlogan"] = {slogan, banner}})
local function editSlogan(sloganText, bannerText)
	bannerText = bannerText or ""
	if not RedEvent then
		notify("Slogan", "ReliableRedEvent not found!")
		return
	end
	local fired = false
	pcall(function()
		RedEvent:FireServer({["UpdateSlogan"] = {sloganText, bannerText}})
		fired = true
		print("[SX Elected] UpdateSlogan fired: '" .. sloganText .. "'")
	end)
	if fired then
		pcall(function() LocalPlayer:SetAttribute("Slogan", sloganText) end)
		notify("Slogan", "Updated: " .. sloganText:sub(1, 30))
	else
		notify("Slogan", "Failed to fire UpdateSlogan")
	end
end

-- ===================== SIGN DISCOVERY =====================
-- Comprehensive scan to figure out how sign editing actually works in this game

local function discoverSignMethod()
	local log = {}
	local function L(text)
		table.insert(log, text)
		print(text)
	end
	local function saveLog()
		pcall(function()
			writefile("SXElectedDiscovery.txt", table.concat(log, "\n"))
		end)
	end

	L("=== SIGN DISCOVERY v3 ===")

	-- Helper: scan a container for modules, decompile, find events + sign refs
	local eventNames = {}
	local signRefs = {}
	local scanned = 0

	local function scanContainer(container, label)
		L("\n--- Scanning: " .. label .. " ---")
		local descs = {}
		pcall(function() descs = container:GetDescendants() end)
		local count = 0
		for _, desc in ipairs(descs) do
			pcall(function()
				if desc:IsA("ModuleScript") or desc:IsA("LocalScript") then
					count = count + 1
					scanned = scanned + 1
					if scanned % 10 == 0 then
						L("  [progress: " .. scanned .. " scripts scanned...]")
						saveLog()
					end
					pcall(function()
						if decompile then
							local src = decompile(desc)
							if src then
								-- Find Red event names
								for eventName in src:gmatch('[Ee]vent%(%s*"([^"]+)"%s*%)') do
									if not eventNames[eventName] then
										eventNames[eventName] = desc:GetFullName()
										L("  Event: \"" .. eventName .. "\" in " .. desc.Name)
									end
								end
								-- Find sign-related references
								local low = src:lower()
								if low:find("signtext") or low:find("sign_text") or low:find("editsign") or low:find("edit_sign") or low:find("updatesign") or low:find("update_sign") or low:find("setsign") or low:find("set_sign") or low:find("signbox") then
									L("  ** SIGN REF in: " .. desc:GetFullName())
									table.insert(signRefs, desc:GetFullName())
									for line in src:gmatch("[^\n]+") do
										local ll = line:lower()
										if ll:find("signtext") or ll:find("sign_text") or ll:find("editsign") or ll:find("updatesign") or ll:find("setsign") or ll:find("signbox") then
											L("    >> " .. line:sub(1, 200))
										end
									end
								end
								-- Also look for "Sign" as an event name specifically
								for eventName in src:gmatch('[Ee]vent%(%s*"([^"]+)"%s*%)') do
									local el = eventName:lower()
									if el:find("sign") or el:find("block") or el:find("edit") or el:find("build") or el:find("text") or el:find("place") or el:find("update") then
										L("  ** INTERESTING EVENT: \"" .. eventName .. "\" in " .. desc:GetFullName())
									end
								end
							end
						end
					end)
				end
			end)
		end
		L("  Scanned " .. count .. " scripts in " .. label)
	end

	-- Scan targeted locations (NOT game:GetDescendants which hangs)
	scanContainer(game:GetService("ReplicatedFirst"), "ReplicatedFirst")
	saveLog()

	pcall(function() scanContainer(ReplicatedStorage, "ReplicatedStorage") end)
	saveLog()

	pcall(function() scanContainer(game:GetService("StarterPlayer"), "StarterPlayer") end)
	saveLog()

	pcall(function() scanContainer(game:GetService("StarterGui"), "StarterGui") end)
	saveLog()

	-- Try ServerScriptService (usually blocked but worth trying)
	pcall(function() scanContainer(game:GetService("ServerScriptService"), "ServerScriptService") end)
	saveLog()

	-- Event summary
	L("\n--- ALL EVENT NAMES SUMMARY ---")
	local allNames = {}
	for name, source in pairs(eventNames) do
		table.insert(allNames, name)
	end
	table.sort(allNames)
	for _, name in ipairs(allNames) do
		L("  \"" .. name .. "\" -> " .. eventNames[name])
	end
	L("  Total unique events: " .. #allNames)

	-- Sign refs summary
	L("\n--- SIGN REFERENCES SUMMARY ---")
	if #signRefs == 0 then
		L("  No sign text references found in scanned modules")
	else
		for _, ref in ipairs(signRefs) do
			L("  " .. ref)
		end
	end

	-- Also check: what happens when you click a sign? Check the ClickDetector connections
	L("\n--- SIGN CLICKDETECTOR CONNECTIONS ---")
	pcall(function()
		local blocks = workspace:FindFirstChild("Blocks")
		if blocks then
			local checked = 0
			for _, block in ipairs(blocks:GetChildren()) do
				if checked >= 5 then break end
				pcall(function()
					local cd = block:FindFirstChildWhichIsA("ClickDetector", true)
					if cd then
						checked = checked + 1
						L("  Sign: " .. block.Name .. " | ClickDetector at " .. cd:GetFullName())
						L("    MaxDist: " .. tostring(cd.MaxActivationDistance))
						pcall(function()
							if getconnections then
								local conns = getconnections(cd.MouseClick)
								L("    MouseClick connections: " .. #conns)
								for ci, conn in ipairs(conns) do
									if ci > 3 then break end
									pcall(function()
										L("      [" .. ci .. "] func: " .. tostring(conn.Function))
										if conn.Function and decompile then
											local fsrc = decompile(conn.Function)
											if fsrc then
												L("      -- DECOMPILED CONNECTION --")
												local lines = 0
												for line in fsrc:gmatch("[^\n]+") do
													lines = lines + 1
													if lines <= 30 then
														L("      " .. line)
													end
												end
												if lines > 30 then
													L("      ... (" .. lines .. " total lines)")
												end
											end
										end
									end)
								end
							end
						end)
					end
				end)
			end
		end
	end)

	-- Check what GUI appears when interacting with a sign (BuildFrame?)
	L("\n--- BUILD/SIGN GUI SEARCH ---")
	pcall(function()
		local gui = LocalPlayer:FindFirstChild("PlayerGui")
		if gui then
			for _, desc in ipairs(gui:GetDescendants()) do
				pcall(function()
					local n = desc.Name:lower()
					if n:find("sign") or n:find("build") or n:find("edit") or n:find("lectern") then
						L("  " .. desc.ClassName .. ": " .. desc:GetFullName())
						if desc:IsA("TextBox") or desc:IsA("TextLabel") then
							L("    Text: " .. tostring(desc.Text):sub(1, 100))
						end
						if desc:IsA("GuiObject") then
							L("    Visible: " .. tostring(desc.Visible) .. " | Size: " .. tostring(desc.Size))
						end
					end
				end)
			end
		end
	end)

	L("\n=== END SIGN DISCOVERY v3 ===")
	L("Total scripts scanned: " .. scanned)
	saveLog()
	notify("Discovery", "Done! Saved to SXElectedDiscovery.txt (F9 for details)")
end

-- ===================== BUILDING SYSTEM =====================
-- Building in Elected works through the BuildingTool + Red networking
-- The client-side tool handles placement and sends data via ReliableRedEvent
-- We interact with the building system by:
-- 1. Equipping the building tool
-- 2. Selecting blocks through the tool's UI
-- 3. Activating at positions

local function findBuildingTool()
	local char = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local searchNames = {"build", "place", "hammer", "wrench"}

	-- Check equipped
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then
				local n = tool.Name:lower()
				for _, keyword in ipairs(searchNames) do
					if n:find(keyword) then return tool end
				end
			end
		end
	end

	-- Check backpack
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local n = tool.Name:lower()
				for _, keyword in ipairs(searchNames) do
					if n:find(keyword) then return tool end
				end
			end
		end
	end

	return nil
end

local function placeBlockAt(cframe, blockName)
	-- Try to use ReliableRedEvent directly if we can figure out the format
	-- Otherwise, use the building tool
	local tool = findBuildingTool()
	if tool then
		equipTool(tool)
		task.wait(0.1)
		-- The building tool places blocks where you click
		-- We move the character to the position and activate the tool
		local char = LocalPlayer.Character
		if char then
			local savedCF = char:GetPivot()
			char:PivotTo(cframe)
			task.wait(0.05)
			pcall(function() tool:Activate() end)
			mouse1click()
			task.wait(0.05)
			char:PivotTo(savedCF)
		end
	else
		notify("Error", "No building tool found! Equip one first.")
	end
end

-- ===================== CLIENT-SIDE FLING =====================
-- Spins your character at high velocity into a target player to fling them

local function flingPlayer(targetPlayer)
	if not targetPlayer or not targetPlayer.Character then
		notify("Error", targetPlayer and (targetPlayer.DisplayName .. " has no character") or "No target")
		return
	end
	local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not targetHRP then
		notify("Error", "Target has no HumanoidRootPart")
		return
	end

	local myChar = LocalPlayer.Character
	local myHRP = getRoot()
	if not myChar or not myHRP then return end

	local savedCF = myHRP.CFrame
	notify("Fling", "Flinging " .. targetPlayer.DisplayName .. "...")

	task.spawn(function()
		-- TP to target and spin at high velocity
		local av = Instance.new("BodyAngularVelocity")
		av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		av.AngularVelocity = Vector3.new(0, 9999, 0)
		av.P = 1000000
		av.Parent = myHRP

		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.P = 9000
		bv.Parent = myHRP

		-- Ram into them for 1.5 seconds
		local startTime = tick()
		while tick() - startTime < 1.5 do
			pcall(function()
				if not targetHRP or not targetHRP.Parent then return end
				local dir = (targetHRP.Position - myHRP.Position).Unit
				bv.Velocity = dir * 500
				myHRP.CFrame = CFrame.new(targetHRP.Position + dir * -3)
			end)
			task.wait()
		end

		-- Cleanup and return
		pcall(function() av:Destroy() end)
		pcall(function() bv:Destroy() end)

		task.wait(0.2)
		pcall(function()
			local root = getRoot()
			if root then root.CFrame = savedCF end
		end)
		notify("Fling", "Flung " .. targetPlayer.DisplayName .. "!")
	end)
end

-- ===================== ANTI-JAIL =====================
-- Detects when player gets jailed (sudden teleport to jail cell) and teleports back

local function startAntiJail()
	antiJailActive = true
	local hrp = getRoot()
	if hrp then lastKnownPos = hrp.CFrame end

	antiJailConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not antiJailActive then return end
			local root = getRoot()
			if not root then return end

			-- Update position every frame
			-- If we suddenly teleport far (jailed), teleport back
			if lastKnownPos then
				local dist = (root.Position - lastKnownPos.Position).Magnitude
				-- Jail detection: sudden move > 50 studs that we didn't cause
				if dist > 50 and not flyActive then
					-- Check if we're in a small enclosed space (jail cell)
					task.wait(0.2)
					root.CFrame = lastKnownPos
					notify("Anti-Jail", "Broke out of jail!")
				end
			end
			lastKnownPos = root.CFrame
		end)
	end)
	notify("Anti-Jail", "Active - will break out automatically")
end

local function stopAntiJail()
	antiJailActive = false
	if antiJailConnection then antiJailConnection:Disconnect() antiJailConnection = nil end
end

-- ===================== ANTI-FLING =====================
-- Prevents fling by anchoring or clamping velocity

local function startAntiFling()
	antiFlingActive = true
	antiFlingConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not antiFlingActive then return end
			local root = getRoot()
			if not root then return end
			-- Clamp velocity to prevent fling
			if root.AssemblyLinearVelocity.Magnitude > 100 then
				root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end
		end)
	end)
	notify("Anti-Fling", "Fling protection active!")
end

local function stopAntiFling()
	antiFlingActive = false
	if antiFlingConnection then antiFlingConnection:Disconnect() antiFlingConnection = nil end
end

-- ===================== FLY =====================
local function startFly()
	local hrp = getRoot()
	local hum = getHumanoid()
	if not hrp or not hum then return end

	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	flyBV.Velocity = Vector3.new(0, 0, 0)
	flyBV.P = 9000
	flyBV.Parent = hrp

	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	flyBG.P = 9000
	flyBG.CFrame = hrp.CFrame
	flyBG.Parent = hrp

	flyConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not flyBV or not flyBV.Parent then return end
			local moveVec = Vector3.zero
			local camCF = camera.CFrame
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + camCF.UpVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - camCF.UpVector end
			flyBV.Velocity = moveVec.Magnitude > 0 and moveVec.Unit * flySpeed or Vector3.zero
			flyBG.CFrame = camCF
		end)
	end)
end

local function stopFly()
	if flyConnection then flyConnection:Disconnect() flyConnection = nil end
	if flyBV then pcall(function() flyBV:Destroy() end) flyBV = nil end
	if flyBG then pcall(function() flyBG:Destroy() end) flyBG = nil end
end

-- ===================== NOCLIP =====================
local function startNoclip()
	noclipConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			local h = char:FindFirstChild("HumanoidRootPart")
			if h then h.CanCollide = false end
			local t = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
			if t then t.CanCollide = false end
		end)
	end)
end

local function stopNoclip()
	if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
end

-- ===================== SPEED BOOST =====================
local function startSpeedBoost()
	local hrp = getRoot()
	if not hrp then return end

	speedBV = Instance.new("BodyVelocity")
	speedBV.MaxForce = Vector3.new(math.huge, 0, math.huge)
	speedBV.Velocity = Vector3.new(0, 0, 0)
	speedBV.P = 9000
	speedBV.Parent = hrp

	speedConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local rt = getRoot()
			local hum = getHumanoid()
			if not rt or not hum then return end
			if not speedBV or not speedBV.Parent then return end
			local moveDir = hum.MoveDirection
			if moveDir.Magnitude > 0 then
				speedBV.Velocity = Vector3.new(moveDir.X, 0, moveDir.Z).Unit * speedValue
			else
				speedBV.Velocity = Vector3.new(0, 0, 0)
			end
		end)
	end)
end

local function stopSpeedBoost()
	if speedConnection then speedConnection:Disconnect() speedConnection = nil end
	if speedBV then pcall(function() speedBV:Destroy() end) speedBV = nil end
end

-- ===================== INFINITE JUMP =====================
local function startInfJump() infJumpActive = true end

UserInputService.JumpRequest:Connect(function()
	if infJumpActive then
		pcall(function()
			local hum = getHumanoid()
			if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	end
end)

-- ===================== GOD MODE =====================
local function startGodMode()
	godModeConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local hum = getHumanoid()
			if hum then
				hum.Health = hum.MaxHealth
				hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			end
		end)
	end)
end

local function stopGodMode()
	if godModeConnection then godModeConnection:Disconnect() godModeConnection = nil end
	pcall(function()
		local hum = getHumanoid()
		if hum then
			hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		end
	end)
end

-- ===================== ESP =====================
local function clearESP()
	for _, h in pairs(espHighlights) do pcall(function() h:Destroy() end) end
	espHighlights = {}
end

local function updateESP()
	clearESP()
	if not espActive then return end

	local hrp = getRoot()

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			pcall(function()
				local pHRP = player.Character:FindFirstChild("HumanoidRootPart")
				local pHum = player.Character:FindFirstChildOfClass("Humanoid")
				if not pHRP or not pHum then return end
				local dist = hrp and math.floor((pHRP.Position - hrp.Position).Magnitude) or 0

				if not player.Character:FindFirstChild("ESP_HL") then
					local hl = Instance.new("Highlight")
					hl.Name = "ESP_HL"
					hl.Adornee = player.Character
					hl.FillColor = Color3.fromRGB(160, 80, 255)
					hl.FillTransparency = 0.5
					hl.OutlineColor = Color3.new(1, 1, 1)
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Parent = player.Character
					table.insert(espHighlights, hl)
				end

				if not player.Character:FindFirstChild("ESP_BB") then
					local bb = Instance.new("BillboardGui")
					bb.Name = "ESP_BB"
					bb.AlwaysOnTop = true
					bb.Size = UDim2.new(4, 0, 0.8, 0)
					bb.StudsOffset = Vector3.new(0, 3.5, 0)
					bb.Adornee = pHRP
					bb.Parent = player.Character
					table.insert(espHighlights, bb)

					local lbl = Instance.new("TextLabel")
					lbl.Text = player.DisplayName .. " [" .. dist .. "m]\nHP: " .. math.floor(pHum.Health) .. "/" .. math.floor(pHum.MaxHealth)
					lbl.TextColor3 = COLORS.textPrimary
					lbl.TextStrokeTransparency = 0
					lbl.TextSize = 12
					lbl.Font = Enum.Font.GothamBold
					lbl.BackgroundTransparency = 1
					lbl.Size = UDim2.new(1, 0, 1, 0)
					lbl.Parent = bb
				end
			end)
		end
	end
end

local function startESP()
	task.spawn(function()
		while espActive do updateESP() task.wait(2) end
	end)
end

-- ===================== FULLBRIGHT =====================
local savedLighting = {}

local function enableFullbright()
	local Lighting = game:GetService("Lighting")
	savedLighting.Brightness = Lighting.Brightness
	savedLighting.ClockTime = Lighting.ClockTime
	savedLighting.FogEnd = Lighting.FogEnd
	savedLighting.GlobalShadows = Lighting.GlobalShadows
	savedLighting.OutdoorAmbient = Lighting.OutdoorAmbient

	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = false
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end

local function disableFullbright()
	local Lighting = game:GetService("Lighting")
	if savedLighting.Brightness then Lighting.Brightness = savedLighting.Brightness end
	if savedLighting.ClockTime then Lighting.ClockTime = savedLighting.ClockTime end
	if savedLighting.FogEnd then Lighting.FogEnd = savedLighting.FogEnd end
	if savedLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = savedLighting.GlobalShadows end
	if savedLighting.OutdoorAmbient then Lighting.OutdoorAmbient = savedLighting.OutdoorAmbient end
end

-- ===================== ANTI-AFK =====================
local function startAntiAfk()
	antiAfkActive = true
	pcall(function()
		if getconnections then
			for _, conn in pairs(getconnections(LocalPlayer.Idled)) do conn:Disable() end
		end
	end)
	task.spawn(function()
		while antiAfkActive do
			pcall(function()
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
				task.wait(0.1)
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
			end)
			task.wait(300)
		end
	end)
	notify("Anti-AFK", "AFK prevention active!")
end

local function stopAntiAfk() antiAfkActive = false end

-- ===================== CHAT SPAM =====================
local spamText = "Elected Admin Hub on top"

local function startChatSpam()
	chatSpamActive = true
	task.spawn(function()
		while chatSpamActive do
			sendChat(spamText)
			task.wait(1.5) -- Chat cooldown
		end
	end)
	notify("Chat Spam", "Spamming chat!")
end

local function stopChatSpam()
	chatSpamActive = false
	notify("Chat Spam", "Stopped")
end

-- ===================== WORD BUILDER =====================
-- Builds text out of blocks in the game world
-- Each letter is a 5x5 pixel grid made of blocks

local LETTER_PIXELS = {
	A = {"01110","10001","11111","10001","10001"},
	B = {"11110","10001","11110","10001","11110"},
	C = {"01111","10000","10000","10000","01111"},
	D = {"11110","10001","10001","10001","11110"},
	E = {"11111","10000","11110","10000","11111"},
	F = {"11111","10000","11110","10000","10000"},
	G = {"01111","10000","10011","10001","01110"},
	H = {"10001","10001","11111","10001","10001"},
	I = {"11111","00100","00100","00100","11111"},
	J = {"00111","00010","00010","10010","01100"},
	K = {"10001","10010","11100","10010","10001"},
	L = {"10000","10000","10000","10000","11111"},
	M = {"10001","11011","10101","10001","10001"},
	N = {"10001","11001","10101","10011","10001"},
	O = {"01110","10001","10001","10001","01110"},
	P = {"11110","10001","11110","10000","10000"},
	Q = {"01110","10001","10101","10010","01101"},
	R = {"11110","10001","11110","10010","10001"},
	S = {"01111","10000","01110","00001","11110"},
	T = {"11111","00100","00100","00100","00100"},
	U = {"10001","10001","10001","10001","01110"},
	V = {"10001","10001","10001","01010","00100"},
	W = {"10001","10001","10101","11011","10001"},
	X = {"10001","01010","00100","01010","10001"},
	Y = {"10001","01010","00100","00100","00100"},
	Z = {"11111","00010","00100","01000","11111"},
	["0"] = {"01110","10011","10101","11001","01110"},
	["1"] = {"00100","01100","00100","00100","01110"},
	["2"] = {"01110","10001","00110","01000","11111"},
	["3"] = {"11110","00001","01110","00001","11110"},
	["4"] = {"10010","10010","11111","00010","00010"},
	["5"] = {"11111","10000","11110","00001","11110"},
	["6"] = {"01110","10000","11110","10001","01110"},
	["7"] = {"11111","00001","00010","00100","01000"},
	["8"] = {"01110","10001","01110","10001","01110"},
	["9"] = {"01110","10001","01111","00001","01110"},
	["!"] = {"00100","00100","00100","00000","00100"},
	["?"] = {"01110","10001","00110","00000","00100"},
	[" "] = {"00000","00000","00000","00000","00000"},
}

local wordBlockSize = 3 -- studs per pixel (Normal blocks are 3x3x3)

-- BuildBlock via direct Red protocol
-- From Red decompile: identifiers stored as ATTRIBUTES on ReliableRedEvent
-- Fire format: ReliableRedEvent:FireServer({[id] = {table.pack(args)}}, {})
-- BuildBlock args: (cframe, blockTemplate, colorData, scaleMode)
local buildBlockEvent = nil
local buildBlockRef = nil

local function getBuildBlockEvent()
	if buildBlockEvent then return buildBlockEvent end

	pcall(function()
		buildBlockRef = game:GetService("ReplicatedStorage").Assets.Blocks.Block
	end)

	local redEvent = ReplicatedStorage:FindFirstChild("ReliableRedEvent")
	if not redEvent then
		print("[SX Elected] ReliableRedEvent not found")
		return nil
	end

	-- Red stores identifiers as attributes on ReliableRedEvent
	local buildBlockId = redEvent:GetAttribute("BuildBlock")

	if not buildBlockId then
		print("[SX Elected] BuildBlock attribute not found on ReliableRedEvent")
		print("[SX Elected] All attributes on ReliableRedEvent:")
		pcall(function()
			for name, value in pairs(redEvent:GetAttributes()) do
				print("[SX Elected]   '" .. name .. "' = '" .. tostring(value) .. "' (type=" .. typeof(value) .. ", len=" .. #tostring(value) .. ")")
			end
		end)
		return nil
	end

	print("[SX Elected] BuildBlock Id: '" .. tostring(buildBlockId) .. "' (len=" .. #buildBlockId .. ")")
	print("[SX Elected] Block ref: " .. tostring(buildBlockRef))

	buildBlockEvent = {
		Id = buildBlockId,
		Fire = function(self, ...)
			redEvent:FireServer({[self.Id] = {table.pack(...)}}, {})
		end
	}

	print("[SX Elected] BuildBlock event ready")
	return buildBlockEvent
end

-- Test fire a single block in front of player
local function testBuildBlock()
	local hrp = getRoot()
	if not hrp then notify("Error", "No character") return end

	local evt = getBuildBlockEvent()
	if not evt then
		notify("Error", "BuildBlock not found - check F9")
		return
	end

	local blockRef = buildBlockRef
	if not blockRef then
		pcall(function()
			blockRef = game:GetService("ReplicatedStorage").Assets.Blocks.Block
		end)
	end
	if not blockRef then
		notify("Error", "Block template not found")
		return
	end

	-- Place one block 10 studs in front, grid-snapped
	local pos = hrp.Position + hrp.CFrame.LookVector * 10 + Vector3.new(0, 3, 0)
	pos = Vector3.new(
		math.floor(pos.X / 3 + 0.5) * 3,
		math.floor(pos.Y / 3 + 0.5) * 3,
		math.floor(pos.Z / 3 + 0.5) * 3
	)
	local cf = CFrame.new(pos)

	print("[SX Elected] === TEST BUILD ===")
	print("[SX Elected] CFrame: " .. tostring(cf))
	print("[SX Elected] Block: " .. tostring(blockRef) .. " (" .. blockRef.ClassName .. ")")
	print("[SX Elected] Id: '" .. tostring(evt.Id) .. "'")

	-- Try multiple fire formats to find which one works
	local redEvent = ReplicatedStorage.ReliableRedEvent

	-- Format A: Our wrapper (batched format with table.pack)
	local okA, errA = pcall(function()
		evt:Fire(cf, blockRef, nil, "Normal")
	end)
	print("[SX Elected] Format A (batched+pack): " .. (okA and "OK" or "ERR: " .. tostring(errA)))

	task.wait(0.2)

	-- Format B: Single packed args without outer array
	local okB, errB = pcall(function()
		redEvent:FireServer({[evt.Id] = table.pack(cf, blockRef, nil, "Normal")}, {})
	end)
	print("[SX Elected] Format B (pack no array): " .. (okB and "OK" or "ERR: " .. tostring(errB)))

	task.wait(0.2)

	-- Format C: Simple array (no table.pack)
	local okC, errC = pcall(function()
		redEvent:FireServer({[evt.Id] = {{cf, blockRef, nil, "Normal"}}}, {})
	end)
	print("[SX Elected] Format C (plain array): " .. (okC and "OK" or "ERR: " .. tostring(errC)))

	task.wait(0.2)

	-- Format D: No second arg
	local okD, errD = pcall(function()
		redEvent:FireServer({[evt.Id] = {table.pack(cf, blockRef, nil, "Normal")}})
	end)
	print("[SX Elected] Format D (no call arg): " .. (okD and "OK" or "ERR: " .. tostring(errD)))

	notify("Test", "4 formats tried - check F9 and look for a block in front of you")
end

-- Dump BuildController decompile to find exact Fire arguments
local function dumpBuildController()
	print("[SX Elected] === DUMP BUILD CONTROLLER ===")
	local log = {}
	pcall(function()
		if not decompile then print("[SX Elected] decompile not available") return end
		local bc = game:GetService("ReplicatedFirst")
		bc = bc and bc:FindFirstChild("Controllers")
		bc = bc and bc:FindFirstChild("BuildingController")
		bc = bc and bc:FindFirstChild("BuildController")
		if not bc then print("[SX Elected] BuildController not found") return end
		local src = decompile(bc)
		if src then
			for line in src:gmatch("[^\n]+") do
				table.insert(log, line)
			end
			print("[SX Elected] BuildController: " .. #log .. " lines")
			-- Print lines with Fire, Build, Block, CFrame, Position
			for i, line in ipairs(log) do
				local ll = line:lower()
				if ll:find(":fire") or ll:find("buildblock") or ll:find("cframe") and ll:find("fire") then
					print("[SX BC:" .. i .. "] " .. line:sub(1, 200))
				end
			end
		end
		pcall(function()
			writefile("SXBuildController.txt", table.concat(log, "\n"))
			print("[SX Elected] Saved full decompile to SXBuildController.txt")
			notify("Build", "Saved to SXBuildController.txt")
		end)
	end)
end

local function buildWord(text, blockColor)
	local hrp = getRoot()
	local char = LocalPlayer.Character
	if not hrp or not char then notify("Error", "No character") return end

	local evt = getBuildBlockEvent()
	if not evt then
		notify("Error", "BuildBlock event not found. Check F9 console for details.")
		return
	end

	-- Get block template from ReplicatedStorage.Assets.Blocks.Block
	local blockRef = buildBlockRef
	if not blockRef then
		pcall(function()
			blockRef = game:GetService("ReplicatedStorage").Assets.Blocks.Block
		end)
	end
	if not blockRef then
		notify("Error", "Block template not found in ReplicatedStorage.Assets.Blocks")
		return
	end

	text = text:upper()

	-- Snap right direction to nearest axis for clean grid alignment
	local rawRight = hrp.CFrame.RightVector
	local ax, ay, az = math.abs(rawRight.X), math.abs(rawRight.Y), math.abs(rawRight.Z)
	local rightDir
	if ax >= ay and ax >= az then
		rightDir = Vector3.new(rawRight.X > 0 and 1 or -1, 0, 0)
	elseif az >= ax and az >= ay then
		rightDir = Vector3.new(0, 0, rawRight.Z > 0 and 1 or -1)
	else
		rightDir = Vector3.new(1, 0, 0)
	end
	local upDir = Vector3.new(0, 1, 0)

	-- Build in front of player, grid-snapped to 3 studs
	local startPos = hrp.Position + hrp.CFrame.LookVector * 15 + Vector3.new(0, 5, 0)
	startPos = Vector3.new(
		math.floor(startPos.X / wordBlockSize + 0.5) * wordBlockSize,
		math.floor(startPos.Y / wordBlockSize + 0.5) * wordBlockSize,
		math.floor(startPos.Z / wordBlockSize + 0.5) * wordBlockSize
	)

	local blocksPlaced = 0
	local charOffset = 0

	notify("Building", "Building: " .. text)
	print("[SX Elected] Building word at: " .. tostring(startPos) .. " dir: " .. tostring(rightDir))

	task.spawn(function()
		for ci = 1, #text do
			local ch = text:sub(ci, ci)
			local pixels = LETTER_PIXELS[ch]
			if pixels then
				for row = 1, 5 do
					for col = 1, 5 do
						if pixels[row]:sub(col, col) == "1" then
							local x = (charOffset + col - 1) * wordBlockSize
							local y = (5 - row) * wordBlockSize
							local pos = startPos + rightDir * x + upDir * y
							local cf = CFrame.new(pos)

							-- Fire with exact format from BuildController decompile:
							-- evt:Fire(cframe, blockTemplate, colorData, scaleMode)
							pcall(function()
								evt:Fire(cf, blockRef, nil, "Normal")
							end)

							blocksPlaced = blocksPlaced + 1
							task.wait(0.15)
						end
					end
				end
				charOffset = charOffset + 6
			else
				charOffset = charOffset + 3
			end
		end
		notify("Built", blocksPlaced .. " blocks placed for: " .. text)
	end)
end

-- ===================== DEMOLISH OWN BLOCKS =====================
local function demolishOwnBlocks()
	local count = 0
	local blocks = workspace:FindFirstChild("Blocks")
	if not blocks then notify("Error", "No blocks folder") return end

	for _, block in ipairs(blocks:GetDescendants()) do
		pcall(function()
			if block:IsA("BasePart") and block:GetAttribute("Builder") == LocalPlayer.Name then
				block:Destroy()
				count = count + 1
			end
		end)
	end
	notify("Demolish", "Removed " .. count .. " of your blocks")
end

-- Count your blocks
local function countOwnBlocks()
	local count = 0
	local blocks = workspace:FindFirstChild("Blocks")
	if blocks then
		for _, block in ipairs(blocks:GetDescendants()) do
			pcall(function()
				if block:IsA("BasePart") and block:GetAttribute("Builder") == LocalPlayer.Name then
					count = count + 1
				end
			end)
		end
	end
	notify("Blocks", "You have " .. count .. " blocks placed")
end

-- ===================== REMOTE SCANNER =====================
-- Scans all remotes for exploiting
local function scanRemotes()
	print("=== ELECTED ADMIN REMOTE SCAN ===")
	local count = 0
	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		pcall(function()
			if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") then
				print("[" .. obj.ClassName .. "] " .. obj:GetFullName())
				count = count + 1
			end
		end)
	end
	print("=== " .. count .. " REMOTES FOUND ===")
	notify("Scan", count .. " remotes printed to F9")
end

-- ===================== GUI SETUP =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SXElected"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local function addCorner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = inst
	return c
end

-- ===================== MOBILE / RESIZE DETECTION =====================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local ORIG_W = 560
local ORIG_H = 460
local windowW = ORIG_W
local windowH = ORIG_H
if isMobile then
	windowW = math.min(math.floor(screenSize.X * 0.92), ORIG_W)
	windowH = math.min(math.floor(screenSize.Y * 0.7), ORIG_H)
	if windowW < 320 then windowW = 320 end
	if windowH < 280 then windowH = 280 end
end

-- ===================== GUI SETUP (WindUI) =====================
-- The hand-built window, tab bar, drag handling and mobile toggle were
-- replaced with WindUI. The builder functions keep their original names and
-- signatures and now produce WindUI elements, so every feature call site is
-- untouched; only these bodies and the window setup changed.
local Fluent
do
	local ok, lib = pcall(function()
		return loadstring(game:HttpGet(
			"https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
	end)
	if not ok or not lib then
		warn("[SX] Fluent failed to load: " .. tostring(lib))
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "Pebbleford Hub",
				Text = "UI library failed to load. Check your internet/executor.",
				Duration = 8,
			})
		end)
		return
	end
	Fluent = lib
	_G.SX_UI = lib
end

local tabNames = {"Mining", "Admin", "Build", "Players", "Movement", "Visuals", "Troll"}
local tabFrames = {}

local Window = Fluent:CreateWindow({
	Title = "Elected Hub",
	SubTitle = "Pebbleford Hub",
	TabWidth = 150,
	Size = UDim2.fromOffset(560, 440),
	Acrylic = false,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.RightShift,
})

for _, name in ipairs(tabNames) do
	tabFrames[name] = Window:AddTab({Title = name})
end

local function switchTab(tabName) uiState = uiState or {}; uiState.activeTab = tabName end

-- ===================== UI COMPONENT BUILDERS (Fluent) =====================
-- Fluent needs a unique flag string per interactive element, so one is
-- generated per call. order is accepted and ignored.
local _flagN = 0
local function nextFlag() _flagN = _flagN + 1 return "sx_" .. _flagN end

local function createSectionLabel(parent, text, order)
	if not parent then return end
	return parent:AddSection(text)
end
local function createInfoLabel(parent, text, order)
	if not parent then return end
	return parent:AddParagraph({Title = "", Content = text})
end
local function createDynamicLabel(parent, text)
	if not parent then return setmetatable({}, {__newindex = function() end}) end
	local para = parent:AddParagraph({Title = "", Content = tostring(text or "")})
	local last = tostring(text or "")
	return setmetatable({}, {
		__newindex = function(_, k, v)
			if k == "Text" then
				local str = tostring(v)
				if str ~= last then last = str; pcall(function() para:SetDesc(str) end) end
			end
		end,
		__index = function() return nil end,
	})
end
local function createToggle(parent, text, order, callback)
	if not parent then return end
	return parent:AddToggle(nextFlag(), {Title = text, Default = false,
		Callback = function(v) if callback then pcall(callback, v) end end})
end
local function createActionButton(parent, text, order, callback)
	if not parent then return end
	return parent:AddButton({Title = text,
		Callback = function() if callback then pcall(callback) end end})
end
local createButton = createActionButton
local function createSlider(parent, text, min, max, default, order, callback)
	if not parent then return end
	return parent:AddSlider(nextFlag(), {Title = text, Min = min, Max = max, Default = default, Rounding = 0,
		Callback = function(v)
			local n = type(v) == "table" and (v.Value or v.Default) or v
			if callback and type(n) == "number" then pcall(callback, n) end
		end})
end
local function createDropdown(parent, text, options, default, callback)
	if not parent then return end
	return parent:AddDropdown(nextFlag(), {Title = text, Values = options, Multi = false, Default = default,
		Callback = function(v) if callback and v then pcall(callback, v) end end})
end
local function createInput(parent, text, placeholder, callback)
	if not parent then return end
	return parent:AddInput(nextFlag(), {Title = text, Default = "", Placeholder = placeholder or "",
		Numeric = false, Finished = false,
		Callback = function(v) if callback then pcall(callback, v) end end})
end
local function createSpacer(parent, order) return nil end

-- ===================== BUILD MINING TAB =====================
do
	local tab = tabFrames["Mining"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Adminium Mining", o())
	createToggle(tab, "Auto Mine (Tool + Prompts)", o(), function(on)
		if on then startAutoMine() else stopAutoMine() end
	end)
	createSlider(tab, "Mine Speed (x100 ms)", 1, 50, math.floor(mineSpeed * 100), o(), function(val)
		mineSpeed = val / 100
	end)
	createInfoLabel(tab, "Equips pickaxe, fires ProximityPrompts + activates tool", o())
	createInfoLabel(tab, "Works best when near Adminium with a pickaxe equipped", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Upgrades", o())
	createToggle(tab, "Auto Upgrade", o(), function(on)
		if on then startAutoUpgrade() else stopAutoUpgrade() end
	end)
	createInfoLabel(tab, "Automatically clicks upgrade buttons when available", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Quick Actions", o())
	createButton(tab, "TP to Adminium + Mine", o(), function()
		local char = LocalPlayer.Character
		if not char then return end
		local adminium = findAdminium()
		if adminium then
			local cf = getItemCFrame(adminium)
			if cf then
				char:PivotTo(cf + Vector3.new(0, 5, 0))
				notify("Teleport", "TP to Adminium!")
				-- Also equip mining tool
				local tool = findMiningTool()
				if tool then equipTool(tool) end
			end
		else
			notify("Error", "Adminium not found in workspace")
		end
	end)
	createButton(tab, "Burst Mine (100 clicks)", o(), function()
		task.spawn(function()
			local tool = findMiningTool()
			if tool then equipTool(tool) end
			local adminium = findAdminium()
			for i = 1, 100 do
				if adminium and adminium.Parent then
					fireAllPrompts(adminium)
				end
				if tool and tool.Parent == LocalPlayer.Character then
					pcall(function() tool:Activate() end)
				end
				mouse1click()
				task.wait(0.02)
			end
			notify("Mine", "Burst complete! 100 clicks")
		end)
	end)
	createButton(tab, "List All Tools (F9)", o(), function()
		print("=== YOUR TOOLS ===")
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		if backpack then
			for _, tool in ipairs(backpack:GetChildren()) do
				if tool:IsA("Tool") then
					print("[Backpack] " .. tool.Name .. " (" .. tool.ClassName .. ")")
				end
			end
		end
		local char = LocalPlayer.Character
		if char then
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") then
					print("[Equipped] " .. tool.Name .. " (" .. tool.ClassName .. ")")
				end
			end
		end
		notify("Tools", "Tool list printed to F9")
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Debug / Remote Spy", o())
	createButton(tab, "Scan All Remotes (F9)", o(), scanRemotes)
	createToggle(tab, "Remote Spy (Log all remotes to F9)", o(), function(on)
		if on then startRemoteSpy() else stopRemoteSpy() end
	end)
	createInfoLabel(tab, "Spy logs every FireServer/InvokeServer call to F9", o())
	createInfoLabel(tab, "Use spy to find how mining/building/signs actually work", o())
end

-- ===================== BUILD ADMIN TAB =====================
do
	local tab = tabFrames["Admin"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Admin Commands (Requires Admin)", o())
	createInfoLabel(tab, "These send ; commands in chat - only work if YOU are admin", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Self Commands", o())
	createButton(tab, ";btools me (Building Tools)", o(), function() adminBtools("me") end)
	createButton(tab, ";fly me", o(), function() adminFly("me") end)
	createButton(tab, ";god me", o(), function() adminGod("me") end)
	createButton(tab, ";speed me 100", o(), function() adminSpeed("me", 100) end)
	createButton(tab, ";noclip me", o(), function() adminNoclip("me") end)
	createButton(tab, ";gun me", o(), function() adminGun("me") end)
	createButton(tab, ";sword me", o(), function() adminSword("me") end)
	createButton(tab, ";car me", o(), function() adminCar("me") end)
	createButton(tab, ";plane me", o(), function() adminPlane("me") end)
	createButton(tab, ";drone me", o(), function() adminDrone("me") end)

	createSpacer(tab, o())

	createSectionLabel(tab, "All Commands", o())
	createButton(tab, ";kill all", o(), function() adminKill("all") end)
	createButton(tab, ";fling all", o(), function() adminFling("all") end)
	createButton(tab, ";bring all", o(), function() adminBring("all") end)
	createButton(tab, ";jail all", o(), function() adminJail("all") end)
	createButton(tab, ";respawn all", o(), function() adminRespawn("all") end)
	createButton(tab, ";mute all", o(), function() adminMute("all") end)
	createButton(tab, ";missile all", o(), function() adminMissile("all") end)
	createButton(tab, ";airstrike all", o(), function() adminAirstrike("all") end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Environment", o())
	createButton(tab, ";time 14 (Daytime)", o(), function() sendAdminCmd(";time 14") end)
	createButton(tab, ";time 0 (Nighttime)", o(), function() sendAdminCmd(";time 0") end)
	createButton(tab, ";gravity 50 (Low Gravity)", o(), function() sendAdminCmd(";gravity 50") end)
	createButton(tab, ";gravity 196 (Normal)", o(), function() sendAdminCmd(";gravity 196") end)
	createButton(tab, ";nuke", o(), function() sendAdminCmd(";nuke") end)
	createButton(tab, ";rain", o(), function() sendAdminCmd(";rain") end)
	createButton(tab, ";fog 50", o(), function() sendAdminCmd(";fog 50") end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Custom Command", o())
	local cmdInput = createTextInput(tab, "Enter command (e.g. ;kill all)", o())
	createButton(tab, "Send Command", o(), function()
		if cmdInput.Text ~= "" then
			sendAdminCmd(cmdInput.Text)
			notify("Command", "Sent: " .. cmdInput.Text)
		end
	end)
end

-- ===================== BUILD BUILD TAB =====================
do
	local tab = tabFrames["Build"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Sign Text Editor", o())
	local signInput = createTextInput(tab, "Sign text...", o())
	createButton(tab, "Edit My Signs", o(), function()
		if signInput.Text ~= "" then
			editAllSigns(signInput.Text, true)
		else
			notify("Error", "Enter sign text first!")
		end
	end)
	createButton(tab, "Edit All Signs", o(), function()
		if signInput.Text ~= "" then
			editAllSigns(signInput.Text, false)
		else
			notify("Error", "Enter sign text first!")
		end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Campaign Slogan", o())
	local sloganInput = createTextInput(tab, "Slogan text...", o())
	local bannerInput = createTextInput(tab, "Banner text (optional)...", o())
	createButton(tab, "Update Slogan", o(), function()
		if sloganInput.Text ~= "" then
			editSlogan(sloganInput.Text, bannerInput.Text)
		else
			notify("Error", "Enter slogan text first!")
		end
	end)
	createButton(tab, "Decompile Network (F9)", o(), decompileNetworkModule)
	createButton(tab, "Discover Sign Method (F9)", o(), discoverSignMethod)

	createSpacer(tab, o())

	createSectionLabel(tab, "Block Management", o())
	createButton(tab, "Count My Blocks", o(), countOwnBlocks)
	createButton(tab, "Demolish All My Blocks", o(), demolishOwnBlocks)

	createSpacer(tab, o())

	createSectionLabel(tab, "Word Builder", o())
	createInfoLabel(tab, "Builds text out of blocks using building tool (A-Z, 0-9)", o())
	createInfoLabel(tab, "REQUIRES building tool equipped with a block selected!", o())
	local wordInput = createTextInput(tab, "Enter text to build...", o())
	createSlider(tab, "Block Size (studs)", 2, 8, wordBlockSize, o(), function(val)
		wordBlockSize = val
	end)
	createButton(tab, "Build Word", o(), function()
		if wordInput.Text ~= "" then
			buildWord(wordInput.Text)
		else
			notify("Error", "Enter text first!")
		end
	end)
	createButton(tab, "Dump BuildController (F9)", o(), dumpBuildController)
	createButton(tab, "TEST: Place 1 Block (F9)", o(), testBuildBlock)
	createInfoLabel(tab, "Test fires 4 different formats. No build tool needed.", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Building Tools", o())
	createButton(tab, "Find + Equip Building Tool", o(), function()
		local tool = findBuildingTool()
		if tool then
			equipTool(tool)
			notify("Build", "Equipped: " .. tool.Name)
		else
			notify("Error", "No building tool found in backpack")
		end
	end)
	createButton(tab, "List All Workspace Blocks (F9)", o(), function()
		local blocks = workspace:FindFirstChild("Blocks")
		if blocks then
			local count = 0
			local types = {}
			for _, block in ipairs(blocks:GetChildren()) do
				count = count + 1
				local name = block.Name
				types[name] = (types[name] or 0) + 1
			end
			print("=== PLACED BLOCKS (" .. count .. " total) ===")
			for name, c in pairs(types) do
				print("  " .. name .. ": " .. c)
			end
			notify("Blocks", count .. " blocks placed - see F9")
		else
			notify("Error", "No Blocks folder in workspace")
		end
	end)
	createButton(tab, "List Block Templates (F9)", o(), function()
		print("=== BLOCK TEMPLATES ===")
		local blocksFolder = ReplicatedStorage:FindFirstChild("Assets")
		if blocksFolder then
			local bFolder = blocksFolder:FindFirstChild("Blocks")
			if bFolder then
				local count = 0
				for _, block in ipairs(bFolder:GetChildren()) do
					print("[Template] " .. block.Name .. " (" .. block.ClassName .. ")")
					count = count + 1
				end
				print("=== " .. count .. " TEMPLATES ===")
				notify("Blocks", count .. " templates - see F9")
				return
			end
		end
		-- Try direct path
		blocksFolder = ReplicatedStorage:FindFirstChild("Blocks")
		if blocksFolder then
			local count = 0
			for _, block in ipairs(blocksFolder:GetChildren()) do
				print("[Template] " .. block.Name .. " (" .. block.ClassName .. ")")
				count = count + 1
			end
			print("=== " .. count .. " TEMPLATES ===")
			notify("Blocks", count .. " templates - see F9")
		else
			notify("Error", "No block templates found")
		end
	end)
end

-- ===================== BUILD PLAYERS TAB =====================
do
	local tab = tabFrames["Players"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Player Actions", o())
	createInfoLabel(tab, "Per-player actions (admin cmds require admin status)", o())

	-- Per-player rows had six buttons at fixed pixel offsets, which does not
	-- survive a resizable window. A target dropdown plus action buttons.
	local elPlayers, elDropdown, elTarget = {}, nil, nil
	local function refreshPlayerActions()
		elPlayers = {}
		local names = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				elPlayers[player.DisplayName] = player
				table.insert(names, player.DisplayName)
			end
		end
		if #names == 0 then names = {"(no players)"} end
		if elDropdown then pcall(function() elDropdown:SetValues(names) end) end
	end
	elDropdown = createDropdown(tab, "Target Player", {"(refresh first)"}, "(refresh first)", function(choice)
		elTarget = elPlayers[choice]
	end)
	local function withTarget(fn)
		return function()
			if not elTarget or not elTarget.Parent then
				notify("Admin", "Pick a target from the dropdown first")
				return
			end
			fn(elTarget)
		end
	end
	createButton(tab, "Kill Target", o(), withTarget(function(p) adminKill(p.Name) end))
	createButton(tab, "Bring Target", o(), withTarget(function(p) adminBring(p.Name) end))
	createButton(tab, "Teleport To Target", o(), withTarget(function(p)
		pcall(function()
			local myChar = LocalPlayer.Character
			local theirHRP = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if myChar and theirHRP then
				myChar:PivotTo(theirHRP.CFrame + Vector3.new(0, 3, 0))
				notify("TP", "Teleported to " .. p.DisplayName)
			end
		end)
	end))
	createButton(tab, "Fling Target", o(), withTarget(function(p) flingPlayer(p) end))
	createButton(tab, "Jail Target", o(), withTarget(function(p) adminJail(p.Name) end))
	createButton(tab, "Kick Target", o(), withTarget(function(p) adminKick(p.Name) end))
	createButton(tab, "Refresh Player List", o(), refreshPlayerActions)
	refreshPlayerActions()

	Players.PlayerAdded:Connect(function() task.wait(1) refreshPlayerActions() end)
	Players.PlayerRemoving:Connect(function() task.wait(0.5) refreshPlayerActions() end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Protection", o())
	createToggle(tab, "Anti-Jail (TP back if jailed)", o(), function(on)
		if on then startAntiJail() else stopAntiJail() end
	end)
	createToggle(tab, "Anti-Fling (Clamp velocity)", o(), function(on)
		if on then startAntiFling() else stopAntiFling() end
	end)
	createInfoLabel(tab, "Anti-jail detects sudden TP and brings you back", o())
end

-- ===================== BUILD MOVEMENT TAB =====================
do
	local tab = tabFrames["Movement"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Flight", o())
	createToggle(tab, "Fly (WASD + Space/Shift)", o(), function(on)
		flyActive = on
		if on then startFly() else stopFly() end
	end)
	createSlider(tab, "Fly Speed", 10, 200, flySpeed, o(), function(val) flySpeed = val end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Speed", o())
	createToggle(tab, "Speed Boost", o(), function(on)
		speedBoostActive = on
		if on then startSpeedBoost() else stopSpeedBoost() end
	end)
	createSlider(tab, "Speed Value", 20, 200, speedValue, o(), function(val) speedValue = val end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Other", o())
	createToggle(tab, "Noclip (Walk Through Walls)", o(), function(on)
		noclipActive = on
		if on then startNoclip() else stopNoclip() end
	end)
	createToggle(tab, "Infinite Jump", o(), function(on)
		infJumpActive = on
	end)
	createToggle(tab, "God Mode (Infinite Health)", o(), function(on)
		godModeActive = on
		if on then startGodMode() else stopGodMode() end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Teleport Locations", o())
	createButton(tab, "TP to Main Island (Spawn)", o(), function()
		local char = LocalPlayer.Character
		if char then char:PivotTo(CFrame.new(0, 30, 0)) notify("TP", "Main Island") end
	end)
	createButton(tab, "TP to Adminium", o(), function()
		local char = LocalPlayer.Character
		if not char then return end
		local adminium = workspace:FindFirstChild("Adminium")
		if adminium then
			local cf = getItemCFrame(adminium)
			if cf then char:PivotTo(cf + Vector3.new(0, 5, 0)) end
		end
		notify("TP", "Adminium")
	end)
	createButton(tab, "TP to Mars", o(), function()
		local char = LocalPlayer.Character
		if char then
			-- Mars is far away, search workspace for it
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj.Name == "Mars" and (obj:IsA("Model") or obj:IsA("BasePart")) then
					local cf = getItemCFrame(obj)
					if cf then char:PivotTo(cf + Vector3.new(0, 10, 0)) break end
				end
			end
			notify("TP", "Mars (if found)")
		end
	end)
	createButton(tab, "TP to Moon", o(), function()
		local char = LocalPlayer.Character
		if char then
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj.Name == "Moon" and (obj:IsA("Model") or obj:IsA("BasePart")) then
					local cf = getItemCFrame(obj)
					if cf then char:PivotTo(cf + Vector3.new(0, 10, 0)) break end
				end
			end
			notify("TP", "Moon (if found)")
		end
	end)
	createButton(tab, "TP to Sky (Y=500)", o(), function()
		local char = LocalPlayer.Character
		local hrp = getRoot()
		if char and hrp then char:PivotTo(CFrame.new(hrp.Position.X, 500, hrp.Position.Z)) end
		notify("TP", "Sky")
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "AFK", o())
	createToggle(tab, "Anti-AFK (Prevent Kick)", o(), function(on)
		antiAfkActive = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Server", o())
	createButton(tab, "Rejoin Server", o(), function()
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end)
	createButton(tab, "Server Hop", o(), function()
		task.spawn(function()
			pcall(function()
				local servers = game:GetService("HttpService"):JSONDecode(
					game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=25")
				)
				for _, server in ipairs(servers.data) do
					if server.id ~= game.JobId and server.playing < server.maxPlayers then
						TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
						return
					end
				end
				notify("Error", "No available servers found")
			end)
		end)
	end)
	createInfoLabel(tab, "PlaceId: " .. tostring(game.PlaceId), o())
end

-- ===================== BUILD VISUALS TAB =====================
do
	local tab = tabFrames["Visuals"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "ESP", o())
	createToggle(tab, "Player ESP (Highlight + Distance)", o(), function(on)
		espActive = on
		if on then startESP() else clearESP() end
	end)
	createInfoLabel(tab, "Shows all players through walls with distance + HP", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Visual Mods", o())
	createToggle(tab, "Fullbright (Remove Darkness)", o(), function(on)
		fullbrightActive = on
		if on then enableFullbright() else disableFullbright() end
	end)
	createInfoLabel(tab, "Removes fog, shadows, makes everything bright", o())
end

-- ===================== BUILD TROLL TAB =====================
do
	local tab = tabFrames["Troll"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Chat Spam", o())
	local spamInput = createTextInput(tab, "Spam message...", o())
	createToggle(tab, "Chat Spam", o(), function(on)
		if spamInput.Text ~= "" then spamText = spamInput.Text end
		if on then startChatSpam() else stopChatSpam() end
	end)
	createInfoLabel(tab, "Sends message in chat every 1.5s", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Sign Spam", o())
	local signSpamInput = createTextInput(tab, "Sign spam text...", o())
	createButton(tab, "Spam My Signs", o(), function()
		if signSpamInput.Text ~= "" then editAllSigns(signSpamInput.Text, true) end
	end)
	createButton(tab, "Spam All Signs", o(), function()
		if signSpamInput.Text ~= "" then editAllSigns(signSpamInput.Text, false) end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Admin Troll (Requires Admin)", o())
	createButton(tab, ";kill all", o(), function() adminKill("all") end)
	createButton(tab, ";fling all", o(), function() adminFling("all") end)
	createButton(tab, ";jail all", o(), function() adminJail("all") end)
	createButton(tab, ";missile all", o(), function() adminMissile("all") end)
	createButton(tab, ";airstrike all", o(), function() adminAirstrike("all") end)
	createButton(tab, ";nuke", o(), function() sendAdminCmd(";nuke") end)
	createButton(tab, ";gravity 10 (Moon gravity)", o(), function() sendAdminCmd(";gravity 10") end)
	createButton(tab, ";speed all 200", o(), function() adminSpeed("all", 200) end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Fake Admin Popup", o())
	createButton(tab, "Show Fake Admin Notification", o(), function()
		-- Create a fake "You are now admin" popup
		local fakeGui = Instance.new("Frame")
		fakeGui.Size = UDim2.new(0, 350, 0, 80)
		fakeGui.Position = UDim2.new(0.5, -175, 0.1, 0)
		fakeGui.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		fakeGui.BorderSizePixel = 0
		fakeGui.Parent = screenGui
		addCorner(fakeGui, 10)

		local stroke = Instance.new("UIStroke")
		stroke.Color = COLORS.admin
		stroke.Thickness = 2
		stroke.Parent = fakeGui

		local fakeLbl = Instance.new("TextLabel")
		fakeLbl.Size = UDim2.new(1, 0, 1, 0)
		fakeLbl.BackgroundTransparency = 1
		fakeLbl.Text = "You have been elected as Administrator!\nYou now have access to admin commands."
		fakeLbl.TextColor3 = COLORS.admin
		fakeLbl.Font = Enum.Font.GothamBold
		fakeLbl.TextSize = 14
		fakeLbl.Parent = fakeGui

		task.delay(5, function() pcall(function() fakeGui:Destroy() end) end)
		notify("Troll", "Fake admin popup shown (local only)")
	end)
end

-- ===================== MINIMIZE / TOGGLE =====================

-- Mobile toggle button removed: WindUI provides its own open button.
-- ===================== RESPAWN HANDLER =====================
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	if flyActive then stopFly() task.wait(0.3) startFly() end
	if speedBoostActive then stopSpeedBoost() task.wait(0.3) startSpeedBoost() end
	if noclipActive then stopNoclip() task.wait(0.3) startNoclip() end
	if godModeActive then stopGodMode() task.wait(0.3) startGodMode() end
	if antiJailActive then stopAntiJail() task.wait(0.3) startAntiJail() end
	if antiFlingActive then stopAntiFling() task.wait(0.3) startAntiFling() end
end)

-- ===================== STARTUP =====================
notify("SX Elected v1.3", "Loaded! Right Shift to toggle")
print("[SX Elected v1.3] Pebbleford Hub - Elected Admin Hub")
print("[SX Elected v1.3] Tabs: Mining | Admin | Build | Players | Movement | Visuals | Troll")
print("[SX Elected v1.3] Red Event: " .. (RedEvent and RedEvent:GetFullName() or "NOT FOUND"))
print("[SX Elected v1.3] Chat: " .. (ChatRemote and "Legacy Chat" or "TextChatService"))
print("[SX Elected v1.3] Mining: Tool-based (equip pickaxe + ProximityPrompt)")
print("[SX Elected v1.3] Building: Tool-based (equip building tool)")
print("[SX Elected v1.3] Signs: EditSign Red event (direct remote fire)")
print("[SX Elected v1.3] Right Shift to toggle GUI")
