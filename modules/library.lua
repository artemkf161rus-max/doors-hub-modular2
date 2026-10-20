-- ============================================================
--  LIBRARY CODE | Obsidian
-- ============================================================
local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local Library = {}

local Hub, Group

local function getLibraryCode()
    local char = player.Character
    if not char then return "_____" end
    local paper = char:FindFirstChild("LibraryHintPaper")
        or char:FindFirstChild("LibraryHintPaperHard")
        or (player.Backpack and player.Backpack:FindFirstChild("LibraryHintPaper"))
        or (player.Backpack and player.Backpack:FindFirstChild("LibraryHintPaperHard"))
    if not paper or not paper:FindFirstChild("UI") then return "_____" end

    local code = { "_", "_", "_", "_", "_" }
    local playerGui = player:FindFirstChild("PlayerGui")
    local permUI = playerGui and playerGui:FindFirstChild("PermUI")
    local hints  = permUI and permUI:FindFirstChild("Hints")
    if hints then
        for _, hint in ipairs(hints:GetChildren()) do
            for _, uiChild in ipairs(paper.UI:GetChildren()) do
                if hint:IsA("ImageLabel") and uiChild:IsA("ImageLabel")
                    and hint.ImageRectOffset == uiChild.ImageRectOffset
                    and code[tonumber(uiChild.Name)] then
                    code[tonumber(uiChild.Name)] = hint.TextLabel.Text
                end
            end
        end
    end
    return table.concat(code)
end

local function buildUI()
    Group = Hub.Groupboxes.Main_Library

    Group:AddButton({
        Text = "Show Library Code",
        Func = function()
            local code = getLibraryCode()
            print("[LIBRARY CODE]", code)
            Hub.Notify({ Title = "Library Code", Description = code, Time = 5 })
        end,
    })
end

function Library.init(hub)
    Hub = hub
    buildUI()
    function Library.cleanup() end
    print("[LIBRARY] init")
    return Library
end

return Library
