-- =========================================================
-- RexHeal modules/Frames.lua
-- VuhDo-Style: 8 getrennte Gruppenfenster (dragbar)
-- MVP Features:
-- 1) Fenster-Position pro Gruppe speichern
-- 2) Gruppen 1..8 einstellbar (raidShowGroups)
-- 3) Aggro-Rahmen rot
-- 4) Dispel Hinweis (Modern API Fix)  ✅ über modules/Dispel.lua (secret-safe)
-- 5) ClickCast Hook (Target + Heal + Party Support)
-- 6) Anzeige-Flags (HP% / Klassenfarben / Mana / Rollenicon)
-- 7) Target-Highlight (Gelber 2px Overlay-Rahmen)
-- + Solo Anzeige optional (showWhenSolo) ✅ Reload/Login FIX
-- + Combat Lockdown Fix ✅ (kein Show/Hide/SetAttribute im Kampf)
-- =========================================================

if not RexHeal then return end
local RH = RexHeal

-- ---------------------------------------------------------
-- DB-shape safe
-- ---------------------------------------------------------
local function DB()
    local d = RH:DB()
    if d and d.profile then return d.profile end
    return d
end

local function InCombat() return InCombatLockdown() end

-- =========================================================
-- Combat-safe Visible Handling (für Secure Buttons!)
-- - Im Kampf: KEIN Show/Hide -> nur Alpha
-- - Out of Combat: Show/Hide normal
-- =========================================================
local function SafeSetVisible(frame, visible)
    if not frame then return end

    if InCombat() then
        frame:SetAlpha(visible and 1 or 0)
        frame._rhWantedVisible = visible and true or false
        return
    end

    frame._rhWantedVisible = nil
    frame:SetAlpha(visible and 1 or 0)
    if visible then frame:Show() else frame:Hide() end
end

local function ApplyWantedVisibilityAfterCombat()
    if not RH._groupWindows then return end

    for g = 1, 8 do
        local gw = RH._groupWindows[g]
        if gw and gw.slots then
            for s = 1, 5 do
                local f = gw.slots[s]
                if f and f._rhWantedVisible ~= nil then
                    local v = f._rhWantedVisible
                    f._rhWantedVisible = nil
                    SafeSetVisible(f, v)
                end
            end
        end
    end
end

-- =========================================================
-- ClickCast Clean-Up
-- =========================================================
local function ClearClickCastAttributes(frame)
    frame:SetAttribute("type1", nil)
    frame:SetAttribute("type2", nil)
    frame:SetAttribute("unit1", nil)
    frame:SetAttribute("unit2", nil)

    local modifiers = { "shift-", "ctrl-", "alt-", "shift-ctrl-", "shift-alt-", "ctrl-alt-", "shift-ctrl-alt-" }
    for _, mod in ipairs(modifiers) do
        frame:SetAttribute(mod .. "type1", nil)
        frame:SetAttribute(mod .. "type2", nil)
        frame:SetAttribute(mod .. "spell1", nil)
        frame:SetAttribute(mod .. "spell2", nil)
    end

    frame:SetAttribute("type-WheelUp", nil)
    frame:SetAttribute("spell-WheelUp", nil)
    frame:SetAttribute("type-WheelDown", nil)
    frame:SetAttribute("spell-WheelDown", nil)
end

-- =========================================================
-- Safe Health Percent (secret/arithmetik-safe)
-- =========================================================
local function GetSafeHealthPercent(unit)
    if not unit or not UnitExists(unit) then return nil end

    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        local pct = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
        if type(pct) == "number" then return pct end
    end

    local ok, val = pcall(function()
        local cur = UnitHealth(unit)
        local max = UnitHealthMax(unit)

        if IsSecretValue and (IsSecretValue(cur) or IsSecretValue(max)) then
            return nil
        end

        cur = tonumber(cur)
        max = tonumber(max)
        if cur and max and max > 0 then
            return math.floor((cur / max) * 100 + 0.5)
        end
        return nil
    end)

    if ok then return val end
    return nil
