-- Key System Gate
-- Key gate, resilient to a single host failing. raw.githubusercontent
-- often rate-limits or fails to fetch on executors, which silently
-- returned here and made the whole hub look dead; jsDelivr mirrors the
-- same repo through a CDN and is the fallback.
local SXKeySources = {
	"https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick()),
	"https://cdn.jsdelivr.net/gh/pebbleford/roblox-scripts@main/keysystem.lua",
}
local keySystem
for _, SXKeyURL in ipairs(SXKeySources) do
	local ok, res = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
	if ok and res then keySystem = res break end
end
if not keySystem or not keySystem.validate("industrialist") then return end

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
-- ===================== GUI SETUP (Terminal, hand-built) =====================
-- Terminal green-on-black hand-built UI. Feature call sites are untouched: the
-- builder functions keep their signatures and now produce terminal-styled
-- frames instead of Fluent elements. Light (no library), so no menu lag.
do
	local T = {
		bg = Color3.fromRGB(0,0,0), bgSecondary = Color3.fromRGB(5,12,6), tabBg = Color3.fromRGB(5,12,6),
		accent = Color3.fromRGB(0,255,65), accentHover = Color3.fromRGB(93,255,143), accentDark = Color3.fromRGB(15,61,28),
		textPrimary = Color3.fromRGB(191,255,205), textSecondary = Color3.fromRGB(63,191,95), textDim = Color3.fromRGB(31,122,52),
		border = Color3.fromRGB(15,61,28), toggleOn = Color3.fromRGB(20,81,42), toggleOff = Color3.fromRGB(11,42,18),
		error = Color3.fromRGB(255,85,85), success = Color3.fromRGB(0,255,65),
	}
	for k,v in pairs(T) do COLORS[k] = v end
end

local _uiOrd = 0
local function _nextOrd() _uiOrd = _uiOrd + 1 return _uiOrd end

local tabNames = {"Farms", "Auto", "Log"}
local tabFrames = {}
uiState = uiState or {activeTab = tabNames[1]}

local _TUIS = UserInputService
local _mobile = _TUIS.TouchEnabled and not _TUIS.KeyboardEnabled
local _vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
local _W = _mobile and math.floor(math.min(_vp.X * 0.95, 540)) or 560
local _H = _mobile and math.floor(math.min(_vp.Y * 0.82, 620)) or 440

local mainWindow = Instance.new("Frame")
mainWindow.Name = "MainWindow"
mainWindow.Size = UDim2.new(0, _W, 0, _H)
mainWindow.Position = UDim2.new(0.5, -_W/2, 0.5, -_H/2)
mainWindow.BackgroundColor3 = COLORS.bg
mainWindow.BorderSizePixel = 0
mainWindow.Active = true
mainWindow.Parent = screenGui
do local st = Instance.new("UIStroke") st.Color = COLORS.border st.Thickness = 1 st.Parent = mainWindow end

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = COLORS.bgSecondary
titleBar.BorderSizePixel = 0
titleBar.Parent = mainWindow

local titleAccent = Instance.new("Frame")
titleAccent.Size = UDim2.new(1, 0, 0, 2)
titleAccent.Position = UDim2.new(0, 0, 1, 0)
titleAccent.BackgroundColor3 = COLORS.accent
titleAccent.BorderSizePixel = 0
titleAccent.ZIndex = 3
titleAccent.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -160, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "INDUSTRIALIST HUB"
titleLabel.TextColor3 = COLORS.textPrimary
titleLabel.Font = Enum.Font.Code
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local keyBadge = Instance.new("TextLabel")
keyBadge.Size = UDim2.new(0, 60, 0, 22)
keyBadge.Position = UDim2.new(1, -132, 0.5, -11)
keyBadge.BackgroundTransparency = 1
keyBadge.Text = "KEY OK"
keyBadge.TextColor3 = COLORS.textDim
keyBadge.Font = Enum.Font.Code
keyBadge.TextSize = 11
keyBadge.Parent = titleBar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -64, 0.5, -14)
minimizeBtn.BackgroundColor3 = COLORS.accentDark
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = COLORS.textPrimary
minimizeBtn.Font = Enum.Font.Code
minimizeBtn.TextSize = 16
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0.5, -14)
closeBtn.BackgroundColor3 = COLORS.accent
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(0,0,0)
closeBtn.Font = Enum.Font.Code
closeBtn.TextSize = 13
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar

