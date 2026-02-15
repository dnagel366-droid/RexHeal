-- =========================================================
-- RexHeal modules/Minimap.lua
-- - Minimap Button (ohne Libs)
-- - FREE DRAG (Quadrat / frei verschiebbar wie Details/BigWigs)
-- - LeftClick: Config Toggle
-- - Tooltip
-- - Position speichern (point/x/y)
-- - Icon: RexUILogo.tga
-- =========================================================

if not RexHeal then return end
local RH = RexHeal

-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------
local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99RexHeal|r: " .. tostring(msg))
    end
end

local function GetProfile()
    local db = RH.GetDB and RH:GetDB()
    if db and db.profile then return db.profile end
    return db
end

local function EnsureCfg()
    local p = GetProfile()
    if not p then return nil end

    p.minimapButton = p.minimapButton or {}

    -- Default Position (oben rechts neben Minimap-ish)
    if p.minimapButton.point == nil then p.minimapButton.point = "TOPRIGHT" end
    if p.minimapButton.x == nil then p.minimapButton.x = -30 end
    if p.minimapButton.y == nil then p.minimapButton.y = -80 end
    if p.minimapButton.hide == nil then p.minimapButton.hide = false end

    return p.minimapButton
end

local function ApplyPosition(btn)
    local cfg = EnsureCfg()
    if not cfg then return end

    btn:ClearAllPoints()
    btn:SetPoint(cfg.point or "TOPRIGHT", UIParent, cfg.point or "TOPRIGHT", cfg.x or 0, cfg.y or 0)
end

local function SavePosition(btn)
    local cfg = EnsureCfg()
    if not cfg then return end

    -- Wir speichern relativ zu UIParent (stabil)
    local point, _, _, x, y = btn:GetPoint(1)
    cfg.point = point or "CENTER"
    cfg.x = x or 0
    cfg.y = y or 0
end

-- ---------------------------------------------------------
-- Reliable Config Open
-- ---------------------------------------------------------
local function OpenConfigReliable()
    if type(RH.ToggleConfig) == "function" then
        pcall(RH.ToggleConfig, RH)

        -- Falls Toggle beim 1. Mal nur erstellt → Show erzwingen
        if RH._configFrame and not RH._configFrame:IsShown() then
            RH._configFrame:Show()
        end
        return
    end

    Print("Config nicht geladen.")
end

-- ---------------------------------------------------------
-- Create Minimap Button
-- ---------------------------------------------------------
function RH:CreateMinimapButton()
    if RH._minimapButton and RH._minimapButton:IsObjectType("Button") then
        return RH._minimapButton
    end

    local cfg = EnsureCfg()
    if not cfg then
        Print("MinimapButton: DB nicht bereit.")
        return nil
    end

    local btn = CreateFrame("Button", "RexHeal_MinimapButton", UIParent)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(50)
    btn:RegisterForClicks("LeftButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:EnableMouse(true)

    btn:SetClampedToScreen(true)

    -- Icon (DEIN LOGO)
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(btn)
    icon:SetTexture("Interface\\AddOns\\RexHeal\\RexUILogo.tga")
    btn._icon = icon

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("RexHeal", 0.2, 1, 0.6)
        GameTooltip:AddLine("Linksklick: RexHeal öffnen", 1, 1, 1)
        GameTooltip:AddLine("Ziehen: Position ändern", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Click
    btn:SetScript("OnClick", function()
        OpenConfigReliable()
    end)

    -- Drag (FREE MOVE)
    btn:SetMovable(true)
    btn:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    RH._minimapButton = btn

    -- Initial State + Position
    if cfg.hide then
        btn:Hide()
    else
        btn:Show()
        ApplyPosition(btn)
    end

    return btn
end

function RH:UpdateMinimapButton()
    local btn = RH._minimapButton
    local cfg = EnsureCfg()
    if not btn or not cfg then return end

    if cfg.hide then
        btn:Hide()
    else
        btn:Show()
        ApplyPosition(btn)
    end
end

function RH:InitMinimapButton()
    RH:CreateMinimapButton()
    RH:UpdateMinimapButton()
end
