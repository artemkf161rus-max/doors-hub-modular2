-- ============================================================
--  ESP | Obsidian (модуль для doors-hub-modular2)
-- ============================================================
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local Lighting           = game:GetService("Lighting")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local player             = Players.LocalPlayer

local ESP = {}

local Hub, Config, Group
local connections = {}

local CurrentRooms = workspace:FindFirstChild("CurrentRooms")
local FloorReplicated = ReplicatedStorage:FindFirstChild("FloorReplicated")
local GameData = ReplicatedStorage:FindFirstChild("GameData")

local Floor
if GameData then
    local f = GameData:FindFirstChild("Floor")
    if f then Floor = f.Value end
end

local function track(c) table.insert(connections, c) return c end

-- ============================================================
--  КАТЕГОРИИ ESP
-- ============================================================
local ESP_CATEGORIES = {
    Keys = {
        Color = Color3.fromRGB(0, 255, 255),
        Names = { KeyObtain = true, ElectricalKeyObtain = true },
        Labels = { KeyObtain = "Door Key", ElectricalKeyObtain = "Electrical Key" },
    },
    Doors = { Color = Color3.fromRGB(0, 255, 0), Names = { Door = true } },
    Items = {
        Color = Color3.fromRGB(255, 255, 255),
        Names = { Vitamins = true, Lighter = true, Flashlight = true, Lockpick = true, SkeletonKey = true, Shears = true, Bandage = true, Crucifix = true },
        Labels = { Vitamins = "Vitamins", Lighter = "Lighter", Flashlight = "Flashlight", Lockpick = "Lockpicks", SkeletonKey = "Skeleton Key", Shears = "Shears", Bandage = "Bandage", Crucifix = "Crucifix" },
    },
    Books = { Color = Color3.fromRGB(255, 100, 150), Names = { LiveHintBook = true }, Labels = { LiveHintBook = "Hint Book" } },
    Misc = { Color = Color3.fromRGB(0, 100, 0), Names = { LeverForGate = true }, Labels = { LeverForGate = "Gate Lever" } },
    Objectives = {
        Color = Color3.fromRGB(0, 255, 0),
        Names = {
            MinesGenerator = true, FuseObtain = true, LiveBreakerPolePickup = true,
            LibraryHintPaper = true, CringlePresent = true, MinesGateButton = true,
            GardenGateButton = true, TimerLever = true, MinesAnchor = true,
            WaterPump = true, VineGuillotine = true,
        },
        Labels = {
            MinesGenerator = "Generator", FuseObtain = "Generator Fuse",
            LiveBreakerPolePickup = "Fuse Breaker", LibraryHintPaper = "Hint Paper",
            CringlePresent = "Present", MinesGateButton = "Gate Button",
            GardenGateButton = "Gate Button", WaterPump = "Water Pump", VineGuillotine = "Vine Lever",
        },
    },
    HidingSpots = {
        Color = Color3.fromRGB(255, 170, 0),
        Names = {
            Wardrobe = true, ["Backdoor_Wardrobe"] = true, Toolshed = true,
            RetroWardrobe = true, ["Wardrobe-FOOLS26"] = true, Locker_Large = true,
            Rooms_Locker = true, Rooms_Locker_Fridge = true,
            Bed = true, Double_Bed = true, DoubleBed = true,
            CircularVent = true, Dumpster = true,
        },
        Labels = {
            Wardrobe = "Closet", ["Backdoor_Wardrobe"] = "Closet", Toolshed = "Closet",
            RetroWardrobe = "Closet", ["Wardrobe-FOOLS26"] = "Closet", Locker_Large = "Locker",
            Rooms_Locker = "Locker", Rooms_Locker_Fridge = "Locker",
            Bed = "Bed", Double_Bed = "Double Bed", DoubleBed = "Double Bed",
            CircularVent = "Vent", Dumpster = "Dumpster",
        },
    },
    Chests = {
        Color = Color3.fromRGB(255, 255, 0),
        Names = {
            ChestBox = true, ChestBoxLocked = true, Toolbox = true, Toolbox_Locked = true,
            Chest_Vine = true, Toolshed_Small = true, Locker_Small_Locked = true, MouseHole = true,
        },
        Labels = {
            ChestBox = "Chest", ChestBoxLocked = "Locked Chest", Toolbox = "Toolbox",
            Toolbox_Locked = "Locked Toolbox", Chest_Vine = "Vine Chest", Toolshed_Small = "Toolshed",
            Locker_Small_Locked = "Locked Item Locker", MouseHole = "Mouse",
        },
    },
    Currency = {
        Color = Color3.fromRGB(255, 255, 0),
        Names = { GoldPile = true, StardustPickup = true },
        Labels = { GoldPile = "Gold Pile", StardustPickup = "Stardust Pile" },
    },
    Ladders = { Color = Color3.fromRGB(255, 255, 255), Names = { Ladder = true }, Labels = { Ladder = "Ladder" } },
}

