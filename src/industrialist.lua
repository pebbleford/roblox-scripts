-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate("industrialist") then return end

-- ================================================================
-- Pebbleford Hub - Industrialist Auto Farm v1.1.1
-- Auto-place farm layouts | Resource monitor | Auto-sell
-- Auto-wire | Auto-pipe | Remote discovery
-- ================================================================

print("[PB Industrialist v1.1.1] Loading...")

-- Cleanup old instance
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("PBIndustrialist")
	if old then old:Destroy() end
end)
pcall(function()
	local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		local o2 = pg:FindFirstChild("PBIndustrialist")
		if o2 then o2:Destroy() end
	end
end)

-- ===================== SERVICES =====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===================== COLORS =====================
local COLORS = {
	bg = Color3.fromRGB(18, 18, 24),
	bgSecondary = Color3.fromRGB(26, 26, 34),
	tabBg = Color3.fromRGB(38, 38, 50),
	accent = Color3.fromRGB(255, 165, 0),
	accentDark = Color3.fromRGB(200, 120, 0),
	text = Color3.fromRGB(230, 230, 230),
	textDim = Color3.fromRGB(150, 150, 165),
	toggleOn = Color3.fromRGB(255, 165, 0),
	toggleOff = Color3.fromRGB(60, 60, 75),
	border = Color3.fromRGB(55, 55, 70),
	success = Color3.fromRGB(0, 200, 100),
	danger = Color3.fromRGB(220, 50, 50),
}

-- ===================== STATE =====================
local guiOpen = true
local activeTab = "Farms"
local logs = {}
local logMax = 50

-- Auto-farm state
local autoSellEnabled = false
local autoSellConnection = nil
local currentFarmBuilding = false

-- ===================== PLACEMENT SYSTEM CONNECTION =====================
-- Direct references to the game's PlacementSystem
local PlacementSystem = ReplicatedStorage:FindFirstChild("PlacementSystem")
local PS = {}
if PlacementSystem then
	PS.Place = PlacementSystem:FindFirstChild("Place")
	PS.PlaceBind = PlacementSystem:FindFirstChild("PlaceBind")
	PS.OptimizedPlaceBind = PlacementSystem:FindFirstChild("OptimizedPlaceBind")
	PS.PipeBind = PlacementSystem:FindFirstChild("PipeBind")
	PS.WireBind = PlacementSystem:FindFirstChild("WireBind")
	PS.Buy = PlacementSystem:FindFirstChild("Buy")
	PS.Delete = PlacementSystem:FindFirstChild("Delete")
	PS.CheckOres = PlacementSystem:FindFirstChild("CheckOres")
	PS.GetNode = PlacementSystem:FindFirstChild("GetNode")
	PS.Buildings = PlacementSystem:FindFirstChild("Buildings")
end

-- Captured remote call data from __namecall hook
local capturedCalls = {}
local captureActive = false
local captureFile = "industrialist_capture.txt"
local hookInstalled = false

-- Serialize a value to a readable string
local function serializeValue(v, depth)
	depth = depth or 0
	if depth > 5 then return "..." end
	local t = typeof(v)
	if t == "string" then
		return '"' .. v:sub(1, 200) .. '"'
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "nil" then
		return "nil"
	elseif t == "Vector3" then
		return "Vector3.new(" .. v.X .. ", " .. v.Y .. ", " .. v.Z .. ")"
	elseif t == "CFrame" then
		local x, y, z = v.Position.X, v.Position.Y, v.Position.Z
		local rx, ry, rz = v:ToEulerAnglesXYZ()
		return "CFrame.new(" .. x .. ", " .. y .. ", " .. z .. ") * CFrame.Angles(" .. rx .. ", " .. ry .. ", " .. rz .. ")"
	elseif t == "Instance" then
		return "Instance<" .. v.ClassName .. "> '" .. v:GetFullName() .. "'"
	elseif t == "Color3" then
		return "Color3.new(" .. v.R .. ", " .. v.G .. ", " .. v.B .. ")"
	elseif t == "UDim2" then
		return "UDim2.new(" .. v.X.Scale .. ", " .. v.X.Offset .. ", " .. v.Y.Scale .. ", " .. v.Y.Offset .. ")"
	elseif t == "EnumItem" then
		return tostring(v)
	elseif t == "table" then
		local parts = {}
		local count = 0
		for k, val in pairs(v) do
			count = count + 1
			if count > 20 then
				table.insert(parts, "... +" .. (count) .. " more")
				break
			end
			local keyStr
			if type(k) == "number" then
				keyStr = "[" .. k .. "]"
			else
				keyStr = "[" .. serializeValue(k, depth + 1) .. "]"
			end
			table.insert(parts, keyStr .. " = " .. serializeValue(val, depth + 1))
		end
		return "{\n" .. string.rep("  ", depth + 1) .. table.concat(parts, ",\n" .. string.rep("  ", depth + 1)) .. "\n" .. string.rep("  ", depth) .. "}"
	else
		return "<" .. t .. "> " .. tostring(v)
	end
end

-- Record a captured call into the capturedCalls table and write to file
local function recordCapture(remote, method, args)
	local selfPath = ""
	pcall(function() selfPath = remote:GetFullName() end)

	local entry = {
		remote = remote.Name,
		path = selfPath,
		method = method,
		className = remote.ClassName,
		argCount = #args,
		args = {},
		rawArgs = args,
		timestamp = os.clock(),
	}
	for i, v in ipairs(args) do
		entry.args[i] = {
			type = typeof(v),
			value = serializeValue(v),
			raw = v,
		}
	end
	table.insert(capturedCalls, entry)

	-- Write to file
	pcall(function()
		local lines = {}
		table.insert(lines, "=== CAPTURED: " .. remote.Name .. ":" .. method .. " at " .. os.date("%H:%M:%S") .. " ===")
		table.insert(lines, "Remote: " .. selfPath .. " (" .. remote.ClassName .. ")")
		table.insert(lines, "Method: " .. method)
		table.insert(lines, "Args: " .. #args)
		for i, v in ipairs(args) do
			table.insert(lines, "  Arg " .. i .. " [" .. typeof(v) .. "]: " .. serializeValue(v))
		end
		table.insert(lines, "")

		local existing = ""
		pcall(function() existing = readfile(captureFile) end)
		writefile(captureFile, existing .. table.concat(lines, "\n") .. "\n")
	end)

	print("[PB Capture] " .. remote.Name .. ":" .. method .. " with " .. #args .. " args")
	for i, v in ipairs(args) do
		print("  Arg " .. i .. " [" .. typeof(v) .. "]: " .. serializeValue(v))
	end
end

-- Method 1: hookmetamethod (Synapse, Script-Ware, some Fluxus)
local function tryHookMetamethod()
	if not hookmetamethod then return false end
	if not newcclosure then return false end

	local ok, err = pcall(function()
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local method = getnamecallmethod()
			local selfPath = ""
			pcall(function() selfPath = self:GetFullName() end)

			if selfPath:find("PlacementSystem") and (method == "FireServer" or method == "InvokeServer") then
				recordCapture(self, method, {...})
			end

			return oldNamecall(self, ...)
		end))
	end)

	if ok then
		print("[PB Industrialist] Hook method: hookmetamethod")
		return true
	end
	print("[PB Industrialist] hookmetamethod failed: " .. tostring(err))
	return false
