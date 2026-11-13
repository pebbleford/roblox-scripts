-- ================================================================
-- Pebbleford Hub - Chat Translator
-- Reads incoming chat, auto-translates to English, and lets you
-- send outgoing messages translated into any target language.
-- v1.6
-- ================================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer

local _spawn = (task and task.spawn) or spawn

-- ===================== COLOR PALETTE (Teal Theme) =====================
local COLORS = {
	bg = Color3.fromRGB(16, 22, 26),
	bgSecondary = Color3.fromRGB(24, 34, 40),
	inputBg = Color3.fromRGB(20, 28, 34),
	accent = Color3.fromRGB(60, 200, 210),
	accentHover = Color3.fromRGB(90, 225, 235),
	accentDark = Color3.fromRGB(40, 150, 160),
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(175, 190, 195),
	textDim = Color3.fromRGB(115, 130, 135),
	border = Color3.fromRGB(45, 65, 75),
	error = Color3.fromRGB(255, 80, 80),
	success = Color3.fromRGB(90, 230, 130),
	warn = Color3.fromRGB(255, 200, 90),
	toggleOn = Color3.fromRGB(60, 200, 210),
	toggleOff = Color3.fromRGB(70, 78, 82),
	chatColor = Color3.fromRGB(120, 235, 245),
}

-- ===================== STATE =====================
local incomingTarget = "en"   -- language to translate incoming messages into
local outgoingTarget = "en"   -- language to translate outgoing messages into
local autoTranslateIncoming = true
local showInGameChat = true
local windowVisible = true
local logLines = {}
local MAX_LOG_LINES = 60
local recentSelfTexts = {}    -- translations we sent, to avoid retranslating them

-- ===================== MOBILE / SIZE =====================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local ORIG_W = 500
local ORIG_H = 470
local windowW = ORIG_W
local windowH = ORIG_H
if isMobile then
	windowW = math.min(math.floor(screenSize.X * 0.92), ORIG_W)
	windowH = math.min(math.floor(screenSize.Y * 0.78), ORIG_H)
	if windowW < 320 then windowW = 320 end
	if windowH < 340 then windowH = 340 end
end

-- ===================== GUI PARENT =====================
local function getGuiParent()
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then return hui end
	end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then return cg end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()

pcall(function()
	local old = guiParent:FindFirstChild("SXTranslator")
	if old then old:Destroy() end
end)
pcall(function()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if pg and pg:FindFirstChild("SXTranslator") then pg.SXTranslator:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SXTranslator"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true
if typeof(syn) == "table" and syn.protect_gui then pcall(syn.protect_gui, screenGui) end
pcall(function() screenGui.Parent = guiParent end)
if not screenGui.Parent then
	pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
end
if not screenGui.Parent then
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ===================== HELPERS =====================
local function addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

local function addStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or COLORS.border
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function addPadding(parent, top, right, bottom, left)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, top or 0)
	p.PaddingRight = UDim.new(0, right or 0)
	p.PaddingBottom = UDim.new(0, bottom or 0)
	p.PaddingLeft = UDim.new(0, left or 0)
	p.Parent = parent
	return p
end

-- ===================== WINDOW =====================
local window = Instance.new("Frame")
window.Size = UDim2.new(0, windowW, 0, windowH)
window.Position = UDim2.new(0.5, -windowW / 2, 0.5, -windowH / 2)
window.BackgroundColor3 = COLORS.bg
window.BorderSizePixel = 0
window.Active = true
window.Parent = screenGui
addCorner(window, 10)
addStroke(window, COLORS.border, 1)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = COLORS.bgSecondary
titleBar.BorderSizePixel = 0
titleBar.Parent = window
addCorner(titleBar, 10)

