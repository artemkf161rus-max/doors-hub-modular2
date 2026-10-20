-- ============================================================
--  ESP | Obsidian (full: Players, Tools, Prompts, Monsters, Doors)
-- ============================================================
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local player             = Players.LocalPlayer

local ESP = {}

local Hub, Config, Group
local connections = {}

-- Хранилища
local espObjects        = {}  -- [Player] = {highlight, billboard}
local toolEspObjects    = {}  -- [Tool] = {highlight, billboard, nameLabel}
local promptEspObjects  = {}  -- [Target] = {highlight, billboard, nameLabel, promptLabel, distLabel, prompt}
local monsterEspObjects = {}  -- [Target] = {highlight, billboard, nameLabel, distLabel}
local doorESPObjects    = {}  -- [DoorModel] = {highlight, billboard, wrapper}
local savedPrompts      = {}  -- [ProximityPrompt] = saved settings (instant)

local function track(c) table.insert(connections, c) return c end

local function getPlayerPos()
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
    return root and root.Position
end

local function getModelPart(target)
    if not target then return nil end
    if target:IsA("Model") then
        return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    elseif target:IsA("BasePart") then
        return target
    end
    return nil
end

-- ============================================================
--  ESP PLAYERS
-- ============================================================
local function createESP(targetPlayer)
    if targetPlayer == player or espObjects[targetPlayer] then return end
    local char = targetPlayer.Character
    if not char then return end

    local hl = Instance.new("Highlight")
    hl.Name = "ESP_Highlight"
    hl.FillColor = Color3.fromRGB(255, 0, 0)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char
    hl.Parent = char

    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_Billboard"
    bb.Size = UDim2.new(0, 200, 0, 30)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = char:FindFirstChild("Head") or char:FindFirstChildWhichIsA("BasePart")
    bb.Parent = char

    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(1, 0, 0, 20)
    nl.BackgroundTransparency = 1
    nl.Text = targetPlayer.Name
    nl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nl.TextStrokeTransparency = 0
    nl.Font = Enum.Font.GothamBold
    nl.TextSize = 14
    nl.Parent = bb

    espObjects[targetPlayer] = { highlight = hl, billboard = bb }
end

local function removeESP(targetPlayer)
    local d = espObjects[targetPlayer]
    if d then
        if d.highlight then d.highlight:Destroy() end
        if d.billboard then d.billboard:Destroy() end
        espObjects[targetPlayer] = nil
    end
end

local function clearAllESP()
    for p in pairs(espObjects) do removeESP(p) end
end

local function watchPlayer(p)
    track(p.CharacterAdded:Connect(function()
        if Hub.Toggles.espPlayers and Hub.Toggles.espPlayers.Value then
            removeESP(p)
            task.wait(0.5)
            createESP(p)
        end
    end))
end