local NameToCategory = {}
for cat, data in pairs(ESP_CATEGORIES) do
    data.Enabled = false
    data.Objects = {}
    for name in pairs(data.Names) do NameToCategory[name] = cat end
end

local function removeESP(category, instance)
    local data = ESP_CATEGORIES[category]
    local entry = data.Objects[instance]
    if not entry then return end
    data.Objects[instance] = nil
    pcall(function() entry.Conn:Disconnect() end)
    pcall(function() entry.Highlight:Destroy() end)
    if entry.Bill then pcall(function() entry.Bill:Destroy() end) end
end

local function addESP(category, instance, label)
    local data = ESP_CATEGORIES[category]
    if data.Objects[instance] then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "ObsidianESP_" .. category
    highlight.Adornee = instance
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = data.Color
    highlight.OutlineColor = data.Color
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.Parent = workspace

    local bill
    if label then
        local part = instance.PrimaryPart or (instance:IsA("BasePart") and instance) or instance:FindFirstChildWhichIsA("BasePart")
        if part then
            bill = Instance.new("BillboardGui")
            bill.Name = "ObsidianESP_Bill_" .. category
            bill.Adornee = part
            bill.Size = UDim2.new(0, 150, 0, 25)
            bill.StudsOffset = Vector3.new(0, 2, 0)
            bill.AlwaysOnTop = true
            bill.MaxDistance = 500
            bill.LightInfluence = 0
            local text = Instance.new("TextLabel")
            text.BackgroundTransparency = 1
            text.Size = UDim2.new(1, 0, 1, 0)
            text.Font = Enum.Font.GothamBold
            text.Text = label
            text.TextColor3 = data.Color
            text.TextStrokeTransparency = 0
            text.TextStrokeColor3 = Color3.new(0, 0, 0)
            text.TextSize = 14
            text.Parent = bill
            bill.Parent = workspace
        end
    end

    local conn = instance.AncestryChanged:Connect(function()
        if not instance:IsDescendantOf(workspace) then removeESP(category, instance) end
    end)
    data.Objects[instance] = { Highlight = highlight, Conn = conn, Bill = bill }
end

local function isBookInBookcase(obj)
    if obj.Name ~= "LiveHintBook" then return false end
    return obj:FindFirstAncestor("Bookcase") ~= nil
end

local function getESPTarget(category, obj)
    if category == "Books" and isBookInBookcase(obj) then return nil, nil end

    if obj.Name == "WaterPump" then return obj:FindFirstChild("Wheel"), "Water Pump" end
    if obj.Name == "VineGuillotine" then return obj:FindFirstChild("Lever"), "Vine Lever" end
    if obj.Name == "TimerLever" then
        local lbl = "Time Lever"
        local t = obj:FindFirstChild("TakeTimer")
        if t and t:IsA("TextLabel") then lbl = "Time Lever [" .. t.Text .. "]" end
        return obj, lbl
    end
    if obj.Name == "MinesAnchor" then
        local sign = obj:FindFirstChild("Sign")
        if sign and sign:FindFirstChild("TextLabel") then
            return obj, "Anchor [" .. sign.TextLabel.Text .. "]"
        end
        return obj, "Anchor"
    end
    if obj.Name == "GoldPile" then
        local val = obj:GetAttribute("GoldValue")
        return obj, val and ("Gold Pile [" .. val .. "]") or "Gold Pile"
    end
    if ESP_CATEGORIES[category].Labels and ESP_CATEGORIES[category].Labels[obj.Name] then
        return obj, ESP_CATEGORIES[category].Labels[obj.Name]
    end
    return obj, nil
