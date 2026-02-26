--[[
    DOORS: The Rooms - Auto A-1000
    Auto-walks through every room to A-1000
    Entity responses:
      A-60  -> rush to nearest locker and hide
      A-90  -> FREEZE (don't move, don't look around)
      A-120 -> rush to nearest locker and hide

    Controls:
      GUI START/STOP button
      RightShift keybind toggle
]]

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local lp = Players.LocalPlayer

-- ===================== CONFIG =====================
local WALK_SPEED = 70
local RUSH_SPEED = 250
local SCAN_RATE = 0.05
local SAFE_BUFFER = 3
local DOOR_WAIT = 2
local MAX_HIDE_TIME = 35
local A90_FREEZE_TIME = 4
local TOGGLE_KEY = Enum.KeyCode.RightShift

-- Entity patterns for The Rooms
local HIDE_ENTITY_PATTERNS = {"a%-60", "a60", "a%-120", "a120"}
local FREEZE_ENTITY_PATTERNS = {"a%-90", "a90"}
local HIDE_ENTITY_EXACT = {"A-60", "A60", "A-120", "A120"}
local FREEZE_ENTITY_EXACT = {"A-90", "A90"}
local ALL_ENTITY_EXACT = {"A-60", "A60", "A-90", "A90", "A-120", "A120"}

local HIDE_WORDS = {"closet", "locker", "wardrobe", "hiding"}

-- ===================== GAME DATA =====================
-- DOORS stores room number in ReplicatedStorage.GameData.LatestRoom
local GameData = nil
local LatestRoom = nil
pcall(function()
    GameData = ReplicatedStorage:WaitForChild("GameData", 5)
    if GameData then
        LatestRoom = GameData:WaitForChild("LatestRoom", 5)
    end
end)

-- ===================== STATE =====================
local active = false
local hiding = false
local frozen = false
local currentTween = nil
local roomCount = 0

-- ===================== CHARACTER =====================
local char, hrp, hum

local function getChar()
    char = lp.Character or lp.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart", 10)
    hum = char:WaitForChild("Humanoid", 10)
end

getChar()
lp.CharacterAdded:Connect(function()
    task.wait(1)
    getChar()
end)

-- ===================== GUI =====================
if lp.PlayerGui:FindFirstChild("DoorsAuto") then
    lp.PlayerGui.DoorsAuto:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "DoorsAuto"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = lp.PlayerGui

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 200, 0, 120)
panel.Position = UDim2.new(0, 10, 0.5, -60)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local border = Instance.new("UIStroke", panel)
border.Color = Color3.fromRGB(160, 50, 50)
border.Thickness = 2

local titleBar = Instance.new("Frame", panel)
titleBar.Size = UDim2.new(1, 0, 0, 26)
titleBar.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local titleFix = Instance.new("Frame", titleBar)
titleFix.Size = UDim2.new(1, 0, 0.5, 0)
titleFix.Position = UDim2.new(0, 0, 0.5, 0)
titleFix.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
titleFix.BorderSizePixel = 0

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(1, -8, 1, 0)
titleLbl.Position = UDim2.new(0, 8, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "DOORS: Auto A-1000"
titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 12
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local function makeLabel(yOff, text, color)
    local l = Instance.new("TextLabel", panel)
    l.Size = UDim2.new(1, -16, 0, 16)
    l.Position = UDim2.new(0, 8, 0, yOff)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local statusLbl = makeLabel(30, "Status: Ready")
local roomLbl = makeLabel(48, "Room: A-000")
local alertLbl = makeLabel(66, "", Color3.fromRGB(255, 80, 80))
alertLbl.Font = Enum.Font.GothamBold

local btn = Instance.new("TextButton", panel)
btn.Size = UDim2.new(1, -16, 0, 24)
btn.Position = UDim2.new(0, 8, 0, 88)
btn.BackgroundColor3 = Color3.fromRGB(40, 130, 40)
btn.Text = "START (RShift)"
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 12
btn.BorderSizePixel = 0
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

-- Drag
local dragging, dragStart, startPos
panel.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = inp.Position
        startPos = panel.Position
    end
end)
panel.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local d = inp.Position - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- ===================== HELPERS =====================

local function setStatus(t) statusLbl.Text = "Status: " .. t end
local function setRoom(n) roomCount = n; roomLbl.Text = string.format("Room: A-%03d", n) end
local function setAlert(t) alertLbl.Text = t end

-- Get the current room number from game data
local function getCurrentRoomNumber()
    if LatestRoom then
        local ok, val = pcall(function() return LatestRoom.Value end)
        if ok and val then return val end
    end
    -- Fallback: find highest numbered room in CurrentRooms
    local rooms = workspace:FindFirstChild("CurrentRooms")
    if not rooms then return 0 end
    local maxN = 0
    for _, room in pairs(rooms:GetChildren()) do
        local n = tonumber(room.Name)
        if n and n > maxN then maxN = n end
    end
    return maxN
end

