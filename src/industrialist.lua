-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate("industrialist") then return end

-- ================================================================
-- Pebbleford Hub - Industrialist Auto Farm v1.2.9
-- Auto-place farm layouts | Resource monitor | Auto-sell
-- Direct PlaceBind placement | Auto-wire | Auto-pipe
-- ================================================================

print("[PB Industrialist v1.2.9] Loading...")

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
	PS.Place = PlacementSystem:FindFirstChild("Place") -- RemoteEvent
	PS.PlaceBind = PlacementSystem:FindFirstChild("PlaceBind") -- RemoteFunction (MAIN)
	PS.OptimizedPlaceBind = PlacementSystem:FindFirstChild("OptimizedPlaceBind")
	PS.PipeBind = PlacementSystem:FindFirstChild("PipeBind") -- RemoteFunction
	PS.WireBind = PlacementSystem:FindFirstChild("WireBind") -- RemoteFunction
	PS.Buy = PlacementSystem:FindFirstChild("Buy")
	PS.Delete = PlacementSystem:FindFirstChild("Delete")
	PS.CheckOres = PlacementSystem:FindFirstChild("CheckOres")
	PS.GetNode = PlacementSystem:FindFirstChild("GetNode")
	PS.Buildings = PlacementSystem:FindFirstChild("Buildings")
end

-- Building model cache: maps friendly name -> building model instance
local buildingCache = {}
-- Build the building cache from PlacementSystem.Buildings
local function buildBuildingCache()
	buildingCache = {}
	if not PS.Buildings then return end
	for _, category in ipairs(PS.Buildings:GetChildren()) do
		for _, building in ipairs(category:GetChildren()) do
			-- Store by exact name
			buildingCache[building.Name] = building
			-- Also store by friendly name with spaces (e.g. "Coal Drill" -> "CoalDrill")
			local friendly = building.Name:gsub("(%l)(%u)", "%1 %2")
			if friendly ~= building.Name then
				buildingCache[friendly] = building
			end
		end
	end
end

-- Find a building model by name (fuzzy match)
local function findBuilding(name)
	-- Exact match first
	if buildingCache[name] then return buildingCache[name] end
	-- Try without spaces
	local noSpaces = name:gsub(" ", "")
	if buildingCache[noSpaces] then return buildingCache[noSpaces] end
	-- Try lowercase fuzzy match
	local lower = name:lower()
	for cachedName, model in pairs(buildingCache) do
		if cachedName:lower() == lower or cachedName:lower():gsub(" ", "") == lower:gsub(" ", "") then
			return model
		end
	end
	-- Partial match
	for cachedName, model in pairs(buildingCache) do
		if cachedName:lower():find(lower:gsub(" ", ""), 1, true) then
			return model
		end
	end
	return nil
end


-- ===================== PLACEMENT ENGINE =====================
-- PlaceBind:InvokeServer(buildingModel, CFrame) is the confirmed working format

local function getPlayerPosition()
	local char = LocalPlayer.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then return root.Position end
	end
	return Vector3.new(0, 0, 0)
end

-- Buy a building from the shop - try multiple methods
local function buyBuilding(model)
	if PS.Buy then
		-- Try both instance and string name
		pcall(function() PS.Buy:FireServer(model) end)
		task.wait(0.05)
		pcall(function() PS.Buy:FireServer(model.Name) end)
		task.wait(0.05)
	end
end

-- Try to place, returns: success, message, serverResult
local function tryPlace(model, cf)
	if PS.PlaceBind then
		local ok, result = pcall(function()
			return PS.PlaceBind:InvokeServer(model, cf)
		end)
		if ok then
			return true, result
		else
			return false, result
		end
	end
	return false, "No PlaceBind"
end