end

-- =========================================================
-- Helpers: Aggro / Role / Mana
-- =========================================================
local function ApplyAggroBorder(f, unit)
    local threat = UnitThreatSituation(unit)
    if threat and threat >= 2 then
        f:SetBackdropBorderColor(1, 0.2, 0.2, 1)
    else
        f:SetBackdropBorderColor(0.26, 0.28, 0.31, 1)
    end
end

local function SetRoleIcon(f, role)
    if not f.roleIcon then return end

    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
        f.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        if role == "TANK" then
            f.roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64)
        elseif role == "HEALER" then
            f.roleIcon:SetTexCoord(20/64, 39/64, 1/64, 20/64)
        elseif role == "DAMAGER" then
            f.roleIcon:SetTexCoord(20/64, 39/64, 22/64, 41/64)
        end
        f.roleIcon:Show()
    else
        f.roleIcon:Hide()
    end
end

local function GetManaPercent(unit)
    if not unit or not UnitExists(unit) then return nil end
    local cur = UnitPower(unit, 0)
    local max = UnitPowerMax(unit, 0)

    if IsSecretValue and (IsSecretValue(cur) or IsSecretValue(max)) then return nil end

    cur = tonumber(cur)
    max = tonumber(max)
    if cur and max and max > 0 then
        return math.floor((cur / max) * 100 + 0.5)
    end
    return nil
end

-- =========================================================
-- Update Slot (VISUAL ONLY + COMBAT SAFE)
-- =========================================================
local function UpdateOne(f)
    local unit = f.unit
    if not unit then
        SafeSetVisible(f, false)
        return
    end

    if not UnitExists(unit) then
        if unit == "player" then
            SafeSetVisible(f, true)
            if not f._rhRetry then
                f._rhRetry = true
                C_Timer.After(0.10, function()
                    if f and f.unit == "player" then
                        f._rhRetry = nil
                        UpdateOne(f)
                    end
                end)
            end
            return
        end

        SafeSetVisible(f, false)
        return
    end

    SafeSetVisible(f, true)

    local pdb = DB()
    local gdb = (pdb and pdb.grid) or {}

    local showHP      = (gdb.showHPPercent ~= false)
    local classColors = (gdb.classColors   ~= false)
    local showMana    = (gdb.showMana      == true)
    local showRole    = (gdb.showRoleIcon  == true)

    local pct = GetSafeHealthPercent(unit)
    f.hpBar:SetMinMaxValues(0, 100)

    if type(pct) == "number" then
        f.hpBar:SetValue(pct)
        if showHP then
            f.pctText:SetFormattedText("%d%%", pct)
            f.pctText:Show()
        else
            f.pctText:Hide()
        end
    else
        f.hpBar:SetValue(100)
        if showHP then
            f.pctText:SetText("??%")
            f.pctText:Show()
        else
            f.pctText:Hide()
        end
    end

    if classColors then
        local _, class = UnitClass(unit)
        local c = (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or nil
        if c then
            f.hpBar:SetStatusBarColor(c.r, c.g, c.b, 1)
        else
            f.hpBar:SetStatusBarColor(0.1, 0.9, 0.1, 1)
        end
    else
        f.hpBar:SetStatusBarColor(0.1, 0.9, 0.1, 1)
    end

    if f.manaText then
        if showMana then
            local mp = GetManaPercent(unit)
            f.manaText:SetFormattedText("M %d%%", mp or 0)
            f.manaText:Show()
        else
            f.manaText:Hide()
        end
    end

    if f.roleIcon then
        if showRole then
            local role = (UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)) or "NONE"
            SetRoleIcon(f, role)
        else
            f.roleIcon:Hide()
        end
    end

    local isTarget = UnitExists("target") and UnitIsUnit(unit, "target")
    if f.targetBorder then
        if isTarget then f.targetBorder:Show() else f.targetBorder:Hide() end
    end

    if not isTarget then
        ApplyAggroBorder(f, unit)
    else
        f:SetBackdropBorderColor(0.26, 0.28, 0.31, 1)
    end

    -- Dispel Dot (kommt aus modules/Dispel.lua)
    if RH.ApplyDispelDot then
        RH:ApplyDispelDot(f, unit)
    end