-- Get the current room model
local function getCurrentRoom()
    local rooms = workspace:FindFirstChild("CurrentRooms")
    if not rooms then return nil end
    local roomNum = getCurrentRoomNumber()
    -- Try direct lookup
    local room = rooms:FindFirstChild(tostring(roomNum))
    if room then return room, roomNum end
    -- Fallback: find highest
    local latest, maxN = nil, -1
    for _, r in pairs(rooms:GetChildren()) do
        local n = tonumber(r.Name)
        if n and n > maxN then maxN = n; latest = r end
    end
    return latest, maxN
end

-- Tween HRP to a target CFrame
local function tweenTo(cf, speed)
    if not hrp or not hrp.Parent then return false end
    local dist = (cf.Position - hrp.Position).Magnitude
    if dist < 1 then return true end
    local t = math.max(dist / (speed or WALK_SPEED), 0.05)
    currentTween = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
    currentTween:Play()
    currentTween.Completed:Wait()
    currentTween = nil
    return true
end

local function stopTween()
    if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
end

-- ===================== ENTITY DETECTION =====================

local function detectEntity()
    for _, name in ipairs(HIDE_ENTITY_EXACT) do
        if workspace:FindFirstChild(name) then return "hide", name end
    end
    for _, name in ipairs(FREEZE_ENTITY_EXACT) do
        if workspace:FindFirstChild(name) then return "freeze", name end
    end
    for _, child in pairs(workspace:GetChildren()) do
        if child:IsA("Model") then
            local n = child.Name:lower()
            for _, pat in ipairs(HIDE_ENTITY_PATTERNS) do
                if n:find(pat) then return "hide", child.Name end
            end
            for _, pat in ipairs(FREEZE_ENTITY_PATTERNS) do
                if n:find(pat) then return "freeze", child.Name end
            end
        end
    end
    return nil, nil
end

local function anyEntityPresent()
    for _, name in ipairs(ALL_ENTITY_EXACT) do
        if workspace:FindFirstChild(name) then return true end
    end
    return false
end

-- ===================== HIDING SPOT FINDER =====================

