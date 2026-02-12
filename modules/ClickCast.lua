-- =========================================================
-- RexHeal modules/ClickCast.lua
-- Combat-safe Mousewheel (kein Zoom im Grid – auch im Kampf)
-- Lösung: SecureHandlerEnterLeaveTemplate + SetBindingClick im Secure Code
-- =========================================================

if not RexHeal then return end
local RH = RexHeal

local function DB()
    local database = RH:DB()
    if database and database.profile then return database.profile end
    return database
end

local overlays = setmetatable({}, { __mode = "k" })
local pending  = setmetatable({}, { __mode = "k" })

local function InCombat() return InCombatLockdown() end

-- ---------------------------------------------------------
-- Overlay: Secure Button + Secure Enter/Leave Bindings
-- ---------------------------------------------------------
local function EnsureOverlay(frame)
    if overlays[frame] then return overlays[frame] end
    if InCombat() then pending[frame] = true return nil end

    local name = (frame:GetName() or ("RH_Ovr" .. tostring(GetTime() * 1000))) .. "_Overlay"

    -- WICHTIG: SecureHandlerEnterLeaveTemplate macht Enter/Leave combat-safe
    local btn = CreateFrame("Button", name, frame,
        "SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate")
    btn:SetAllPoints(frame)
    btn:SetFrameLevel(frame:GetFrameLevel() + 50)
    btn:EnableMouse(true)
    btn:RegisterForClicks("AnyDown")
    btn:EnableMouseWheel(true)

    -- Secure Enter: Wheel nur während Mouseover auf diesen Button umbiegen
    btn:SetAttribute("_onenter", [[
        self:ClearBindings()

        -- Nur setzen, wenn wirklich Wheel-Actions existieren
        if self:GetAttribute("type-wheelup") then
            self:SetBindingClick(true, "MOUSEWHEELUP", self, "wheelup")
        end
        if self:GetAttribute("type-wheeldown") then
            self:SetBindingClick(true, "MOUSEWHEELDOWN", self, "wheeldown")
        end
    ]])

    -- Secure Leave: Bindings wieder freigeben (dann greift normaler Zoom)
    btn:SetAttribute("_onleave", [[
        self:ClearBindings()
    ]])

    overlays[frame] = btn
    return btn
end

-- ---------------------------------------------------------
-- ClickCast: Attributes setzen (out of combat)
-- ---------------------------------------------------------
local function ApplyToButton(btn, unit)
    if not btn or InCombat() then return end

    local db = DB()
    local binds = (db.clickcast and db.clickcast.bindings) or {}
    local tOnHeal = (db.general and db.general.targetOnHeal)

    btn:SetAttribute("unit", unit)

    -- 1) Normale Klicks 1..16 (type1/type2/... -> macro)
    for i = 1, 16 do
        local spell = binds[i]
        if spell and spell ~= "" then
            btn:SetAttribute("type" .. i, "macro")
            local macro =
                (tOnHeal and "/target [@mouseover,exists,nodead]\n" or "") ..
                "/cast [@mouseover,exists,nodead] " .. spell
            btn:SetAttribute("macrotext" .. i, macro)
        else
            btn:SetAttribute("type" .. i, "target")
            btn:SetAttribute("macrotext" .. i, nil)
        end
    end

-- 2) WheelUp/WheelDown (eigene Felder, KEIN Fallback auf Button1)
local cc = (db.clickcast or {})
local wUp   = cc.WheelUp
local wDown = cc.WheelDown

-- optional: falls du doch mal alte DBs hast, die Wheel in bindings gespeichert haben:
if (not wUp or wUp == "") and type(binds["WheelUp"]) == "string" then
    wUp = binds["WheelUp"]
end
if (not wDown or wDown == "") and type(binds["WheelDown"]) == "string" then
    wDown = binds["WheelDown"]
end

if wUp and wUp ~= "" then
    btn:SetAttribute("type-wheelup", "macro")
    local mUp =
        (tOnHeal and "/target [@mouseover,exists,nodead]\n" or "") ..
        "/cast [@mouseover,exists,nodead] " .. wUp
    btn:SetAttribute("macrotext-wheelup", mUp)
else
    btn:SetAttribute("type-wheelup", nil)
    btn:SetAttribute("macrotext-wheelup", nil)
end

if wDown and wDown ~= "" then
    btn:SetAttribute("type-wheeldown", "macro")
    local mDown =
        (tOnHeal and "/target [@mouseover,exists,nodead]\n" or "") ..
        "/cast [@mouseover,exists,nodead] " .. wDown
    btn:SetAttribute("macrotext-wheeldown", mDown)
else
    btn:SetAttribute("type-wheeldown", nil)
    btn:SetAttribute("macrotext-wheeldown", nil)
end

end

-- ---------------------------------------------------------
-- Public API
-- ---------------------------------------------------------
function RH:ApplyClickCast(frame)
    if not frame then return end
    local btn = EnsureOverlay(frame)
    if not btn then return end
    local unit = frame.unit or frame:GetAttribute("unit")
    ApplyToButton(btn, unit)
end

function RH:RefreshAllClickCast()
    if InCombat() then return end
    for frame, btn in pairs(overlays) do
        local unit = frame.unit or frame:GetAttribute("unit")
        ApplyToButton(btn, unit)
    end
end

-- ---------------------------------------------------------
-- Pending overlays nach Combat anlegen
-- ---------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
    for frame in pairs(pending) do
        pending[frame] = nil
        RH:ApplyClickCast(frame)
    end
end)
