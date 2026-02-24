--[[
    Synapse X The Revival - Key System
    HWID-locked key validation with local auth caching

    Auth Flow:
    1. Get HWID (multi-executor fallback)
    2. Check GitHub whitelist -> auto-pass if found
    3. Check local auth file -> auto-pass if HWID hash matches
    4. Show key GUI -> correct key binds to HWID -> save locally

    Returns: { validate = fn, getHWID = fn }
]]

local KEY_SYSTEM = {}

-- ============================================================
-- CONFIG
-- ============================================================
local VALID_KEYS = {
    ["synapsextherevivalontop"] = true,
    ["sxr-midnight-4f82k"] = true,
}
local AUTH_SALT = "SXR_2024_PEBBLEFORD_REVIVAL"
local AUTH_FILE = "SynapseXAuth.json"
local WHITELIST_URL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/whitelist.txt?v=" .. tostring(tick())

-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- HWID DETECTION (multi-executor fallback)
-- ============================================================
local function getHWID()
    -- Method 1: Direct gethwid() (Synapse X, Script-Ware, etc.)
    local ok1, hwid1 = pcall(function()
        return gethwid()
    end)
    if ok1 and hwid1 and type(hwid1) == "string" and #hwid1 > 5 then
        return hwid1
    end

    -- Method 2: getexecutorname() + hardware info
    local ok2, hwid2 = pcall(function()
        return getexecutorhwid and getexecutorhwid() or nil
    end)
    if ok2 and hwid2 and type(hwid2) == "string" and #hwid2 > 5 then
        return hwid2
    end

    -- Method 3: RbxAnalyticsService:GetClientId()
    local ok3, hwid3 = pcall(function()
        local analytics = game:GetService("RbxAnalyticsService")
        return analytics:GetClientId()
    end)
    if ok3 and hwid3 and type(hwid3) == "string" and #hwid3 > 5 then
        return hwid3
    end

    -- Method 4: HWID from identifyexecutor + UserId combo
    local ok4, hwid4 = pcall(function()
        local execName = identifyexecutor and identifyexecutor() or "Unknown"
        local userId = tostring(LocalPlayer.UserId)
        return execName .. "_" .. userId .. "_" .. tostring(game.PlaceId)
    end)
    if ok4 and hwid4 then
        return hwid4
    end

    -- Final fallback: UserId only (weakest, but still prevents trivial sharing)
    return "UID_" .. tostring(LocalPlayer.UserId)
end

-- ============================================================
-- DJB2 HASH
-- ============================================================
local function simpleHash(input)
    local hash = 5381
    for i = 1, #input do
        hash = ((hash * 33) + string.byte(input, i)) % 4294967296
    end
    return tostring(hash)
end

-- ============================================================
-- AUTH TOKEN
-- ============================================================
local function generateAuthToken(hwid)
    return simpleHash(hwid .. AUTH_SALT .. "synapsextherevivalontop")
end

-- ============================================================
-- LOCAL AUTH (writefile/readfile)
-- ============================================================
local function saveLocalAuth(hwid)
    local ok = pcall(function()
        local data = {
            hwid_hash = simpleHash(hwid),
            auth_token = generateAuthToken(hwid),
            timestamp = os.time(),
            version = "1.0"
        }
        writefile(AUTH_FILE, HttpService:JSONEncode(data))
    end)
    return ok
end

local function checkLocalAuth(hwid)
    local ok, result = pcall(function()
        if not isfile(AUTH_FILE) then return false end
        local raw = readfile(AUTH_FILE)
        local data = HttpService:JSONDecode(raw)
        if not data or not data.hwid_hash or not data.auth_token then return false end

        -- Verify HWID matches
        local currentHash = simpleHash(hwid)
        if data.hwid_hash ~= currentHash then return false end

        -- Verify auth token matches
        local expectedToken = generateAuthToken(hwid)
        if data.auth_token ~= expectedToken then return false end

        return true
    end)
    return ok and result == true
end

-- ============================================================
-- GITHUB WHITELIST CHECK
-- ============================================================
local function checkWhitelist(hwid)
    local ok, result = pcall(function()
        local raw = game:HttpGet(WHITELIST_URL)
        if not raw or #raw < 3 then return false end

        local hwidHash = simpleHash(hwid)

        for line in raw:gmatch("[^\r\n]+") do
            local trimmed = line:match("^%s*(.-)%s*$")
            -- Skip comments and empty lines
            if trimmed and #trimmed > 0 and trimmed:sub(1, 1) ~= "#" then
                if trimmed == hwidHash then
                    return true
                end
            end
        end
        return false
    end)
    return ok and result == true
end

