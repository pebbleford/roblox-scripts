-- ╔═══════════════════════════════════════════════════════════════╗
-- ║              Spin Fling + Dinos Anim Fling                  ║
-- ║   V = Spin Fling (Infinite Yield style)                     ║
-- ║   B = Dinos Anim / Walk Fling (velocity spike style)        ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ===================== STATE =====================
local spinFlingActive = false
local walkFlingActive = false
local spinBAV = nil
local noclipConn = nil
local walkFlingConn = nil
local savedPhysProps = {}

-- ===================== HELPERS =====================
local function getRoot()
	local char = LocalPlayer.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then return hum.RootPart end
	end
	return nil
end

local function startNoclip()
	if noclipConn then return end
	noclipConn = RunService.Stepped:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)
	end)
end

local function stopNoclip()
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
end

-- ===================== SPIN FLING (Infinite Yield Style) =====================
-- High density + BodyAngularVelocity + noclip + massless + pulse spin

local function startSpinFling()
	local char = LocalPlayer.Character
	if not char then return end
	local root = getRoot()
	if not root then return end

	spinFlingActive = true

	-- Save original physics & set density to 100 (super heavy)
	savedPhysProps = {}
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			savedPhysProps[part] = part.CustomPhysicalProperties
			part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
		end
	end

	-- Enable noclip
	startNoclip()
	task.wait(0.1)

	-- BodyAngularVelocity - spin on Y axis at insane speed
	spinBAV = Instance.new("BodyAngularVelocity")
	spinBAV.AngularVelocity = Vector3.new(0, 99999, 0)
	spinBAV.MaxTorque = Vector3.new(0, math.huge, 0)
	spinBAV.P = math.huge
	spinBAV.Parent = root

	-- Set all parts massless + zero velocity
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			part.Velocity = Vector3.new(0, 0, 0)
		end
	end

	-- Pulse spin on/off to create repeated impulse spikes
	task.spawn(function()
		while spinFlingActive do
			if spinBAV and spinBAV.Parent then
				spinBAV.AngularVelocity = Vector3.new(0, 99999, 0)
			end
			task.wait(0.2)
			if spinBAV and spinBAV.Parent then
				spinBAV.AngularVelocity = Vector3.new(0, 0, 0)
			end
			task.wait(0.1)
		end
	end)

	print("[Spin Fling] Active - walk into players to fling them!")
end

local function stopSpinFling()
	spinFlingActive = false

	-- Remove BodyAngularVelocity
	if spinBAV then
		pcall(function() spinBAV:Destroy() end)
		spinBAV = nil
	end

	-- Stop noclip
	stopNoclip()

	-- Restore physics properties
	local char = LocalPlayer.Character
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				if savedPhysProps[part] then
					part.CustomPhysicalProperties = savedPhysProps[part]
				else
					part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
				end
				part.Massless = false
			end
		end
	end
	savedPhysProps = {}

	-- Break velocity
	pcall(function()
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Velocity = Vector3.new(0, 0, 0)
					part.RotVelocity = Vector3.new(0, 0, 0)
				end
			end
		end
	end)

	print("[Spin Fling] Stopped")
end

-- ===================== DINOS ANIM / WALK FLING =====================
-- Velocity spike each physics frame - walk normally while flinging

local function startWalkFling()
	local char = LocalPlayer.Character
	if not char then return end
	local root = getRoot()
	if not root then return end

	walkFlingActive = true

	-- Enable noclip
	startNoclip()

	-- Velocity spike loop (Infinite Yield walkfling technique)
	walkFlingConn = task.spawn(function()
		local movel = 0.1
		while walkFlingActive do
			RunService.Heartbeat:Wait()
			local character = LocalPlayer.Character
			local rt = getRoot()
			if not (character and character.Parent and rt and rt.Parent) then continue end

			-- Save current velocity
			local vel = rt.Velocity

			-- SPIKE: multiply velocity massively + huge upward burst
			rt.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)

			RunService.RenderStepped:Wait()
			-- RESTORE: set velocity back to normal
			character = LocalPlayer.Character
			rt = getRoot()
			if character and character.Parent and rt and rt.Parent then
				rt.Velocity = vel
			end

			RunService.Stepped:Wait()
			-- MICRO-OSCILLATE: tiny bounce to keep physics alive
			character = LocalPlayer.Character
			rt = getRoot()
			if character and character.Parent and rt and rt.Parent then
				rt.Velocity = vel + Vector3.new(0, movel, 0)
				movel = movel * -1
			end
		end
	end)

	print("[Walk Fling] Active - walk into players to fling them! (Dinos Anim style)")
end

local function stopWalkFling()
	walkFlingActive = false

	-- Stop noclip
	stopNoclip()

	-- Break velocity
	pcall(function()
		local char = LocalPlayer.Character
		if char then
			local V3 = Vector3.new(0, 0, 0)
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Velocity = V3
					part.RotVelocity = V3
				end
			end
		end
	end)

	print("[Walk Fling] Stopped")
end

-- ===================== KEYBINDS =====================
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	-- V = Toggle Spin Fling
	if input.KeyCode == Enum.KeyCode.V then
		-- Stop walk fling if active
		if walkFlingActive then stopWalkFling() end

		if spinFlingActive then
			stopSpinFling()
		else
			startSpinFling()
		end
	end

	-- B = Toggle Walk Fling (Dinos Anim)
	if input.KeyCode == Enum.KeyCode.B then
		-- Stop spin fling if active
		if spinFlingActive then stopSpinFling() end

		if walkFlingActive then
			stopWalkFling()
		else
			startWalkFling()
		end
	end
end)

-- Cleanup on respawn
LocalPlayer.CharacterAdded:Connect(function()
	spinFlingActive = false
	walkFlingActive = false
	spinBAV = nil
	savedPhysProps = {}
	stopNoclip()
end)

print("[Fling Script] Loaded!")
print("[Fling Script] V = Spin Fling (Infinite Yield) | B = Walk Fling (Dinos Anim)")