end

-- Method 2: hookfunction on each remote (Fluxus, KRNL, some others)
local function tryHookFunction()
	if not hookfunction then return false end

	local remotes = {PS.Place, PS.PlaceBind, PS.OptimizedPlaceBind, PS.PipeBind, PS.WireBind, PS.Buy, PS.Delete}
	local hooked = 0

	for _, remote in ipairs(remotes) do
		if remote then
			if remote:IsA("RemoteEvent") then
				pcall(function()
					local oldFire
					oldFire = hookfunction(remote.FireServer, newcclosure(function(self, ...)
						if self == remote then
							recordCapture(remote, "FireServer", {...})
						end
						return oldFire(self, ...)
					end))
					hooked = hooked + 1
				end)
			elseif remote:IsA("RemoteFunction") then
				pcall(function()
					local oldInvoke
					oldInvoke = hookfunction(remote.InvokeServer, newcclosure(function(self, ...)
						if self == remote then
							recordCapture(remote, "InvokeServer", {...})
						end
						return oldInvoke(self, ...)
					end))
					hooked = hooked + 1
				end)
			end
		end
	end

	if hooked > 0 then
		print("[PB Industrialist] Hook method: hookfunction (" .. hooked .. " remotes)")
		return true
	end
	return false
end

-- Method 3: Workspace monitor - watch for new models appearing after placement
-- No hook needed, works on ANY executor
local function tryWorkspaceMonitor()
	print("[PB Industrialist] Hook method: workspace monitor (universal)")

	-- Watch for new models in workspace that appear after hammer use
	local monitoring = true

	-- Take initial snapshot of workspace models owned by player
	local function getPlotModels()
		local models = {}
		-- Look for the player's plot/base area
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") and obj.Parent then
				local name = obj.Parent.Name:lower()
				if name:find("plot") or name:find("base") or name:find("build") or name:find("player") then
					models[obj] = true
				end
			end
		end
		return models
	end

	local beforeModels = getPlotModels()
	local beforeCount = 0
	for _ in pairs(beforeModels) do beforeCount = beforeCount + 1 end

	-- Monitor for new additions
	workspace.DescendantAdded:Connect(function(obj)
		if not monitoring then return end
		if not obj:IsA("Model") then return end

		task.wait(0.2) -- Let the model fully load

		-- Check if this looks like a placed building
		local hasParts = false
		for _, child in ipairs(obj:GetDescendants()) do
			if child:IsA("BasePart") then hasParts = true break end
		end

		if hasParts then
			local pos = Vector3.new(0, 0, 0)
			pcall(function()
				local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
				if primary then pos = primary.Position end
			end)

			-- Record as a "detected" placement (not a remote capture, but position+name)
			local entry = {
				remote = "DETECTED",
				path = obj:GetFullName(),
				method = "WorkspaceMonitor",
				className = "Model",
				argCount = 2,
				args = {
					[1] = {type = "string", value = '"' .. obj.Name .. '"', raw = obj.Name},
					[2] = {type = "CFrame", value = serializeValue(obj:GetPivot()), raw = obj:GetPivot()},
				},
				rawArgs = {obj.Name, obj:GetPivot()},
				timestamp = os.clock(),
				modelRef = obj,
			}
			table.insert(capturedCalls, entry)

			pcall(function()
				local existing = ""
				pcall(function() existing = readfile(captureFile) end)
				writefile(captureFile, existing .. "=== DETECTED: " .. obj.Name .. " at " .. tostring(pos) .. " ===\n" .. "Path: " .. obj:GetFullName() .. "\n\n")
			end)

			print("[PB Detect] New building: " .. obj.Name .. " at " .. tostring(pos))
		end
	end)

	return true
end

-- Install capture hook - tries multiple methods
local function installCaptureHook()
	if hookInstalled then return true, "Already installed" end

	-- Clear capture file
	pcall(function() writefile(captureFile, "=== Pebbleford Hub - Industrialist Capture Log ===\n\n") end)

	-- Try methods in order of reliability
	if tryHookMetamethod() then
		hookInstalled = true
		return true, "hookmetamethod"
	end

	if tryHookFunction() then
		hookInstalled = true
		return true, "hookfunction"
	end

	-- Universal fallback - always works
	if tryWorkspaceMonitor() then
		hookInstalled = true
		return true, "workspace monitor"
	end

	return false, "all methods failed"
end

-- Get the list of buildings from the game
local function getGameBuildings()
	local buildings = {}
	if PS.Buildings then
		for _, category in ipairs(PS.Buildings:GetChildren()) do
			if category:IsA("Folder") then
				for _, building in ipairs(category:GetChildren()) do
					table.insert(buildings, {
						name = building.Name,
						category = category.Name,
						instance = building,
						path = building:GetFullName(),
					})
				end
			end
		end
	end
	return buildings
end