local titleBarFix = Instance.new("Frame")
titleBarFix.Size = UDim2.new(1, 0, 0, 12)
titleBarFix.Position = UDim2.new(0, 0, 1, -12)
titleBarFix.BackgroundColor3 = COLORS.bgSecondary
titleBarFix.BorderSizePixel = 0
titleBarFix.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -100, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Chat Translator v1.6"
titleLabel.TextColor3 = COLORS.textPrimary
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 36, 1, 0)
versionLabel.Position = UDim2.new(1, -78, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v1.6"
versionLabel.TextColor3 = COLORS.textDim
versionLabel.TextSize = 12
versionLabel.Font = Enum.Font.Gotham
versionLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = COLORS.textPrimary
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
addCorner(closeBtn, 6)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

-- ===================== CONTENT =====================
local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 1, -40)
content.Position = UDim2.new(0, 0, 0, 40)
content.BackgroundTransparency = 1
content.Parent = window
addPadding(content, 12, 12, 12, 12)

-- --- helper: build a small toggle row
local function createToggleRow(parent, yOffset, label, initial, onChange)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.Position = UDim2.new(0, 0, 0, yOffset)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -60, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = label
	text.TextColor3 = COLORS.textPrimary
	text.TextSize = 13
	text.Font = Enum.Font.Gotham
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 50, 0, 22)
	btn.Position = UDim2.new(1, -50, 0.5, -11)
	btn.BackgroundColor3 = initial and COLORS.toggleOn or COLORS.toggleOff
	btn.Text = initial and "ON" or "OFF"
	btn.TextColor3 = COLORS.textPrimary
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Parent = row
	addCorner(btn, 6)

	local state = initial
	btn.MouseButton1Click:Connect(function()
		state = not state
		btn.BackgroundColor3 = state and COLORS.toggleOn or COLORS.toggleOff
		btn.Text = state and "ON" or "OFF"
		onChange(state)
	end)
	return btn
end

-- --- helper: build a labelled TextBox row
local function createInputRow(parent, yOffset, label, initial, placeholder, onChange)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.Position = UDim2.new(0, 0, 0, yOffset)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(0.5, -6, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = label
	text.TextColor3 = COLORS.textPrimary
	text.TextSize = 13
	text.Font = Enum.Font.Gotham
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = row

	local boxHolder = Instance.new("Frame")
	boxHolder.Size = UDim2.new(0.5, -6, 1, 0)
	boxHolder.Position = UDim2.new(0.5, 6, 0, 0)
	boxHolder.BackgroundColor3 = COLORS.inputBg
	boxHolder.BorderSizePixel = 0
	boxHolder.Parent = row
	addCorner(boxHolder, 6)
	addStroke(boxHolder, COLORS.border, 1)
	addPadding(boxHolder, 4, 8, 4, 8)

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 1, 0)
	box.BackgroundTransparency = 1
	box.Text = initial
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = COLORS.textDim
	box.TextColor3 = COLORS.textPrimary
	box.TextSize = 13
	box.Font = Enum.Font.Gotham
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = boxHolder
	box.FocusLost:Connect(function() onChange(box.Text) end)
	return box
end

-- Section: Incoming
local incHeader = Instance.new("TextLabel")
incHeader.Size = UDim2.new(1, 0, 0, 18)
incHeader.Position = UDim2.new(0, 0, 0, 0)
incHeader.BackgroundTransparency = 1
incHeader.Text = "INCOMING"
incHeader.TextColor3 = COLORS.accent
incHeader.TextSize = 11
incHeader.Font = Enum.Font.GothamBold
incHeader.TextXAlignment = Enum.TextXAlignment.Left
incHeader.Parent = content

createToggleRow(content, 20, "Auto-translate incoming chat", autoTranslateIncoming, function(v)
	autoTranslateIncoming = v
end)
createToggleRow(content, 50, "Show translations in game chat", showInGameChat, function(v)
	showInGameChat = v
end)
createInputRow(content, 80, "Translate incoming to:", incomingTarget, "en", function(v)
	v = (v or ""):gsub("%s+", ""):lower()
	if v ~= "" then incomingTarget = v end
end)