-- ============================================================
--  ESP TOOLS
-- ============================================================
local function createToolESP(tool)
    if toolEspObjects[tool] or not tool:IsA("Tool") then return end
    local isDoor  = tool.Name:sub(1, 4) == "Door"
    local isLever = tool.Name:sub(1, 5) == "Lever" or tool.Name == "LeverToGate"
    local hlColor, textColor
    if isDoor then hlColor, textColor = Config.DOOR_COLOR, Config.DOOR_COLOR
    elseif isLever then hlColor, textColor = Config.LEVER_COLOR, Config.LEVER_COLOR
    else hlColor, textColor = Config.TOOL_COLOR, Config.TOOL_COLOR end

    local hl = Instance.new("Highlight")
    hl.Name = "ToolESP_Highlight"
    hl.FillColor = hlColor
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.4
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = tool
    hl.Parent = tool

    local bb = Instance.new("BillboardGui")
    bb.Name = "ToolESP_Billboard"
    bb.Size = UDim2.new(0, 180, 0, 22)
    bb.StudsOffset = Vector3.new(0, 1.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = tool
    local ap = tool:FindFirstChildWhichIsA("BasePart")
    bb.Adornee = ap or tool

    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(1, 0, 1, 0)
    nl.BackgroundTransparency = 1
    nl.Text = tool.Name
    nl.TextColor3 = textColor
    nl.TextStrokeTransparency = 0
    nl.Font = Enum.Font.GothamBold
    nl.TextSize = 14
    nl.Parent = bb

    toolEspObjects[tool] = { highlight = hl, billboard = bb, nameLabel = nl }
end

local function removeToolESP(tool)
    local d = toolEspObjects[tool]
    if d then
        if d.highlight then d.highlight:Destroy() end
        if d.billboard then d.billboard:Destroy() end
        toolEspObjects[tool] = nil
    end
end

local function clearAllToolESP()
    for t in pairs(toolEspObjects) do removeToolESP(t) end
end

local function scanTools()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") then
            if Hub.Toggles.espTools and Hub.Toggles.espTools.Value then createToolESP(obj) else removeToolESP(obj) end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if char then
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("Tool") then
                    if Hub.Toggles.espTools and Hub.Toggles.espTools.Value then createToolESP(obj) else removeToolESP(obj) end
                end
            end
        end
        local bp = p:FindFirstChildOfClass("Backpack")
        if bp then
            for _, obj in ipairs(bp:GetChildren()) do
                if obj:IsA("Tool") then
                    if Hub.Toggles.espTools and Hub.Toggles.espTools.Value then createToolESP(obj) else removeToolESP(obj) end
                end
            end
        end
    end
end

-- ============================================================
--  ESP PROMPTS
-- ============================================================
local function isPromptBlacklisted(target)
    if not target then return false end
    local name = target.Name
    if Config.PROMPT_BLACKLIST[name] then return true end
    for blocked in pairs(Config.PROMPT_BLACKLIST) do
        if string.find(string.lower(name), string.lower(blocked), 1, true) then return true end
    end
    return false
end

local function isPromptBlueListed(target)
    if not target then return false end
    local name = string.lower(target.Name)
    for blue in pairs(Config.PROMPT_BLUELIST) do
        if string.sub(name, 1, #blue) == string.lower(blue) then return true end
    end
    return false
end

local function getPromptTarget(prompt)
    local parent = prompt.Parent
    if not parent then return nil end
    if parent:IsA("Model") then return parent end
    if parent:IsA("BasePart") then
        return parent:FindFirstAncestorOfClass("Model") or parent
    end
    return nil
end

local function createPromptESP(prompt)
    local target = getPromptTarget(prompt)
    if not target or promptEspObjects[target] then return end
    if target == player.Character or isPromptBlacklisted(target) then return end

    local isDoor  = target.Name:sub(1, 4) == "Door"
    local isLever = target.Name:sub(1, 5) == "Lever" or target.Name == "LeverToGate"
    local isBlue  = isPromptBlueListed(target)
    local fc, tc
    if isDoor then fc, tc = Config.DOOR_COLOR, Config.DOOR_COLOR
    elseif isLever then fc, tc = Config.LEVER_COLOR, Config.LEVER_COLOR
    elseif isBlue then fc, tc = Config.KEY_COLOR, Config.KEY_COLOR
    else fc, tc = Config.PROMPT_COLOR, Config.PROMPT_COLOR end

    local hl = Instance.new("Highlight")
    hl.Name = "PromptESP_Highlight"
    hl.FillColor = fc
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = target
    hl.Parent = target

    local bb = Instance.new("BillboardGui")
    bb.Name = "PromptESP_Billboard"
    bb.Size = UDim2.new(0, 220, 0, 58)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    local ap = getModelPart(target)
    bb.Adornee = ap or target
    bb.Parent = ap or target

    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(1, 0, 0, 18)
    nl.BackgroundTransparency = 1
    nl.Text = target.Name
    nl.TextColor3 = tc
    nl.TextStrokeTransparency = 0
    nl.Font = Enum.Font.GothamBold
    nl.TextSize = 14
    nl.Parent = bb

    local pl = Instance.new("TextLabel")
    pl.Size = UDim2.new(1, 0, 0, 16)
    pl.Position = UDim2.new(0, 0, 0, 18)
    pl.BackgroundTransparency = 1
    pl.Text = prompt.ActionText ~= "" and prompt.ActionText or "Interact"
    pl.TextColor3 = Color3.fromRGB(255, 255, 255)
    pl.TextStrokeTransparency = 0
    pl.Font = Enum.Font.Gotham
    pl.TextSize = 12
    pl.Parent = bb

    local dl = Instance.new("TextLabel")
    dl.Size = UDim2.new(1, 0, 0, 16)
    dl.Position = UDim2.new(0, 0, 0, 34)
    dl.BackgroundTransparency = 1
    dl.Text = "[0 studs]"
    dl.TextColor3 = Color3.fromRGB(180, 255, 180)
    dl.TextStrokeTransparency = 0
    dl.Font = Enum.Font.GothamBold
    dl.TextSize = 12
    dl.Parent = bb

    promptEspObjects[target] = {
        highlight = hl, billboard = bb, nameLabel = nl,
        promptLabel = pl, distLabel = dl, prompt = prompt,
    }
end

local function removePromptESP(target)
    local d = promptEspObjects[target]
    if d then
        if d.highlight then d.highlight:Destroy() end
        if d.billboard then d.billboard:Destroy() end
        promptEspObjects[target] = nil
    end
end

local function clearAllPromptESP()
    for t in pairs(promptEspObjects) do removePromptESP(t) end
end

local function scanPrompts()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local target = getPromptTarget(obj)
            if target then
                if Hub.Toggles.espPrompts and Hub.Toggles.espPrompts.Value and not isPromptBlacklisted(target) then
                    createPromptESP(obj)
                else
                    removePromptESP(target)
                end
            end
        end
    end
end

-- ============================================================
--  ESP MONSTERS
-- ============================================================
local function isBlacklistedMonster(t)
    if not t then return false end
    local n = string.lower(t.Name)
    for b in pairs(Config.MONSTER_BLACKLIST) do
        if string.find(n, string.lower(b), 1, true) then return true end
    end
    return false
end

local function isPlayerChar(t)
    if not t or not t:IsA("Model") then return false end
    return Players:GetPlayerFromCharacter(t) ~= nil
end

local function isMonster(t)
    if not t or isBlacklistedMonster(t) then return false end
    local n = string.lower(t.Name)
    for _, p in ipairs(Config.MONSTER_PREFIXES) do
        if string.sub(n, 1, #p) == string.lower(p) then return true end
    end
    return false
end

local function isRig(t)
    if not t or not t:IsA("Model") then return false end
    if isPlayerChar(t) or isMonster(t) or isBlacklistedMonster(t) then return false end
    if not t:FindFirstChildOfClass("Humanoid") then return false end
    if not t:FindFirstChild("HumanoidRootPart") then return false end
    return true
end

local function shouldMonster(t)
    if isPlayerChar(t) or isBlacklistedMonster(t) then return false end
    return isMonster(t) or isRig(t)
end

local function createMonsterESP(target)
    if monsterEspObjects[target] or not shouldMonster(target) then return end
    local fc, oc, tc
    if isMonster(target) then
        fc, oc, tc = Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 100, 100), Color3.fromRGB(255, 50, 50)
    else
        fc, oc, tc = Color3.fromRGB(255, 140, 0), Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 180, 60)
    end

    local hl = Instance.new("Highlight")
    hl.Name = "MonsterESP_Highlight"
    hl.FillColor = fc
    hl.OutlineColor = oc
    hl.FillTransparency = 0.4
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = target
    hl.Parent = target

    local bb = Instance.new("BillboardGui")
    bb.Name = "MonsterESP_Billboard"
    bb.Size = UDim2.new(0, 220, 0, 40)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    local ap = getModelPart(target)
    bb.Adornee = ap or target
    bb.Parent = ap or target

    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(1, 0, 0, 20)
    nl.BackgroundTransparency = 1
    nl.Text = (isMonster(target) and "⚠ " or "[Rig] ") .. target.Name .. (isMonster(target) and " ⚠" or "")
    nl.TextColor3 = tc
    nl.TextStrokeTransparency = 0
    nl.Font = Enum.Font.GothamBold
    nl.TextSize = 16
    nl.Parent = bb

    local dl = Instance.new("TextLabel")
    dl.Size = UDim2.new(1, 0, 0, 16)
    dl.Position = UDim2.new(0, 0, 0, 20)
    dl.BackgroundTransparency = 1
    dl.Text = "[0 studs]"
    dl.TextColor3 = Color3.fromRGB(255, 220, 180)
    dl.TextStrokeTransparency = 0
    dl.Font = Enum.Font.GothamBold
    dl.TextSize = 12
    dl.Parent = bb

    monsterEspObjects[target] = { highlight = hl, billboard = bb, nameLabel = nl, distLabel = dl }
end

local function removeMonsterESP(target)
    local d = monsterEspObjects[target]
    if d then
        if d.highlight then d.highlight:Destroy() end
        if d.billboard then d.billboard:Destroy() end
        monsterEspObjects[target] = nil
    end
end

local function clearAllMonsterESP()
    for t in pairs(monsterEspObjects) do removeMonsterESP(t) end
end

local function scanMonsters()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if shouldMonster(obj) then
            if Hub.Toggles.espMonsters and Hub.Toggles.espMonsters.Value then createMonsterESP(obj)
            else removeMonsterESP(obj) end
        end
    end
end

-- ============================================================
--  ESP DOORS (wrapper Part + Weld, как в Abysall)
-- ============================================================
local function getDoorNumber(doorModel)
    local num = tonumber(doorModel.Parent and doorModel.Parent.Name)
        or tonumber(doorModel.Parent and doorModel.Parent.Parent and doorModel.Parent.Parent.Name)
    if num then num = num + 1 end
    return tostring(num or "?")
end

local function createDoorESP(doorModel)
    if doorESPObjects[doorModel] then return end
    if not doorModel:IsA("Model") then return end
    local doorPart = doorModel:FindFirstChild("Door")
    if not doorPart or not doorPart:IsA("BasePart") then return end

    local wrapper = Instance.new("Part")
    wrapper.Name = "ObsidianDoorWrapper"
    wrapper.Transparency = 0.999
    wrapper.Size = doorPart.Size
    wrapper.CFrame = doorPart.CFrame
    wrapper.CanCollide = false
    wrapper.CanTouch = false
    wrapper.CanQuery = false
    wrapper.Massless = true
    wrapper.Anchored = false
    wrapper.Parent = doorModel

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = wrapper
    weld.Part1 = doorPart
    weld.Parent = wrapper

    local hl = Instance.new("Highlight")
    hl.Name = "ObsidianESP_Door"
    hl.Adornee = wrapper
    hl.FillColor = Config.DOOR_COLOR
    hl.OutlineColor = Config.DOOR_COLOR
    hl.FillTransparency = 1
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = workspace

    local bill = Instance.new("BillboardGui")
    bill.Name = "ObsidianESP_DoorBill"
    bill.Adornee = wrapper
    bill.Size = UDim2.new(0, 150, 0, 25)
    bill.StudsOffset = Vector3.new(0, 2, 0)
    bill.AlwaysOnTop = true
    bill.MaxDistance = 500
    bill.LightInfluence = 0

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, 0, 1, 0)
    text.Font = Enum.Font.GothamBold
    text.Text = "Door " .. getDoorNumber(doorModel)
    text.TextColor3 = Config.DOOR_COLOR
    text.TextStrokeTransparency = 0
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.TextSize = 14
    text.Parent = bill
    bill.Parent = workspace

    doorESPObjects[doorModel] = { highlight = hl, billboard = bill, wrapper = wrapper }

    doorModel.Destroying:Once(function()
        local d = doorESPObjects[doorModel]
        if d then
            pcall(function() d.highlight:Destroy() end)
            pcall(function() d.billboard:Destroy() end)
            pcall(function() d.wrapper:Destroy() end)
            doorESPObjects[doorModel] = nil
        end
    end)
