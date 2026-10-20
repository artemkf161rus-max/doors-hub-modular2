-- ============================================================
--  MISC | Obsidian
-- ============================================================
local Players                = game:GetService("Players")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local player                 = Players.LocalPlayer

local Misc = {}

local Hub, Config, Group
local connections = {}

local lagState = { enabled = false, saved = {} }
local infState = { enabled = false }

local FakePrompts = {}
local PromptContainer = nil

local LOCK_PROMPT_NAMES = {
    UnlockPrompt = true, SkullPrompt = true, LockPrompt = true,
    ThingToEnable = true, FusesPrompt = true,
}

local ItemNames = {
    Lockpick = "Lockpicks", Shears = "Shears", SkeletonKey = "Skeleton Key",
    Multitool = "Multitool", Key = "Key", KeyBackdoor = "Backdoor Key",
    KeyElectrical = "Electrical Key", KeyIron = "Iron Key",
    GeneratorFuse = "Generator Fuse",
}

local function track(c) table.insert(connections, c) return c end

local function getPromptContainer()
    if PromptContainer and PromptContainer.Parent then return PromptContainer end
    if gethui then
        PromptContainer = Instance.new("Folder")
        PromptContainer.Name = "PromptContainer_" .. tostring(math.random(1, 99999))
        PromptContainer.Parent = gethui()
    else
        PromptContainer = Instance.new("Folder")
        PromptContainer.Name = "PromptContainer"
        PromptContainer.Parent = game:GetService("CoreGui")
    end
    return PromptContainer
end

local function isScreechSound(obj)
    if not obj.Parent then return false end
    return string.find(string.lower(obj.Parent.Name), "screech", 1, true) ~= nil
end

local function applyAntiLag()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            if not lagState.saved[obj] then lagState.saved[obj] = { Material = obj.Material } end
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke")
            or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Beam") then
            obj.Enabled = false
        elseif obj:IsA("Sound") then
            obj.Volume = isScreechSound(obj) and 1 or 0
        end
    end
end

local function restoreAntiLag()
    for obj, data in pairs(lagState.saved) do
        if obj and obj.Parent and obj:IsA("BasePart") and data.Material then
            obj.Material = data.Material
        end
    end
    lagState.saved = {}
end

local function isLockPrompt(prompt)
    if LOCK_PROMPT_NAMES[prompt.Name] then return true end
    if prompt.Parent and prompt.Parent:GetAttribute("Locked") == true then return true end
    if prompt.Parent and prompt.Parent.Parent
        and prompt.Parent.Parent.Name == "Locker_Small_Locked"
        and prompt.Name == "ActivateEventPrompt" then
        return true
    end
    return false
end

local function makeFakePrompt(originalPrompt)
    if originalPrompt:GetAttribute("FakePrompt") then return end
    for fake in pairs(FakePrompts) do
        if FakePrompts[fake] == originalPrompt then return end
    end
    local fake = originalPrompt:Clone()
    fake:SetAttribute("FakePrompt", true)
    fake.Name = originalPrompt.Name
    fake.Parent = originalPrompt.Parent
    task.wait()
    fake.Enabled = originalPrompt.Enabled
    originalPrompt.Parent = getPromptContainer()
    FakePrompts[fake] = originalPrompt
    track(originalPrompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        if fake and fake.Parent then fake.Enabled = originalPrompt.Enabled end
    end))
    originalPrompt.Destroying:Once(function()
        if fake and fake.Parent then fake:Destroy() end
        FakePrompts[fake] = nil
    end)
    fake.Destroying:Once(function() FakePrompts[fake] = nil end)
end

local function scanPromptsForFake()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and not obj:GetAttribute("FakePrompt") and isLockPrompt(obj) then
            makeFakePrompt(obj)
        end
    end
end

local function onPromptAdded(obj)
    if not obj:IsA("ProximityPrompt") then return end
    if obj:GetAttribute("FakePrompt") then return end
    task.wait(0.1)
    if isLockPrompt(obj) then makeFakePrompt(obj) end
end

local function firePrompt(prompt)
    if not prompt or not prompt.Parent then return end
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(math.max(prompt.HoldDuration, 0.05))
            prompt:InputHoldEnd()
        end)
    end
end

local function onPromptTriggered(prompt)
    if not infState.enabled then return end
    if not prompt:GetAttribute("FakePrompt") then return end
    local char = player.Character
    if not char then return end
    local anyTool = char:FindFirstChildOfClass("Tool")
    if not anyTool then return end
    local toolData = ItemNames[anyTool.Name]
    if not toolData then
        local realPrompt = FakePrompts[prompt]
        if realPrompt then firePrompt(realPrompt) end
        return
    end
    local drops = workspace:FindFirstChild("Drops")
    local rf    = ReplicatedStorage:FindFirstChild("RemotesFolder")
    if not drops or not rf then return end
    local dropRemote = rf:FindFirstChild("DropItem")
    if not dropRemote then return end
    local gotDrop = false
    local dropConn
    dropConn = drops.ChildAdded:Connect(function(newTool)
        if gotDrop then return end
        gotDrop = true
        if dropConn then dropConn:Disconnect() end
        task.wait(0.15)
        local dropPrompt = newTool:FindFirstChild("ModulePrompt")
            or newTool:FindFirstChildWhichIsA("ProximityPrompt")
        if dropPrompt then firePrompt(dropPrompt) end
        local realPrompt = FakePrompts[prompt]
        if realPrompt then firePrompt(realPrompt) end
    end)
    track(dropConn)
    task.delay(2, function()
        if not gotDrop and dropConn then
            dropConn:Disconnect()
            local realPrompt = FakePrompts[prompt]
            if realPrompt then firePrompt(realPrompt) end
        end
    end)
    pcall(function() dropRemote:FireServer(anyTool) end)
end

local function buildUI()
    Group = Hub.Groupboxes.Main_Misc

    Group:AddToggle("AntiLag", {
        Text = "Anti-Lag", Default = false,
        Callback = function(on)
            lagState.enabled = on
            if on then applyAntiLag() else restoreAntiLag() end
        end,
    })

    Group:AddDivider()

    Group:AddToggle("InfiniteItems", {
        Text = "Infinite Items", Default = false,
        Tooltip = "Lockpick, Skeleton Key, Shears, Multitool",
        Callback = function(on)
            infState.enabled = on
            if on then scanPromptsForFake() end
        end,
    })
end

function Misc.init(hub)
    Hub, Config = hub, hub.Config
    buildUI()

    Hub.Objects.FakePrompts = FakePrompts
    Hub.Objects.PromptContainer = getPromptContainer

    task.spawn(scanPromptsForFake)
    track(workspace.DescendantAdded:Connect(onPromptAdded))
    track(ProximityPromptService.PromptTriggered:Connect(onPromptTriggered))

    function Misc.cleanup()
        lagState.enabled = false
        infState.enabled = false
        restoreAntiLag()

        for fake, original in pairs(FakePrompts) do
            if original and original.Parent == PromptContainer and fake and fake.Parent then
                original.Parent = fake.Parent
            end
            if fake and fake.Parent then fake:Destroy() end
        end
        FakePrompts = {}
        Hub.Objects.FakePrompts = FakePrompts

        if PromptContainer and PromptContainer.Parent then PromptContainer:Destroy() end
        PromptContainer = nil

        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
    end

    print("[MISC] init")
    return Misc
end

return Misc