-- Divider
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, 0, 0, 1)
divider.Position = UDim2.new(0, 0, 0, 118)
divider.BackgroundColor3 = COLORS.border
divider.BorderSizePixel = 0
divider.Parent = content

-- Section: Outgoing
local outHeader = Instance.new("TextLabel")
outHeader.Size = UDim2.new(1, 0, 0, 18)
outHeader.Position = UDim2.new(0, 0, 0, 128)
outHeader.BackgroundTransparency = 1
outHeader.Text = "OUTGOING"
outHeader.TextColor3 = COLORS.accent
outHeader.TextSize = 11
outHeader.Font = Enum.Font.GothamBold
outHeader.TextXAlignment = Enum.TextXAlignment.Left
outHeader.Parent = content

createInputRow(content, 148, "Send message as:", outgoingTarget, "en", function(v)
	v = (v or ""):gsub("%s+", ""):lower()
	if v ~= "" then outgoingTarget = v end
end)

-- Message input
local msgFrame = Instance.new("Frame")
msgFrame.Size = UDim2.new(1, 0, 0, 60)
msgFrame.Position = UDim2.new(0, 0, 0, 182)
msgFrame.BackgroundColor3 = COLORS.inputBg
msgFrame.BorderSizePixel = 0
msgFrame.Parent = content
addCorner(msgFrame, 6)
addStroke(msgFrame, COLORS.border, 1)
addPadding(msgFrame, 6, 8, 6, 8)

local msgBox = Instance.new("TextBox")
msgBox.Size = UDim2.new(1, 0, 1, 0)
msgBox.BackgroundTransparency = 1
msgBox.Text = ""
msgBox.PlaceholderText = "Type in any language..."
msgBox.PlaceholderColor3 = COLORS.textDim
msgBox.TextColor3 = COLORS.textPrimary
msgBox.TextSize = 13
msgBox.Font = Enum.Font.Gotham
msgBox.ClearTextOnFocus = false
msgBox.MultiLine = true
msgBox.TextWrapped = true
msgBox.TextXAlignment = Enum.TextXAlignment.Left
msgBox.TextYAlignment = Enum.TextYAlignment.Top
msgBox.Parent = msgFrame

-- Send button
local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.new(1, 0, 0, 32)
sendBtn.Position = UDim2.new(0, 0, 0, 250)
sendBtn.BackgroundColor3 = COLORS.accent
sendBtn.Text = "Send Translated"
sendBtn.TextColor3 = Color3.fromRGB(15, 25, 30)
sendBtn.TextSize = 14
sendBtn.Font = Enum.Font.GothamBold
sendBtn.BorderSizePixel = 0
sendBtn.AutoButtonColor = false
sendBtn.Parent = content
addCorner(sendBtn, 6)
sendBtn.MouseEnter:Connect(function() sendBtn.BackgroundColor3 = COLORS.accentHover end)
sendBtn.MouseLeave:Connect(function() sendBtn.BackgroundColor3 = COLORS.accent end)

-- Log panel
local logHeader = Instance.new("TextLabel")
logHeader.Size = UDim2.new(1, 0, 0, 18)
logHeader.Position = UDim2.new(0, 0, 0, 290)
logHeader.BackgroundTransparency = 1
logHeader.Text = "LOG"
logHeader.TextColor3 = COLORS.accent
logHeader.TextSize = 11
logHeader.Font = Enum.Font.GothamBold
logHeader.TextXAlignment = Enum.TextXAlignment.Left
logHeader.Parent = content

local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, 0, 1, -314)
logFrame.Position = UDim2.new(0, 0, 0, 310)
logFrame.BackgroundColor3 = COLORS.inputBg
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 4
logFrame.ScrollBarImageColor3 = COLORS.accent
logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.Parent = content
addCorner(logFrame, 6)
addStroke(logFrame, COLORS.border, 1)
addPadding(logFrame, 6, 8, 6, 8)