-- Drag (mouse + touch)
do
	local dragging, ds, sp = false, nil, nil
	titleBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true ds = i.Position sp = mainWindow.Position
		end
	end)
	_TUIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - ds
			mainWindow.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
		end
	end)
	_TUIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

local tabButtons = {}
local _tabN = #tabNames
-- Tabs wrap into rows instead of squishing into one, so names stay readable on
-- phones. Fewer per row on mobile, taller cells for fat-finger taps.
local _perRow = _mobile and 4 or math.min(_tabN, 6)
if _tabN < _perRow then _perRow = _tabN end
local _cellW = math.floor(_W / _perRow)
local _cellH = _mobile and 34 or 28
local _rows = math.ceil(_tabN / _perRow)
local _tabBarH = _rows * _cellH
local _contentTop = 42 + _tabBarH + 2

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, _tabBarH)
tabBar.Position = UDim2.new(0, 0, 0, 42)
tabBar.BackgroundColor3 = COLORS.bgSecondary
tabBar.BorderSizePixel = 0
tabBar.Parent = mainWindow
do local dv = Instance.new("Frame") dv.Size = UDim2.new(1,0,0,1) dv.Position = UDim2.new(0,0,1,-1) dv.BackgroundColor3 = COLORS.border dv.BorderSizePixel = 0 dv.ZIndex = 2 dv.Parent = tabBar end
do local g = Instance.new("UIGridLayout") g.CellSize = UDim2.new(0, _cellW, 0, _cellH) g.CellPadding = UDim2.new(0,0,0,0) g.SortOrder = Enum.SortOrder.LayoutOrder g.FillDirectionMaxCells = _perRow g.Parent = tabBar end

for i, tabName in ipairs(tabNames) do
	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -8, 1, -(_contentTop + 4))
	content.Position = UDim2.new(0, 4, 0, _contentTop)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = _mobile and 5 or 3
	content.ScrollBarImageColor3 = COLORS.accent
	content.CanvasSize = UDim2.new(0,0,0,0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Visible = (i == 1)
	content.Parent = mainWindow
	local lay = Instance.new("UIListLayout") lay.SortOrder = Enum.SortOrder.LayoutOrder lay.Padding = UDim.new(0, _mobile and 6 or 4) lay.Parent = content
	local pd = Instance.new("UIPadding") pd.PaddingLeft = UDim.new(0,4) pd.PaddingRight = UDim.new(0,4) pd.PaddingTop = UDim.new(0,4) pd.Parent = content
	tabFrames[tabName] = content

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, _cellW, 0, _cellH)
	b.BackgroundColor3 = COLORS.accentDark
	b.BackgroundTransparency = (i == 1) and 0 or 1
	b.Text = string.upper(tabName)
	b.TextColor3 = (i == 1) and COLORS.accent or COLORS.textSecondary
	b.Font = Enum.Font.Code
	b.TextSize = _mobile and 11 or 10
	b.TextScaled = false
	b.AutoButtonColor = false
	b.LayoutOrder = i
	b.ZIndex = 3
	b.Parent = tabBar
	do local sep = Instance.new("Frame") sep.Size = UDim2.new(0,1,1,0) sep.Position = UDim2.new(1,-1,0,0) sep.BackgroundColor3 = COLORS.bg sep.BorderSizePixel = 0 sep.ZIndex = 4 sep.Parent = b end
	tabButtons[tabName] = b
end

local function switchTab(name)
	uiState.activeTab = name
	for n, f in pairs(tabFrames) do f.Visible = (n == name) end
	for n, b in pairs(tabButtons) do
		if n == name then b.BackgroundTransparency = 0 b.TextColor3 = COLORS.accent
		else b.BackgroundTransparency = 1 b.TextColor3 = COLORS.textSecondary end
	end
end
for name, b in pairs(tabButtons) do b.MouseButton1Click:Connect(function() switchTab(name) end) end

-- Minimise / close + mobile reopen button
local reopenBtn = Instance.new("TextButton")
reopenBtn.Size = UDim2.new(0, 46, 0, 46)
reopenBtn.Position = UDim2.new(0, 12, 0.5, -23)
reopenBtn.BackgroundColor3 = COLORS.accent
reopenBtn.Text = "PB"
reopenBtn.TextColor3 = Color3.fromRGB(0,0,0)
reopenBtn.Font = Enum.Font.Code
reopenBtn.TextSize = 14
reopenBtn.BorderSizePixel = 0
reopenBtn.Visible = false
reopenBtn.Parent = screenGui
local function _hide() mainWindow.Visible = false reopenBtn.Visible = true end
minimizeBtn.MouseButton1Click:Connect(_hide)
closeBtn.MouseButton1Click:Connect(_hide)
reopenBtn.MouseButton1Click:Connect(function() mainWindow.Visible = true reopenBtn.Visible = false end)
_TUIS.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.RightShift then
		mainWindow.Visible = not mainWindow.Visible
		reopenBtn.Visible = not mainWindow.Visible
	end
