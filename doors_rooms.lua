--[[
    DOORS: The Rooms - Auto A-1000
    Uses PathfindingService to walk through rooms
    Auto-hides in lockers when A-60/A-120 detected
    Disables A-90 by renaming its module

    Controls: START/STOP button or RightShift
]]

-- Validate we're in DOORS: The Rooms
if game.PlaceId ~= 6516141723 and game.PlaceId ~= 6839171747 then
    -- Try anyway, might be a private server
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local floorCheck = pcall(function()
    return ReplicatedStorage.GameData.Floor.Value
end)

-- Services
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local LatestRoom = ReplicatedStorage.GameData.LatestRoom
local TOGGLE_KEY = Enum.KeyCode.RightShift

-- ===================== STATE =====================
local active = false
local renderConn = nil

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

-- ===================== ANTI-AFK =====================
pcall(function()
    local GC = getconnections or get_signal_cons
    if GC then
        for _, v in pairs(GC(lp.Idled)) do
            if v.Disable then v:Disable()
            elseif v.Disconnect then v:Disconnect() end
        end
    end
end)

-- ===================== DISABLE A-90 =====================
pcall(function()
    local a90Module = lp.PlayerGui.MainUI.Initiator.Main_Game.RemoteListener.Modules:FindFirstChild("A90")
    if a90Module then
        a90Module.Name = "A90_disabled"
    end
end)

-- ===================== GUI =====================
if game.CoreGui:FindFirstChild("DoorsAuto") then
    game.CoreGui.DoorsAuto:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "DoorsAuto"
gui.ResetOnSpawn = false
gui.Parent = game.CoreGui

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
        dragging = true; dragStart = inp.Position; startPos = panel.Position
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
local function setRoom(n) roomLbl.Text = string.format("Room: A-%03d", math.clamp(n, 0, 1000)) end
local function setAlert(t) alertLbl.Text = t end

-- Find the nearest empty locker (Rooms_Locker with no one hiding in it)
local function getLocker()
    if not hrp or not hrp.Parent then return nil end
    local closest = nil
    for _, v in pairs(workspace.CurrentRooms:GetDescendants()) do
        if v.Name == "Rooms_Locker" then
            if v:FindFirstChild("Door") and v:FindFirstChild("HiddenPlayer") then
                if v.HiddenPlayer.Value == nil then
                    if v.Door.Position.Y > -3 then
                        if closest == nil then
                            closest = v.Door
                        else
                            if (hrp.Position - v.Door.Position).Magnitude < (closest.Position - hrp.Position).Magnitude then
                                closest = v.Door
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- Check if A-60 or A-120 is active (Main part above Y -4)
local function getActiveEntity()
    local entity = workspace:FindFirstChild("A60") or workspace:FindFirstChild("A120")
    if entity then
        local main = entity:FindFirstChild("Main")
        if main and main.Position.Y > -4 then
            return entity
        end
    end
    return nil
end

-- Get the target to walk to: locker if entity active, otherwise next door
local function getTarget()
    local entity = getActiveEntity()
    if entity then
        return getLocker(), true
    end
    -- Walk to current room's door
    local ok, door = pcall(function()
        return workspace.CurrentRooms[tostring(LatestRoom.Value)].Door.Door
    end)
    if ok and door then
        return door, false
    end
    return nil, false
end

-- ===================== RENDER LOOP (collision + entity check) =====================