local logLayout = Instance.new("UIListLayout")
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Padding = UDim.new(0, 2)
logLayout.Parent = logFrame

local logCounter = 0
local function addLog(msg, color)
	logCounter = logCounter + 1
	local line = Instance.new("TextLabel")
	line.LayoutOrder = logCounter
	line.Size = UDim2.new(1, -4, 0, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.BackgroundTransparency = 1
	line.Text = msg
	line.TextColor3 = color or COLORS.textSecondary
	line.TextSize = 12
	line.Font = Enum.Font.Gotham
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.TextWrapped = true
	line.Parent = logFrame

	table.insert(logLines, line)
	while #logLines > MAX_LOG_LINES do
		local old = table.remove(logLines, 1)
		if old then old:Destroy() end
	end
	-- scroll to bottom next frame
	_spawn(function()
		task.wait()
		logFrame.CanvasPosition = Vector2.new(0, logFrame.AbsoluteCanvasSize.Y)
	end)
end

-- ===================== TRANSLATION =====================
-- Google's public gtx endpoint is used because it needs no key. Response
-- is a nested JSON array: result[1] holds one entry per sentence chunk,
-- each of the form { translatedText, sourceText, ... }; result[3] is the
-- detected source language code.
-- Robust HTTP GET. game:HttpGet is often blocked/rate-limited by executors for
-- Google's API, so prefer the executor's own request function (syn.request,
-- http_request, request, fluxus.request...) which sends a proper User-Agent and
-- is far more reliable. Falls back to game:HttpGet.
local _reqFn = (syn and syn.request) or (http and http.request) or http_request or request
	or (fluxus and fluxus.request) or (getgenv and getgenv().request)
local function httpGet(url)
	if _reqFn then
		local ok, res = pcall(_reqFn, { Url = url, Method = "GET", Headers = { ["User-Agent"] = "Mozilla/5.0" } })
		if ok and type(res) == "table" and type(res.Body) == "string"
			and (res.StatusCode == 200 or res.StatusCode == nil or res.Success) and #res.Body > 0 then
			return res.Body
		end
	end
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok and type(body) == "string" then return body end
	return nil
end

-- Each backend is one host attempt: returns translated, detected or nil.
local function enc(s) return HttpService:UrlEncode(s) end

local function _googleAttempt(host)
	return function(text, tl, sl)
		local url = ("https://%s/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s"):format(host, enc(sl), enc(tl), enc(text))
		local body = httpGet(url)
		if not body then return nil end
		local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
		if ok and type(data) == "table" and type(data[1]) == "table" then
			local parts = {}
			for _, seg in ipairs(data[1]) do
				if type(seg) == "table" and type(seg[1]) == "string" then table.insert(parts, seg[1]) end
			end
			local t = table.concat(parts)
			if t ~= "" then return t, (type(data[3]) == "string" and data[3] or nil) end
		end
		return nil
	end
end

local function _lingvaAttempt(host)
	return function(text, tl, sl)
		local url = ("https://%s/api/v1/%s/%s/%s"):format(host, enc(sl), enc(tl), enc(text))
		local body = httpGet(url)
		if not body then return nil end
		local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
		if ok and type(data) == "table" and type(data.translation) == "string" and data.translation ~= "" then
			local det = (type(data.info) == "table" and type(data.info.detectedSource) == "string") and data.info.detectedSource or nil
			return data.translation, det
		end
		return nil
	end
end

local function _mymemoryAttempt(text, tl, sl)
	local msl = (sl == "auto") and "en" or sl
	local url = ("https://api.mymemory.translated.net/get?q=%s&langpair=%s|%s"):format(enc(text), enc(msl), enc(tl))
	local body = httpGet(url)
	if not body then return nil end
	local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
	if ok and type(data) == "table" and type(data.responseData) == "table"
		and type(data.responseData.translatedText) == "string" and data.responseData.translatedText ~= "" then
		return data.responseData.translatedText, nil
	end
	return nil
end

local _backends = {
	_googleAttempt("translate.googleapis.com"),
	_googleAttempt("clients5.google.com"),
	_lingvaAttempt("lingva.ml"),
	_lingvaAttempt("lingva.garudalinux.org"),
	_lingvaAttempt("translate.plausibility.cloud"),
	_mymemoryAttempt,
}
-- Remember which backend last worked so we hit it FIRST next time, instead of
-- re-waiting on a blocked host (Google) on every single translation.
local _lastGood = 1

local function translate(text, targetLang, sourceLang)
	if not text or text == "" then return nil, nil, "empty" end
	local tl = targetLang or "en"
	local sl = sourceLang or "auto"
	-- Build try order: last-known-good first, then the rest.
	local order = { _lastGood }
	for i = 1, #_backends do if i ~= _lastGood then table.insert(order, i) end end
	for _, idx in ipairs(order) do
		local t, d = _backends[idx](text, tl, sl)
		if t then _lastGood = idx return t, d end
	end
	return nil, nil, "all translation hosts blocked by executor"
end

-- ===================== CHAT INJECTION =====================
local function pushToGameChat(text, color)
	if not showInGameChat then return end
	-- Legacy chat / SetCore path works for both chat versions in most cases.
	pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = text,
			Color = color or COLORS.chatColor,
			Font = Enum.Font.SourceSansBold,
			TextSize = 18,
		})
	end)
	-- Also try the new TextChatService system-message API for the new chat.
	pcall(function()
		local ch = TextChatService:FindFirstChild("TextChannels")
		if ch and ch:FindFirstChild("RBXGeneral") and ch.RBXGeneral.DisplaySystemMessage then
			ch.RBXGeneral:DisplaySystemMessage(text)
		end
	end)
