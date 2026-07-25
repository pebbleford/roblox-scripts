--[[
    MM2 Structure Dumper (Pebbleford Hub - recon tool)
    Run this in an MM2 round (ideally AFTER roles are assigned, gun/knife exist).
    It prints the game's real structure and copies the full report to your
    clipboard. Paste the clipboard contents back so the hub's Gun ESP / TP Kill /
    Silent Aim / Auto-Shoot can be wired to the ACTUAL remotes/objects.
    Not obfuscated, no key. Safe to read.
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local L = {}
local function out(s) L[#L + 1] = tostring(s) end
local function className(x) local ok, c = pcall(function() return x.ClassName end) return ok and c or "?" end

-- bounded recursive tree of an instance (class + name), flags remotes/scripts
local function tree(inst, prefix, depth, maxDepth, budget)
    if depth > maxDepth then return end
    local kids
    local ok = pcall(function() kids = inst:GetChildren() end)
    if not ok or not kids then return end
    for _, c in ipairs(kids) do
        if budget.n >= budget.max then out(prefix .. "... (truncated)") return end
        budget.n = budget.n + 1
        local cls = className(c)
        local tag = ""
        if cls == "RemoteEvent" or cls == "RemoteFunction" or cls == "BindableEvent" then tag = "   <== REMOTE"
        elseif cls == "LocalScript" or cls == "Script" or cls == "ModuleScript" then tag = "   <== SCRIPT"
        elseif cls == "NumberValue" or cls == "IntValue" or cls == "StringValue" or cls == "BoolValue" or cls == "ObjectValue" then
            local v = pcall(function() return c.Value end) and tostring(c.Value) or "?"
            tag = "   [=" .. v .. "]"
        end
        out(prefix .. cls .. " '" .. c.Name .. "'" .. tag)
        tree(c, prefix .. "  ", depth + 1, maxDepth, budget)
    end
end

-- try to decompile a script (executor-dependent); returns source or nil
local function tryDecompile(scr)
    local dec = decompile
    if type(dec) ~= "function" then return nil end
    local ok, src = pcall(dec, scr)
    if ok and type(src) == "string" and #src > 0 then return src end
    return nil
end

local function looksGun(n) n = n:lower() return n:find("gun") or n:find("revolver") or n:find("pistol") end
local function looksKnife(n) n = n:lower() return n:find("knife") or n:find("blade") end

out("========== MM2 STRUCTURE DUMP ==========")
out("PlaceId=" .. tostring(game.PlaceId) .. "  JobId=" .. tostring(game.JobId))
out("executor: " .. (identifyexecutor and tostring(identifyexecutor()) or "unknown"))
out("decompile available: " .. tostring(type(decompile) == "function"))
out("")

-- 1) Weapons: find every gun/knife tool anywhere, deep-dump + decompile
out("========== [1] WEAPON TOOLS (deep) ==========")
local weaponTools = {}
local function collectTools(container, where)
    local ok, kids = pcall(function() return container:GetChildren() end)
    if not ok or not kids then return end
    for _, t in ipairs(kids) do
        if className(t) == "Tool" and (looksGun(t.Name) or looksKnife(t.Name)) then
            weaponTools[#weaponTools + 1] = { tool = t, where = where }
        end
    end
end
collectTools(LP:FindFirstChild("Backpack") or LP, "MyBackpack")
if LP.Character then collectTools(LP.Character, "MyCharacter") end
for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then collectTools(p.Character, p.Name .. ".Character") end
    local bp = p:FindFirstChild("Backpack")
    if bp then collectTools(bp, p.Name .. ".Backpack") end
end
-- also loose weapons in workspace (dropped)
collectTools(workspace, "workspace(dropped)")
local gd = workspace:FindFirstChild("GunDrop"); if gd then collectTools(gd, "workspace.GunDrop") end

if #weaponTools == 0 then
    out("  (no gun/knife tools found — run this DURING a round after roles assign)")
end
local dumpedScripts = {}
for _, e in ipairs(weaponTools) do
    local t = e.tool
    out("")
    out("TOOL '" .. t.Name .. "'  @ " .. e.where)
    tree(t, "  ", 1, 4, { n = 0, max = 120 })
    -- decompile any scripts inside for the fire logic
    for _, s in ipairs(t:GetDescendants()) do
        local cls = className(s)
        if (cls == "LocalScript" or cls == "ModuleScript") and not dumpedScripts[s] then
            dumpedScripts[s] = true
            local src = tryDecompile(s)
            if src then
                out("  --- DECOMPILED " .. cls .. " '" .. s.Name .. "' (first 5000 chars) ---")
                out(src:sub(1, 5000))
                out("  --- end " .. s.Name .. " ---")
            end
        end
    end
end

-- 2) All remotes in ReplicatedStorage (shoot remote lives here or in the tool)
out("")
out("========== [2] REMOTES in ReplicatedStorage ==========")
local rn = 0
for _, d in ipairs(RS:GetDescendants()) do
    local cls = className(d)
    if cls == "RemoteEvent" or cls == "RemoteFunction" then
        rn = rn + 1
        if rn <= 150 then out("  " .. cls .. "  " .. d:GetFullName()) end
    end
end
out("  total remotes in RS: " .. rn)

-- 3) Workspace top-level (find drop folders, map containers)
out("")
out("========== [3] WORKSPACE top-level ==========")
local wn = 0
for _, c in ipairs(workspace:GetChildren()) do
    wn = wn + 1
    if wn <= 120 then out("  " .. className(c) .. " '" .. c.Name .. "'") end
end
out("  total workspace children: " .. wn)

-- 4) Coins
out("")
out("========== [4] COINS ==========")
for _, name in ipairs({ "CoinContainer", "Coins", "CoinFolder", "Coin" }) do
    local f = workspace:FindFirstChild(name)
    if f then
        local kids = f:GetChildren()
        out("  workspace." .. name .. "  (" .. #kids .. " children, class " .. className(f) .. ")")
        if kids[1] then
            out("  sample child: " .. className(kids[1]) .. " '" .. kids[1].Name .. "'")
            tree(kids[1], "    ", 1, 2, { n = 0, max = 30 })
        end
    end
end

-- 5) ReplicatedStorage + notable module scripts
out("")
out("========== [5] ReplicatedStorage top-level ==========")
for _, c in ipairs(RS:GetChildren()) do
    out("  " .. className(c) .. " '" .. c.Name .. "'")
end

-- 6) Per-player role snapshot (confirm role detection by tool name)
out("")
out("========== [6] PLAYERS / ROLE tools ==========")
for _, p in ipairs(Players:GetPlayers()) do
    local tools = {}
    local function grab(cont) if cont then for _, t in ipairs(cont:GetChildren()) do if className(t) == "Tool" then tools[#tools + 1] = t.Name end end end end
    grab(p.Character); grab(p:FindFirstChild("Backpack"))
    out("  " .. p.Name .. ": [" .. table.concat(tools, ", ") .. "]")
end

out("")
out("========== END DUMP ==========")

local report = table.concat(L, "\n")
-- print in chunks so the console doesn't truncate
for i = 1, #L do print(L[i]) end
-- copy full report to clipboard
local setclip = setclipboard or toclipboard or (syn and syn.write_clipboard)
if setclip then pcall(setclip, report) print("\n[mm2_dump] Full report copied to clipboard — paste it back.")
else print("\n[mm2_dump] No clipboard function; screenshot/scroll the console output above.") end