end

local function setESPCategory(category, enabled)
    local data = ESP_CATEGORIES[category]
    data.Enabled = enabled
    if enabled then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if data.Names[obj.Name] and (obj:IsA("Model") or obj:IsA("BasePart")) then
                local target, label = getESPTarget(category, obj)
                if target then addESP(category, target, label) end
            end
        end
    else
        for instance in pairs(data.Objects) do removeESP(category, instance) end
    end
end

track(workspace.DescendantAdded:Connect(function(obj)
    local category = NameToCategory[obj.Name]
    if category and ESP_CATEGORIES[category].Enabled and (obj:IsA("Model") or obj:IsA("BasePart")) then
        task.defer(function()
            if not ESP_CATEGORIES[category].Enabled or not obj:IsDescendantOf(workspace) then return end
            local target, label = getESPTarget(category, obj)
            if target then addESP(category, target, label) end
        end)
    end
end))

-- ============================================================
--  PLAYER ESP
-- ============================================================
local playerESPEnabled = false
local playerHighlights = {}

local function addPlayerESP(char)
    if not char or playerHighlights[char] then return end
    local h = Instance.new("Highlight")
    h.Name = "ObsidianESP_Player"
    h.Adornee = char
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.FillColor = Color3.fromRGB(255, 255, 255)
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.7
    h.OutlineTransparency = 0
    h.Parent = workspace
    playerHighlights[char] = h
end

local function setPlayerESP(state)
    playerESPEnabled = state
    if state then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then
                if plr.Character then addPlayerESP(plr.Character) end
                track(plr.CharacterAdded:Connect(function(c) task.wait(0.5) if playerESPEnabled then addPlayerESP(c) end end))
            end
        end
    else
        for _, h in pairs(playerHighlights) do pcall(function() h:Destroy() end) end
        table.clear(playerHighlights)
    end
end

track(Players.PlayerAdded:Connect(function(plr)
    if plr == player then return end
    track(plr.CharacterAdded:Connect(function(c) task.wait(0.5) if playerESPEnabled then addPlayerESP(c) end end))
end))

-- ============================================================
--  ENTITY ESP / NOTIFY
-- ============================================================
local Entities = {
    ["RushMoving"] = { Alias = "Rush", NotifyMessage = { Title = "Entity 'Rush' has spawned.", Body = "Find a hiding spot." } },
    ["AmbushMoving"] = { Alias = "Ambush", NotifyMessage = { Title = "Entity 'Ambush' has spawned.", Body = "Find a hiding spot." } },
    ["Eyes"] = { Alias = "Eyes", NotifyMessage = { Title = "Entity 'Eyes' has spawned.", Body = "Avoid looking at it." } },
    ["Lookman"] = { Alias = "Eyes", NotifyMessage = { Title = "Entity 'Eyes' has spawned.", Body = "Avoid looking at it." } },
    ["BackdoorRush"] = { Alias = "Blitz", NotifyMessage = { Title = "Entity 'Blitz' has spawned.", Body = "Find a hiding spot." } },
    ["BackdoorLookman"] = { Alias = "Lookman", NotifyMessage = { Title = "Entity 'Lookman' has spawned.", Body = "Avoid looking at its eyes." } },
    ["Groundskeeper"] = { Alias = "Groundskeeper", NotifyMessage = { Title = "Entity 'Groundskeeper' has spawned.", Body = "Avoid stepping on the grass." } },
    ["A60"] = { Alias = "A-60", NotifyMessage = { Title = "Entity 'A-60' has spawned.", Body = "Find a hiding spot." } },
    ["A120"] = { Alias = "A-120", NotifyMessage = { Title = "Entity 'A-120' has spawned.", Body = "Find a hiding spot." } },
    ["GloombatSwarm"] = { Alias = "Gloombat Swarm", NotifyMessage = { Title = "Entity 'Gloombat Swarm' has spawned.", Body = "Keep all light sources turned off." } },
    ["GlitchRush"] = { Alias = "RNIUSHCG==", NotifyMessage = { Title = "Entity 'RNIUSHCG==' has spawned.", Body = "Find a hiding spot." } },
    ["GlitchAmbush"] = { Alias = "AR0xMBUSH", NotifyMessage = { Title = "Entity 'AR0xMBUSH' has spawned.", Body = "Find a hiding spot." } },
    ["MonumentEntity"] = { Alias = "Monument", NotifyMessage = { Title = "Entity 'Monument' has spawned.", Body = "It can't move while you are looking at it." } },
    ["JeffTheKiller"] = { Alias = "Jeff the Killer", NotifyMessage = { Title = "Entity 'Jeff the Killer' has spawned.", Body = "Avoid touching him." } },
    ["CustomEntity"] = { Alias = "Custom Entity", NotifyMessage = { Title = "Entity 'Custom Entity' has spawned.", Body = "Find a hiding spot." } },
    ["FrozenAmbush"] = { Alias = "Frozen Ambush", NotifyMessage = { Title = "Entity 'Frozen Ambush' has spawned.", Body = "Find a hiding spot." } },
    ["SallyMoving"] = { Alias = "Sally", NotifyMessage = { Title = "Entity 'Sally' has spawned.", Body = "Drop an item for her." } },
}