end

-- ===================== INCOMING CHAT HANDLER =====================
local function handleIncoming(speakerName, rawText)
	if not autoTranslateIncoming then return end
	if not rawText or rawText == "" then return end
	-- Skip our own outgoing translations echoing back through the chat hook.
	if recentSelfTexts[rawText] then
		recentSelfTexts[rawText] = nil
		return
	end
	_spawn(function()
		local translated, detected, err = translate(rawText, incomingTarget, "auto")
		if not translated then
			addLog(("[!] translate failed for %s: %s"):format(speakerName, tostring(err)), COLORS.error)
			return
		end
		local src = detected or "??"
		-- Same language as target = no useful translation, skip noise.
		if src == incomingTarget then return end
		local line = ("%s [%s→%s]: %s"):format(speakerName, src, incomingTarget, translated)
		addLog(line, COLORS.textPrimary)
		pushToGameChat(line, COLORS.chatColor)
	end)
end

-- Hook BOTH chat systems rather than guessing one. Some games fire only
-- TextChatService.MessageReceived, some only Player.Chatted, some both - so we
-- listen on both and de-dupe so a message seen twice isn't translated twice.
local usingNewChat = false
pcall(function()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		usingNewChat = true
	end
end)

local _recentIncoming = {}
local function incomingOnce(name, msg)
	if not msg or msg == "" then return end
	local key = name .. "\0" .. msg
	if _recentIncoming[key] and (tick() - _recentIncoming[key]) < 1.5 then return end
	_recentIncoming[key] = tick()
	handleIncoming(name, msg)
end

pcall(function()
	TextChatService.MessageReceived:Connect(function(message)
		if not message then return end
		local src = message.TextSource
		if src and src.UserId == LocalPlayer.UserId then return end
		local plr = src and Players:GetPlayerByUserId(src.UserId)
		local name = (plr and plr.DisplayName) or (src and src.Name) or "Player"
		incomingOnce(name, message.Text)
	end)
end)

