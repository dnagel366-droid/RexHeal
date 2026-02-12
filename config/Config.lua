-- =========================================================
-- RexHeal config/Config.lua
-- Alpha Config Box – BIS PUNKT 6 + ClickCast (Text-Eingabe)
-- - Fenster: 560x440, verschiebbar, clamped
-- - Navigation links (Tabs)
-- - Rechts: Scrollfläche stabil
-- - Allgemein Tab fertig
-- - Grid Tab (Slider + Dropdown, live RH:UpdateGrid())
-- - Anzeige Tab (HP% / Klassenfarben / Mana / Rollenicon)
-- - ClickCast Tab: freie Spellnamen per Eingabe (WheelUp/Down + Button 1..16)
-- - Minimap = Platzhalter
-- =========================================================

if not RexHeal then return end
local RH = RexHeal

local function DB()
    return RH:DB()
end

local cfgFrame

-- Navi state
local navButtons = {}
local activeTab = "Allgemein"

-- Content refs
local scrollFrame
local scrollChild
local currentContent -- Frame, der pro Tab neu gebaut wird

-- =========================================================
-- Fallback wipe
-- =========================================================
if not wipe then
    function wipe(t)
        if type(t) ~= "table" then return t end
        for k in pairs(t) do t[k] = nil end
        return t
    end
end

-- =========================================================
-- ClickCast Helper (DB + safe refresh)
-- =========================================================
local function ClickDB()
    local db = DB()
    db.clickcast = db.clickcast or {}
    db.clickcast.enabled = (db.clickcast.enabled ~= false)
    db.clickcast.bindings = db.clickcast.bindings or {}
    if db.clickcast.WheelUp == nil then db.clickcast.WheelUp = "" end
    if db.clickcast.WheelDown == nil then db.clickcast.WheelDown = "" end
    return db.clickcast
end

local function SafeRefreshClickCast()
    if InCombatLockdown() then
        print("|cffff4444RexHeal: Im Kampf nicht änderbar.|r")
        return
    end
    if RH and RH.RefreshAllClickCast then
        pcall(function() RH:RefreshAllClickCast() end)
    end
end

-- =========================================================
-- Minimal ElvUI-ish Helpers
-- =========================================================
local function CreateBackdrop(frame, alpha)
    frame:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.08, 0.09, 0.10, alpha or 0.95)
    frame:SetBackdropBorderColor(0.22, 0.24, 0.27, 1)
end

local function CreateLabel(parent, text, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(STANDARD_TEXT_FONT, size or 14, "OUTLINE")
    fs:SetTextColor(r or 0.90, g or 0.92, b or 0.95, 1)
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

local function CreateDivider(parent)
    local line = parent:CreateTexture(nil, "BORDER")
    line:SetTexture("Interface/Buttons/WHITE8x8")
    line:SetVertexColor(0.20, 0.22, 0.25, 1)
    return line
end

local function CreateFlatButton(parent, w, h, text)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    CreateBackdrop(b, 0.35)

    b._text = CreateLabel(b, text or "", 12, 0.88, 0.90, 0.93)
    b._text:SetPoint("CENTER", 0, 0)

    b._hl = b:CreateTexture(nil, "HIGHLIGHT")
    b._hl:SetTexture("Interface/Buttons/WHITE8x8")
    b._hl:SetVertexColor(1, 1, 1, 0.06)
    b._hl:SetAllPoints(b)

    b:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(0.10, 0.11, 0.12, 0.55)
    end)

    return b
end

local function SetButtonNormal(btn)
    btn:SetBackdropColor(0.08, 0.09, 0.10, 0.35)
    btn:SetBackdropBorderColor(0.22, 0.24, 0.27, 1)
end

local function SetButtonActive(btn)
    btn:SetBackdropColor(0.12, 0.13, 0.14, 0.70)
    btn:SetBackdropBorderColor(0.22, 0.24, 0.27, 1)
end

local function SetButtonPrimary(btn)
    btn:SetBackdropColor(0.10, 0.12, 0.14, 0.55)
    btn:SetBackdropBorderColor(0.28, 0.30, 0.34, 1)