local EntityHighlights = {}
local entityESPEnabled = false

local function getEntityInfo(instance)
    if not instance or not instance:IsA("Model") then return nil end
    return Entities[instance.Name]
end

local function hasAnyTrue(tbl)
    if not tbl then return false end
    for _, v in pairs(tbl) do if v == true then return true end end
    return false
end

local function isInESPList(name)
    local info = Entities[name] if not info then return false end
    local opt = Hub.Options.EntityESPOptions
    if not opt or not opt.Value then return true end
    if not hasAnyTrue(opt.Value) then return true end
    return opt.Value[info.Alias] == true
end

local function isInNotifyList(name)
    local info = Entities[name] if not info then return false end
    local opt = Hub.Options.NotifyEntityList
    if not opt or not opt.Value then return true end
    if not hasAnyTrue(opt.Value) then return true end
    return opt.Value[info.Alias] == true
end

local function getEntityColor()
    local ok, col = pcall(function() return Hub.Options.EntityESPColor.Value end)
    if ok and typeof(col) == "Color3" then return col end
    return Color3.fromRGB(255, 0, 0)
end

local function getModelPart(model)
    if model.PrimaryPart then return model.PrimaryPart end
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then return part end
    end
end

local function removeEntityHighlight(instance)
    local entry = EntityHighlights[instance]
    if not entry then return end
    EntityHighlights[instance] = nil
    pcall(function() if entry.Conn then entry.Conn:Disconnect() end end)
    pcall(function() if entry.Highlight then entry.Highlight:Destroy() end end)
    pcall(function() if entry.Bill then entry.Bill:Destroy() end end)
    pcall(function() if entry.Box then entry.Box:Destroy() end end)
end

local function addEntityHighlight(instance)
    if EntityHighlights[instance] then return end
    local info = getEntityInfo(instance)
    if not info then return end
    local color = getEntityColor()
    local part = getModelPart(instance)
    if not part then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "OldDoorsHub_EntityESP"
    highlight.Adornee = instance
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = workspace

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "OldDoorsHub_EntityBox"
    box.Adornee = part
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Size = part.Size
    box.Transparency = 0.4
    box.Color3 = color
    box.Parent = workspace.CurrentCamera or workspace

    local bill = Instance.new("BillboardGui")
    bill.Name = "OldDoorsHub_EntityBill"
    bill.Adornee = part
    bill.Size = UDim2.new(0, 200, 0, 40)
    bill.StudsOffset = Vector3.new(0, 3, 0)
    bill.AlwaysOnTop = true
    bill.MaxDistance = 1000
    bill.LightInfluence = 0
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = info.Alias
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextSize = 16
    label.Parent = bill
    bill.Parent = workspace.CurrentCamera or workspace

    local conn = instance.Destroying:Connect(function() removeEntityHighlight(instance) end)
    EntityHighlights[instance] = { Highlight = highlight, Box = box, Bill = bill, Conn = conn }
end

local function refreshEntityHighlights()
    for instance in pairs(EntityHighlights) do
        if not instance.Parent or not isInESPList(instance.Name) then removeEntityHighlight(instance) end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and getEntityInfo(obj) and isInESPList(obj.Name) then addEntityHighlight(obj) end
    end