end

-- =========================================================
-- Create Slot
-- =========================================================
local function CreateSlot(parent)
    local pdb = DB()
    local db = (pdb and pdb.grid) or {}

    local f = CreateFrame("Button", nil, parent, "SecureUnitButtonTemplate,BackdropTemplate")
    f:SetSize(tonumber(db.width) or 70, tonumber(db.height) or 45)

    f:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.10, 0.11, 0.12, 0.72)
    f:SetBackdropBorderColor(0.26, 0.28, 0.31, 1)

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("TOPLEFT", 2, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(100)
    bar:SetStatusBarColor(0.1, 0.9, 0.1, 1)
    f.hpBar = bar

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.08, 0.09, 0.10, 0.90)
    f.hpBg = bg

    f.pctText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.pctText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    f.pctText:SetTextColor(0.95, 0.96, 0.98, 1)
    f.pctText:SetDrawLayer("OVERLAY", 7)
    bar:SetFrameLevel(f:GetFrameLevel() + 5)

    f.manaText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.manaText:SetPoint("BOTTOM", bar, "BOTTOM", 0, 1)
    f.manaText:SetTextColor(0.80, 0.82, 0.86, 1)
    f.manaText:Hide()

    -- Dispel Dot (wird durch RH:ApplyDispelDot gesetzt) -> AN DIE BAR, damit er sicher oben liegt
    f.dispelDot = bar:CreateTexture(nil, "OVERLAY")
    f.dispelDot:SetSize(12, 12)
    f.dispelDot:SetPoint("TOPLEFT", bar, "TOPLEFT", 4, -4)
    f.dispelDot:Hide()


    f.roleIcon = bar:CreateTexture(nil, "OVERLAY")
    f.roleIcon:SetSize(14, 14)
    f.roleIcon:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -2, -2)
    f.roleIcon:Hide()

    f.targetBorder = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.targetBorder:SetAllPoints(f)
    f.targetBorder:SetFrameLevel(f:GetFrameLevel() + 50)
    f.targetBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    f.targetBorder:SetBackdropBorderColor(1.0, 0.85, 0.25, 1)
    f.targetBorder:Hide()

    ClearClickCastAttributes(f)

    f:SetScript("OnEvent", function(self, event, arg1)
        if arg1 and self.unit and arg1 ~= self.unit then return end
        UpdateOne(self)
    end)

    -- Start unsichtbar (combat-safe)
    f:SetAlpha(0)
    return f
end

-- =========================================================
-- Assign Unit (SECURE)
-- - im Kampf: KEIN SetAttribute, kein RegisterUnitWatch!
-- =========================================================
local function AssignUnit(f, unit)
    if InCombat() then
        f._rhPendingUnit = unit
        RH._pendingGridUpdate = true
        return
    end

    f._rhPendingUnit = nil
    f.unit = unit
    f:SetAttribute("unit", unit)

    if RH.ApplyClickCast then
        RH:ApplyClickCast(f)
    end

    f:UnregisterAllEvents()

    if unit then
        if unit == "player" and not IsInGroup() and not IsInRaid() then
            if UnregisterUnitWatch then UnregisterUnitWatch(f) end
        else
            if RegisterUnitWatch then RegisterUnitWatch(f) end
        end

        f:RegisterUnitEvent("UNIT_HEALTH", unit)
        f:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
        f:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", unit)
        f:RegisterUnitEvent("UNIT_AURA", unit)
        f:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
        f:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
        f:RegisterUnitEvent("UNIT_MAXPOWER", unit)

        UpdateOne(f)
    else
        if UnregisterUnitWatch then UnregisterUnitWatch(f) end
        SafeSetVisible(f, false)
    end