end

-- Clean Checkbox
local function CreateCheckbox(parent, labelText)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(18, 18)

    c.box = CreateFrame("Frame", nil, c, "BackdropTemplate")
    c.box:SetAllPoints()
    CreateBackdrop(c.box, 0.40)

    c.tick = c.box:CreateTexture(nil, "OVERLAY")
    c.tick:SetTexture("Interface/Buttons/WHITE8x8")
    c.tick:SetPoint("TOPLEFT", 4, -4)
    c.tick:SetPoint("BOTTOMRIGHT", -4, 4)
    c.tick:SetVertexColor(0.25, 0.85, 0.45, 0.95)

    c.text = CreateLabel(parent, labelText or "", 12, 0.88, 0.90, 0.93)
    c.text:SetPoint("LEFT", c, "RIGHT", 10, 0)

    c._checked = false
    function c:SetChecked(state)
        self._checked = state and true or false
        self.tick:SetShown(self._checked)
    end
    function c:GetChecked()
        return self._checked
    end

    c:SetScript("OnEnter", function()
        c.box:SetBackdropBorderColor(0.35, 0.38, 0.42, 1)
    end)
    c:SetScript("OnLeave", function()
        c.box:SetBackdropBorderColor(0.22, 0.24, 0.27, 1)
    end)

    return c
end

-- =========================================================
-- EditBox helper (freies Eintragen)
-- =========================================================
local function CreateInputRow(parent, width, labelText, placeholder)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetSize(width, 44)

    local lbl = CreateLabel(wrap, labelText or "", 12, 0.88, 0.90, 0.93)
    lbl:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, 0)

    local box = CreateFrame("EditBox", nil, wrap, "BackdropTemplate")
    box:SetSize(width, 26)
    box:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, -18)
    CreateBackdrop(box, 0.25)
    box:SetAutoFocus(false)
    box:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    box:SetTextInsets(8, 8, 0, 0)

    local ph = CreateLabel(box, placeholder or "", 11, 0.55, 0.58, 0.62)
    ph:SetPoint("LEFT", box, "LEFT", 8, 0)
    ph:SetJustifyH("LEFT")

    local function UpdatePlaceholder()
        local t = box:GetText()
        ph:SetShown(not t or t == "")
    end

    box:HookScript("OnTextChanged", UpdatePlaceholder)
    box:HookScript("OnEditFocusGained", function() box:SetBackdropBorderColor(0.35, 0.38, 0.42, 1) end)
    box:HookScript("OnEditFocusLost", function() box:SetBackdropBorderColor(0.22, 0.24, 0.27, 1) UpdatePlaceholder() end)

    wrap.input = box
    wrap.label = lbl
    wrap._UpdatePlaceholder = UpdatePlaceholder
    return wrap
end

-- =========================================================
-- Layout helpers
-- =========================================================
local function GetContentWidth()
    if not scrollFrame then return 360 end
    local w = scrollFrame:GetWidth()
    if not w or w <= 0 then return 360 end
    return w - 8
end

local function ClearContent()
    if currentContent then
        currentContent:Hide()
        currentContent:SetParent(nil)
        currentContent = nil
    end
end

local function MakeContentFrame()
    ClearContent()
    local c = CreateFrame("Frame", nil, scrollChild)
    c:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    c:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
    c:SetWidth(GetContentWidth())
    currentContent = c
    return c
end

local function EnsureScrollChild()
    if not scrollChild then return end
    local w = GetContentWidth() + 8
    scrollChild:SetWidth(w)
end

local function SetScrollHeight(h)
    if scrollChild then scrollChild:SetHeight(h or 1) end
    if scrollFrame and scrollFrame.SetVerticalScroll then
        scrollFrame:SetVerticalScroll(0)
    end
end

local function SafeUpdateGrid()
    if RH and RH.UpdateGrid then
        pcall(function() RH:UpdateGrid() end)
    end
end

