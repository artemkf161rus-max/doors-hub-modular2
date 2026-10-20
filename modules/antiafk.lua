-- ============================================================
--  ANTI-AFK | Obsidian
-- ============================================================
local Players     = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local player      = Players.LocalPlayer

local AntiAFK = {}

local Hub, Group
local connections = {}

local afkState = { enabled = false, lastPing = 0 }

local function track(c) table.insert(connections, c) return c end

local function setupAntiAfk()
    track(player.Idled:Connect(function()
        if not afkState.enabled then return end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        afkState.lastPing = tick()
    end))
end

local function buildUI()
    Group = Hub.Groupboxes.Exploits_Util

    Group:AddToggle("antiAfk", {
        Text = "Anti-AFK", Default = false,
        Tooltip = "Не даёт кикнуть за 20 мин AFK",
        Callback = function(on)
            afkState.enabled = on
        end,
    })
end

function AntiAFK.init(hub)
    Hub = hub
    buildUI()
    setupAntiAfk()

    function AntiAFK.cleanup()
        afkState.enabled = false
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
    end

    print("[ANTI-AFK] init")
    return AntiAFK
end

return AntiAFK