end

-- =========================================================
-- Group Windows
-- =========================================================
local groupWindows = {}

local function SaveGroupPos(g)
    local pdb = DB()
    if not pdb then return end
    pdb.grid = pdb.grid or {}
    local db = pdb.grid

    db.raidGroupPos = db.raidGroupPos or {}
    local win = groupWindows[g] and groupWindows[g].win
    if not win then return end

    local point, _, relPoint, x, y = win:GetPoint()
    db.raidGroupPos[g] = { point = point, relPoint = relPoint, x = x, y = y }
end

local function CreateGroupWindow(g)
    local pdb = DB()
    local db = (pdb and pdb.grid) or {}
    local spacing = tonumber(db.spacing) or 2

    local HEADER_H = 18
    local PAD = 5

    local win = CreateFrame("Frame", "RexHeal_RaidGroup" .. g, UIParent, "BackdropTemplate")
    win:SetClampedToScreen(false)
    win:SetMovable(true)
    win:EnableMouse(false)

    -- Fallback anchor
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    -- Keine Gruppen-Box
    win:SetBackdrop(nil)

    win:SetScript("OnDragStart", function(self)
        local pdb2 = DB()
        if pdb2 and pdb2.general and pdb2.general.lockFrames then return end
        self:StartMoving()
    end)

    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveGroupPos(g)
    end)

    -- Header (sichtbar, damit du Gruppen erkennst)
    win.header = CreateFrame("Frame", nil, win, "BackdropTemplate")
    win.header:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -1)
    win.header:SetPoint("TOPRIGHT", win, "TOPRIGHT", -1, -1)
    win.header:SetHeight(HEADER_H)
    win.header:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    win.header:SetBackdropColor(0.12, 0.13, 0.14, 0.70)
    win.header:SetBackdropBorderColor(0.26, 0.28, 0.31, 1)

    win.header.text = win.header:CreateFontString(nil, "OVERLAY")
    win.header.text:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    win.header.text:SetTextColor(0.90, 0.92, 0.95, 1)
    win.header.text:SetPoint("LEFT", win.header, "LEFT", 6, 0)
    win.header.text:SetText("Gruppe " .. g)

    -- DragBar (nur Header Bereich)
    -- DragBar (größerer Greifbereich zum Verschieben)
    win.dragBar = CreateFrame("Frame", nil, win)
    win.dragBar:SetPoint("TOPLEFT", win, "TOPLEFT", -10, 10)      -- etwas größer als Header
    win.dragBar:SetPoint("TOPRIGHT", win, "TOPRIGHT", 10, 10)
    win.dragBar:SetHeight(HEADER_H + 16)                         -- höherer Greifbereich
    win.dragBar:EnableMouse(true)
    win.dragBar:SetFrameLevel((win.header and win.header:GetFrameLevel() or win:GetFrameLevel()) + 5)


    win.dragBar:SetScript("OnMouseDown", function()
        local pdb2 = DB()
        if pdb2 and pdb2.general and pdb2.general.lockFrames then return end
        win:StartMoving()
    end)

    win.dragBar:SetScript("OnMouseUp", function()
        win:StopMovingOrSizing()
        SaveGroupPos(g)
    end)

    local slots = {}
    for s = 1, 5 do
        slots[s] = CreateSlot(win)
        slots[s]:ClearAllPoints()
        slots[s]:SetPoint("TOPLEFT", win, "TOPLEFT",
            PAD,
            -(PAD + HEADER_H) - (s - 1) * ((tonumber(db.height) or 45) + spacing)
        )
    end

    win:SetSize(
        (tonumber(db.width) or 70) + (PAD * 2),
        (PAD * 2 + HEADER_H) + 5 * (tonumber(db.height) or 45) + 4 * spacing
    )

    return win, slots