end)

-- ===================== UI COMPONENT BUILDERS (Terminal) =====================
local function createSectionLabel(parent, text, order)
	if not parent then return end
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 22)
	l.BackgroundTransparency = 1
	l.Text = string.upper(tostring(text))
	l.TextColor3 = COLORS.accentHover
	l.Font = Enum.Font.Code
	l.TextSize = 12
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.LayoutOrder = _nextOrd()
	l.Parent = parent
	return l
end

local function createInfoLabel(parent, text, order)
	if not parent then return end
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 18)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.Text = tostring(text)
	l.TextColor3 = COLORS.textDim
	l.Font = Enum.Font.Code
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.LayoutOrder = _nextOrd()
	l.Parent = parent
	return l
end

local function createDynamicLabel(parent, text)
	if not parent then return setmetatable({}, {__newindex = function() end}) end
	local l = createInfoLabel(parent, text or "", 0)
	l.TextColor3 = COLORS.textSecondary
	return setmetatable({}, {
		__newindex = function(_, k, v)
			if k == "Text" then pcall(function() l.Text = tostring(v) end)
			elseif k == "TextColor3" then pcall(function() l.TextColor3 = v end) end
		end,
		__index = function() return nil end,
	})
end

local function createToggle(parent, text, order, callback)
	if not parent then return end
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, _mobile and 44 or 36)
	row.BackgroundColor3 = COLORS.tabBg
	row.BorderSizePixel = 0
	row.LayoutOrder = _nextOrd()
	row.Parent = parent
	do local st = Instance.new("UIStroke") st.Color = COLORS.accentDark st.Thickness = 1 st.Parent = row end
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -66, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = tostring(text)
	lbl.TextColor3 = COLORS.textPrimary
	lbl.Font = Enum.Font.Code
	lbl.TextSize = _mobile and 15 or 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.new(0, 50, 0, 22)
	pill.Position = UDim2.new(1, -56, 0.5, -11)
	pill.BackgroundColor3 = COLORS.toggleOff
	pill.BorderSizePixel = 0
	pill.Text = "OFF"
	pill.TextColor3 = COLORS.accent
	pill.Font = Enum.Font.Code
	pill.TextSize = 12
	pill.Parent = row
	local isOn = false
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = row
	local function set(on)
		isOn = on
		pill.Text = on and "ON" or "OFF"
		pill.BackgroundColor3 = on and COLORS.toggleOn or COLORS.toggleOff
	end
	btn.MouseButton1Click:Connect(function() set(not isOn) if callback then pcall(callback, isOn) end end)
	return {setVisualState = set, isOn = function() return isOn end}
end

local function createActionButton(parent, text, order, callback)
	if not parent then return end
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, _mobile and 40 or 32)
	b.BackgroundColor3 = COLORS.tabBg
	b.Text = string.upper(tostring(text))
	b.TextColor3 = COLORS.accent
	b.Font = Enum.Font.Code
	b.TextSize = 12
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.LayoutOrder = _nextOrd()
	b.Parent = parent
	do local st = Instance.new("UIStroke") st.Color = COLORS.accentDark st.Thickness = 1 st.Parent = b end
	b.MouseEnter:Connect(function() b.BackgroundColor3 = COLORS.accentDark end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = COLORS.tabBg end)
	b.MouseButton1Click:Connect(function() if callback then pcall(callback) end end)
	return b
end
local createButton = createActionButton