end

local function removeDoorESP(doorModel)
    local d = doorESPObjects[doorModel]
    if d then
        pcall(function() d.highlight:Destroy() end)
        pcall(function() d.billboard:Destroy() end)
        pcall(function() d.wrapper:Destroy() end)
        doorESPObjects[doorModel] = nil
    end
end

local function clearAllDoorESP()
    for m in pairs(doorESPObjects) do removeDoorESP(m) end
end

local function scanDoors()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Door" and obj:IsA("Model")
            and obj.Parent and tonumber(obj.Parent.Name) then
            if Hub.Toggles.DoorsESP and Hub.Toggles.DoorsESP.Value then
                createDoorESP(obj)
            else
                removeDoorESP(obj)
            end
        end
    end
end

-- ============================================================
--  INSTANT PROMPT
-- ============================================================
local function makePromptInstant(prompt)
    if not prompt:IsA("ProximityPrompt") then return end
    if savedPrompts[prompt] then return end
    savedPrompts[prompt] = {
        HoldDuration = prompt.HoldDuration,
        MaxActivationDistance = prompt.MaxActivationDistance,
        RequiresLineOfSight = prompt.RequiresLineOfSight,
        ClickablePrompt = prompt.ClickablePrompt,
    }
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.ClickablePrompt = true
end

