local url = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/esp.lua"
local code = game:HttpGet(url, true)
local fn, err = loadstring(code)
if not fn then
    warn("[ESP Loader] Failed to compile: " .. tostring(err))
    return
end
fn()