-- =========================================================
-- UI: Custom Slider + Dropdown (clean)
-- =========================================================
local function CreateSlimSlider(parent, width, minV, maxV, step)
    local s = CreateFrame("Slider", nil, parent)
    s:SetSize(width, 14)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step or 1)
    s:SetObeyStepOnDrag(true)
    s:EnableMouse(true)

    s.bg = s:CreateTexture(nil, "BORDER")
    s.bg:SetTexture("Interface/Buttons/WHITE8x8")
    s.bg:SetPoint("LEFT", s, "LEFT", 0, 0)
    s.bg:SetPoint("RIGHT", s, "RIGHT", 0, 0)
    s.bg:SetHeight(6)
    s.bg:SetVertexColor(1, 1, 1, 0.08)

    s.fill = s:CreateTexture(nil, "ARTWORK")
    s.fill:SetTexture("Interface/Buttons/WHITE8x8")
    s.fill:SetPoint("LEFT", s.bg, "LEFT", 0, 0)
    s.fill:SetHeight(6)
    s.fill:SetVertexColor(0.25, 0.85, 0.45, 0.35)

    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface/Buttons/WHITE8x8")
    thumb:SetSize(10, 16)
    thumb:SetVertexColor(1, 1, 1, 0.35)
    s:SetThumbTexture(thumb)
    s.thumb = thumb

    local function UpdateFill()
        local v = s:GetValue()
        local a, b = s:GetMinMaxValues()
        local pct = 0
        if b > a then pct = (v - a) / (b - a) end
        pct = math.max(0, math.min(1, pct))
        s.fill:SetWidth((width) * pct)
    end
    s._UpdateFill = UpdateFill

    s:HookScript("OnValueChanged", function()
        s:_UpdateFill()
    end)

    s:SetValue(minV)
    s:_UpdateFill()

    return s
end