local function restorePrompt(prompt)
    local s = savedPrompts[prompt]
    if not s then return end
    if prompt and prompt.Parent then
        prompt.HoldDuration = s.HoldDuration
        prompt.MaxActivationDistance = s.MaxActivationDistance
        prompt.RequiresLineOfSight = s.RequiresLineOfSight
        prompt.ClickablePrompt = s.ClickablePrompt
    end
    savedPrompts[prompt] = nil
end

local function applyInstant()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            if Hub.Toggles.instantPrompt and Hub.Toggles.instantPrompt.Value then makePromptInstant(obj)
            else restorePrompt(obj) end
        end
    end
end

-- ============================================================
--  UPDATE LOOP
-- ============================================================
local function updateLoop()
    local myPos = getPlayerPos()

    if Hub.Toggles.espPlayers and Hub.Toggles.espPlayers.Value then
        for tp, data in pairs(espObjects) do
            local char = tp.Character
            local charPos
            if char then
                local h = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
                charPos = h and h.Position
            end
            local inRange = true
            if myPos and charPos then inRange = (charPos - myPos).Magnitude <= Config.ESP_RADIUS end
            if char and data.highlight and inRange then
                data.highlight.Enabled = true
                data.highlight.Adornee = char
                if data.billboard then
                    data.billboard.Enabled = true
                    data.billboard.Adornee = char:FindFirstChild("Head") or char:FindFirstChildWhichIsA("BasePart")
                end
            else
                if data.highlight then data.highlight.Enabled = false end
                if data.billboard then data.billboard.Enabled = false end
            end
        end
    end

    if Hub.Toggles.espTools and Hub.Toggles.espTools.Value then
        for tool, data in pairs(toolEspObjects) do
            if not tool.Parent then removeToolESP(tool)
            else
                local ap = tool:FindFirstChildWhichIsA("BasePart")
                local toolPos = ap and ap.Position
                local inRange = true
                if myPos and toolPos then inRange = (toolPos - myPos).Magnitude <= Config.ESP_RADIUS end
                if data.highlight then data.highlight.Enabled = inRange data.highlight.Adornee = tool end
                if data.billboard then data.billboard.Enabled = inRange data.billboard.Adornee = ap or tool end
                if data.nameLabel then data.nameLabel.Text = tool.Name end
            end
        end
    end

    if Hub.Toggles.espPrompts and Hub.Toggles.espPrompts.Value then
        for target, data in pairs(promptEspObjects) do
            if not target.Parent then removePromptESP(target)
            else
                local ap = getModelPart(target)
                local inRange = true
                if myPos and ap then inRange = (ap.Position - myPos).Magnitude <= Config.ESP_RADIUS end
                if data.billboard then data.billboard.Enabled = inRange data.billboard.Adornee = ap or target end
                if data.highlight then data.highlight.Enabled = inRange data.highlight.Adornee = target end
                if data.nameLabel then data.nameLabel.Text = target.Name end
                if data.promptLabel and data.prompt and data.prompt.Parent then
                    data.promptLabel.Text = data.prompt.ActionText ~= "" and data.prompt.ActionText or "Interact"
                end
                if data.distLabel and myPos and ap then
                    data.distLabel.Text = string.format("[%.0f studs]", (ap.Position - myPos).Magnitude)
                end
            end
        end
    end

    if Hub.Toggles.espMonsters and Hub.Toggles.espMonsters.Value then
        for target, data in pairs(monsterEspObjects) do
            if not target.Parent then removeMonsterESP(target)
            else
                local ap = getModelPart(target)
                if data.billboard then data.billboard.Adornee = ap or target end
                if data.highlight then data.highlight.Adornee = target end
                if data.distLabel and myPos and ap then
                    data.distLabel.Text = string.format("[%.0f studs]", (ap.Position - myPos).Magnitude)
                end
            end
        end
    end

    if Hub.Toggles.DoorsESP and Hub.Toggles.DoorsESP.Value then
        for doorModel, data in pairs(doorESPObjects) do
            if not doorModel.Parent then removeDoorESP(doorModel)
            else
                local wrapper = data.wrapper
                if wrapper and wrapper.Parent then
                    -- wrapper следует за Door через Weld, но на случай рассинхрона — подтягиваем
                    local doorPart = doorModel:FindFirstChild("Door")
                    if doorPart and doorPart:IsA("BasePart") then
                        -- синхронизируем размер если дверь изменилась
                        if wrapper.Size ~= doorPart.Size then wrapper.Size = doorPart.Size end
                    end
                    local inRange = true
                    if myPos then inRange = (wrapper.Position - myPos).Magnitude <= Config.ESP_RADIUS end
                    if data.highlight then data.highlight.Enabled = inRange end
                    if data.billboard then data.billboard.Enabled = inRange end
                end
            end
        end
    end