local function startRenderLoop()
    if renderConn then renderConn:Disconnect() end
    renderConn = RunService.RenderStepped:Connect(function()
        if not active then return end
        if not char or not hrp or not hrp.Parent or not hum then return end

        -- Noclip + expand collision for pathfinding
        pcall(function()
            hrp.CanCollide = false
            local collision = char:FindFirstChild("Collision")
            if collision then
                collision.CanCollide = false
                collision.Size = Vector3.new(8, collision.Size.Y, 8)
            end
        end)

        -- Keep walkspeed up
        hum.WalkSpeed = 21

        -- Entity is active - check if we need to hide or exit
        local entity = getActiveEntity()
        if entity then
            local locker = getLocker()
            if locker then
                -- If close to locker door, enter it
                if locker.Parent and locker.Parent:FindFirstChild("HidePrompt") then
                    if (hrp.Position - locker.Position).Magnitude < 2 then
                        if hrp.Anchored == false then
                            setAlert("!! HIDING !!")
                            pcall(function()
                                fireproximityprompt(locker.Parent.HidePrompt)
                            end)
                        end
                    end
                end
            end
        else
            -- Entity gone - exit locker if we're hiding
            if hrp.Anchored == true then
                pcall(function()
                    char:SetAttribute("Hiding", false)
                end)
                setAlert("")
            end
        end
    end)
end

-- ===================== ROOM CHANGE LISTENER =====================

LatestRoom:GetPropertyChangedSignal("Value"):Connect(function()
    if not active then return end
    local val = LatestRoom.Value
    setRoom(val)

    if val >= 1000 then
        lp.DevComputerMovementMode = Enum.DevComputerMovementMode.KeyboardMouse
        setStatus("REACHED A-1000!")
        active = false
        btn.Text = "A-1000!"
        btn.BackgroundColor3 = Color3.fromRGB(200, 170, 30)
    end
end)

-- ===================== MAIN PATHFINDING LOOP =====================

task.spawn(function()
    while true do
        if active then
            getChar()
            if hrp and hrp.Parent and hum then
                local target, isEntity = getTarget()

                if isEntity then
                    setStatus("Entity! Going to locker")
                    setAlert("!! ENTITY DETECTED !!")
                end

                if target then
                    -- Pathfind to target
                    local path = PathfindingService:CreatePath({
                        WaypointSpacing = 1,
                        AgentRadius = 0.1,
                        AgentCanJump = false,
                    })

                    local ok = pcall(function()
                        path:ComputeAsync(hrp.Position - Vector3.new(0, 3, 0), target.Position)
                    end)

                    if ok and path.Status ~= Enum.PathStatus.NoPath then
                        local waypoints = path:GetWaypoints()
                        for _, wp in pairs(waypoints) do
                            if not active then break end
                            if hrp.Anchored == false then
                                hum:MoveTo(wp.Position)
                                hum.MoveToFinished:Wait()
                            else
                                -- We're in a locker, wait until entity passes
                                setStatus("Hidden in locker")
                                while hrp.Anchored and active do
                                    task.wait(0.3)
                                end
                                setAlert("")
                                setStatus("Running")
                                break
                            end
                        end
                    else
                        setStatus("No path found, retrying...")
                    end
                else
                    setStatus("Waiting for door...")
                end
            end
        end
        task.wait(0.1)
    end
end)

-- ===================== TOGGLE =====================

local function toggle()
    active = not active
    if active then
        getChar()
        btn.Text = "STOP (RShift)"
        btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        setStatus("Running")
        setRoom(LatestRoom.Value)

        -- Prevent player input from interfering
        lp.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable

        -- Disable A-90 module
        pcall(function()
            local a90 = lp.PlayerGui.MainUI.Initiator.Main_Game.RemoteListener.Modules:FindFirstChild("A90")
            if a90 then a90.Name = "A90_disabled" end
        end)

        startRenderLoop()
    else
        btn.Text = "START (RShift)"
        btn.BackgroundColor3 = Color3.fromRGB(40, 130, 40)
        setStatus("Paused")
        lp.DevComputerMovementMode = Enum.DevComputerMovementMode.KeyboardMouse
        if renderConn then renderConn:Disconnect() renderConn = nil end
    end
end

btn.MouseButton1Click:Connect(toggle)
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == TOGGLE_KEY then toggle() end
end)

setStatus("Ready - press START")
print("[DOORS Auto] Loaded - press START or RShift")
