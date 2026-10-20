-- ============================================================
--  MOVEMENT | Pivot teleport (без BodyVelocity, без raknet)
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")
local player            = Players.LocalPlayer

local Movement = {}

local Hub, Config, Group
local connections = {}

local speedState = { enabled = false, value = 0, loop = nil }
local fovState   = { enabled = false, value = 70, loop = nil }
local fbState    = { enabled = false, saved = {} }

local function track(c) table.insert(connections, c) return c end
local function getChar() return player.Character end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end

-- ============================================================
--  SPEED — Pivot teleport
-- ============================================================
local function cleanupSpeed()
    if speedState.loop then speedState.loop:Disconnect() speedState.loop = nil end
    local hum = getHum()
    if hum then hum.WalkSpeed = 15 end
end

local function applySpeed()
    local hum = getHum()
    if not hum then return end
    hum.WalkSpeed = 15

    if not speedState.loop then
        speedState.loop = RunService.Heartbeat:Connect(function()
            if not speedState.enabled then return end
            local char = getChar()
            local cam = workspace.CurrentCamera
            if not char or not cam then return end
            local hum2 = char:FindFirstChildOfClass("Humanoid")
            if not hum2 then return end

            -- телепорт вперёд от камеры каждый кадр
            -- speedState.value = стадов за кадр (1-100)
            local offset = speedState.value * 0.1
            if offset > 0 then
                pcall(function()
                    char:PivotTo(cam:GetPivot() * CFrame.new(0, 0, -offset))
                end)
            end
        end)
        track(speedState.loop)
    end
end

-- ============================================================
--  FOV
-- ============================================================
local function cleanupFOV()
    if fovState.loop then fovState.loop:Disconnect() fovState.loop = nil end
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = Config.FOV_DEFAULT end
end

local function applyFOV()
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = fovState.value end
    if not fovState.loop then
        fovState.loop = RunService.RenderStepped:Connect(function()
            if not fovState.enabled then return end
            local c = workspace.CurrentCamera
            if c and c.FieldOfView ~= fovState.value then c.FieldOfView = fovState.value end
        end)
        track(fovState.loop)
    end
end

-- ============================================================
--  FULLBRIGHT
-- ============================================================
local function applyFullbright()
    if not fbState.saved.saved then
        fbState.saved.Ambient        = Lighting.Ambient
        fbState.saved.OutdoorAmbient = Lighting.OutdoorAmbient
        fbState.saved.Brightness     = Lighting.Brightness
        fbState.saved.ClockTime      = Lighting.ClockTime
        fbState.saved.GlobalShadows  = Lighting.GlobalShadows
        fbState.saved.FogEnd         = Lighting.FogEnd
        fbState.saved.saved = true
    end
    Lighting.Ambient        = Color3.fromRGB(178, 178, 178)
    Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    Lighting.Brightness     = 3
    Lighting.ClockTime      = 12
    Lighting.GlobalShadows  = false
    Lighting.FogEnd         = 100000
end

local function cleanupFullbright()
    if fbState.saved.saved then
        Lighting.Ambient        = fbState.saved.Ambient
        Lighting.OutdoorAmbient = fbState.saved.OutdoorAmbient
        Lighting.Brightness     = fbState.saved.Brightness
        Lighting.ClockTime      = fbState.saved.ClockTime
        Lighting.GlobalShadows  = fbState.saved.GlobalShadows
        Lighting.FogEnd         = fbState.saved.FogEnd
        fbState.saved = {}
    end
end

-- ============================================================
--  UI
-- ============================================================
local function buildUI()
    Group = Hub.Groupboxes.Main_Movement

    Group:AddSlider("SpeedValue", {
        Text = "Teleport Speed (0-100)", Min = 0, Max = 100, Default = 0, Rounding = 0,
        Tooltip = "Стадов за кадр. 10 = ~60 стадов/сек, 100 = ~600 стадов/сек",
        Callback = function(v) speedState.value = math.floor(v) end,
    })

    Group:AddToggle("SpeedEnable", {
        Text = "Enable Teleport Speed", Default = false,
        Tooltip = "Pivot-телепорт вперёд от камеры. Обходит античит DOORS.",
        Callback = function(on)
            speedState.enabled = on
            if on then applySpeed() else cleanupSpeed() end
        end,
    })

    Group:AddDivider()

    Group:AddToggle("FOVEnable", {
        Text = "FOV Enable", Default = false,
        Callback = function(on)
            fovState.enabled = on
            if on then applyFOV() else cleanupFOV() end
        end,
    })

    Group:AddSlider("FOVValue", {
        Text = "FOV", Min = Config.FOV_MIN, Max = Config.FOV_MAX,
        Default = Config.FOV_DEFAULT, Rounding = 0,
        Callback = function(v) fovState.value = math.floor(v) end,
    })

    Group:AddDivider()

    Group:AddToggle("Fullbright", {
        Text = "Fullbright", Default = false,
        Callback = function(on)
            fbState.enabled = on
            if on then applyFullbright() else cleanupFullbright() end
        end,
    })
end

-- ============================================================
--  INIT
-- ============================================================
function Movement.init(hub)
    Hub, Config = hub, hub.Config
    buildUI()

    track(player.CharacterAdded:Connect(function()
        task.wait(1)
        if speedState.enabled then
            cleanupSpeed()
            applySpeed()
        end
    end))

    function Movement.cleanup()
        speedState.enabled = false
        fovState.enabled = false
        fbState.enabled = false
        cleanupSpeed()
        cleanupFOV()
        cleanupFullbright()
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
    end

    print("[MOVEMENT] init")
    return Movement
end

return Movement
