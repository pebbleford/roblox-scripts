-- ╔═══════════════════════════════════════════════════════════════╗
-- ║                  Spin Fling Script                          ║
-- ║       Spin your character to fling nearby players           ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local spinning = false
local spinSpeed = 100
local flingPower = 9999
local connection = nil
local bodyAngularVelocity = nil
local bodyThrust = nil

local function getCharacter()
    Character = LocalPlayer.Character
    if not Character then return false end
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    Humanoid = Character:FindFirstChild("Humanoid")
    return Character and HumanoidRootPart and Humanoid
end

local function startFling()
    if not getCharacter() then
        warn("[Spin Fling] No character found")
        return
    end

    if spinning then return end
    spinning = true

    -- Make character spin
    bodyAngularVelocity = Instance.new("BodyAngularVelocity")
    bodyAngularVelocity.AngularVelocity = Vector3.new(0, spinSpeed, 0)
    bodyAngularVelocity.MaxTorque = Vector3.new(0, math.huge, 0)
    bodyAngularVelocity.P = flingPower
    bodyAngularVelocity.Parent = HumanoidRootPart

    -- Keep character upright with slight upward force
    bodyThrust = Instance.new("BodyThrust")
    bodyThrust.Force = Vector3.new(0, 500, 0)
    bodyThrust.Location = Vector3.new(0, 0, 0)
    bodyThrust.Parent = HumanoidRootPart

    -- Fling on touch
    connection = HumanoidRootPart.Touched:Connect(function(hit)
        if not spinning then return end
        local hitChar = hit:FindFirstAncestorOfClass("Model")
        if not hitChar or hitChar == Character then return end
        local hitHRP = hitChar:FindFirstChild("HumanoidRootPart")
        local hitHum = hitChar:FindFirstChild("Humanoid")
        if hitHRP and hitHum and hitHum.Health > 0 then
            local direction = (hitHRP.Position - HumanoidRootPart.Position).Unit
            hitHRP.Velocity = direction * flingPower + Vector3.new(0, flingPower / 2, 0)
            hitHRP.RotVelocity = Vector3.new(
                math.random(-spinSpeed, spinSpeed),
                math.random(-spinSpeed, spinSpeed),
                math.random(-spinSpeed, spinSpeed)
            )
        end
    end)

    print("[Spin Fling] Active - spinning!")
end

local function stopFling()
    spinning = false

    if bodyAngularVelocity then
        bodyAngularVelocity:Destroy()
        bodyAngularVelocity = nil
    end

    if bodyThrust then
        bodyThrust:Destroy()
        bodyThrust = nil
    end

    if connection then
        connection:Disconnect()
        connection = nil
    end

    if HumanoidRootPart then
        HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
        HumanoidRootPart.RotVelocity = Vector3.new(0, 0, 0)
    end

    print("[Spin Fling] Stopped")
end

local function toggle()
    if spinning then
        stopFling()
    else
        startFling()
    end
end

-- Re-setup on respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
    spinning = false
    bodyAngularVelocity = nil
    bodyThrust = nil
    connection = nil
end)

-- Toggle with keybind (V key)
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.V then
        toggle()
    end
end)

-- Start immediately
startFling()
print("[Spin Fling] Press V to toggle on/off")