end

local function setEntityESP(state)
    entityESPEnabled = state
    if state then refreshEntityHighlights()
    else for instance in pairs(EntityHighlights) do removeEntityHighlight(instance) end end
end

local function handleSpawn(obj)
    if not obj or not obj:IsA("Model") then return end
    local info = getEntityInfo(obj)
    if not info then return end
    task.defer(function()
        task.wait(0.15)
        if not obj.Parent then return end
        if entityESPEnabled and isInESPList(obj.Name) then addEntityHighlight(obj) end
        if Hub.Toggles.NotifyEntities and Hub.Toggles.NotifyEntities.Value and isInNotifyList(obj.Name) then
            Hub.Notify({ Title = info.NotifyMessage.Title, Description = info.NotifyMessage.Body, Time = 5 })
        end
    end)
end

track(workspace.ChildAdded:Connect(handleSpawn))
track(workspace.DescendantAdded:Connect(function(obj) if obj:IsA("Model") then handleSpawn(obj) end end))

task.spawn(function()
    while true do
        task.wait(1.5)
        if entityESPEnabled then refreshEntityHighlights() end
    end
end)

-- ============================================================
--  SHOW SEEK / EYESTALK PATH
-- ============================================================
local seekNodesFolder = Instance.new("Folder")
seekNodesFolder.Name = "OldDoorsHub_SeekNodes"
seekNodesFolder.Parent = workspace

local seekBeams = {}
local previousSeekNode = nil
local seekPathColor = Color3.fromRGB(0, 255, 0)
local showSeekPathEnabled = false
local showEyestalkPathEnabled = false
local eyestalkBeams = {}

local function updateBeamVisibility(beams, visible)
    local vis = visible and 0 or 1
    local seq = NumberSequence.new({ NumberSequenceKeypoint.new(0, vis), NumberSequenceKeypoint.new(1, vis) })
    for _, beam in pairs(beams) do
        pcall(function() if beam.Parent then beam.Transparency = seq end end)
    end
end

local function clearSeekBeams()
    seekNodesFolder:ClearAllChildren()
    table.clear(seekBeams)
    previousSeekNode = nil
end

local function addSeekLight(light)
    if light.Name ~= "SeekGuidingLight" then return end
    if light:GetAttribute("HDH_Highlighted") then return end
    light:SetAttribute("HDH_Highlighted", true)

    local node = Instance.new("Part")
    node.Size = Vector3.one
    node.Transparency = 1
    node.Parent = seekNodesFolder
    node.Anchored = true
    node.CFrame = light.CFrame
    node.CanCollide = false
    node.Name = "SeekNode"

    local prev = previousSeekNode or node
    previousSeekNode = node

    local beam = Instance.new("Beam")
    beam.Color = ColorSequence.new(seekPathColor)
    beam.FaceCamera = true
    beam.Width0 = 0.2
    beam.Width1 = 0.2
    beam.Brightness = 10
    beam.LightInfluence = 0
    beam.LightEmission = 0
    beam.Enabled = true
    local vis = showSeekPathEnabled and 0 or 1
    beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, vis), NumberSequenceKeypoint.new(1, vis) })
    beam.Parent = seekNodesFolder
    local a0 = Instance.new("Attachment", node)
    local a1 = Instance.new("Attachment", prev)
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    table.insert(seekBeams, beam)
end

local function handlePathLights(folder)
    clearSeekBeams()
    for _, light in ipairs(folder:GetChildren()) do addSeekLight(light) end
    track(folder.ChildAdded:Connect(addSeekLight))
end

for _, obj in ipairs(workspace:GetChildren()) do
    if obj.Name == "PathLights" then handlePathLights(obj) end
end
track(workspace.ChildAdded:Connect(function(obj)
    if obj.Name == "PathLights" then handlePathLights(obj) end
end))

local function clearEyestalkBeams()
    for _, beam in pairs(eyestalkBeams) do pcall(function() beam:Destroy() end) end
    table.clear(eyestalkBeams)
    for _, node in ipairs(seekNodesFolder:GetChildren()) do
        if node.Name == "EyestalkNode" then node:Destroy() end
    end
end

