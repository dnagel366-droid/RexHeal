-- =========================================================
-- RexHeal core/Core.lua
-- - Event Bootstrap
-- - Slash Command /rex
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
-- Slash Command /rex
-- ---------------------------------------------------------
local function RegisterSlash()
    SLASH_REXHEAL1 = "/rex"
    SLASH_REXHEAL2 = "/rexheal"
    SlashCmdList["REXHEAL"] = function(msg)
        msg = (msg and msg:lower()) or ""

        if msg == "reset" then
            RH:ResetProfile()
            print("|cff33ff99RexHeal|r: Profil wurde zurückgesetzt.")
            return
        end

        -- PANIC FIX: Wheel Override manuell zurücksetzen
        if msg == "wheelreset" then
            if RH and RH._wheelOwner then
                ClearOverrideBindings(RH._wheelOwner)
                RH._wheelOwner = nil
            end
            print("|cff33ff99RexHeal|r: Wheel Override zurückgesetzt.")
            return
        end

        -- Standard: Config öffnen
        if RH.ToggleConfig then
            RH:ToggleConfig()
        else
            print("|cffff4444RexHeal|r: Config nicht geladen (config/Config.lua).")
        end
    end
end

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

    RegisterSlash()

    print("|cff33ff99RexHeal|r geladen. Tippe |cffffffff/rex|r")
end

function RH:OnPlayerLogin()
    -- Grid init (über Frames.lua Hook)
    if _G.RexHeal_InitGrid then
        local ok, err = pcall(_G.RexHeal_InitGrid)
        if not ok then
            print("|cffff4444RexHeal Fehler:|r InitGrid", err)
        end
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
