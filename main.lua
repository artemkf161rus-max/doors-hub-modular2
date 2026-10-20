-- ============================================================
--  DOORS HUB | main.lua (loader)
--  Obsidian UI | модульная архитектура
-- ============================================================

local env = (getgenv and getgenv()) or _G
if env.HubUnload then
    pcall(env.HubUnload)
    env.HubUnload = nil
end

-- ============================================================
--  CONFIG
-- ============================================================
local REPO_BASE     = "https://raw.githubusercontent.com/artemkf161rus-max/doors-hub-modular2/main/"
local OBSIDIAN_BASE = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local MODULES = {
    "modules/movement.lua",
    "modules/misc.lua",
    "modules/library.lua",
    "modules/jump.lua",
    "modules/esp.lua",
    "modules/bypass.lua",
    "modules/antiafk.lua",
}

-- ============================================================
--  LOGGER
-- ============================================================
local function log(...)  print("[Hub]", ...) end
local function warn_(...) warn("[Hub]", ...) end

-- ============================================================
--  LOAD HELPERS
-- ============================================================
local function fetch(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if not ok or type(res) ~= "string" or #res == 0 then
        warn_("fetch failed:", url, tostring(res))
        return nil
    end
    return res
end

local function loadChunk(url)
    local src = fetch(url)
    if not src then return nil end
    local fn, err = loadstring(src)
    if not fn then
        warn_("loadstring failed:", url, tostring(err))
        return nil
    end
    local ok, res = pcall(fn)
    if not ok then
        warn_("chunk error:", url, tostring(res))
        return nil
    end
    return res
end

-- ============================================================
--  LOAD OBSIDIAN
-- ============================================================
log("loading Obsidian...")

local Library      = loadChunk(OBSIDIAN_BASE .. "Library.lua")
local SaveManager  = loadChunk(OBSIDIAN_BASE .. "addons/SaveManager.lua")
local ThemeManager = loadChunk(OBSIDIAN_BASE .. "addons/ThemeManager.lua")

if not Library then
    warn_("Library missing, abort")
    return
end

local Options = Library.Options
local Toggles = Library.Toggles

log("Obsidian loaded")

-- ============================================================
--  CREATE WINDOW
-- ============================================================
local Window = Library:CreateWindow({
    Title            = "Doors Hub",
    Footer           = "v1.0",
    NotifySide       = "Right",
    ShowCustomCursor = false,
    Center           = true,
    AutoShow         = true,
    Resizable        = false,
    ToggleKeybind    = Enum.KeyCode.RightShift,
})

task.defer(function()
    pcall(function() Window:Show() end)
end)

-- ============================================================
--  TABS
-- ============================================================
local Tabs = {
    Main     = Window:AddTab("Main",     "house"),
    Visuals  = Window:AddTab("Visuals",  "eye"),
    Exploits = Window:AddTab("Exploits", "shield"),
    Settings = Window:AddTab("Settings", "settings"),
}

-- ============================================================
--  GROUPBOXES
-- ============================================================
local Groupboxes = {
    Main_Movement = Tabs.Main:AddLeftGroupbox("Movement"),
    Main_Misc     = Tabs.Main:AddRightGroupbox("Misc"),
    Main_Library  = Tabs.Main:AddRightGroupbox("Library"),

    Visuals_ESP   = Tabs.Visuals:AddLeftGroupbox("ESP"),
    Visuals_World = Tabs.Visuals:AddRightGroupbox("World"),
    Visuals_Paths = Tabs.Visuals:AddRightGroupbox("Paths"),

    Exploits_Bypass = Tabs.Exploits:AddLeftGroupbox("Bypass"),
    Exploits_Util   = Tabs.Exploits:AddRightGroupbox("Utility"),
}

-- ============================================================
--  HUB OBJECT
-- ============================================================
local Hub = {
    Library      = Library,
    SaveManager  = SaveManager,
    ThemeManager = ThemeManager,
    Window       = Window,
    Tabs         = Tabs,
    Groupboxes   = Groupboxes,
    Options      = Options,
    Toggles      = Toggles,
    Objects      = {
        FakePrompts     = {},
        PromptContainer = nil,
    },
    Modules      = {},
    Config       = {
        -- Movement
        MIN_SPEED          = 16,
        MAX_SPEED          = 150,
        REAL_SPEED_DEFAULT = 16,
        FAKE_SPEED         = 15,

        -- FOV
        FOV_MIN     = 1,
        FOV_MAX     = 120,
        FOV_DEFAULT = 70,

        -- ESP
        ESP_RADIUS     = 500,
        TOOL_WAIT      = 0.1,
        DOOR_COLOR     = Color3.fromRGB(0, 255, 0),
        LEVER_COLOR    = Color3.fromRGB(255, 170, 0),
        TOOL_COLOR     = Color3.fromRGB(255, 255, 255),
        PROMPT_COLOR   = Color3.fromRGB(0, 200, 255),
        KEY_COLOR      = Color3.fromRGB(0, 255, 255),

        PROMPT_BLACKLIST = {
            Wardrobe = true, ["Backdoor_Wardrobe"] = true, Toolshed = true,
            RetroWardrobe = true, ["Wardrobe-FOOLS26"] = true,
            Double_Bed = true, DoubleBed = true, Bed = true,
            Locker_Large = true, Rooms_Locker = true, Rooms_Locker_Fridge = true,
            CircularVent = true, Dumpster = true,
            HidePrompt = true, RiftPrompt = true, InteractPrompt = true,
            ClimbPrompt = true, DonatePrompt = true, DialoguePrompt = true,
            RevivePrompt = true, EnterPrompt = true, AnimatePrompt = true,
            ToolEventPrompt = true, Prompt = true, PropPrompt = true,
        },

        PROMPT_BLUELIST = {
            Key = true, KeyObtain = true, KeyBackdoor = true,
            KeyElectrical = true, KeyIron = true, GeneratorFuse = true,
            FuseObtain = true, SkeletonKey = true, Lockpick = true,
        },

        MONSTER_PREFIXES = {
            "rush", "ambush", "eyes", "halt", "blitz", "lookman", "screech",
            "gloombat", "a-60", "a-120", "sally", "jeff", "groundskeeper",
            "monument", "ar0xmbush", "rniushcg", "dupe", "figure",
            "snare", "giggle", "grumble", "dread", "surge", "timothy",
            "void", "glitch", "seek", "shadow", "custom",
        },

        MONSTER_BLACKLIST = {
            "wardrobe", "door", "key", "lock", "ladder", "item",
            "shelf", "table", "chair", "plant",
        },
    },
}

Hub.Notify = function(data)
    pcall(function()
        Library:Notify({
            Title       = data.Title or "Doors Hub",
            Description = data.Description or "",
            Time        = data.Time or 5,
        })
    end)
end

-- ============================================================
--  LOAD MODULES
-- ============================================================
local loaded = {}

local function loadModule(name, path)
    local mod = loadChunk(REPO_BASE .. path)
    if not mod or type(mod) ~= "table" or not mod.init then
        warn_("module failed:", name, path)
        return nil
    end
    local ok, result = pcall(mod.init, Hub)
    if not ok then
        warn_("init failed:", name, tostring(result))
        return nil
    end
    Hub.Modules[name] = result
    table.insert(loaded, name)
    log("loaded:", name)
    return result
end

for _, path in ipairs(MODULES) do
    local name = path:match("([^/]+)%.lua$") or path
    loadModule(name, path)
    task.wait()
end

log("modules:", #loaded .. "/" .. #MODULES)

-- ============================================================
--  SETTINGS TAB
-- ============================================================
pcall(function()
    local SG = Tabs.Settings:AddLeftGroupbox("Menu")

    SG:AddButton({
        Text = "Unload",
        Tooltip = "Выгрузить хаб и отключить все функции",
        Func = function()
            if env.HubUnload then
                env.HubUnload()
            else
                Library:Unload()
            end
        end,
    })

    SG:AddLabel("Menu Key"):AddKeyPicker("MenuKeybind", {
        Default = "RightShift",
        NoUI = true,
        Text = "Открыть/закрыть меню",
    })
    Library.ToggleKeybind = Options.MenuKeybind

    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    ThemeManager:SetFolder("DoorsHub")
    SaveManager:SetFolder("DoorsHub/configs")
    SaveManager:BuildConfigSection(Tabs.Settings)
    ThemeManager:ApplyToTab(Tabs.Settings)
    SaveManager:LoadAutoloadConfig()
end)

-- ============================================================
--  UNLOAD
-- ============================================================
local function cleanup()
    for name, mod in pairs(Hub.Modules) do
        if type(mod) == "table" and type(mod.cleanup) == "function" then
            pcall(mod.cleanup)
            log("cleaned:", name)
        end
    end
    Hub.Modules = {}
    if env.HubUnload then env.HubUnload = nil end
end

Library:OnUnload(cleanup)
env.HubUnload = function() Library:Unload() end

-- ============================================================
--  READY
-- ============================================================
Hub.Notify({
    Title = "Doors Hub",
    Description = "Loaded " .. #loaded .. " modules. RightShift — открыть.",
    Time = 5,
})

log("ready")

return Hub