local function placeMachine(buildingName, worldPosition, rotation)
	local model = findBuilding(buildingName)
	if not model then
		return false, "Building not found: " .. buildingName
	end

	local cf = CFrame.new(worldPosition)
	if rotation then
		cf = cf * CFrame.Angles(0, math.rad(rotation), 0)
	end

	-- Attempt 1: Try placing directly (might already be owned)
	local ok, result = tryPlace(model, cf)
	if ok then
		-- Check if server indicated success (nil = success from our earlier test)
		-- If result is a string containing "enough" or false, placement failed
		local resultStr = tostring(result):lower()
		if result == nil or (result ~= false and not resultStr:find("enough") and not resultStr:find("fail") and not resultStr:find("error")) then
			return true, "Placed " .. buildingName .. " (already owned)"
		end
		print("[PB Industrialist] Place returned: " .. tostring(result) .. " - trying to buy first")
	end

	-- Attempt 2: Buy then place
	buyBuilding(model)
	task.wait(0.3)

	ok, result = tryPlace(model, cf)
	if ok then
		local resultStr = tostring(result):lower()
		if result == nil or (result ~= false and not resultStr:find("enough") and not resultStr:find("fail")) then
			return true, "Placed " .. buildingName .. " (bought + placed)"
		end
		print("[PB Industrialist] Still failed after buy: " .. tostring(result))
	end

	-- Attempt 3: Try alternate buy methods then place
	print("[PB Industrialist] Trying alternate buy methods for " .. buildingName)
	if PS.Buy then
		-- Try with category
		if model.Parent then
			pcall(function() PS.Buy:FireServer(model.Parent.Name, model.Name) end)
			task.wait(0.05)
			pcall(function() PS.Buy:FireServer(model.Name, model.Parent.Name) end)
			task.wait(0.05)
		end
		-- Try with quantity
		pcall(function() PS.Buy:FireServer(model, 1) end)
		task.wait(0.05)
		pcall(function() PS.Buy:FireServer(model.Name, 1) end)
		task.wait(0.3)
	end

	ok, result = tryPlace(model, cf)
	if ok then
		return true, "Placed " .. buildingName .. " (alt buy)"
	end

	return false, "Failed to place " .. buildingName .. ": " .. tostring(result)
end

-- Find a placed building in workspace near a position
local function findPlacedBuilding(pos, radius)
	radius = radius or 10
	local nearest = nil
	local nearestDist = radius
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.PrimaryPart then
			local dist = (obj.PrimaryPart.Position - pos).Magnitude
			if dist < nearestDist then
				nearest = obj
				nearestDist = dist
			end
		end
	end
	return nearest
end

local function connectPipe(fromPos, toPos)
	if not PS.PipeBind then return false, "No PipeBind remote" end

	-- Find the placed buildings near these positions
	local fromModel = findPlacedBuilding(fromPos)
	local toModel = findPlacedBuilding(toPos)

	print("[PB Industrialist] Pipe: from=" .. tostring(fromModel and fromModel.Name or "nil") .. " to=" .. tostring(toModel and toModel.Name or "nil"))

	-- Try multiple arg formats
	local tryFormats = {}
	-- Position-based
	table.insert(tryFormats, function() return PS.PipeBind:InvokeServer(fromPos, toPos) end)
	table.insert(tryFormats, function() return PS.PipeBind:InvokeServer(CFrame.new(fromPos), CFrame.new(toPos)) end)
	-- Model-based
	if fromModel and toModel then
		table.insert(tryFormats, function() return PS.PipeBind:InvokeServer(fromModel, toModel) end)
		table.insert(tryFormats, function() return PS.PipeBind:InvokeServer(fromModel.PrimaryPart, toModel.PrimaryPart) end)
	end

	for i, fn in ipairs(tryFormats) do
		local ok, result = pcall(fn)
		print("[PB Industrialist] PipeBind format " .. i .. ": ok=" .. tostring(ok) .. " result=" .. tostring(result))
		if ok and result ~= false then
			return true, "Pipe connected (format " .. i .. "): " .. tostring(result)
		end
	end
	return false, "All pipe formats failed"
end