local function createSlider(parent, text, min, max, default, order, callback)
	if not parent then return end
	local c = Instance.new("Frame")
	c.Size = UDim2.new(1, 0, 0, _mobile and 54 or 46)
	c.BackgroundColor3 = COLORS.tabBg
	c.BorderSizePixel = 0
	c.LayoutOrder = _nextOrd()
	c.Parent = parent
	do local st = Instance.new("UIStroke") st.Color = COLORS.accentDark st.Thickness = 1 st.Parent = c end
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -80, 0, 20)
	lbl.Position = UDim2.new(0, 10, 0, 3)
	lbl.BackgroundTransparency = 1
	lbl.Text = tostring(text)
	lbl.TextColor3 = COLORS.textSecondary
	lbl.Font = Enum.Font.Code
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = c
	local val = Instance.new("TextLabel")
	val.Size = UDim2.new(0, 70, 0, 20)
	val.Position = UDim2.new(1, -75, 0, 3)
	val.BackgroundTransparency = 1
	val.Text = tostring(default)
	val.TextColor3 = COLORS.accentHover
	val.Font = Enum.Font.Code
	val.TextSize = 12
	val.TextXAlignment = Enum.TextXAlignment.Right
	val.Parent = c
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, -20, 0, 6)
	bg.Position = UDim2.new(0, 10, 0, 30)
	bg.BackgroundColor3 = COLORS.bgSecondary
	bg.BorderSizePixel = 0
	bg.Parent = c
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
	fill.BackgroundColor3 = COLORS.accent
	fill.BorderSizePixel = 0
	fill.Parent = bg
	local drag = false
	local function upd(x)
		local p = math.clamp((x - bg.AbsolutePosition.X)/bg.AbsoluteSize.X, 0, 1)
		fill.Size = UDim2.new(p, 0, 1, 0)
		local v = math.floor(min + p*(max-min))
		val.Text = tostring(v)
		if callback then pcall(callback, v) end
	end
	bg.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true upd(i.Position.X) end end)
	bg.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end end)
	_TUIS.InputChanged:Connect(function(i) if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i.Position.X) end end)
	return c
end

local function createDropdown(parent, text, options, default, callback)
	if not parent then return end
	local wrap = {}
	local cur = default
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 32)
	b.BackgroundColor3 = COLORS.tabBg
	b.Text = tostring(text) .. ": " .. tostring(default)
	b.TextColor3 = COLORS.accent
	b.Font = Enum.Font.Code
	b.TextSize = 12
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.LayoutOrder = _nextOrd()
	b.Parent = parent
	do local st = Instance.new("UIStroke") st.Color = COLORS.accentDark st.Thickness = 1 st.Parent = b end
	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, 0, 0, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.BackgroundColor3 = COLORS.bgSecondary
	list.BorderSizePixel = 0
	list.Visible = false
	list.LayoutOrder = _nextOrd()
	list.Parent = parent
	local ll = Instance.new("UIListLayout") ll.Parent = list
	local function rebuild(opts)
		for _, ch in ipairs(list:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
		for _, opt in ipairs(opts) do
			local o = Instance.new("TextButton")
			o.Size = UDim2.new(1, 0, 0, 26)
			o.BackgroundColor3 = COLORS.bgSecondary
			o.Text = tostring(opt)
			o.TextColor3 = COLORS.textSecondary
			o.Font = Enum.Font.Code
			o.TextSize = 11
			o.BorderSizePixel = 0
			o.Parent = list
			o.MouseButton1Click:Connect(function()
				cur = opt
				b.Text = tostring(text) .. ": " .. tostring(opt)
				list.Visible = false
				if callback then pcall(callback, opt) end
			end)
		end
	end
	rebuild(options or {})
	b.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
	function wrap:Refresh(opts) rebuild(opts) end
	function wrap:SetValues(opts) rebuild(opts) end
	return wrap
end

local function createInput(parent, text, placeholder, callback)
	if not parent then return end
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 32)
	box.BackgroundColor3 = COLORS.tabBg
	box.Text = ""
	box.PlaceholderText = placeholder or tostring(text)
	box.PlaceholderColor3 = COLORS.textDim
	box.TextColor3 = COLORS.textPrimary
	box.Font = Enum.Font.Code
	box.TextSize = 12
	box.ClearTextOnFocus = false
	box.BorderSizePixel = 0
	box.LayoutOrder = _nextOrd()
	box.Parent = parent
	do local st = Instance.new("UIStroke") st.Color = COLORS.accentDark st.Thickness = 1 st.Parent = box end
	local pd = Instance.new("UIPadding") pd.PaddingLeft = UDim.new(0,8) pd.Parent = box
	box.FocusLost:Connect(function() if callback then pcall(callback, box.Text) end end)
	return box
end

local function createSpacer(parent, order)
	if not parent then return end
	local s = Instance.new("Frame")
	s.Size = UDim2.new(1, 0, 0, 4)
	s.BackgroundTransparency = 1
	s.LayoutOrder = _nextOrd()
	s.Parent = parent
end


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