end

-- ============================================================
--  UI
-- ============================================================
local function buildUI()
    Group = Hub.Groupboxes.Visuals_ESP

    Group:AddToggle("espPlayers", {
        Text = "ESP Players", Default = false,
        Callback = function(on)
            if on then for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
            else clearAllESP() end
        end,
    })

    Group:AddToggle("espTools", {
        Text = "ESP Tools", Default = false,
        Callback = function(on) if on then scanTools() else clearAllToolESP() end end,
    })

    Group:AddToggle("espPrompts", {
        Text = "ESP Prompts", Default = false,
        Callback = function(on) if on then scanPrompts() else clearAllPromptESP() end end,
    })

    Group:AddToggle("espMonsters", {
        Text = "ESP Monsters", Default = false,
        Callback = function(on) if on then scanMonsters() else clearAllMonsterESP() end end,
    })

    Group:AddToggle("DoorsESP", {
        Text = "Doors ESP (Green)", Default = false,
        Callback = function(on) if on then scanDoors() else clearAllDoorESP() end end,
    })

    Group:AddDivider()

    Group:AddToggle("instantPrompt", {
        Text = "Instant Prompt", Default = false,
        Callback = function() applyInstant() end,
    })
end

-- ============================================================
--  INIT
-- ============================================================
function ESP.init(hub)
    Hub, Config = hub, hub.Config
    buildUI()

    -- Players
    for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
    track(Players.PlayerAdded:Connect(function(p)
        watchPlayer(p)
        if Hub.Toggles.espPlayers and Hub.Toggles.espPlayers.Value then
            task.wait(0.5) createESP(p)
        end
    end))
    track(Players.PlayerRemoving:Connect(function(p) removeESP(p) end))

    -- Tools
    track(workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Tool") and Hub.Toggles.espTools and Hub.Toggles.espTools.Value then
            task.wait(Config.TOOL_WAIT or 0.1) createToolESP(obj)
        end
    end))

    -- Prompts + instant
    track(workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("ProximityPrompt") then
            if Hub.Toggles.espPrompts and Hub.Toggles.espPrompts.Value then
                task.wait(Config.TOOL_WAIT or 0.1)
                local target = getPromptTarget(obj)
                if target and not isPromptBlacklisted(target) then createPromptESP(obj) end
            end
            if Hub.Toggles.instantPrompt and Hub.Toggles.instantPrompt.Value then
                task.wait(Config.TOOL_WAIT or 0.1) makePromptInstant(obj)
            end
        end
    end))

    -- Monsters
    track(workspace.DescendantAdded:Connect(function(obj)
        if Hub.Toggles.espMonsters and Hub.Toggles.espMonsters.Value and shouldMonster(obj) then
            task.wait(Config.TOOL_WAIT or 0.1) createMonsterESP(obj)
        end
    end))

    -- Doors
    track(workspace.DescendantAdded:Connect(function(obj)
        if obj.Name == "Door" and obj:IsA("Model") and obj.Parent and tonumber(obj.Parent.Name) then
            if Hub.Toggles.DoorsESP and Hub.Toggles.DoorsESP.Value then
                task.wait(Config.TOOL_WAIT or 0.1) createDoorESP(obj)
            end
        end
    end))

    track(RunService.RenderStepped:Connect(updateLoop))

    function ESP.cleanup()
        clearAllESP()
        clearAllToolESP()
        clearAllPromptESP()
        clearAllMonsterESP()
        clearAllDoorESP()
        for p in pairs(savedPrompts) do restorePrompt(p) end
        savedPrompts = {}
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
    end

    print("[ESP] init")
    return ESP
end

return ESP