-- ============================================================
-- KEY ENTRY GUI
-- ============================================================
local function showKeyGUI(hwid)
    local authenticated = false
    local closed = false

    -- Remove old GUI if exists
    pcall(function()
        if CoreGui:FindFirstChild("SXKeySystem") then
            CoreGui.SXKeySystem:Destroy()
        end
    end)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SXKeySystem"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false

    pcall(function() screenGui.Parent = CoreGui end)
    if not screenGui.Parent then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Overlay (dims game)
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.4
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 100
    overlay.Parent = screenGui

    -- Main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 360, 0, 320)
    mainFrame.Position = UDim2.new(0.5, -180, 0.5, -160)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.ZIndex = 101
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = mainFrame

    -- Orange accent bar at top
    local accentBar = Instance.new("Frame")
    accentBar.Name = "AccentBar"
    accentBar.Size = UDim2.new(1, 0, 0, 3)
    accentBar.Position = UDim2.new(0, 0, 0, 0)
    accentBar.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    accentBar.BorderSizePixel = 0
    accentBar.ZIndex = 102
    accentBar.Parent = mainFrame

    -- Title: SYNAPSE X THE REVIVAL
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "SYNAPSE X THE REVIVAL"
    title.TextColor3 = Color3.fromRGB(255, 140, 0)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.ZIndex = 102
    title.Parent = mainFrame

    -- Subtitle: Key System
    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, -20, 0, 20)
    subtitle.Position = UDim2.new(0, 10, 0, 45)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Key System"
    subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
    subtitle.TextSize = 13
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Center
    subtitle.ZIndex = 102
    subtitle.Parent = mainFrame

    -- Separator line
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.85, 0, 0, 1)
    sep.Position = UDim2.new(0.075, 0, 0, 75)
    sep.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    sep.BorderSizePixel = 0
    sep.ZIndex = 102
    sep.Parent = mainFrame

    -- HWID display
    local hwidLabel = Instance.new("TextLabel")
    hwidLabel.Name = "HWIDLabel"
    hwidLabel.Size = UDim2.new(1, -30, 0, 18)
    hwidLabel.Position = UDim2.new(0, 15, 0, 85)
    hwidLabel.BackgroundTransparency = 1
    hwidLabel.Text = "HWID Hash: " .. simpleHash(hwid)
    hwidLabel.TextColor3 = Color3.fromRGB(100, 100, 110)
    hwidLabel.TextSize = 10
    hwidLabel.Font = Enum.Font.Code
    hwidLabel.TextXAlignment = Enum.TextXAlignment.Left
    hwidLabel.ZIndex = 102
    hwidLabel.Parent = mainFrame

    -- Key input box
    local keyBox = Instance.new("TextBox")
    keyBox.Name = "KeyInput"
    keyBox.Size = UDim2.new(0.85, 0, 0, 38)
    keyBox.Position = UDim2.new(0.075, 0, 0, 115)
    keyBox.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    keyBox.BorderSizePixel = 0
    keyBox.Text = ""
    keyBox.PlaceholderText = "Enter your key..."
    keyBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 90)
    keyBox.TextColor3 = Color3.fromRGB(220, 220, 220)
    keyBox.TextSize = 13
    keyBox.Font = Enum.Font.Gotham
    keyBox.ClearTextOnFocus = false
    keyBox.ZIndex = 102
    keyBox.Parent = mainFrame

    local keyBoxCorner = Instance.new("UICorner")
    keyBoxCorner.CornerRadius = UDim.new(0, 6)
    keyBoxCorner.Parent = keyBox

    local keyBoxPadding = Instance.new("UIPadding")
    keyBoxPadding.PaddingLeft = UDim.new(0, 10)
    keyBoxPadding.PaddingRight = UDim.new(0, 10)
    keyBoxPadding.Parent = keyBox

    -- Activate button
    local activateBtn = Instance.new("TextButton")
    activateBtn.Name = "ActivateButton"
    activateBtn.Size = UDim2.new(0.85, 0, 0, 38)
    activateBtn.Position = UDim2.new(0.075, 0, 0, 165)
    activateBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    activateBtn.BorderSizePixel = 0
    activateBtn.Text = "ACTIVATE KEY"
    activateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    activateBtn.TextSize = 14
    activateBtn.Font = Enum.Font.GothamBold
    activateBtn.ZIndex = 102
    activateBtn.Parent = mainFrame

    local activateBtnCorner = Instance.new("UICorner")
    activateBtnCorner.CornerRadius = UDim.new(0, 6)
    activateBtnCorner.Parent = activateBtn

    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(0.85, 0, 0, 20)
    statusLabel.Position = UDim2.new(0.075, 0, 0, 215)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.ZIndex = 102
    statusLabel.Parent = mainFrame

    -- Close button (X)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -35, 0, 7)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(120, 120, 130)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 103
    closeBtn.Parent = mainFrame

    -- Get Key button (link hint)
    local getKeyLabel = Instance.new("TextLabel")
    getKeyLabel.Name = "GetKeyLabel"
    getKeyLabel.Size = UDim2.new(0.85, 0, 0, 18)
    getKeyLabel.Position = UDim2.new(0.075, 0, 0, 245)
    getKeyLabel.BackgroundTransparency = 1
    getKeyLabel.Text = "Join our Discord for keys"
    getKeyLabel.TextColor3 = Color3.fromRGB(80, 120, 200)
    getKeyLabel.TextSize = 11
    getKeyLabel.Font = Enum.Font.Gotham
    getKeyLabel.TextXAlignment = Enum.TextXAlignment.Center
    getKeyLabel.ZIndex = 102
    getKeyLabel.Parent = mainFrame

    -- Footer
    local footer = Instance.new("TextLabel")
    footer.Name = "Footer"
    footer.Size = UDim2.new(1, -20, 0, 16)
    footer.Position = UDim2.new(0, 10, 1, -25)
    footer.BackgroundTransparency = 1
    footer.Text = "Synapse X The Revival v1.0 | HWID Locked"
    footer.TextColor3 = Color3.fromRGB(60, 60, 70)
    footer.TextSize = 9
    footer.Font = Enum.Font.Code
    footer.TextXAlignment = Enum.TextXAlignment.Center
    footer.ZIndex = 102
    footer.Parent = mainFrame

    -- Entrance animation
    mainFrame.BackgroundTransparency = 1
    local tweenIn = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0
    })
    tweenIn:Play()

    -- Button hover effect
    activateBtn.MouseEnter:Connect(function()
        TweenService:Create(activateBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(255, 160, 30)
        }):Play()
    end)
    activateBtn.MouseLeave:Connect(function()
        TweenService:Create(activateBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(255, 140, 0)
        }):Play()
    end)

    closeBtn.MouseEnter:Connect(function()
        closeBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    end)
    closeBtn.MouseLeave:Connect(function()
        closeBtn.TextColor3 = Color3.fromRGB(120, 120, 130)
    end)

    -- Set status helper
    local function setStatus(text, color)
        statusLabel.Text = text
        statusLabel.TextColor3 = color or Color3.fromRGB(180, 180, 180)
    end

    -- Activate handler
    local function tryActivate()
        local enteredKey = keyBox.Text:match("^%s*(.-)%s*$") -- trim

        if not enteredKey or #enteredKey == 0 then
            setStatus("Please enter a key.", Color3.fromRGB(255, 100, 100))
            return
        end

        setStatus("Validating...", Color3.fromRGB(255, 200, 100))
        activateBtn.Active = false
        activateBtn.BackgroundColor3 = Color3.fromRGB(150, 90, 0)

        task.wait(0.3) -- Brief delay for feel

        if VALID_KEYS[enteredKey:lower()] then
            -- Key is correct! Save auth
            local saved = saveLocalAuth(hwid)
            if saved then
                setStatus("Key activated! Loading script...", Color3.fromRGB(100, 255, 100))
            else
                setStatus("Key valid! (Could not save locally)", Color3.fromRGB(100, 255, 100))
            end
            authenticated = true
            task.wait(1)
            pcall(function() screenGui:Destroy() end)
        else
            setStatus("Invalid key!", Color3.fromRGB(255, 80, 80))
            activateBtn.Active = true
            activateBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)

            -- Shake animation
            local orig = mainFrame.Position
            for i = 1, 3 do
                mainFrame.Position = UDim2.new(0.5, -180 + 6, 0.5, -160)
                task.wait(0.04)
                mainFrame.Position = UDim2.new(0.5, -180 - 6, 0.5, -160)
                task.wait(0.04)
            end
            mainFrame.Position = orig
        end
    end

    activateBtn.MouseButton1Click:Connect(function()
        tryActivate()
    end)

    keyBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            tryActivate()
        end
    end)

    -- Close handler
    closeBtn.MouseButton1Click:Connect(function()
        closed = true
        pcall(function() screenGui:Destroy() end)
    end)

    -- Wait for result
    while not authenticated and not closed do
        task.wait(0.1)
    end

    return authenticated
end

-- ============================================================
-- MAIN VALIDATE FUNCTION
-- ============================================================
function KEY_SYSTEM.validate()
    local hwid = getHWID()

    -- Step 1: Check GitHub whitelist
    local whitelisted = checkWhitelist(hwid)
    if whitelisted then
        return true
    end

    -- Step 2: Check local auth
    local localAuth = checkLocalAuth(hwid)
    if localAuth then
        return true
    end

    -- Step 3: Show key GUI (blocks until user enters key or closes)
    local result = showKeyGUI(hwid)
    return result
end

function KEY_SYSTEM.getHWID()
    return getHWID()
end

return KEY_SYSTEM