local function CreateDropdown(parent, width, labelText)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetSize(width, 30)

    local lbl = CreateLabel(wrap, labelText or "", 12, 0.88, 0.90, 0.93)
    lbl:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, 0)

    local btn = CreateFlatButton(wrap, width, 26, "")
    btn:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, -14)
    SetButtonNormal(btn)

    local caret = wrap:CreateFontString(nil, "OVERLAY")
    caret:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    caret:SetTextColor(0.70, 0.72, 0.75, 1)
    caret:SetText("▼")
    caret:SetPoint("RIGHT", btn, "RIGHT", -8, 0)

    local menu = CreateFrame("Frame", nil, wrap, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(width)
    menu:Hide()
    CreateBackdrop(menu, 0.95)
    menu:SetFrameStrata("DIALOG")
    menu:EnableMouse(true)

    wrap._btn = btn
    wrap._menu = menu
    wrap._items = {}

    function wrap:SetValueText(t)
        btn._text:SetText(t or "")
    end

    local function CloseMenu()
        menu:Hide()
    end

    menu:SetScript("OnMouseDown", function() end)
    btn:SetScript("OnClick", function()
        if menu:IsShown() then CloseMenu() else menu:Show() end
    end)

    function wrap:SetOptions(list, onSelect)
        for i = 1, #wrap._items do
            wrap._items[i]:Hide()
            wrap._items[i]:SetParent(nil)
        end
        wipe(wrap._items)

        local y = -6
        for i = 1, #list do
            local opt = list[i]
            local b = CreateFlatButton(menu, width - 12, 24, tostring(opt.text))
            b:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, y)
            y = y - 26
            SetButtonNormal(b)

            b:SetScript("OnClick", function()
                CloseMenu()
                if onSelect then onSelect(opt.value, opt.text) end
            end)

            wrap._items[i] = b
        end

        menu:SetHeight(10 + (#list * 26))
    end

    wrap:SetScript("OnLeave", function()
        CloseMenu()
    end)

    return wrap
end

-- =========================================================
-- TAB CONTENT: Allgemein (Punkt 3)
-- =========================================================
local function BuildGeneralTab()
    local db = DB()
    db.general = db.general or {}
    if db.general.testMode == nil then db.general.testMode = false end

    local c = MakeContentFrame()
    EnsureScrollChild()

    local w = GetContentWidth()

    local header = CreateLabel(c, "Allgemein", 16, 0.92, 0.94, 0.97)
    header:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -6)
    header:SetWidth(w - 12)

    local hint = CreateLabel(c, "Basis-Einstellungen für RexHeal (Alpha).", 12, 0.60, 0.62, 0.66)
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    hint:SetWidth(w - 12)

    local sep = CreateDivider(c)
    sep:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
    sep:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, 0)
    sep:SetHeight(1)

    local moveBtn = CreateFlatButton(c, w - 12, 36, "GRID VERSCHIEBEN")
    moveBtn:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 6, -16)
    SetButtonPrimary(moveBtn)

    moveBtn:SetScript("OnClick", function()
        if RH.ToggleGridMove then
            RH:ToggleGridMove()
        else
            print("|cffffcc00RexHeal|r: Grid-Verschieben noch nicht angebunden (ToggleGridMove fehlt).")
        end
    end)

    local lockCB = CreateCheckbox(c, "Frames sperren")
    lockCB:SetPoint("TOPLEFT", moveBtn, "BOTTOMLEFT", 2, -16)
    lockCB:SetChecked(db.general.lockFrames and true or false)

    lockCB:SetScript("OnClick", function(self)
        local newState = not self:GetChecked()
        self:SetChecked(newState)
        db.general.lockFrames = newState and true or false
        SafeUpdateGrid()
    end)

    local status = CreateLabel(c, "", 12, 0.60, 0.62, 0.66)
    status:SetPoint("TOPLEFT", lockCB.text, "BOTTOMLEFT", 0, -10)
    status:SetWidth(w - 12)

    local function RefreshTestUI()
        status:SetText(db.general.testMode and "Test-Modus: AN (UI Toggle – Logik folgt später)" or "Test-Modus: AUS")
    end

    local testBtn = CreateFlatButton(c, (w - 18) / 2, 30, "")
    testBtn:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -12)
    SetButtonNormal(testBtn)

    local resetBtn = CreateFlatButton(c, (w - 18) / 2, 30, "Reset Profil")
    resetBtn:SetPoint("LEFT", testBtn, "RIGHT", 6, 0)
    SetButtonNormal(resetBtn)

    local function RefreshTestButtonText()
        testBtn._text:SetText(db.general.testMode and "TEST-MODUS: AN" or "TEST-MODUS: AUS")
    end

    testBtn:SetScript("OnClick", function()
        db.general.testMode = not db.general.testMode
        RefreshTestButtonText()
        RefreshTestUI()
        SafeUpdateGrid()
    end)

    resetBtn:SetScript("OnClick", function()
        if RH.ResetProfile then
            RH:ResetProfile()
            print("|cff33ff99RexHeal|r: Profil zurückgesetzt.")
            SafeUpdateGrid()
            BuildGeneralTab()
        else
            print("|cffff4444RexHeal|r: ResetProfile() fehlt.")
        end
    end)

    RefreshTestButtonText()
    RefreshTestUI()

    c:SetHeight(340)
    SetScrollHeight(340)
end