local function findHidingSpot()
    local rooms = workspace:FindFirstChild("CurrentRooms")
    if not rooms or not hrp or not hrp.Parent then return nil end
    local best, bestDist = nil, math.huge
    for _, room in pairs(rooms:GetChildren()) do
        for _, desc in pairs(room:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                local node = desc.Parent
                local isHideSpot = false
                for _ = 1, 6 do
                    if not node then break end
                    local n = node.Name:lower()
                    for _, kw in ipairs(HIDE_WORDS) do
                        if n:find(kw) then isHideSpot = true; break end
                    end
                    if isHideSpot then break end
                    node = node.Parent
                end
                if isHideSpot then
                    local part = desc.Parent
                    if part:IsA("BasePart") then
                        local d = (part.Position - hrp.Position).Magnitude
                        if d < bestDist then best = desc; bestDist = d end
                    end
                end
            end
        end
    end
    return best
end

-- ===================== DOOR FINDER + OPENER =====================

local function findAndOpenDoor()
    local room, roomNum = getCurrentRoom()
    if not room then return false, 0 end

    -- DOORS uses a "Door" model inside the room
    local doorModel = room:FindFirstChild("Door")
    if not doorModel then return false, roomNum end

    -- Find the door part to walk to
    local doorPart = doorModel:FindFirstChild("Door") or doorModel.PrimaryPart or doorModel:FindFirstChildWhichIsA("BasePart")
    if not doorPart then return false, roomNum end

    -- Walk to the door
    setStatus("Walking to door")
    tweenTo(doorPart.CFrame * CFrame.new(0, 0, -3), WALK_SPEED)
    if hiding or frozen then return false, roomNum end

    setStatus("Opening door")

    -- Method 1: ClientOpen:FireServer() (how DOORS actually opens doors)
    local clientOpen = doorModel:FindFirstChild("ClientOpen")
    if clientOpen and clientOpen:IsA("RemoteEvent") then
        clientOpen:FireServer()
        return true, roomNum
    end

    -- Method 2: Fire the lock's UnlockPrompt first, then ClientOpen
    local lockModel = doorModel:FindFirstChild("Lock")
    if lockModel then
        local unlockPrompt = lockModel:FindFirstChild("UnlockPrompt")
        if unlockPrompt and unlockPrompt:IsA("ProximityPrompt") then
            if fireproximityprompt then
                fireproximityprompt(unlockPrompt, 0)
            end
            task.wait(0.3)
        end
        -- Try ClientOpen again after unlocking
        clientOpen = doorModel:FindFirstChild("ClientOpen")
        if clientOpen and clientOpen:IsA("RemoteEvent") then
            clientOpen:FireServer()
            return true, roomNum
        end
    end

    -- Method 3: fireproximityprompt on any prompt in the door
    local prompt = doorModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and fireproximityprompt then
        fireproximityprompt(prompt, 0)
        return true, roomNum
    end

    -- Method 4: just walk through (some rooms have open doorways)
    tweenTo(doorPart.CFrame * CFrame.new(0, 0, 5), WALK_SPEED)
    return true, roomNum
end

-- ===================== A-60 / A-120: HIDE IN LOCKER =====================

local function hideFromEntity(name)
    if hiding or frozen then return end
    hiding = true
    stopTween()

    setAlert("!! " .. name .. " - HIDING !!")
    setStatus("Rushing to locker")

    local prompt = findHidingSpot()
    if prompt then
        local part = prompt.Parent
        if part:IsA("BasePart") then
            tweenTo(part.CFrame, RUSH_SPEED)
        end
        task.wait(0.05)
        if fireproximityprompt then
            fireproximityprompt(prompt)
        end
        setStatus("Hidden - waiting...")
        local t0 = tick()
        repeat
            task.wait(0.3)
        until not anyEntityPresent() or (tick() - t0 > MAX_HIDE_TIME)
        task.wait(SAFE_BUFFER)
        setStatus("Exiting locker")
        if fireproximityprompt then
            fireproximityprompt(prompt)
        end
        task.wait(0.5)
    else
        setStatus("No locker! Freezing...")
        local t0 = tick()
        repeat task.wait(0.5)
        until not anyEntityPresent() or (tick() - t0 > MAX_HIDE_TIME)
        task.wait(SAFE_BUFFER)
    end

    setAlert("")
    hiding = false
end

-- ===================== A-90: FREEZE =====================

local function freezeForA90(name)
    if hiding or frozen then return end
    frozen = true
    stopTween()

    setAlert("!! " .. name .. " - DON'T MOVE !!")
    setStatus("FROZEN - A-90!")

    local wasAnchored = false
    if hrp and hrp.Parent then
        wasAnchored = hrp.Anchored
        hrp.Anchored = true
    end
    local savedSpeed = 0
    if hum and hum.Parent then
        savedSpeed = hum.WalkSpeed
        hum.WalkSpeed = 0
        hum.JumpPower = 0
    end

    local t0 = tick()
    repeat
        task.wait(0.2)
        if hrp and hrp.Parent then hrp.Anchored = true end
        if hum and hum.Parent then hum.WalkSpeed = 0 end
    until (tick() - t0 > A90_FREEZE_TIME) and not anyEntityPresent()

    task.wait(1)

    if hrp and hrp.Parent then hrp.Anchored = wasAnchored end
    if hum and hum.Parent then
        hum.WalkSpeed = savedSpeed
        hum.JumpPower = 50
    end

    setAlert("")
    frozen = false
end

-- ===================== ENTITY SCANNER =====================

local function handleEntity(entityType, name)
    if entityType == "hide" then
        hideFromEntity(name)
    elseif entityType == "freeze" then
        freezeForA90(name)
    end
end

task.spawn(function()
    while true do
        task.wait(SCAN_RATE)
        if active and not hiding and not frozen then
            local entityType, name = detectEntity()
            if entityType then handleEntity(entityType, name) end
        end
    end
end)

workspace.ChildAdded:Connect(function(child)
    if not active or hiding or frozen then return end
    task.wait()
    local n = child.Name:lower()
    if n:find("a%-60") or n:find("a60") or n:find("a%-120") or n:find("a120") then
        hideFromEntity(child.Name)
        return
    end
    if n:find("a%-90") or n:find("a90") then
        freezeForA90(child.Name)
        return
    end
end)

-- ===================== ROOM PROGRESSION =====================

task.spawn(function()
    while true do
        task.wait(0.5)
        if active and not hiding and not frozen then
            getChar()
            if hrp and hrp.Parent then
                local curRoom = getCurrentRoomNumber()
                setRoom(curRoom)

                local opened, roomN = findAndOpenDoor()
                if opened then
                    -- Wait for room to load
                    task.wait(DOOR_WAIT)
                    -- Update room from game data
                    local newRoom = getCurrentRoomNumber()
                    setRoom(newRoom)
                end

                if getCurrentRoomNumber() >= 1000 then
                    setStatus("REACHED A-1000!")
                    active = false
                    btn.Text = "A-1000!"
                    btn.BackgroundColor3 = Color3.fromRGB(200, 170, 30)
                    break
                end
            end
        end
    end
end)

-- Listen for room changes via game data
if LatestRoom then
    LatestRoom.Changed:Connect(function(newVal)
        if active then
            setRoom(newVal)
        end
    end)
end

-- ===================== TOGGLE =====================

local function toggle()
    if getCurrentRoomNumber() >= 1000 then return end
    active = not active
    if active then
        btn.Text = "STOP (RShift)"
        btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        setStatus("Running")
        setRoom(getCurrentRoomNumber())
    else
        btn.Text = "START (RShift)"
        btn.BackgroundColor3 = Color3.fromRGB(40, 130, 40)
        setStatus("Paused")
        stopTween()
    end
end

btn.MouseButton1Click:Connect(toggle)
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == TOGGLE_KEY then toggle() end
end)

setStatus("Ready - press START")
print("[DOORS Auto] Loaded - press START or RShift to begin")
