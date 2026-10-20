-- ============================================================
--  MOVEMENT | Obsidian (fixed WalkSpeed)
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player            = Players.LocalPlayer

local Movement = {}

local Hub, Config, Group
local connections = {}

local speedState = { enabled = false, value = 16, loop = nil }
local fovState   = { enabled = false, value = 70, loop = nil }
local fbState    = { enabled = false, saved = {} }

local function track(c) table.insert(connections, c) return c end

-- ============================================================
--  ABYSSAL-STYLE SPEED
-- ============================================================
local function getChar() return player.Character end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end
local function getLiveModifiers()
    return ReplicatedStorage:FindFirstChild("LiveModifiers")
end
local function isCrouching(char)
    if not char then return false end
    local cp = char:FindFirstChild("CollisionPart") or char:FindFirstChild("Collision")
    if cp then
        local crouch = cp:FindFirstChild("CollisionCrouch")
        if crouch then return crouch.CollisionGroup == "PlayerCrouching" end
    end
    return false
end
local function getInjuriesSpeed(hum)
    if not hum then return 0 end
    return 0.075 * (hum.MaxHealth - hum.Health)
end
local function getCurrentSpeed()
    local char = getChar()
    local hum  = getHum()
    local base = 15
    if not char or not hum then return base end
    base += char:GetAttribute("SpeedBoost") or 0
    base += char:GetAttribute("SpeedBoostBehind") or 0
    base += char:GetAttribute("SpeedBoostExtra") or 0

    local lm = getLiveModifiers()
    if lm then
        if lm:FindFirstChild("PlayerFast")    then base += 3 end
        if lm:FindFirstChild("PlayerFaster")  then base += 6 end
        if lm:FindFirstChild("PlayerFastest") then base += 20 end
        if lm:FindFirstChild("PlayerSlow")    then base -= 3 end
        if lm:FindFirstChild("PlayerSlowHealth") then base -= getInjuriesSpeed(hum) end
    end

    if isCrouching(char) then
        if lm and lm:FindFirstChild("PlayerCrouchSlow") then base -= 8
        elseif lm and lm:FindFirstChild("PlayerSlow") then base -= 8
        else base -= 5 end
    end
    return base
end

local function applySpeed()
    if speedState.loop then return end
    speedState.loop = RunService.Heartbeat:Connect(function()
        if not speedState.enabled then return end
        local hum = getHum()
        if not hum then return end
        local target = getCurrentSpeed() + speedState.value
        if math.abs(hum.WalkSpeed - target) > 0.1 then
            hum.WalkSpeed = target
        end
    end)
    track(speedState.loop)
end

local function cleanupSpeed()
    if speedState.loop then speedState.loop:Disconnect() speedState.loop = nil end
    local hum = getHum()
    if hum then hum.WalkSpeed = 15 end
end

-- ============================================================
--  FOV / FULLBRIGHT (без изменений)
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

local function buildUI()
    Group = Hub.Groupboxes.Main_Movement

    Group:AddSlider("SpeedValue", {
        Text = "Speed Boost", Min = 0, Max = 135, Default = 0, Rounding = 0,
        Callback = function(v) speedState.value = math.floor(v) end,
    })

    Group:AddToggle("SpeedEnable", {
        Text = "Enable Speed", Default = false,
        Tooltip = "Обход античита через атрибут SpeedBoost",
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