-- =========================================================
-- TAB CONTENT: Grid (Punkt 4)
-- =========================================================
local function BuildGridTab()
    local db = DB()
    db.grid = db.grid or {}

    local c = MakeContentFrame()
    EnsureScrollChild()

    local w = GetContentWidth()

    local header = CreateLabel(c, "Grid", 16, 0.92, 0.94, 0.97)
    header:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -6)
    header:SetWidth(w - 12)

    local hint = CreateLabel(c, "Größe & Abstände – wirken sofort.", 12, 0.60, 0.62, 0.66)
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    hint:SetWidth(w - 12)

    local sep = CreateDivider(c)
    sep:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
    sep:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, 0)
    sep:SetHeight(1)

    local y = -16

    local function AddSliderRow(title, minV, maxV, step, getFn, setFn, fmt)
        local row = CreateFrame("Frame", nil, c)
        row:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 6, y)
        row:SetSize(w - 12, 54)

        local lbl = CreateLabel(row, title, 12, 0.88, 0.90, 0.93)
        lbl:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)

        local valFS = CreateLabel(row, "", 12, 0.65, 0.68, 0.72)
        valFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)

        local slider = CreateSlimSlider(row, w - 12, minV, maxV, step)
        slider:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -18)

        local function UpdateText(v)
            if fmt then valFS:SetText(fmt(v)) else valFS:SetText(tostring(v)) end
        end

        local function SetValue(v, silent)
            v = tonumber(v) or minV
            v = math.max(minV, math.min(maxV, v))
            slider:SetValue(v)
            slider:_UpdateFill()
            UpdateText(v)
            if not silent then
                setFn(v)
                SafeUpdateGrid()
            end
        end

        slider:SetScript("OnValueChanged", function(self, value)
            local v = value
            if step and step > 0 then
                v = math.floor((v / step) + 0.5) * step
            end
            UpdateText(v)
            setFn(v)
            SafeUpdateGrid()
            self:_UpdateFill()
        end)

        SetValue(getFn(), true)
        y = y - 64
    end

    db.grid.scale = tonumber(db.grid.scale) or 1.0
    db.grid.width = tonumber(db.grid.width) or 70
    db.grid.height = tonumber(db.grid.height) or 45
    db.grid.spacing = tonumber(db.grid.spacing) or 2
    db.grid.groupSpacing = tonumber(db.grid.groupSpacing) or 18
    db.grid.raidShowGroups = tonumber(db.grid.raidShowGroups) or 8

    AddSliderRow("Scale", 0.50, 2.00, 0.05, function() return db.grid.scale end, function(v) db.grid.scale = v end, function(v) return string.format("%.2f", v) end)
    AddSliderRow("Breite", 40, 140, 1, function() return db.grid.width end, function(v) db.grid.width = v end)
    AddSliderRow("Höhe", 20, 90, 1, function() return db.grid.height end, function(v) db.grid.height = v end)
    AddSliderRow("Spacing", 0, 12, 1, function() return db.grid.spacing end, function(v) db.grid.spacing = v end)
    AddSliderRow("GroupSpacing", 0, 40, 1, function() return db.grid.groupSpacing end, function(v) db.grid.groupSpacing = v end)

    local dd = CreateDropdown(c, w - 12, "Gruppenanzahl (1–8)")
    dd:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 6, y)
    dd:SetValueText(tostring(db.grid.raidShowGroups))

    local opts = {}
    for i = 1, 8 do opts[#opts + 1] = { value = i, text = tostring(i) } end

    dd:SetOptions(opts, function(val, text)
        db.grid.raidShowGroups = tonumber(val) or 8
        dd:SetValueText(text)
        SafeUpdateGrid()
    end)

    c:SetHeight(520)
    SetScrollHeight(520)
end

-- =========================================================
-- TAB CONTENT: Anzeige (Punkt 6)
-- =========================================================
local function BuildAnzeigeTab()
    local db = DB()
    db.grid = db.grid or {}

    if db.grid.showHPPercent == nil then db.grid.showHPPercent = true end
    if db.grid.classColors   == nil then db.grid.classColors   = true end
    if db.grid.showMana      == nil then db.grid.showMana      = false end
    if db.grid.showRoleIcon  == nil then db.grid.showRoleIcon  = false end

    local c = MakeContentFrame()
    EnsureScrollChild()

    local w = GetContentWidth()

    local header = CreateLabel(c, "Anzeige", 16, 0.92, 0.94, 0.97)
    header:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -6)
    header:SetWidth(w - 12)

    local hint = CreateLabel(c, "Anzeige-Optionen – wirken sofort.", 12, 0.60, 0.62, 0.66)
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    hint:SetWidth(w - 12)

    local sep = CreateDivider(c)
    sep:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
    sep:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, 0)
    sep:SetHeight(1)

    local y = -18
    local function AddCheckRow(label, getFn, setFn)
        local cb = CreateCheckbox(c, label)
        cb:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 8, y)
        cb:SetChecked(getFn() and true or false)
        cb:SetScript("OnClick", function(self)
            local newState = not self:GetChecked()
            self:SetChecked(newState)
            setFn(newState and true or false)
            SafeUpdateGrid()
        end)
        y = y - 34
    end

    AddCheckRow("HP% anzeigen", function() return db.grid.showHPPercent end, function(v) db.grid.showHPPercent = v end)
    AddCheckRow("Klassenfarben", function() return db.grid.classColors end, function(v) db.grid.classColors = v end)
    AddCheckRow("Mana anzeigen", function() return db.grid.showMana end, function(v) db.grid.showMana = v end)
    AddCheckRow("Rollen-Icon anzeigen", function() return db.grid.showRoleIcon end, function(v) db.grid.showRoleIcon = v end)

    c:SetHeight(260)
    SetScrollHeight(260)