local function connectWire(fromPos, toPos)
	if not PS.WireBind then return false, "No WireBind remote" end

	local fromModel = findPlacedBuilding(fromPos)
	local toModel = findPlacedBuilding(toPos)

	print("[PB Industrialist] Wire: from=" .. tostring(fromModel and fromModel.Name or "nil") .. " to=" .. tostring(toModel and toModel.Name or "nil"))

	local tryFormats = {}
	table.insert(tryFormats, function() return PS.WireBind:InvokeServer(fromPos, toPos) end)
	table.insert(tryFormats, function() return PS.WireBind:InvokeServer(CFrame.new(fromPos), CFrame.new(toPos)) end)
	if fromModel and toModel then
		table.insert(tryFormats, function() return PS.WireBind:InvokeServer(fromModel, toModel) end)
		table.insert(tryFormats, function() return PS.WireBind:InvokeServer(fromModel.PrimaryPart, toModel.PrimaryPart) end)
	end

	for i, fn in ipairs(tryFormats) do
		local ok, result = pcall(fn)
		print("[PB Industrialist] WireBind format " .. i .. ": ok=" .. tostring(ok) .. " result=" .. tostring(result))
		if ok and result ~= false then
			return true, "Wire connected (format " .. i .. "): " .. tostring(result)
		end
	end
	return false, "All wire formats failed"
end


-- ===================== FARM BLUEPRINTS =====================
-- Each blueprint defines machines and their relative positions in a grid
-- Positions are in studs relative to origin (where player stands)