local function hookPlayer(plr)
	if plr == LocalPlayer then return end
	pcall(function()
		plr.Chatted:Connect(function(msg) incomingOnce(plr.DisplayName or plr.Name, msg) end)
	end)
end
for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end
Players.PlayerAdded:Connect(hookPlayer)

-- ===================== SEND TRANSLATED =====================
local function sendChat(text)
	local sent = false

	-- Try TextChatService regardless of usingNewChat: the earlier guess could
	-- be wrong, and trying both paths is cheaper than being wrong. Any text
	-- channel is acceptable, since games rename RBXGeneral (RBXSystem, custom
	-- names), so the first channel that has SendAsync is used rather than
	-- assuming one fixed name.
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		if not channels then return end
		local general = channels:FindFirstChild("RBXGeneral")
		local target = general
		if not target then
			for _, ch in ipairs(channels:GetChildren()) do
				if ch:IsA("TextChannel") then target = ch break end
			end
		end
		if target then
			target:SendAsync(text)
			sent = true
		end
	end)

	-- Legacy SayMessageRequest, for games still on the old chat.
	if not sent then
		pcall(function()
			local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
			if events and events:FindFirstChild("SayMessageRequest") then
				events.SayMessageRequest:FireServer(text, "All")
				sent = true
			end
		end)
	end

	return sent
end

local sending = false
local function doSend()
	if sending then return end
	local raw = msgBox.Text
	if not raw or raw:gsub("%s+", "") == "" then
		addLog("[!] type a message first", COLORS.warn)
		return
	end
	sending = true
	sendBtn.Text = "Translating..."
	sendBtn.BackgroundColor3 = COLORS.accentDark

	_spawn(function()
		local translated, detected, err = translate(raw, outgoingTarget, "auto")
		if not translated then
			addLog("[!] outgoing translate failed: " .. tostring(err), COLORS.error)
			sending = false
			sendBtn.Text = "Send Translated"
			sendBtn.BackgroundColor3 = COLORS.accent
			return
		end
		recentSelfTexts[translated] = true
		local ok = sendChat(translated)
		if ok then
			addLog(("me [%s→%s]: %s"):format(detected or "??", outgoingTarget, translated), COLORS.success)
			msgBox.Text = ""
		else
			-- The translation succeeded; only sending was blocked. Show it and
			-- copy it so the message can be pasted into chat by hand instead of
			-- being lost.
			addLog(("translated (send blocked): %s"):format(translated), COLORS.warn)
			addLog("[!] copied to clipboard - paste it into chat manually", COLORS.warn)
			pcall(function() if setclipboard then setclipboard(translated) end end)
		end
		sending = false
		sendBtn.Text = "Send Translated"
		sendBtn.BackgroundColor3 = COLORS.accent
	end)
end

sendBtn.MouseButton1Click:Connect(doSend)
msgBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then doSend() end
end)

-- ===================== DRAGGING =====================
local dragging, dragStart, startPos = false, nil, nil
titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = window.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		window.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

addLog("Ready. Chat mode: " .. (usingNewChat and "TextChatService" or "Legacy"), COLORS.textDim)
addLog("Language codes: en, es, fr, de, ja, ko, zh, ru, pt, it, ar, hi, tr, nl, pl, tl, id, vi, th", COLORS.textDim)

-- Startup self-test so you instantly know if translation works on this executor.
_spawn(function()
	addLog("Testing translation...", COLORS.textDim)
	local out, det, err = translate("hola", "en", "auto")
	if out then
		addLog("[OK] Translation works (" .. (_reqFn and "request" or "HttpGet") .. "). hola -> " .. out, COLORS.success)
	else
		addLog("[X] Translation blocked by your executor: " .. tostring(err), COLORS.error)
		addLog("    Your executor can't reach Google Translate. Try a different executor.", COLORS.warn)
	end
end)