end

local function EnsureGroupWindows()
    if groupWindows[1] then return end

    for g = 1, 8 do
        local win, slots = CreateGroupWindow(g)
        groupWindows[g] = { win = win, slots = slots }
    end

    RH._groupWindows = groupWindows
end

local function ApplyGroupPosOrDefault(g)
    EnsureGroupWindows()

    local pdb = DB()
    local db = (pdb and pdb.grid) or {}
    db.raidGroupPos = db.raidGroupPos or {}

    local saved = db.raidGroupPos[g]
    local win = groupWindows[g] and groupWindows[g].win
    if not win then return false end

    if type(saved) == "table" and saved.point and saved.relPoint then
        win:ClearAllPoints()
        win:SetPoint(saved.point, UIParent, saved.relPoint, saved.x or 0, saved.y or 0)
        return true
    end

    return false
end

local function LayoutDefaultPositions()
    EnsureGroupWindows()

    local pdb = DB()
    local db = (pdb and pdb.grid) or {}

    local w = tonumber(db.width) or 70
    local h = tonumber(db.height) or 45

    for g = 1, 8 do
        local col = (g - 1) % 4
        local row = math.floor((g - 1) / 4)

        local win = groupWindows[g].win
        win:ClearAllPoints()
        win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 200 + col * (w + 28), -200 - row * (h * 5 + 30))
        SaveGroupPos(g)
    end
end

-- =========================================================
-- Update Grid (SECURE)
-- =========================================================
function RH:UpdateGrid()
    if InCombat() then
        RH._pendingGridUpdate = true
        return
    end

    EnsureGroupWindows()

    local root = DB()
    if not root then return end
    if root.profile then root = root.profile end

    root.grid = root.grid or {}
    local db = root.grid
    if db.showWhenSolo == nil then db.showWhenSolo = true end

    local scale      = tonumber(db.scale) or 1.0
    local width      = tonumber(db.width) or 70
    local height     = tonumber(db.height) or 45
    local spacing    = tonumber(db.spacing) or 2
    local showGroups = tonumber(db.raidShowGroups) or 8
    local showSolo   = (db.showWhenSolo == true)

    local HEADER_H = 18
    local PAD = 5

    -- Live Apply Layout + pending-unit apply
    for g = 1, 8 do
        local gw = groupWindows[g]
        if gw and gw.win and gw.slots then
            if gw.win.SetScale then gw.win:SetScale(scale) end
            gw.win:SetSize(width + (PAD * 2), (PAD * 2 + HEADER_H) + 5 * height + 4 * spacing)

            for s = 1, 5 do
                local f = gw.slots[s]
                if f then
                    f:SetSize(width, height)
                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", gw.win, "TOPLEFT", PAD,
                        -(PAD + HEADER_H) - (s - 1) * (height + spacing)
                    )

                    if f._rhPendingUnit ~= nil then
                        local u = f._rhPendingUnit
                        f._rhPendingUnit = nil
                        AssignUnit(f, u)
                    end
                end
            end
        end
    end

    -- Positions once
    if not RH._groupPositionsReady then
        RH._groupPositionsReady = true
        local any = false
        for g = 1, 8 do any = ApplyGroupPosOrDefault(g) or any end
        if not any then LayoutDefaultPositions() end
    end

    -- Clear all
    for g = 1, 8 do
        groupWindows[g].win:Hide()
        for s = 1, 5 do
            AssignUnit(groupWindows[g].slots[s], nil)
            SafeSetVisible(groupWindows[g].slots[s], false)
        end
    end

    -- SOLO
    if not IsInGroup() and not IsInRaid() then
        if not showSolo then return end

        local gw = groupWindows[1]
        if not gw or not gw.win or not gw.slots or not gw.slots[1] then return end

        gw.win:Show()
        if gw.win.header then gw.win.header:Hide() end

        AssignUnit(gw.slots[1], "player")
        SafeSetVisible(gw.slots[1], true)

        gw.slots[1]:ClearAllPoints()
        gw.slots[1]:SetPoint("TOPLEFT", gw.win, "TOPLEFT", PAD, -(PAD + HEADER_H))
        return
    end

    -- In Group: Header wieder an
    for g = 1, 8 do
        local gw = groupWindows[g]
        if gw and gw.win and gw.win.header then
            gw.win.header:Show()
        end
    end

    -- RAID
    local used = {0,0,0,0,0,0,0,0}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local _, _, subgroup = GetRaidRosterInfo(i)
            if subgroup and subgroup <= showGroups then
                used[subgroup] = used[subgroup] + 1
                if used[subgroup] <= 5 then
                    local f = groupWindows[subgroup].slots[used[subgroup]]
                    AssignUnit(f, "raid" .. i)
                    groupWindows[subgroup].win:Show()
                    SafeSetVisible(f, true)
                end
            end
        end
        return
    end

    -- PARTY
    groupWindows[1].win:Show()
    AssignUnit(groupWindows[1].slots[1], "player")
    SafeSetVisible(groupWindows[1].slots[1], true)

    for i = 1, GetNumSubgroupMembers() do
        local f = groupWindows[1].slots[i+1]
        AssignUnit(f, "party" .. i)
        SafeSetVisible(f, true)
    end
