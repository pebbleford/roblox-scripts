local url = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/synapsex.lua?v=" .. tostring(tick())
local code = game:HttpGet(url, true)
local fn, err = loadstring(code)
if not fn then
    warn("[Synapse X Loader] Failed to compile: " .. tostring(err))
    return
end
fn()
