-- =========================================================
-- RexHeal core/Core.lua
-- - Event Bootstrap
-- - Modul-Ladegerüst
-- =========================================================

RexHeal = RexHeal or {}
local RH = RexHeal

local function DB()
    return RH:DB()
end

-- ---------------------------------------------------------
-- Minimales Addon-Frame
-- ---------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

RH._eventFrame = f
RH._inCombat = InCombatLockdown() or false

-- ---------------------------------------------------------
-- Modul-Gerüst (später: sichere Reihenfolge + ApplyAll)
-- ---------------------------------------------------------
function RH:CallModule(fnName, ...)
    local fn = _G[fnName]
    if type(fn) == "function" then
        local ok, err = pcall(fn, ...)
        if not ok then
            print("|cffff4444RexHeal Fehler:|r", fnName, err)
        end
    end
end

function RH:OnAddonLoaded(addonName)
    if addonName ~= "RexHeal" then return end

    -- DB init
    RH:GetDB()

    -- Slash Commands init (/rh + /rex alias)
    if RH.InitSlashCommands then RH:InitSlashCommands() end

    print("|cff33ff99RexHeal|r geladen. Tippe |cffffffff/rh|r oder |cffffffff/rex|r")
end

function RH:OnPlayerLogin()
    -- Grid init
    if _G.RexHeal_InitGrid then
        local ok, err = pcall(_G.RexHeal_InitGrid)
        if not ok then
            print("|cffff4444RexHeal Fehler:|r InitGrid", err)
        end
    end

    -- Minimap Button init
    if RH.InitMinimapButton then
        RH:InitMinimapButton()
    end
end

-- ---------------------------------------------------------
-- Event Handler
-- ---------------------------------------------------------
f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        RH:OnAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        RH:OnPlayerLogin()
    elseif event == "PLAYER_REGEN_DISABLED" then
        RH._inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        RH._inCombat = false
    end
end)