end

-- =========================================================
-- TAB CONTENT: ClickCast (freie Eingabe)
-- =========================================================
local function BuildClickCastTab()
    local db = DB()
    db.general = db.general or {}
    if db.general.targetOnHeal == nil then db.general.targetOnHeal = true end

    local cc = ClickDB()

    local c = MakeContentFrame()
    EnsureScrollChild()
    local w = GetContentWidth()

    local header = CreateLabel(c, "ClickCast", 16, 0.92, 0.94, 0.97)
    header:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -6)
    header:SetWidth(w - 12)

    local hint = CreateLabel(c, "Trage Spellnamen ein (genau wie im Zauberbuch). Leer = deaktiviert. Änderungen wirken sofort (außer im Kampf).", 12, 0.60, 0.62, 0.66)
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    hint:SetWidth(w - 12)

    local sep = CreateDivider(c)
    sep:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
    sep:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, 0)
    sep:SetHeight(1)

    local y = -18

    local en = CreateCheckbox(c, "ClickCast aktiv")
    en:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 8, y)
    en:SetChecked(cc.enabled and true or false)
    en:SetScript("OnClick", function(self)
        local newState = not self:GetChecked()
        self:SetChecked(newState)
        cc.enabled = newState and true or false
        SafeRefreshClickCast()
    end)
    y = y - 34

    local toh = CreateCheckbox(c, "Ziel beim Heilen (optional)")
    toh:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 8, y)
    toh:SetChecked(db.general.targetOnHeal and true or false)
    toh:SetScript("OnClick", function(self)
        local newState = not self:GetChecked()
        self:SetChecked(newState)
        db.general.targetOnHeal = newState and true or false
        SafeRefreshClickCast()
    end)
    y = y - 46

    local sub = CreateLabel(c, "Mausrad", 13, 0.85, 0.88, 0.92)
    sub:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 6, y)
    y = y - 26

    local rowUp = CreateInputRow(c, w - 12, "Mausrad hoch", "z.B. Erneuerung / Rejuvenation")
    rowUp:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 6, y)
    y = y - 52

    local rowDown = CreateInputRow(c, w - 12, "Mausrad runter", "z.B. Blitzheilung / Regrowth")
    rowDown:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 6, y)
    y = y - 60

    local sub2 = CreateLabel(c, "Maus Buttons (1–16)", 13, 0.85, 0.88, 0.92)
    sub2:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 6, y)
    y = y - 26

    local function NormalizeText(t)
        t = tostring(t or "")
        t = t:gsub("^%s+", ""):gsub("%s+$", "")
        return t
    end

    local function BindEditBox(editBox, getFn, setFn)
        editBox:SetText(getFn() or "")
        editBox:ClearFocus()

        local function Commit()
            local v = NormalizeText(editBox:GetText())
            setFn(v)
            editBox:SetText(v)
            SafeRefreshClickCast()
        end

        editBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            Commit()
        end)

        editBox:SetScript("OnEditFocusLost", function()
            Commit()
        end)
    end

    BindEditBox(rowUp.input, function() return cc.WheelUp end, function(v) cc.WheelUp = v end)
BindEditBox(rowDown.input, function() return cc.WheelDown end, function(v) cc.WheelDown = v end)

-- Middle Mouse (Button 3) extra sichtbar
local rowMid = CreateInputRow(c, w - 12, "Mittlere Maustaste (Taste 3)", "z.B. Reinigung / Dispel")
rowMid:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 6, y)
y = y - 52