local function handleEyestalkRoom(room)
    if not room:GetAttribute("RawName") or not string.find(room:GetAttribute("RawName"), "Eyestalk") then return end
    if not showEyestalkPathEnabled then return end

    task.spawn(function()
        local roomExit = room:WaitForChild("RoomExit", 10)
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not roomExit or not root then return end

        local path = PathfindingService:CreatePath({
            AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 2,
            AgentRadius = 1, AgentHeight = 1,
        })
        local ok = pcall(function() path:ComputeAsync(root.Position, roomExit.Position) end)
        if not ok or path.Status ~= Enum.PathStatus.Success then return end

        local prevNode = nil
        for _, wp in ipairs(path:GetWaypoints()) do
            local node = Instance.new("Part")
            node.Size = Vector3.one
            node.Transparency = 1
            node.Parent = seekNodesFolder
            node.Anchored = true
            node.Position = wp.Position
            node.CanCollide = false
            node.Name = "EyestalkNode"

            local prev = prevNode or node
            prevNode = node

            local beam = Instance.new("Beam")
            beam.Color = ColorSequence.new(seekPathColor)
            beam.FaceCamera = true
            beam.Width0 = 0.2
            beam.Width1 = 0.2
            beam.Brightness = 10
            beam.LightInfluence = 0
            beam.LightEmission = 0
            beam.Enabled = true
            local vis = showEyestalkPathEnabled and 0 or 1
            beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, vis), NumberSequenceKeypoint.new(1, vis) })
            beam.Parent = seekNodesFolder
            local a0 = Instance.new("Attachment", node)
            local a1 = Instance.new("Attachment", prev)
            beam.Attachment0 = a0
            beam.Attachment1 = a1
            table.insert(eyestalkBeams, beam)
            task.wait()
        end
    end)
end

if CurrentRooms then track(CurrentRooms.ChildAdded:Connect(handleEyestalkRoom)) end

-- ============================================================
--  NOTIFY HASTE / OXYGEN
-- ============================================================
local notifyHasteEnabled = false
local notifyOxygenEnabled = false
local lastOxygen = nil

local function formatTime(sec)
    local m = math.floor(sec / 60)
    local s = sec - m * 60
    return string.format("%02d:%02d", m, s)
end

local function hookHasteTimer()
    if not FloorReplicated then return end
    local timer = FloorReplicated:FindFirstChild("DigitalTimer")
    if timer then
        track(timer:GetPropertyChangedSignal("Value"):Connect(function()
            if notifyHasteEnabled then
                Hub.Notify({ Title = "Haste Timer", Description = formatTime(timer.Value), Time = 2 })
            end
        end))
    end
    track(FloorReplicated.ChildAdded:Connect(function(obj)
        if obj.Name == "DigitalTimer" then
            track(obj:GetPropertyChangedSignal("Value"):Connect(function()
                if notifyHasteEnabled then
                    Hub.Notify({ Title = "Haste Timer", Description = formatTime(obj.Value), Time = 2 })
                end
            end))
        end
    end))
end
task.defer(hookHasteTimer)

local function attachOxygenHook(char)
    if not char then return end
    lastOxygen = char:GetAttribute("Oxygen")
    track(char:GetAttributeChangedSignal("Oxygen"):Connect(function()
        local cur = char:GetAttribute("Oxygen")
        if notifyOxygenEnabled and cur and lastOxygen and cur < lastOxygen then
            Hub.Notify({ Title = "Oxygen", Description = string.format("%.1f%%", cur), Time = 2 })
        end
        lastOxygen = cur
    end))
end
if player.Character then attachOxygenHook(player.Character) end
track(player.CharacterAdded:Connect(function(char) task.wait(0.5) attachOxygenHook(char) end))

-- ============================================================
--  WORLD: Remove Fog / Cutscenes / Fullbright
-- ============================================================
local fogEnabled = false
local fogSaved = {}
local fogConns = {}
local fogInstanceConns = {}