-- Replay a captured placement call at a new position
local function replayPlacement(capturedEntry, newPosition)
	if not capturedEntry then return false end

	-- If this was captured via hookmetamethod/hookfunction, replay the exact call
	if capturedEntry.method == "FireServer" or capturedEntry.method == "InvokeServer" then
		local remote = nil
		pcall(function()
			local parts = {}
			for part in capturedEntry.path:gmatch("[^%.]+") do
				table.insert(parts, part)
			end
			local obj = game
			for _, part in ipairs(parts) do
				obj = obj:FindFirstChild(part)
			end
			remote = obj
		end)

		if not remote then
			print("[PB Industrialist] Could not find remote: " .. capturedEntry.path)
			return false
		end

		-- Rebuild args, replacing position/CFrame with new position
		local newArgs = {}
		for i, argData in ipairs(capturedEntry.args) do
			local raw = capturedEntry.rawArgs[i]
			if argData.type == "CFrame" then
				local rx, ry, rz = raw:ToEulerAnglesXYZ()
				newArgs[i] = CFrame.new(newPosition) * CFrame.Angles(rx, ry, rz)
			elseif argData.type == "Vector3" then
				newArgs[i] = newPosition
			else
				newArgs[i] = raw
			end
		end

		pcall(function()
			if capturedEntry.method == "FireServer" then
				remote:FireServer(unpack(newArgs))
			elseif capturedEntry.method == "InvokeServer" then
				remote:InvokeServer(unpack(newArgs))
			end
		end)

		return true
	end

	-- If this was captured via workspace monitor, try calling remotes directly
	-- We know the building name and need to try common arg patterns
	if capturedEntry.method == "WorkspaceMonitor" then
		local buildingName = capturedEntry.rawArgs[1]
		local cf = CFrame.new(newPosition)

		-- Find the building model in PlacementSystem.Buildings
		local buildingModel = nil
		if PS.Buildings then
			for _, desc in ipairs(PS.Buildings:GetDescendants()) do
				if desc.Name == buildingName then
					buildingModel = desc
					break
				end
			end
		end

		-- Try PlaceBind (RemoteFunction) with common arg patterns
		if PS.PlaceBind then
			local tried = false
			-- Pattern 1: name, CFrame
			pcall(function() PS.PlaceBind:InvokeServer(buildingName, cf) tried = true end)
			task.wait(0.05)
			-- Pattern 2: model reference, CFrame
			if buildingModel then
				pcall(function() PS.PlaceBind:InvokeServer(buildingModel, cf) end)
				task.wait(0.05)
			end
			-- Pattern 3: name, position, rotation
			pcall(function() PS.PlaceBind:InvokeServer(buildingName, newPosition, Vector3.new(0, 0, 0)) end)
			task.wait(0.05)
			-- Pattern 4: table with name + cframe
			pcall(function() PS.PlaceBind:InvokeServer({Name = buildingName, CFrame = cf}) end)
			task.wait(0.05)
			-- Pattern 5: table with model + cframe
			if buildingModel then
				pcall(function() PS.PlaceBind:InvokeServer({Building = buildingModel, CFrame = cf}) end)
				task.wait(0.05)
			end
			if tried then return true end
		end

		-- Try OptimizedPlaceBind
		if PS.OptimizedPlaceBind then
			pcall(function() PS.OptimizedPlaceBind:InvokeServer(buildingName, cf) end)
			task.wait(0.05)
			if buildingModel then
				pcall(function() PS.OptimizedPlaceBind:InvokeServer(buildingModel, cf) end)
				task.wait(0.05)
			end
		end

		-- Try Place (RemoteEvent)
		if PS.Place then
			pcall(function() PS.Place:FireServer(buildingName, cf) end)
			task.wait(0.05)
			if buildingModel then
				pcall(function() PS.Place:FireServer(buildingModel, cf) end)
				task.wait(0.05)
			end
		end

		return true
	end

	return false
end

-- ===================== FARM BLUEPRINTS =====================
-- Each blueprint defines machines and their relative positions in a grid
-- Positions are in studs relative to origin (where player stands)

