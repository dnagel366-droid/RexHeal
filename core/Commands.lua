-- =========================================================
-- RexHeal core/Commands.lua
-- - Slash Commands: /rh und /rex (Alias)
-- - Subcommands: config, lock, unlock, reset, help
-- - Fix: Config öffnet beim ersten Aufruf
-- =========================================================

if not RexHeal then return end
local RH = RexHeal

-- ---------------------------------------------------------
-- Chat Print
-- ---------------------------------------------------------
local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99RexHeal|r: " .. tostring(msg))
    end
end

-- ---------------------------------------------------------
-- String Helpers
-- ---------------------------------------------------------
local function Trim(s)
    s = tostring(s or "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

local function SplitFirstWord(input)
    input = Trim(input)
    if input == "" then return "", "" end
    local cmd, rest = input:match("^(%S+)%s*(.*)$")
    return (cmd or ""):lower(), (rest or "")
end

-- ---------------------------------------------------------
-- Config Frame Finder (für 1x-Open Fix)
-- ---------------------------------------------------------
local function GetConfigFrame()
    if RH and type(RH.GetConfigFrame) == "function" then
        local ok, f = pcall(RH.GetConfigFrame, RH)
        if ok and f then return f end
    end

    if RH and RH._configFrame then return RH._configFrame end
    if _G.RexHealConfig then return _G.RexHealConfig end
    if _G.RexHealConfigFrame then return _G.RexHealConfigFrame end
    if _G.RexHeal_ConfigFrame then return _G.RexHeal_ConfigFrame end

    return nil
end

-- ---------------------------------------------------------
-- Help
-- ---------------------------------------------------------
local function ShowHelp()
    Print("Befehle:")
    Print("  |cffffffff/rh|r oder |cffffffff/rex|r  → Config öffnen/schließen")
    Print("  |cffffffff/rh lock|r                  → Frames sperren")
    Print("  |cffffffff/rh unlock|r                → Frames entsperren")
    Print("  |cffffffff/rh reset|r                 → Positionen zurücksetzen")
    Print("  |cffffffff/rh wheelreset|r            → Mousewheel Override reset")
    Print("  |cffffffff/rh help|r                  → Hilfe anzeigen")
end

-- ---------------------------------------------------------
-- SafeCall Wrapper
-- ---------------------------------------------------------
local function SafeCall(fnName)
    local fn = RH and RH[fnName]
    if type(fn) == "function" then
        local ok, err = pcall(fn, RH)
        if not ok then
            Print("Fehler in " .. fnName .. ": " .. tostring(err))
        end
        return true
    end
    return false
end

-- ---------------------------------------------------------
-- Toggle Config (FIXED → öffnet beim ersten Mal)
-- ---------------------------------------------------------
local function ToggleConfig()
    -- Erst normales Toggle versuchen
    if not SafeCall("ToggleConfig") then
        Print("ToggleConfig() fehlt. (Config-Modul nicht geladen?)")
        return
    end

    -- Falls beim ersten Aufruf nur erstellt wurde → SHOW erzwingen
    local f = GetConfigFrame()
    if f and f.Show and not f:IsShown() then
        f:Show()
    end
end

-- ---------------------------------------------------------
-- Lock / Unlock / Reset
-- ---------------------------------------------------------
local function Lock()
    if not SafeCall("LockFrames") then
        SafeCall("Lock")
    end
end

local function Unlock()
    if not SafeCall("UnlockFrames") then
        SafeCall("Unlock")
    end
end

local function Reset()
    if not SafeCall("ResetPositions") then
        SafeCall("Reset")
    end
end

-- ---------------------------------------------------------
-- Slash Handler
-- ---------------------------------------------------------
local function HandleSlash(input)
    local cmd = ""
    cmd, _ = SplitFirstWord(input)

    if cmd == "" or cmd == "config" then
        ToggleConfig()
        return
    end

    if cmd == "lock" then
        Lock()
        return
    end

    if cmd == "unlock" then
        Unlock()
        return
    end

    if cmd == "reset" then
        Reset()
        return
    end

    if cmd == "wheelreset" then
        if RH and RH._wheelOwner then
            ClearOverrideBindings(RH._wheelOwner)
            RH._wheelOwner = nil
        end
        Print("Wheel Override zurückgesetzt.")
        return
    end

    if cmd == "help" or cmd == "?" then
        ShowHelp()
        return
    end

    Print("Unbekannter Befehl: |cffffffff" .. cmd .. "|r")
    ShowHelp()
end

-- ---------------------------------------------------------
-- Init Slash Commands
-- ---------------------------------------------------------
function RH:InitSlashCommands()
    SLASH_REXHEAL1 = "/rh"
    SlashCmdList["REXHEAL"] = HandleSlash

    SLASH_REXHEALALIAS1 = "/rex"
    SlashCmdList["REXHEALALIAS"] = HandleSlash

    Print("Slash Commands aktiv: /rh und /rex")
end