end

function RH:CreateGridContainer()
    RH:UpdateGrid()
end

-- =========================================================
-- Boot / Events
-- =========================================================
local roster = CreateFrame("Frame")
roster:RegisterEvent("ADDON_LOADED")
roster:RegisterEvent("PLAYER_LOGIN")
roster:RegisterEvent("PLAYER_ENTERING_WORLD")
roster:RegisterEvent("ZONE_CHANGED_NEW_AREA")
roster:RegisterEvent("GROUP_ROSTER_UPDATE")
roster:RegisterEvent("RAID_ROSTER_UPDATE")
roster:RegisterEvent("PLAYER_TARGET_CHANGED")
roster:RegisterEvent("PLAYER_REGEN_ENABLED")
roster:RegisterEvent("PLAYER_REGEN_DISABLED")

local function FullGridRefresh_Retry(tries)
    tries = (tries or 0)
    if tries > 20 then return end
    if not RH or not RH.UpdateGrid then return end

    local ok = pcall(function()
        local r = DB()
        if r and r.profile then r = r.profile end
        if not r then error("no db") end
        r.grid = r.grid or {}
        if r.grid.showWhenSolo == nil then r.grid.showWhenSolo = true end
    end)

    if not ok then
        C_Timer.After(0.10, function() FullGridRefresh_Retry(tries + 1) end)
        return
    end

    RH:UpdateGrid()
    C_Timer.After(0.10, function() if RH and RH.UpdateGrid then RH:UpdateGrid() end end)
    C_Timer.After(0.40, function() if RH and RH.UpdateGrid then RH:UpdateGrid() end end)
end

roster:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_REGEN_DISABLED" then
        RH._inCombat = true
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        RH._inCombat = false
        ApplyWantedVisibilityAfterCombat()

        if RH._pendingGridUpdate then
            RH._pendingGridUpdate = nil
            FullGridRefresh_Retry(0)
        end
        return
    end

    if event == "ADDON_LOADED" then
        if arg1 ~= "RexHeal" then return end
        FullGridRefresh_Retry(0)
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        -- Visual only (keine Secure Änderungen nötig)
        if RH._groupWindows then
            for g = 1, 8 do
                local gw = RH._groupWindows[g]
                if gw and gw.slots then
                    for s = 1, 5 do
                        local f = gw.slots[s]
                        if f and f.unit then
                            UpdateOne(f)
                        end
                    end
                end
            end
        end
        return
    end

    FullGridRefresh_Retry(0)
end)

C_Timer.After(0.20, function() FullGridRefresh_Retry(0) end)
