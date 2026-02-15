-- =========================================================
-- RexHeal modules/BlizzardFrames.lua
-- Blizzard Party/Raid Frames Toggle (ElvUI-Style)
-- - DB: db.general.hideBlizzardFrames (true = ausblenden)
-- - Combat-safe: im Kampf nur Alpha/Mouse, OOC echtes Show/Hide
-- =========================================================

if not RexHeal then return end
local RH = RexHeal

local function DB()
    local d = RH:DB()
    if d and d.profile then return d.profile end
    return d
end

local function InCombat() return InCombatLockdown() end

-- Merken was wir geändert haben
local managed = {}  -- [frame] = {wasShown=?, alpha=?}
local pendingApply = false

-- ---------------------------------------------------------
-- Safe Apply: Hide/Show ohne Combat-Taint
-- ---------------------------------------------------------
local function RememberFrameState(frame)
    if not frame or managed[frame] then return end
    managed[frame] = {
        wasShown = frame:IsShown(),
        alpha = frame:GetAlpha(),
        mouse = frame:IsMouseEnabled(),
    }
end

local function SafeSetHidden(frame, hide)
    if not frame then return end
    RememberFrameState(frame)

    if InCombat() then
        -- Im Kampf: KEIN Show/Hide
        frame:SetAlpha(hide and 0 or (managed[frame] and managed[frame].alpha) or 1)
        if frame.EnableMouse then frame:EnableMouse(not hide) end
        pendingApply = true
        return
    end

    -- Out of combat: echtes Show/Hide
    if hide then
        frame:SetAlpha(0)
        if frame.EnableMouse then frame:EnableMouse(false) end
        frame:Hide()
    else
        local st = managed[frame]
        if st then
            frame:SetAlpha(st.alpha or 1)
            if frame.EnableMouse then frame:EnableMouse(st.mouse ~= false) end
            if st.wasShown then frame:Show() else frame:Hide() end
        else
            frame:SetAlpha(1)
            if frame.EnableMouse then frame:EnableMouse(true) end
            frame:Show()
        end
    end
end

-- ---------------------------------------------------------
-- Sammle Blizzard Frames (Party/Raid) möglichst robust
-- ---------------------------------------------------------
local function GetBlizzardFrames()
    local frames = {}

    -- Compact Raid Frames (Retail)
    if _G.CompactRaidFrameManager then
        frames[#frames+1] = _G.CompactRaidFrameManager
    end
    if _G.CompactRaidFrameContainer then
        frames[#frames+1] = _G.CompactRaidFrameContainer
    end

    -- Compact Party Frame (manche UIs)
    if _G.CompactPartyFrame then
        frames[#frames+1] = _G.CompactPartyFrame
    end

    -- PartyFrame (je nach Version/Setup)
    if _G.PartyFrame then
        frames[#frames+1] = _G.PartyFrame
    end

    -- Old compact unit frames
    if _G.CompactUnitFrameProfiles then
        frames[#frames+1] = _G.CompactUnitFrameProfiles
    end

    -- Versuch: einzelne Party Member Frames (falls vorhanden)
    for i = 1, 5 do
        local f = _G["CompactPartyFrameMember" .. i] or _G["PartyMemberFrame" .. i]
        if f then frames[#frames+1] = f end
    end

    return frames
end

-- ---------------------------------------------------------
-- Apply Toggle
-- ---------------------------------------------------------
function RH:ApplyBlizzardFrameToggle()
    local db = DB()
    db.general = db.general or {}
    if db.general.hideBlizzardFrames == nil then db.general.hideBlizzardFrames = true end

    local hide = (db.general.hideBlizzardFrames == true)
    local list = GetBlizzardFrames()

    -- Wenn Blizzard CompactRaidFrames Addon noch nicht geladen ist:
    -- Nicht erzwingen, aber wenn es später lädt, greifen unsere Events.
    for _, frame in ipairs(list) do
        SafeSetHidden(frame, hide)
    end
end

-- Optional: externe Calls
function RH:HideBlizzardFrames()
    local db = DB()
    db.general = db.general or {}
    db.general.hideBlizzardFrames = true
    self:ApplyBlizzardFrameToggle()
end

function RH:ShowBlizzardFrames()
    local db = DB()
    db.general = db.general or {}
    db.general.hideBlizzardFrames = false
    self:ApplyBlizzardFrameToggle()
end

-- ---------------------------------------------------------
-- Event Bootstrap
-- ---------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("ADDON_LOADED")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then
            pendingApply = false
            if RH and RH.ApplyBlizzardFrameToggle then
                pcall(function() RH:ApplyBlizzardFrameToggle() end)
            end
        end
        return
    end

    -- Wenn CompactRaidFrames Addon später reinlädt
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_CompactRaidFrames" or arg1 == "Blizzard_EditMode" then
            if RH and RH.ApplyBlizzardFrameToggle then
                pcall(function() RH:ApplyBlizzardFrameToggle() end)
            end
        end
        return
    end

    if RH and RH.ApplyBlizzardFrameToggle then
        pcall(function() RH:ApplyBlizzardFrameToggle() end)
    end
end)

-- Kleine Verzögerung nach Login (UI baut sich manchmal erst)
C_Timer.After(0.25, function()
    if RH and RH.ApplyBlizzardFrameToggle then
        pcall(function() RH:ApplyBlizzardFrameToggle() end)
    end
end)