local FARM_BLUEPRINTS = {
	{
		name = "Coal Starter",
		description = "3 Coal Drills -> Truck Depot. Simple money maker.",
		tier = "Early",
		machines = {
			{name = "Coal Drill", offset = Vector3.new(0, 0, 0)},
			{name = "Coal Drill", offset = Vector3.new(8, 0, 0)},
			{name = "Coal Drill", offset = Vector3.new(16, 0, 0)},
			{name = "Truck Depot", offset = Vector3.new(8, 0, 16)},
			{name = "Coal Generator", offset = Vector3.new(-8, 0, 8)},
		},
		pipes = {
			{from = 1, to = 4},
			{from = 2, to = 4},
			{from = 3, to = 4},
		},
		wires = {
			{from = 5, to = 1},
			{from = 5, to = 2},
			{from = 5, to = 3},
			{from = 5, to = 4},
		},
	},
	{
		name = "Copper Wire Line",
		description = "9 Copper Drills -> 3 Furnaces -> Molder -> 2 Presses -> 2 Rollers -> 4 Depots",
		tier = "Early-Mid",
		machines = {
			-- Row 1: Drills
			{name = "Copper Drill", offset = Vector3.new(0, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(8, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(16, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(24, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(32, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(40, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(48, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(56, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(64, 0, 0)},
			-- Row 2: Furnaces
			{name = "Electric Furnace", offset = Vector3.new(8, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(32, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(56, 0, 16)},
			-- Row 3: Molder
			{name = "Ingot Molder", offset = Vector3.new(32, 0, 32)},
			-- Row 4: Presses + Rollers
			{name = "Press", offset = Vector3.new(16, 0, 48)},
			{name = "Press", offset = Vector3.new(48, 0, 48)},
			{name = "Roller", offset = Vector3.new(16, 0, 64)},
			{name = "Roller", offset = Vector3.new(48, 0, 64)},
			-- Row 5: Truck Depots
			{name = "Truck Depot", offset = Vector3.new(0, 0, 80)},
			{name = "Truck Depot", offset = Vector3.new(20, 0, 80)},
			{name = "Truck Depot", offset = Vector3.new(40, 0, 80)},
			{name = "Truck Depot", offset = Vector3.new(60, 0, 80)},
			-- Power
			{name = "Coal Generator", offset = Vector3.new(-12, 0, 32)},
			{name = "Coal Generator", offset = Vector3.new(76, 0, 32)},
		},
	},
	{
		name = "Iron Coil Line",
		description = "15 Iron Drills -> 5 Furnaces -> Molder -> 8 Sawmills -> 8 Rollers -> Van Depots",
		tier = "Mid",
		machines = {
			-- Drills row
			{name = "Iron Drill", offset = Vector3.new(0, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(8, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(16, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(24, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(32, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(40, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(48, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(56, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(64, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(72, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(80, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(88, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(96, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(104, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(112, 0, 0)},
			-- Furnaces
			{name = "Electric Furnace", offset = Vector3.new(8, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(32, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(56, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(80, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(104, 0, 16)},
			-- Molder
			{name = "Ingot Molder", offset = Vector3.new(56, 0, 32)},
			-- Sawmills
			{name = "Sawmill", offset = Vector3.new(0, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(16, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(32, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(48, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(64, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(80, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(96, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(112, 0, 48)},
			-- Rollers
			{name = "Roller", offset = Vector3.new(0, 0, 64)},
			{name = "Roller", offset = Vector3.new(16, 0, 64)},
			{name = "Roller", offset = Vector3.new(32, 0, 64)},
			{name = "Roller", offset = Vector3.new(48, 0, 64)},
			{name = "Roller", offset = Vector3.new(64, 0, 64)},
			{name = "Roller", offset = Vector3.new(80, 0, 64)},
			{name = "Roller", offset = Vector3.new(96, 0, 64)},
			{name = "Roller", offset = Vector3.new(112, 0, 64)},
			-- Van Depots
			{name = "Van Depot", offset = Vector3.new(20, 0, 80)},
			{name = "Van Depot", offset = Vector3.new(90, 0, 80)},
			-- Power
			{name = "Coal Generator", offset = Vector3.new(-12, 0, 24)},
			{name = "Coal Generator", offset = Vector3.new(-12, 0, 48)},
			{name = "Coal Generator", offset = Vector3.new(124, 0, 24)},
			{name = "Coal Generator", offset = Vector3.new(124, 0, 48)},
		},
	},
	{
		name = "Gearbox Factory",
		description = "Crankshafts + Plastic Casings -> Craft Assemblers. $2,552/unit.",
		tier = "Mid-Late",
		machines = {
			-- Crankshaft line (simplified)
			{name = "Iron Drill", offset = Vector3.new(0, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(8, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(16, 0, 0)},
			{name = "Electric Furnace", offset = Vector3.new(8, 0, 16)},
			{name = "Ingot Molder", offset = Vector3.new(8, 0, 32)},
			{name = "Press", offset = Vector3.new(8, 0, 48)},
			-- Plastic line
			{name = "Oil Pump", offset = Vector3.new(40, 0, 0)},
			{name = "Oil Pump", offset = Vector3.new(48, 0, 0)},
			{name = "Plastic Molding Machine", offset = Vector3.new(44, 0, 16)},
			-- Assemblers
			{name = "Craft Assembler", offset = Vector3.new(24, 0, 64)},
			{name = "Craft Assembler", offset = Vector3.new(36, 0, 64)},
			-- Sell
			{name = "Truck Depot", offset = Vector3.new(30, 0, 80)},
			-- Power
			{name = "Coal Generator", offset = Vector3.new(-12, 0, 32)},
			{name = "Coal Generator", offset = Vector3.new(60, 0, 32)},
		},
	},
}

-- ===================== LOGGING =====================
local logFrame = nil
local function addLog(msg)
	table.insert(logs, "[" .. os.date("%H:%M:%S") .. "] " .. msg)
	if #logs > logMax then table.remove(logs, 1) end
	if logFrame then
		-- Update log display
		for _, child in ipairs(logFrame:GetChildren()) do
			if child:IsA("TextLabel") then child:Destroy() end
		end
		for i, log in ipairs(logs) do
			local l = Instance.new("TextLabel")
			l.Size = UDim2.new(1, -10, 0, 16)
			l.Position = UDim2.new(0, 5, 0, (i - 1) * 16)
			l.BackgroundTransparency = 1
			l.Text = log
			l.TextColor3 = COLORS.textDim
			l.TextSize = 11
			l.Font = Enum.Font.RobotoMono
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.TextTruncate = Enum.TextTruncate.AtEnd
			l.Parent = logFrame
		end
		logFrame.CanvasSize = UDim2.new(0, 0, 0, #logs * 16)
		logFrame.CanvasPosition = Vector2.new(0, math.max(0, #logs * 16 - logFrame.AbsoluteSize.Y))
	end
	print("[PB Industrialist] " .. msg)
end

-- ===================== GUI SETUP =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PBIndustrialist"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Try CoreGui first, fall back to PlayerGui
pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not screenGui.Parent then
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 520, 0, 420)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
mainFrame.BackgroundColor3 = COLORS.bg
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = COLORS.accent
mainStroke.Thickness = 2
mainStroke.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = COLORS.bgSecondary
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

-- Logo
local logoBox = Instance.new("Frame")
logoBox.Size = UDim2.new(0, 26, 0, 26)
logoBox.Position = UDim2.new(0, 6, 0, 5)
logoBox.BackgroundColor3 = COLORS.accent
logoBox.BorderSizePixel = 0
logoBox.Parent = titleBar

local logoCorner = Instance.new("UICorner")
logoCorner.CornerRadius = UDim.new(0, 5)
logoCorner.Parent = logoBox

local logoText = Instance.new("TextLabel")
logoText.Size = UDim2.new(1, 0, 1, 0)
logoText.BackgroundTransparency = 1
logoText.Text = "P"
logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
logoText.TextSize = 16
logoText.Font = Enum.Font.GothamBold
logoText.Parent = logoBox

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 250, 1, 0)
titleLabel.Position = UDim2.new(0, 38, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Pebbleford Hub - Industrialist"
titleLabel.TextColor3 = COLORS.text
titleLabel.TextSize = 15
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 50, 1, 0)
versionLabel.Position = UDim2.new(0, 290, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v1.1.1"
versionLabel.TextColor3 = COLORS.textDim
versionLabel.TextSize = 12
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextXAlignment = Enum.TextXAlignment.Left
versionLabel.Parent = titleBar

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -36, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = COLORS.danger
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar

-- Minimize button
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 36, 0, 36)
minBtn.Position = UDim2.new(1, -72, 0, 0)
minBtn.BackgroundTransparency = 1
minBtn.Text = "_"
minBtn.TextColor3 = COLORS.textDim
minBtn.TextSize = 16
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = titleBar

-- Dragging
local dragging = false
local dragStart, startPos

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

-- ===================== TABS =====================
local tabNames = {"Capture", "Farms", "Auto", "Log"}
local tabButtons = {}
local tabFrames = {}

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 30)
tabBar.Position = UDim2.new(0, 0, 0, 36)
tabBar.BackgroundColor3 = COLORS.bgSecondary
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local tabWidth = 1 / #tabNames
for i, name in ipairs(tabNames) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(tabWidth, -2, 1, 0)
	btn.Position = UDim2.new(tabWidth * (i - 1), 1, 0, 0)
	btn.BackgroundColor3 = COLORS.tabBg
	btn.BackgroundTransparency = 0.5
	btn.Text = name
	btn.TextColor3 = COLORS.textDim
	btn.TextSize = 13
	btn.Font = Enum.Font.GothamSemibold
	btn.BorderSizePixel = 0
	btn.Parent = tabBar
	tabButtons[name] = btn

	local frame = Instance.new("ScrollingFrame")
	frame.Size = UDim2.new(1, -10, 1, -76)
	frame.Position = UDim2.new(0, 5, 0, 66)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.ScrollBarImageColor3 = COLORS.accent
	frame.Visible = (name == activeTab)
	frame.CanvasSize = UDim2.new(0, 0, 0, 0)
	frame.Parent = mainFrame
	tabFrames[name] = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame

	-- Auto-resize canvas
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end)
end

local function switchTab(name)
	activeTab = name
	for tName, btn in pairs(tabButtons) do
		if tName == name then
			btn.BackgroundTransparency = 0
			btn.BackgroundColor3 = COLORS.accent
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundTransparency = 0.5
			btn.BackgroundColor3 = COLORS.tabBg
			btn.TextColor3 = COLORS.textDim
		end
	end
	for tName, frame in pairs(tabFrames) do
		frame.Visible = (tName == name)
	end
end

for name, btn in pairs(tabButtons) do
	btn.MouseButton1Click:Connect(function() switchTab(name) end)
end
switchTab("Capture")

-- ===================== HELPER: GUI ELEMENTS =====================
local function createSectionLabel(parent, text, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -10, 0, 24)
	lbl.BackgroundTransparency = 1
	lbl.Text = "  " .. text
	lbl.TextColor3 = COLORS.accent
	lbl.TextSize = 14
	lbl.Font = Enum.Font.GothamBold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.LayoutOrder = order or 0
	lbl.Parent = parent
	return lbl
end

local function createActionButton(parent, text, order, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -10, 0, 32)
	btn.BackgroundColor3 = COLORS.tabBg
	btn.Text = "  " .. text
	btn.TextColor3 = COLORS.text
	btn.TextSize = 13
	btn.Font = Enum.Font.GothamSemibold
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.BorderSizePixel = 0
	btn.LayoutOrder = order or 0
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.border
	stroke.Thickness = 1
	stroke.Parent = btn

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = COLORS.accentDark
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = COLORS.tabBg
	end)

	if callback then
		btn.MouseButton1Click:Connect(callback)
	end

	return btn
end

local function createToggle(parent, text, default, order, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -10, 0, 32)
	frame.BackgroundColor3 = COLORS.tabBg
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order or 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.border
	stroke.Thickness = 1
	stroke.Parent = frame

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -60, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = COLORS.text
	lbl.TextSize = 13
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = frame

	local toggleBg = Instance.new("Frame")
	toggleBg.Size = UDim2.new(0, 40, 0, 20)
	toggleBg.Position = UDim2.new(1, -50, 0.5, -10)
	toggleBg.BackgroundColor3 = default and COLORS.toggleOn or COLORS.toggleOff
	toggleBg.BorderSizePixel = 0
	toggleBg.Parent = frame

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 10)
	toggleCorner.Parent = toggleBg

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = toggleBg

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0, 8)
	knobCorner.Parent = knob

	local enabled = default

	local clickBtn = Instance.new("TextButton")
	clickBtn.Size = UDim2.new(1, 0, 1, 0)
	clickBtn.BackgroundTransparency = 1
	clickBtn.Text = ""
	clickBtn.Parent = frame

	clickBtn.MouseButton1Click:Connect(function()
		enabled = not enabled
		toggleBg.BackgroundColor3 = enabled and COLORS.toggleOn or COLORS.toggleOff
		knob.Position = enabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		if callback then callback(enabled) end
	end)

	return frame, function() return enabled end
end

local function createInfoLabel(parent, text, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -10, 0, 20)
	lbl.BackgroundTransparency = 1
	lbl.Text = "  " .. text
	lbl.TextColor3 = COLORS.textDim
	lbl.TextSize = 12
	lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextWrapped = true
	lbl.LayoutOrder = order or 0
	lbl.Parent = parent
	return lbl
end

-- ===================== PLACEMENT ENGINE =====================
-- Uses captured remote data to replay placements at new positions

local function getPlayerPosition()
	local char = LocalPlayer.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then return root.Position end
	end
	return Vector3.new(0, 0, 0)
end

-- Get the last captured Place/PlaceBind call
local function getLastPlaceCapture()
	for i = #capturedCalls, 1, -1 do
		local c = capturedCalls[i]
		if c.remote == "Place" or c.remote == "PlaceBind" or c.remote == "OptimizedPlaceBind" then
			return c
		end
	end
	return nil
end

-- Get the last captured PipeBind call
local function getLastPipeCapture()
	for i = #capturedCalls, 1, -1 do
		local c = capturedCalls[i]
		if c.remote == "PipeBind" then return c end
	end
	return nil
end

-- Get the last captured WireBind call
local function getLastWireCapture()
	for i = #capturedCalls, 1, -1 do
		local c = capturedCalls[i]
		if c.remote == "WireBind" then return c end
	end
	return nil
end

local function tryPlaceMachine(machineName, worldPosition)
	addLog("Placing: " .. machineName .. " at " .. tostring(worldPosition))

	local capture = getLastPlaceCapture()
	if not capture then
		addLog("  -> No captured placement yet! Place something manually first.")
		return false
	end

	local ok = replayPlacement(capture, worldPosition)
	if ok then
		addLog("  -> Replayed " .. capture.remote .. ":" .. capture.method .. " for " .. machineName)
	else
		addLog("  -> Failed to replay placement")
	end
	return ok
end

local function tryConnectPipe(fromPos, toPos)
	local capture = getLastPipeCapture()
	if capture and PS.PipeBind then
		pcall(function()
			PS.PipeBind:InvokeServer(fromPos, toPos)
		end)
		addLog("Piped: " .. tostring(fromPos) .. " -> " .. tostring(toPos))
	else
		addLog("No pipe capture yet - connect one pipe manually first")
	end
end

local function tryConnectWire(fromPos, toPos)
	local capture = getLastWireCapture()
	if capture and PS.WireBind then
		pcall(function()
			PS.WireBind:InvokeServer(fromPos, toPos)
		end)
		addLog("Wired: " .. tostring(fromPos) .. " -> " .. tostring(toPos))
	else
		addLog("No wire capture yet - connect one wire manually first")
	end
end

-- ===================== BUILD FARM =====================
local function buildFarm(blueprint)
	if currentFarmBuilding then
		addLog("Already building a farm! Wait for it to finish.")
		return
	end

	local capture = getLastPlaceCapture()
	if not capture then
		addLog("ERROR: No placement captured yet!")
		addLog("  1. Click 'Start Capture' in the Capture tab")
		addLog("  2. Place ONE thing with the hammer")
		addLog("  3. Then come back and click BUILD")
		return
	end

	currentFarmBuilding = true
	addLog("=== Building: " .. blueprint.name .. " ===")

	local origin = getPlayerPosition()
	origin = Vector3.new(
		math.floor(origin.X / 8) * 8,
		origin.Y,
		math.floor(origin.Z / 8) * 8
	)

	addLog("Origin: " .. tostring(origin))
	addLog("Using captured " .. capture.remote .. " call with " .. capture.argCount .. " args")

	-- Place all machines
	local placedPositions = {}
	for i, machine in ipairs(blueprint.machines) do
		local worldPos = origin + machine.offset
		placedPositions[i] = worldPos
		tryPlaceMachine(machine.name, worldPos)
		task.wait(0.5)
	end

	-- Connect pipes
	if blueprint.pipes then
		task.wait(1)
		addLog("Connecting pipes...")
		for _, pipe in ipairs(blueprint.pipes) do
			tryConnectPipe(placedPositions[pipe.from], placedPositions[pipe.to])
			task.wait(0.3)
		end
	end

	-- Connect wires
	if blueprint.wires then
		task.wait(1)
		addLog("Connecting wires...")
		for _, wire in ipairs(blueprint.wires) do
			tryConnectWire(placedPositions[wire.from], placedPositions[wire.to])
			task.wait(0.3)
		end
	end

	addLog("=== " .. blueprint.name .. " build complete! ===")
	currentFarmBuilding = false
end

-- ===================== AUTO SELL =====================
local function startAutoSell()
	if autoSellConnection then return end
	addLog("Auto-sell started")

	autoSellConnection = RunService.Heartbeat:Connect(function()
		if not autoSellEnabled then return end
		if PS.Buy then
			pcall(function() PS.Buy:FireServer() end)
		end
	end)
end

local function stopAutoSell()
	if autoSellConnection then
		autoSellConnection:Disconnect()
		autoSellConnection = nil
	end
	addLog("Auto-sell stopped")
end

-- ===================== POPULATE TABS =====================

-- === CAPTURE TAB ===
local captureTab = tabFrames["Capture"]

createSectionLabel(captureTab, "Step 1: Connect to Game", 0)
createInfoLabel(captureTab, "This hooks into the game's placement system.", 1)
createInfoLabel(captureTab, "After starting, place ONE thing with the hammer.", 2)
createInfoLabel(captureTab, "The script learns the exact remote call format.", 3)

local captureStatusLabel = createInfoLabel(captureTab, "Status: Not started", 4)

local captureLogLabel = createInfoLabel(captureTab, "", 6)

createActionButton(captureTab, "Start Capture (Hook Placement System)", 5, function()
	local ok, method = installCaptureHook()
	if ok then
		captureStatusLabel.Text = "  Status: LISTENING via " .. method .. " - Place something!"
		captureStatusLabel.TextColor3 = COLORS.success
		addLog("Capture started via " .. method .. "! Place something with the hammer.")

		if method == "workspace monitor" then
			addLog("Using universal fallback - will detect new buildings in workspace")
			addLog("Place something and it will be detected automatically")
		end

		-- Monitor for captures
		task.spawn(function()
			local lastCount = 0
			while true do
				task.wait(0.5)
				if #capturedCalls > lastCount then
					local latest = capturedCalls[#capturedCalls]
					captureStatusLabel.Text = "  Status: CAPTURED " .. #capturedCalls .. " calls! Latest: " .. latest.remote .. ":" .. latest.method

					local argSummary = ""
					for i, a in ipairs(latest.args) do
						argSummary = argSummary .. "\n    Arg " .. i .. " [" .. a.type .. "]: " .. a.value:sub(1, 80)
					end
					captureLogLabel.Text = "  Last capture:" .. argSummary
					captureLogLabel.Size = UDim2.new(1, -10, 0, 16 + (#latest.args * 16))

					addLog("Captured: " .. latest.remote .. ":" .. latest.method .. " (" .. latest.argCount .. " args)")
					lastCount = #capturedCalls
				end
			end
		end)
	else
		captureStatusLabel.Text = "  Status: FAILED - " .. method
		captureStatusLabel.TextColor3 = COLORS.danger
		addLog("ERROR: All capture methods failed")
	end
end)

createActionButton(captureTab, "View Capture File", 7, function()
	local content = ""
	pcall(function() content = readfile(captureFile) end)
	if content ~= "" then
		addLog("=== Capture File Contents ===")
		for line in content:gmatch("[^\n]+") do
			addLog(line)
		end
	else
		addLog("No capture file yet - start capture first")
	end
end)

createSectionLabel(captureTab, "Step 2: Check Connection", 10)

local psStatusLabel = createInfoLabel(captureTab, "PlacementSystem: checking...", 11)

createActionButton(captureTab, "Check PlacementSystem Status", 12, function()
	local status = {}
	if PlacementSystem then
		table.insert(status, "PlacementSystem: FOUND")
		for name, ref in pairs(PS) do
			if ref then
				local className = ""
				pcall(function() className = ref.ClassName end)
				table.insert(status, "  " .. name .. ": " .. className)
			end
		end
	else
		table.insert(status, "PlacementSystem: NOT FOUND")
	end
	for _, s in ipairs(status) do addLog(s) end
	psStatusLabel.Text = "  " .. status[1]
	psStatusLabel.TextColor3 = PlacementSystem and COLORS.success or COLORS.danger
end)

createSectionLabel(captureTab, "Game Buildings", 20)
createInfoLabel(captureTab, "Machines found in the game's building system:", 21)

createActionButton(captureTab, "List All Buildings", 22, function()
	local buildings = getGameBuildings()
	if #buildings > 0 then
		addLog("=== " .. #buildings .. " buildings found ===")
		local byCategory = {}
		for _, b in ipairs(buildings) do
			byCategory[b.category] = byCategory[b.category] or {}
			table.insert(byCategory[b.category], b.name)
		end
		for cat, names in pairs(byCategory) do
			addLog("[" .. cat .. "] " .. table.concat(names, ", "))
		end
	else
		addLog("No buildings folder found in PlacementSystem")
	end
end)

createSectionLabel(captureTab, "Captured Calls Summary", 30)

createActionButton(captureTab, "Show All Captured Calls", 31, function()
	if #capturedCalls == 0 then
		addLog("No calls captured yet")
		return
	end
	for i, c in ipairs(capturedCalls) do
		addLog("#" .. i .. " " .. c.remote .. ":" .. c.method .. " (" .. c.argCount .. " args)")
		for j, a in ipairs(c.args) do
			addLog("  Arg " .. j .. " [" .. a.type .. "]: " .. a.value:sub(1, 100))
		end
	end
end)

createActionButton(captureTab, "Clear Captures", 32, function()
	capturedCalls = {}
	captureStatusLabel.Text = "  Status: Cleared - place something to capture again"
	captureLogLabel.Text = ""
	pcall(function() writefile(captureFile, "") end)
	addLog("Captures cleared")
end)

-- === FARMS TAB ===
local farmsTab = tabFrames["Farms"]

createSectionLabel(farmsTab, "Farm Blueprints", 0)
createInfoLabel(farmsTab, "First: Go to Capture tab and place ONE thing.", 1)
createInfoLabel(farmsTab, "Then come back here, stand at your build spot, and click BUILD.", 2)

for i, bp in ipairs(FARM_BLUEPRINTS) do
	local order = i * 10 + 10

	-- Farm card frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -10, 0, 90)
	card.BackgroundColor3 = COLORS.bgSecondary
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = farmsTab

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 6)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = COLORS.border
	cardStroke.Thickness = 1
	cardStroke.Parent = card

	-- Tier badge
	local tierBadge = Instance.new("TextLabel")
	tierBadge.Size = UDim2.new(0, 70, 0, 18)
	tierBadge.Position = UDim2.new(0, 8, 0, 6)
	tierBadge.BackgroundColor3 = COLORS.accent
	tierBadge.Text = bp.tier
	tierBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	tierBadge.TextSize = 10
	tierBadge.Font = Enum.Font.GothamBold
	tierBadge.Parent = card

	local tierCorner = Instance.new("UICorner")
	tierCorner.CornerRadius = UDim.new(0, 4)
	tierCorner.Parent = tierBadge

	-- Farm name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -100, 0, 22)
	nameLabel.Position = UDim2.new(0, 84, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = bp.name
	nameLabel.TextColor3 = COLORS.text
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -16, 0, 28)
	descLabel.Position = UDim2.new(0, 8, 0, 28)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = bp.description
	descLabel.TextColor3 = COLORS.textDim
	descLabel.TextSize = 11
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Parent = card

	-- Machine count
	local countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.new(0, 100, 0, 16)
	countLabel.Position = UDim2.new(0, 8, 1, -22)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = #bp.machines .. " machines"
	countLabel.TextColor3 = COLORS.textDim
	countLabel.TextSize = 10
	countLabel.Font = Enum.Font.Gotham
	countLabel.TextXAlignment = Enum.TextXAlignment.Left
	countLabel.Parent = card

	-- Build button
	local buildBtn = Instance.new("TextButton")
	buildBtn.Size = UDim2.new(0, 80, 0, 26)
	buildBtn.Position = UDim2.new(1, -90, 1, -32)
	buildBtn.BackgroundColor3 = COLORS.accent
	buildBtn.Text = "BUILD"
	buildBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buildBtn.TextSize = 12
	buildBtn.Font = Enum.Font.GothamBold
	buildBtn.BorderSizePixel = 0
	buildBtn.Parent = card

	local buildCorner = Instance.new("UICorner")
	buildCorner.CornerRadius = UDim.new(0, 4)
	buildCorner.Parent = buildBtn

	buildBtn.MouseButton1Click:Connect(function()
		buildBtn.Text = "BUILDING..."
		buildBtn.BackgroundColor3 = COLORS.textDim
		task.spawn(function()
			buildFarm(bp)
			buildBtn.Text = "BUILD"
			buildBtn.BackgroundColor3 = COLORS.accent
		end)
	end)
end

-- Custom farm section
createSectionLabel(farmsTab, "Custom Placement", 200)

local customNameBox = Instance.new("TextBox")
customNameBox.Size = UDim2.new(1, -10, 0, 30)
customNameBox.BackgroundColor3 = COLORS.tabBg
customNameBox.Text = ""
customNameBox.PlaceholderText = "Machine name (e.g. Coal Drill)"
customNameBox.TextColor3 = COLORS.text
customNameBox.PlaceholderColor3 = COLORS.textDim
customNameBox.TextSize = 13
customNameBox.Font = Enum.Font.Gotham
customNameBox.BorderSizePixel = 0
customNameBox.ClearTextOnFocus = false
customNameBox.LayoutOrder = 201
customNameBox.Parent = farmsTab

local customCorner = Instance.new("UICorner")
customCorner.CornerRadius = UDim.new(0, 6)
customCorner.Parent = customNameBox

createActionButton(farmsTab, "Place Single Machine at Position", 202, function()
	local name = customNameBox.Text
	if name == "" then
		addLog("Enter a machine name first!")
		return
	end
	local pos = getPlayerPosition()
	tryPlaceMachine(name, pos)
end)

local customCountBox = Instance.new("TextBox")
customCountBox.Size = UDim2.new(1, -10, 0, 30)
customCountBox.BackgroundColor3 = COLORS.tabBg
customCountBox.Text = ""
customCountBox.PlaceholderText = "Row count (e.g. 5)"
customCountBox.TextColor3 = COLORS.text
customCountBox.PlaceholderColor3 = COLORS.textDim
customCountBox.TextSize = 13
customCountBox.Font = Enum.Font.Gotham
customCountBox.BorderSizePixel = 0
customCountBox.ClearTextOnFocus = false
customCountBox.LayoutOrder = 203
customCountBox.Parent = farmsTab

local customCountCorner = Instance.new("UICorner")
customCountCorner.CornerRadius = UDim.new(0, 6)
customCountCorner.Parent = customCountBox

createActionButton(farmsTab, "Place Row of Machines (8 stud spacing)", 204, function()
	local name = customNameBox.Text
	local count = tonumber(customCountBox.Text) or 3
	if name == "" then
		addLog("Enter a machine name first!")
		return
	end
	if count > 50 then count = 50 end
	local origin = getPlayerPosition()
	task.spawn(function()
		currentFarmBuilding = true
		for i = 0, count - 1 do
			tryPlaceMachine(name, origin + Vector3.new(i * 8, 0, 0))
			task.wait(0.5)
		end
		addLog("Placed row of " .. count .. " " .. name)
		currentFarmBuilding = false
	end)
end)

local customSpacingBox = Instance.new("TextBox")
customSpacingBox.Size = UDim2.new(1, -10, 0, 30)
customSpacingBox.BackgroundColor3 = COLORS.tabBg
customSpacingBox.Text = ""
customSpacingBox.PlaceholderText = "Grid size (e.g. 3x3)"
customSpacingBox.TextColor3 = COLORS.text
customSpacingBox.PlaceholderColor3 = COLORS.textDim
customSpacingBox.TextSize = 13
customSpacingBox.Font = Enum.Font.Gotham
customSpacingBox.BorderSizePixel = 0
customSpacingBox.ClearTextOnFocus = false
customSpacingBox.LayoutOrder = 205
customSpacingBox.Parent = farmsTab

local customSpacingCorner = Instance.new("UICorner")
customSpacingCorner.CornerRadius = UDim.new(0, 6)
customSpacingCorner.Parent = customSpacingBox

createActionButton(farmsTab, "Place Grid of Machines (8 stud spacing)", 206, function()
	local name = customNameBox.Text
	local gridText = customSpacingBox.Text
	if name == "" then
		addLog("Enter a machine name first!")
		return
	end
	local cols, rows = 3, 3
	if gridText:find("x") then
		local c, r = gridText:match("(%d+)x(%d+)")
		cols = tonumber(c) or 3
		rows = tonumber(r) or 3
	end
	if cols > 10 then cols = 10 end
	if rows > 10 then rows = 10 end

	local origin = getPlayerPosition()
	task.spawn(function()
		currentFarmBuilding = true
		for row = 0, rows - 1 do
			for col = 0, cols - 1 do
				tryPlaceMachine(name, origin + Vector3.new(col * 8, 0, row * 8))
				task.wait(0.5)
			end
		end
		addLog("Placed " .. cols .. "x" .. rows .. " grid of " .. name)
		currentFarmBuilding = false
	end)
end)

-- === AUTO TAB ===
local autoTab = tabFrames["Auto"]

createSectionLabel(autoTab, "Automation", 0)

createToggle(autoTab, "Auto Sell (fire sell remotes)", false, 1, function(on)
	autoSellEnabled = on
	if on then startAutoSell() else stopAutoSell() end
end)

createSectionLabel(autoTab, "Resource Monitor", 10)

local monitorLabel = createInfoLabel(autoTab, "Scanning workspace for resources...", 11)

createActionButton(autoTab, "Scan Resources in Workspace", 12, function()
	addLog("Scanning workspace for resource nodes...")
	local counts = {}
	pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("BasePart") then
				local name = obj.Name:lower()
				for _, res in ipairs({"coal", "iron", "copper", "gold", "oil", "lithium", "tungsten", "uranium"}) do
					if name:find(res) then
						counts[res] = (counts[res] or 0) + 1
					end
				end
			end
		end
	end)
	local parts = {}
	for res, count in pairs(counts) do
		table.insert(parts, res .. ": " .. count)
	end
	local result = #parts > 0 and table.concat(parts, ", ") or "No resource nodes found"
	monitorLabel.Text = "  " .. result
	addLog("Resources: " .. result)
end)

createSectionLabel(autoTab, "Player Machines", 20)

createActionButton(autoTab, "List My Placed Machines", 21, function()
	addLog("Scanning for your machines...")
	local myMachines = {}
	pcall(function()
		-- Look for machines owned by the player in workspace
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") then
				-- Check common ownership patterns
				local owner = obj:FindFirstChild("Owner") or obj:FindFirstChild("PlayerName") or obj:GetAttribute("Owner")
				if owner then
					local ownerName = ""
					if typeof(owner) == "Instance" and owner:IsA("StringValue") then
						ownerName = owner.Value
					elseif type(owner) == "string" then
						ownerName = owner
					end
					if ownerName == LocalPlayer.Name or ownerName == tostring(LocalPlayer.UserId) then
						myMachines[obj.Name] = (myMachines[obj.Name] or 0) + 1
					end
				end
			end
		end
	end)
	if next(myMachines) then
		for name, count in pairs(myMachines) do
			addLog("  " .. name .. " x" .. count)
		end
	else
		addLog("  No owned machines found (may use different ownership system)")
	end
end)

createSectionLabel(autoTab, "Teleport", 30)

createActionButton(autoTab, "TP to Nearest Truck Depot", 31, function()
	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local nearest = nil
	local nearestDist = math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and (obj.Name:lower():find("truck") or obj.Name:lower():find("depot")) then
			local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if primary then
				local dist = (primary.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearest = primary
					nearestDist = dist
				end
			end
		end
	end

	if nearest then
		root.CFrame = nearest.CFrame + Vector3.new(0, 5, 0)
		addLog("Teleported to depot (" .. math.floor(nearestDist) .. " studs)")
	else
		addLog("No truck depot found in workspace")
	end
end)

createActionButton(autoTab, "TP to Nearest Drill", 32, function()
	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local nearest = nil
	local nearestDist = math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name:lower():find("drill") then
			local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if primary then
				local dist = (primary.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearest = primary
					nearestDist = dist
				end
			end
		end
	end

	if nearest then
		root.CFrame = nearest.CFrame + Vector3.new(0, 5, 0)
		addLog("Teleported to drill (" .. math.floor(nearestDist) .. " studs)")
	else
		addLog("No drill found in workspace")
	end
end)

-- (Remotes tab removed - replaced by Capture tab)

-- === LOG TAB ===
logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -10, 1, -76)
logFrame.Position = UDim2.new(0, 5, 0, 66)
logFrame.BackgroundColor3 = COLORS.bgSecondary
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 4
logFrame.ScrollBarImageColor3 = COLORS.accent
logFrame.Visible = false
logFrame.Parent = mainFrame

-- Replace the auto-generated log tab frame
tabFrames["Log"]:Destroy()
tabFrames["Log"] = logFrame

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 6)
logCorner.Parent = logFrame

-- ===================== TOGGLE BUTTON =====================
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 40, 0, 40)
toggleBtn.Position = UDim2.new(0, 10, 0.5, -20)
toggleBtn.BackgroundColor3 = COLORS.accent
toggleBtn.Text = "PB"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize = 12
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.BorderSizePixel = 0
toggleBtn.Visible = false
toggleBtn.ZIndex = 10
toggleBtn.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleBtn

-- ===================== CLOSE / MINIMIZE =====================
closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	toggleBtn.Visible = true
	guiOpen = false
end)

minBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	toggleBtn.Visible = true
	guiOpen = false
end)

toggleBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = true
	toggleBtn.Visible = false
	guiOpen = true
end)

-- Toggle with Insert key
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Insert then
		guiOpen = not guiOpen
		mainFrame.Visible = guiOpen
		toggleBtn.Visible = not guiOpen
	end
end)

-- ===================== STARTUP =====================
addLog("Pebbleford Hub - Industrialist v1.1.1 loaded")
if PlacementSystem then
	addLog("PlacementSystem found!")
	local psChildren = {}
	for name, ref in pairs(PS) do
		if ref then table.insert(psChildren, name) end
	end
	addLog("  Connected: " .. table.concat(psChildren, ", "))
else
	addLog("WARNING: PlacementSystem not found in ReplicatedStorage")
end
addLog("Go to Capture tab -> Start Capture -> Place one thing with hammer")
addLog("Then use Farms tab to auto-build!")
addLog("Press Insert to toggle GUI.")