BindEditBox(rowMid.input,
    function() return cc.bindings[3] end,
    function(v) cc.bindings[3] = v end
)

	
    local rowY = y
    for i = 1, 16 do
        local r = CreateInputRow(c, w - 12, "Button " .. i, "z.B. Heilung / Heal")
        r:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 6, rowY)

        BindEditBox(r.input,
            function() return cc.bindings[i] end,
            function(v) cc.bindings[i] = v end
        )

        rowY = rowY - 52
    end

    local totalH = math.abs(rowY) + 140
    c:SetHeight(totalH)
    SetScrollHeight(totalH)
end

-- =========================================================
-- Platzhalter Tabs
-- =========================================================
local function BuildPlaceholderTab(name)
    local c = MakeContentFrame()
    EnsureScrollChild()

    local w = GetContentWidth()

    local header = CreateLabel(c, name, 16, 0.92, 0.94, 0.97)
    header:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -6)
    header:SetWidth(w - 12)

    local sub = CreateLabel(c, "Inhalt folgt in den nächsten Schritten.", 12, 0.60, 0.62, 0.66)
    sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    sub:SetWidth(w - 12)

    c:SetHeight(220)
    SetScrollHeight(220)
end

-- =========================================================
-- Tab Switch
-- =========================================================
local function UpdateNavVisual()
    for name, btn in pairs(navButtons) do
        if name == activeTab then SetButtonActive(btn) else SetButtonNormal(btn) end
    end
end

local function BuildTab(tabName)
    if tabName == "Allgemein" then BuildGeneralTab()
    elseif tabName == "Grid" then BuildGridTab()
    elseif tabName == "Anzeige" then BuildAnzeigeTab()
    elseif tabName == "ClickCast" then BuildClickCastTab()
    else BuildPlaceholderTab(tabName) end
end

local function SetTab(tabName)
    activeTab = tabName
    UpdateNavVisual()
    BuildTab(tabName)
end

-- =========================================================
-- UI: Grundgerüst + Navigation
-- =========================================================
local function CreateConfigFrame()
    if cfgFrame then return cfgFrame end
    DB()

    local f = CreateFrame("Frame", "RexHeal_ConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(560, 440)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    CreateBackdrop(f, 0.96)

    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(34)
    CreateBackdrop(header, 0.20)

    local title = CreateLabel(header, "RexHeal – Alpha Config", 14, 0.92, 0.94, 0.97)
    title:SetPoint("LEFT", header, "LEFT", 12, 0)

    local close = CreateFrame("Button", nil, header, "BackdropTemplate")
    close:SetSize(22, 22)
    close:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    CreateBackdrop(close, 0.25)
    local x = CreateLabel(close, "×", 16, 0.95, 0.55, 0.55)
    x:SetPoint("CENTER", 0, -1)
    close:SetScript("OnClick", function() f:Hide() end)

    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -35)
    body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

    local nav = CreateFrame("Frame", nil, body, "BackdropTemplate")
    nav:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    nav:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
    nav:SetWidth(150)
    CreateBackdrop(nav, 0.10)

    local scrollWrap = CreateFrame("Frame", nil, body, "BackdropTemplate")
    scrollWrap:SetPoint("TOPLEFT", nav, "TOPRIGHT", 1, 0)
    scrollWrap:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)

    scrollFrame = CreateFrame("ScrollFrame", nil, scrollWrap, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", scrollWrap, "TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollWrap, "BOTTOMRIGHT", -28, 10)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    local btnNames = { "Allgemein", "Grid", "Anzeige", "ClickCast", "Minimap" }
    local y = -14
    for i = 1, #btnNames do
        local name = btnNames[i]
        local b = CreateFlatButton(nav, 128, 26, name)
        b:SetPoint("TOPLEFT", nav, "TOPLEFT", 11, y)
        b:SetScript("OnClick", function() SetTab(name) end)
        navButtons[name] = b
        y = y - 30
    end

    cfgFrame = f
    SetTab(activeTab)
    return f
end

function RH:ToggleConfig()
    local f = CreateConfigFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        EnsureScrollChild()
        SetTab(activeTab)
    end
end
