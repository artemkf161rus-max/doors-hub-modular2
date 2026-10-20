-- ============================================================
--  JUMP ENABLE | Obsidian
-- ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player           = Players.LocalPlayer

local JumpEnable = {}

local Hub, Config, Group
local connections = {}

local jumpState = {
    enabled = false, jumpPower = 50,
    loop = nil, infiniteLoop = nil,
}

local function track(c) table.insert(connections, c) return c end

local function applyJump()
    local char = player.Character
    if not char then return end
    char:SetAttribute("CanJump", true)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = jumpState.jumpPower
    end
end

if hookmetamethod and newcclosure and getnamecallmethod then
    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            if getnamecallmethod() == "SetAttribute" then
                local args = {...}
                if args[1] == "CanJump" and args[2] == false then
                    return oldNamecall(self, "CanJump", true)
                end
            end
            return oldNamecall(self, ...)
        end))
    end)
end

if hookmetamethod and newcclosure then
    pcall(function()
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if key == "JumpPower" then
                local real = oldIndex(self, key)
                if real and real < jumpState.jumpPower then return jumpState.jumpPower end
                return real
            end
            return oldIndex(self, key)
        end))
    end)
end

local function startLoop()
    if jumpState.loop then return end
    jumpState.loop = RunService.Heartbeat:Connect(function()
        if not jumpState.enabled then return end
        local char = player.Character
        if not char then return end
        if char:GetAttribute("CanJump") ~= true then char:SetAttribute("CanJump", true) end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.JumpPower < jumpState.jumpPower then hum.JumpPower = jumpState.jumpPower end
    end)
    track(jumpState.loop)
end

local function stopLoop()
    if jumpState.loop then jumpState.loop:Disconnect() jumpState.loop = nil end
end

track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not jumpState.enabled then return end
    if input.KeyCode == Enum.KeyCode.Space then
        local char = player.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end
end))

local function buildUI()
    Group = Hub.Groupboxes.Main_Movement

    Group:AddDivider()

    Group:AddToggle("JumpEnable", {
        Text = "Jump Enable", Default = false,
        Callback = function(on)
            jumpState.enabled = on
            if on then applyJump() startLoop() else stopLoop() end
        end,
    })

    Group:AddSlider("JumpPower", {
        Text = "Jump Power (50-500)", Min = 50, Max = 500, Default = 50, Rounding = 0,
        Callback = function(v)
            jumpState.jumpPower = math.floor(v)
            if jumpState.enabled then
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum.JumpPower = jumpState.jumpPower end
            end
        end,
    })

    Group:AddToggle("InfiniteJumps", {
        Text = "Infinite Jumps", Default = false,
        Callback = function(on)
            if on then
                if not jumpState.infiniteLoop then
                    jumpState.infiniteLoop = RunService.Heartbeat:Connect(function()
                        if not Hub.Toggles.InfiniteJumps or not Hub.Toggles.InfiniteJumps.Value then return end
                        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                            local char = player.Character
                            local hum = char and char:FindFirstChildOfClass("Humanoid")
                            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                        end
                    end)
                    track(jumpState.infiniteLoop)
                end
            elseif jumpState.infiniteLoop then
                jumpState.infiniteLoop:Disconnect()
                jumpState.infiniteLoop = nil
            end
        end,
    })
end

function JumpEnable.init(hub)
    Hub, Config = hub, hub.Config
    buildUI()

    track(player.CharacterAdded:Connect(function()
        task.wait(1)
        if jumpState.enabled then applyJump() end
    end))

    track(player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        track(char:GetAttributeChangedSignal("CanJump"):Connect(function()
            if jumpState.enabled and char:GetAttribute("CanJump") ~= true then
                char:SetAttribute("CanJump", true)
            end
        end))
    end))

    function JumpEnable.cleanup()
        jumpState.enabled = false
        stopLoop()
        if jumpState.infiniteLoop then jumpState.infiniteLoop:Disconnect() jumpState.infiniteLoop = nil end
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
    end

    print("[JUMP] init")
    return JumpEnable
end

return JumpEnable