local function setRemoveFog(state)
    if state == fogEnabled then return end
    fogEnabled = state
    if state then
        fogSaved.FogEnd = Lighting.FogEnd
        fogSaved.FogStart = Lighting.FogStart
        Lighting.FogEnd = 10000000
        for _, obj in ipairs(Lighting:GetChildren()) do
            if obj:IsA("Atmosphere") then
                if not obj:GetAttribute("HDH_OldDensity") then obj:SetAttribute("HDH_OldDensity", obj.Density) end
                obj.Density = 0
                if not fogInstanceConns[obj] then
                    fogInstanceConns[obj] = obj:GetPropertyChangedSignal("Density"):Connect(function()
                        if fogEnabled and obj.Density ~= 0 then
                            if not obj:GetAttribute("HDH_OldDensity") then obj:SetAttribute("HDH_OldDensity", obj.Density) end
                            obj.Density = 0
                        end
                    end)
                end
            end
        end
        fogConns.FogEnd = Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
            if fogEnabled and Lighting.FogEnd ~= 10000000 then
                fogSaved.FogEnd = Lighting.FogEnd
                Lighting.FogEnd = 10000000
            end
        end)
    else
        Lighting.FogEnd = fogSaved.FogEnd or 1000
        if fogSaved.FogStart then Lighting.FogStart = fogSaved.FogStart end
        table.clear(fogSaved)
        for _, c in pairs(fogConns) do pcall(function() c:Disconnect() end) end
        table.clear(fogConns)
        for obj, c in pairs(fogInstanceConns) do
            pcall(function() c:Disconnect() end)
            if obj and obj.Parent then
                local old = obj:GetAttribute("HDH_OldDensity")
                if old then obj.Density = old end
            end
        end
        table.clear(fogInstanceConns)
    end
end

track(Lighting.DescendantAdded:Connect(function(obj)
    if obj:IsA("Atmosphere") and fogEnabled then
        if not obj:GetAttribute("HDH_OldDensity") then obj:SetAttribute("HDH_OldDensity", obj.Density) end
        obj.Density = 0
        if not fogInstanceConns[obj] then
            fogInstanceConns[obj] = obj:GetPropertyChangedSignal("Density"):Connect(function()
                if fogEnabled and obj.Density ~= 0 then
                    if not obj:GetAttribute("HDH_OldDensity") then obj:SetAttribute("HDH_OldDensity", obj.Density) end
                    obj.Density = 0
                end
            end)
        end
    end
end))

local cutsceneNames = {
    "Figure", "FigureEnd", "FigureHotelEnd", "FigureHotelFire",
    "SeekIntroFools", "SeekIntroHotel", "SeekIntroMines", "SeekIntroMines2",
    "SerewSeekDrain", "SewerSeekLower", "GrumbleNestEnd", "EyestalkIntro",
}
local removeCutscenesEnabled = false

local function processCutsceneFolder(folder, state)
    if not folder then return end
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("ModuleScript") then
            local origName = obj:GetAttribute("HDH_OriginalName")
            if not origName then
                origName = obj.Name:gsub("_Disabled$", "")
                obj:SetAttribute("HDH_OriginalName", origName)
            end
            if table.find(cutsceneNames, origName) then
                if state then
                    if obj.Name ~= origName .. "_Disabled" then obj.Name = origName .. "_Disabled" end
                else
                    if obj.Name ~= origName then obj.Name = origName end
                end
            end
        end
    end
end

local function setRemoveCutscenes(state)
    removeCutscenesEnabled = state
    local pg = player:FindFirstChild("PlayerGui")
    local mainUI = pg and pg:FindFirstChild("MainUI")
    if mainUI then
        local initiator = mainUI:FindFirstChild("Initiator")
        local mainGame = initiator and initiator:FindFirstChild("Main_Game")
        local remoteListener = mainGame and mainGame:FindFirstChild("RemoteListener")
        local cutscenes = remoteListener and remoteListener:FindFirstChild("Cutscenes")
        if cutscenes then processCutsceneFolder(cutscenes, state) end
    end
    if FloorReplicated then processCutsceneFolder(FloorReplicated, state) end
end

local function hookCutsceneFolders()
    local pg = player:FindFirstChild("PlayerGui")
    local mainUI = pg and pg:FindFirstChild("MainUI")
    if mainUI then
        local initiator = mainUI:FindFirstChild("Initiator")
        local mainGame = initiator and initiator:FindFirstChild("Main_Game")
        local remoteListener = mainGame and mainGame:FindFirstChild("RemoteListener")
        local cutscenes = remoteListener and remoteListener:FindFirstChild("Cutscenes")
        if cutscenes then
            track