local FARM_BLUEPRINTS = {
	{
		name = "Coal Starter",
		description = "3 Coal Drills -> Truck Depot. Wind Turbine + AV Poles for power.",
		tier = "Early",
		machines = {
			{name = "Coal Drill", offset = Vector3.new(0, 0, 0)},        -- 1
			{name = "Coal Drill", offset = Vector3.new(8, 0, 0)},        -- 2
			{name = "Coal Drill", offset = Vector3.new(16, 0, 0)},       -- 3
			{name = "Truck Depot", offset = Vector3.new(8, 0, 16)},      -- 4
			{name = "Wind Turbine 2", offset = Vector3.new(-8, 0, 8)},   -- 5
			{name = "AV Pole", offset = Vector3.new(0, 0, 8)},           -- 6
			{name = "AV Pole", offset = Vector3.new(8, 0, 8)},           -- 7
			{name = "AV Pole", offset = Vector3.new(16, 0, 8)},          -- 8
		},
		pipes = {
			{from = 1, to = 4},
			{from = 2, to = 4},
			{from = 3, to = 4},
		},
		wires = {
			{from = 5, to = 6},  -- Turbine -> first pole
			{from = 6, to = 7},  -- Pole chain
			{from = 7, to = 8},
		},
	},
	{
		name = "Copper Wire Line",
		description = "9 Copper Drills -> 3 Furnaces -> Molder -> 2 Presses -> 2 Rollers -> 4 Depots",
		tier = "Early-Mid",
		machines = {
			-- Row 1: Drills
			{name = "Copper Drill", offset = Vector3.new(0, 0, 0)},       -- 1
			{name = "Copper Drill", offset = Vector3.new(8, 0, 0)},       -- 2
			{name = "Copper Drill", offset = Vector3.new(16, 0, 0)},      -- 3
			{name = "Copper Drill", offset = Vector3.new(24, 0, 0)},      -- 4
			{name = "Copper Drill", offset = Vector3.new(32, 0, 0)},      -- 5
			{name = "Copper Drill", offset = Vector3.new(40, 0, 0)},      -- 6
			{name = "Copper Drill", offset = Vector3.new(48, 0, 0)},      -- 7
			{name = "Copper Drill", offset = Vector3.new(56, 0, 0)},      -- 8
			{name = "Copper Drill", offset = Vector3.new(64, 0, 0)},      -- 9
			-- Row 2: Furnaces
			{name = "Electric Furnace", offset = Vector3.new(8, 0, 16)},   -- 10
			{name = "Electric Furnace", offset = Vector3.new(32, 0, 16)},  -- 11
			{name = "Electric Furnace", offset = Vector3.new(56, 0, 16)},  -- 12
			-- Row 3: Molder
			{name = "Ingot Molder", offset = Vector3.new(32, 0, 32)},     -- 13
			-- Row 4: Presses + Rollers
			{name = "Press", offset = Vector3.new(16, 0, 48)},            -- 14
			{name = "Press", offset = Vector3.new(48, 0, 48)},            -- 15
			{name = "Roller", offset = Vector3.new(16, 0, 64)},           -- 16
			{name = "Roller", offset = Vector3.new(48, 0, 64)},           -- 17
			-- Row 5: Truck Depots
			{name = "Truck Depot", offset = Vector3.new(0, 0, 80)},       -- 18
			{name = "Truck Depot", offset = Vector3.new(20, 0, 80)},      -- 19
			{name = "Truck Depot", offset = Vector3.new(40, 0, 80)},      -- 20
			{name = "Truck Depot", offset = Vector3.new(60, 0, 80)},      -- 21
			-- Power: Wind Turbines + AV Pole line down the middle
			{name = "Wind Turbine 2", offset = Vector3.new(-12, 0, 32)},  -- 22
			{name = "Wind Turbine 2", offset = Vector3.new(76, 0, 32)},   -- 23
			{name = "AV Pole", offset = Vector3.new(0, 0, 32)},           -- 24
			{name = "AV Pole", offset = Vector3.new(16, 0, 32)},          -- 25
			{name = "AV Pole", offset = Vector3.new(32, 0, 32)},          -- 26 (near molder)
			{name = "AV Pole", offset = Vector3.new(48, 0, 32)},          -- 27
			{name = "AV Pole", offset = Vector3.new(64, 0, 32)},          -- 28
		},
		wires = {
			{from = 22, to = 24}, -- Left turbine -> first pole
			{from = 24, to = 25}, -- Pole chain
			{from = 25, to = 26},
			{from = 26, to = 27},
			{from = 27, to = 28},
			{from = 28, to = 23}, -- Last pole -> right turbine
		},
	},
	{
		name = "Iron Coil Line",
		description = "15 Iron Drills -> 5 Furnaces -> Molder -> 8 Sawmills -> 8 Rollers -> Van Depots",
		tier = "Mid",
		machines = {
			-- Drills row
			{name = "Iron Drill", offset = Vector3.new(0, 0, 0)},         -- 1
			{name = "Iron Drill", offset = Vector3.new(8, 0, 0)},         -- 2
			{name = "Iron Drill", offset = Vector3.new(16, 0, 0)},        -- 3
			{name = "Iron Drill", offset = Vector3.new(24, 0, 0)},        -- 4
			{name = "Iron Drill", offset = Vector3.new(32, 0, 0)},        -- 5
			{name = "Iron Drill", offset = Vector3.new(40, 0, 0)},        -- 6
			{name = "Iron Drill", offset = Vector3.new(48, 0, 0)},        -- 7
			{name = "Iron Drill", offset = Vector3.new(56, 0, 0)},        -- 8
			{name = "Iron Drill", offset = Vector3.new(64, 0, 0)},        -- 9
			{name = "Iron Drill", offset = Vector3.new(72, 0, 0)},        -- 10
			{name = "Iron Drill", offset = Vector3.new(80, 0, 0)},        -- 11
			{name = "Iron Drill", offset = Vector3.new(88, 0, 0)},        -- 12
			{name = "Iron Drill", offset = Vector3.new(96, 0, 0)},        -- 13
			{name = "Iron Drill", offset = Vector3.new(104, 0, 0)},       -- 14
			{name = "Iron Drill", offset = Vector3.new(112, 0, 0)},       -- 15
			-- Furnaces
			{name = "Electric Furnace", offset = Vector3.new(8, 0, 16)},  -- 16
			{name = "Electric Furnace", offset = Vector3.new(32, 0, 16)}, -- 17
			{name = "Electric Furnace", offset = Vector3.new(56, 0, 16)}, -- 18
			{name = "Electric Furnace", offset = Vector3.new(80, 0, 16)}, -- 19
			{name = "Electric Furnace", offset = Vector3.new(104, 0, 16)},-- 20
			-- Molder
			{name = "Ingot Molder", offset = Vector3.new(56, 0, 32)},     -- 21
			-- Sawmills
			{name = "Sawmill", offset = Vector3.new(0, 0, 48)},           -- 22
			{name = "Sawmill", offset = Vector3.new(16, 0, 48)},          -- 23
			{name = "Sawmill", offset = Vector3.new(32, 0, 48)},          -- 24
			{name = "Sawmill", offset = Vector3.new(48, 0, 48)},          -- 25
			{name = "Sawmill", offset = Vector3.new(64, 0, 48)},          -- 26
			{name = "Sawmill", offset = Vector3.new(80, 0, 48)},          -- 27
			{name = "Sawmill", offset = Vector3.new(96, 0, 48)},          -- 28
			{name = "Sawmill", offset = Vector3.new(112, 0, 48)},         -- 29
			-- Rollers
			{name = "Roller", offset = Vector3.new(0, 0, 64)},            -- 30
			{name = "Roller", offset = Vector3.new(16, 0, 64)},           -- 31
			{name = "Roller", offset = Vector3.new(32, 0, 64)},           -- 32
			{name = "Roller", offset = Vector3.new(48, 0, 64)},           -- 33
			{name = "Roller", offset = Vector3.new(64, 0, 64)},           -- 34
			{name = "Roller", offset = Vector3.new(80, 0, 64)},           -- 35
			{name = "Roller", offset = Vector3.new(96, 0, 64)},           -- 36
			{name = "Roller", offset = Vector3.new(112, 0, 64)},          -- 37
			-- Van Depots
			{name = "Van Depot", offset = Vector3.new(20, 0, 80)},        -- 38
			{name = "Van Depot", offset = Vector3.new(90, 0, 80)},        -- 39
			-- Power: Wind Turbines + AV Pole line
			{name = "Wind Turbine 2", offset = Vector3.new(-12, 0, 32)},  -- 40
			{name = "Wind Turbine 2", offset = Vector3.new(124, 0, 32)},  -- 41
			{name = "AV Pole", offset = Vector3.new(0, 0, 32)},           -- 42
			{name = "AV Pole", offset = Vector3.new(16, 0, 32)},          -- 43
			{name = "AV Pole", offset = Vector3.new(32, 0, 32)},          -- 44
			{name = "AV Pole", offset = Vector3.new(48, 0, 32)},          -- 45
			{name = "AV Pole", offset = Vector3.new(64, 0, 32)},          -- 46
			{name = "AV Pole", offset = Vector3.new(80, 0, 32)},          -- 47
			{name = "AV Pole", offset = Vector3.new(96, 0, 32)},          -- 48
			{name = "AV Pole", offset = Vector3.new(112, 0, 32)},         -- 49
		},
		wires = {
			{from = 40, to = 42}, -- Left turbine -> first pole
			{from = 42, to = 43}, -- Pole chain across the factory
			{from = 43, to = 44},
			{from = 44, to = 45},
			{from = 45, to = 46},
			{from = 46, to = 47},
			{from = 47, to = 48},
			{from = 48, to = 49},
			{from = 49, to = 41}, -- Last pole -> right turbine
		},
	},
	{
		name = "Gearbox Factory",
		description = "Crankshafts + Plastic Casings -> Craft Assemblers. $2,552/unit.",
		tier = "Mid-Late",
		machines = {
			-- Crankshaft line
			{name = "Iron Drill", offset = Vector3.new(0, 0, 0)},                -- 1
			{name = "Iron Drill", offset = Vector3.new(8, 0, 0)},                -- 2
			{name = "Iron Drill", offset = Vector3.new(16, 0, 0)},               -- 3
			{name = "Electric Furnace", offset = Vector3.new(8, 0, 16)},          -- 4
			{name = "Ingot Molder", offset = Vector3.new(8, 0, 32)},             -- 5
			{name = "Press", offset = Vector3.new(8, 0, 48)},                    -- 6
			-- Plastic line
			{name = "Oil Pump", offset = Vector3.new(40, 0, 0)},                 -- 7
			{name = "Oil Pump", offset = Vector3.new(48, 0, 0)},                 -- 8
			{name = "Plastic Molding Machine", offset = Vector3.new(44, 0, 16)},  -- 9
			-- Assemblers
			{name = "Craft Assembler", offset = Vector3.new(24, 0, 64)},         -- 10
			{name = "Craft Assembler", offset = Vector3.new(36, 0, 64)},         -- 11
			-- Sell
			{name = "Truck Depot", offset = Vector3.new(30, 0, 80)},             -- 12
			-- Power: Wind Turbine + AV Poles
			{name = "Wind Turbine 2", offset = Vector3.new(-12, 0, 32)},         -- 13
			{name = "AV Pole", offset = Vector3.new(0, 0, 32)},                  -- 14
			{name = "AV Pole", offset = Vector3.new(16, 0, 32)},                 -- 15
			{name = "AV Pole", offset = Vector3.new(32, 0, 32)},                 -- 16
			{name = "AV Pole", offset = Vector3.new(48, 0, 32)},                 -- 17
		},
		wires = {
			{from = 13, to = 14}, -- Turbine -> first pole
			{from = 14, to = 15}, -- Pole chain
			{from = 15, to = 16},
			{from = 16, to = 17},
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

local tabNames = {"Farms", "Auto", "Log"}
local tabFrames = {}

local Window = Fluent:CreateWindow({
	Title = "Industrialist Hub",
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

-- ===================== BUILD FARM =====================
local function buildFarm(blueprint)
	if currentFarmBuilding then
		addLog("Already building a farm! Wait for it to finish.")
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

	-- Pre-check: verify all building names exist
	addLog("Checking building names...")
	local allFound = true
	for i, machine in ipairs(blueprint.machines) do
		local model = findBuilding(machine.name)
		if model then
			addLog("  OK: " .. machine.name .. " -> " .. model.Name)
		else
			addLog("  MISSING: " .. machine.name .. " (not found in game!)")
			allFound = false
		end
	end
	if not allFound then
		addLog("WARNING: Some buildings not found! They will be skipped.")
	end

	-- Place all machines
	local placedPositions = {}
	for i, machine in ipairs(blueprint.machines) do
		local worldPos = origin + machine.offset
		placedPositions[i] = worldPos
		addLog("Placing " .. i .. "/" .. #blueprint.machines .. ": " .. machine.name)
		local ok, msg = placeMachine(machine.name, worldPos)
		addLog("  -> " .. msg)
		task.wait(0.8)
	end

	-- Connect pipes
	if blueprint.pipes then
		task.wait(2)
		addLog("Connecting " .. #blueprint.pipes .. " pipes...")
		for j, pipe in ipairs(blueprint.pipes) do
			local fromPos = placedPositions[pipe.from]
			local toPos = placedPositions[pipe.to]
			addLog("  Pipe " .. j .. ": machine " .. pipe.from .. " -> " .. pipe.to)
			local ok, result = connectPipe(fromPos, toPos)
			addLog("    ok=" .. tostring(ok) .. " result=" .. tostring(result))
			task.wait(0.5)
		end
	end

	-- Connect wires
	if blueprint.wires then
		task.wait(2)
		addLog("Connecting " .. #blueprint.wires .. " wires...")
		for j, wire in ipairs(blueprint.wires) do
			local fromPos = placedPositions[wire.from]
			local toPos = placedPositions[wire.to]
			addLog("  Wire " .. j .. ": machine " .. wire.from .. " -> " .. wire.to)
			local ok, result = connectWire(fromPos, toPos)
			addLog("    ok=" .. tostring(ok) .. " result=" .. tostring(result))
			task.wait(0.5)
		end
	end

	addLog("=== " .. blueprint.name .. " build complete! ===")
	currentFarmBuilding = false
end

-- ===================== AUTO SELL =====================
local function startAutoSell()
	if autoSellConnection then return end
	addLog("Auto-sell started")

	local lastAutoSellWarn = 0
	autoSellConnection = RunService.Heartbeat:Connect(function()
		if not autoSellEnabled then return end
		-- SAFETY: this game has no confirmed sell remote here. Do NOT fire
		-- PS.Buy (the BUY remote) to sell -- that spams purchases every frame
		-- and never sells. Neutralized until the real sell remote is found.
		local now = os.clock()
		if now - lastAutoSellWarn >= 5 then
			lastAutoSellWarn = now
			addLog("Auto Sell needs the game's real sell remote (recon required)")
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

-- === FARMS TAB ===
local farmsTab = tabFrames["Farms"]

createSectionLabel(farmsTab, "Farm Blueprints", 0)
createInfoLabel(farmsTab, "Stand at your build spot and click BUILD.", 1)
createInfoLabel(farmsTab, "Uses direct PlaceBind to place machines automatically.", 2)

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

createActionButton(farmsTab, "List All Available Buildings", 200, function()
	if not PS.Buildings then
		addLog("No PlacementSystem.Buildings found")
		return
	end
	local total = 0
	for _, category in ipairs(PS.Buildings:GetChildren()) do
		local names = {}
		for _, building in ipairs(category:GetChildren()) do
			table.insert(names, building.Name)
			total = total + 1
		end
		if #names > 0 then
			addLog("[" .. category.Name .. "] " .. table.concat(names, ", "))
		end
	end
	addLog("Total: " .. total .. " buildings")
end)

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
	placeMachine(name, pos)
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
			placeMachine(name, origin + Vector3.new(i * 8, 0, 0))
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
				placeMachine(name, origin + Vector3.new(col * 8, 0, row * 8))
				task.wait(0.5)
			end
		end
		addLog("Placed " .. cols .. "x" .. rows .. " grid of " .. name)
		currentFarmBuilding = false
	end)
end)

-- === AUTO TAB ===
local autoTab = tabFrames["Auto"]

createSectionLabel(autoTab, "Diagnostics", 0)

createActionButton(autoTab, "Scan All PlacementSystem Remotes", 1, function()
	if not PlacementSystem then
		addLog("No PlacementSystem found")
		return
	end
	addLog("=== All PlacementSystem children ===")
	for _, child in ipairs(PlacementSystem:GetChildren()) do
		addLog("  " .. child.Name .. " [" .. child.ClassName .. "]")
	end
	addLog("=== All RemoteEvents/Functions in game ===")
	local count = 0
	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
			addLog("  " .. obj:GetFullName() .. " [" .. obj.ClassName .. "]")
			count = count + 1
		end
	end
	addLog("Found " .. count .. " remotes in ReplicatedStorage")
end)

createActionButton(autoTab, "Test Buy + Place (single Coal Drill)", 2, function()
	local model = findBuilding("Coal Drill")
	if not model then
		addLog("Coal Drill not found in building cache")
		return
	end
	addLog("Testing Buy then Place for Coal Drill...")
	buyBuilding(model)
	task.wait(0.3)
	local pos = getPlayerPosition() + Vector3.new(8, 0, 0)
	local ok, msg = placeMachine("Coal Drill", pos)
	addLog("Result: " .. msg)
end)

createSectionLabel(autoTab, "Automation", 5)

createToggle(autoTab, "Auto Sell (fire sell remotes)", false, 6, function(on)
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

-- (Capture tab removed in v1.2.9 - using direct PlaceBind)

-- Log, minimise/close chrome and the Insert-key toggle were all part of the
-- hand-built window that WindUI replaced; addLog now prints to the console,
-- and WindUI provides its own open button and show/hide control. The Log tab
-- created by the tab loop stays as an empty WindUI tab.

-- ===================== STARTUP =====================
addLog("Pebbleford Hub - Industrialist v1.2.9 loaded")
if PlacementSystem then
	addLog("PlacementSystem found!")
	local psChildren = {}
	for name, ref in pairs(PS) do
		if ref then table.insert(psChildren, name) end
	end
	addLog("  Connected: " .. table.concat(psChildren, ", "))
	buildBuildingCache()
	addLog("  Cached " .. (function() local c = 0 for _ in pairs(buildingCache) do c = c + 1 end return c end)() .. " buildings")
else
	addLog("WARNING: PlacementSystem not found in ReplicatedStorage")
end
addLog("Stand at your build spot and use the Farms tab to auto-build!")
addLog("Press Insert to toggle GUI.")
