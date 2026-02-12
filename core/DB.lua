-- =========================================================
-- RexHeal core/DB.lua
-- - SavedVariables + Defaults
-- - Profil-DB (ohne AceDB)
-- - Mit Migration (buttons -> bindings)
-- =========================================================

RexHeal = RexHeal or {}
local RH = RexHeal

local DEFAULTS = {
    profile = {
        general = {
            debug = false,
            lockFrames = false,
            targetOnHeal = true, -- "Ziel beim Heilen"
        },

        grid = {
            enabled = true,

            -- ✅ Solo anzeigen (Standard)
            showWhenSolo = true,

            scale = 1.0,
            width = 70,
            height = 45,
            spacing = 2,

            -- Abstand zwischen Gruppenfenstern (VuhDo-Look)
            groupSpacing = 18,

            -- wie viele Raidgruppen-Fenster anzeigen (1..8)
            raidShowGroups = 8,

            -- Positionsspeicher pro Gruppe (1..8)
            raidGroupPos = {},

            showMana = false,
            classColors = true,
            showHPPercent = true,
            showRoleIcon = false,

            -- Fallback-Position
            position = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
        },

        clickcast = {
            enabled = true,

            -- bindings:
            -- [1..16] = "SpellName"
            bindings = {},

            -- Mousewheel extra
            WheelUp = "",
            WheelDown = "",

            -- Alt (wird migriert, damit nichts verloren geht):
            buttons = {},
        },

        minimap = {
            enabled = true,
            hide = false,
            angle = 220,
        },
    }
}

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do
        t[k] = DeepCopy(v)
    end
    return t
end

local function DeepMerge(dst, src)
    if type(dst) ~= "table" then return DeepCopy(src) end
    if type(src) ~= "table" then return dst end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = DeepMerge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- =========================================================
-- Migration: clickcast.buttons -> clickcast.bindings
-- =========================================================
local function Migrate(db)
    if not db or not db.profile then return end
    local p = db.profile

    p.clickcast = p.clickcast or {}
    p.clickcast.bindings = p.clickcast.bindings or {}

    -- WheelUp/Down aus alten bindings übernehmen, falls vorhanden
    if p.clickcast.WheelUp == nil or p.clickcast.WheelUp == "" then
        if type(p.clickcast.bindings["WheelUp"]) == "string" and p.clickcast.bindings["WheelUp"] ~= "" then
            p.clickcast.WheelUp = p.clickcast.bindings["WheelUp"]
        end
    end
    if p.clickcast.WheelDown == nil or p.clickcast.WheelDown == "" then
        if type(p.clickcast.bindings["WheelDown"]) == "string" and p.clickcast.bindings["WheelDown"] ~= "" then
            p.clickcast.WheelDown = p.clickcast.bindings["WheelDown"]
        end
    end

    -- Alt-Keys aus bindings entfernen
    p.clickcast.bindings["WheelUp"] = nil
    p.clickcast.bindings["WheelDown"] = nil

    -- Wenn alt "buttons" existiert -> migrieren (nur wenn bindings leer)
    if type(p.clickcast.buttons) == "table" then
        local hasBindings = false
        for _, v in pairs(p.clickcast.bindings) do
            if v and v ~= "" then
                hasBindings = true
                break
            end
        end

        if not hasBindings then
            for k, v in pairs(p.clickcast.buttons) do
                if p.clickcast.bindings[k] == nil or p.clickcast.bindings[k] == "" then
                    p.clickcast.bindings[k] = v
                end
            end
        end
    end
end

function RH:GetDefaults()
    return DeepCopy(DEFAULTS)
end

function RH:GetDB()
    if not _G.RexHealDB or type(_G.RexHealDB) ~= "table" then
        _G.RexHealDB = {}
    end

    if type(_G.RexHealDB.profile) ~= "table" then
        _G.RexHealDB.profile = {}
    end

    -- Defaults ergänzen (nur fehlende Keys)
    DeepMerge(_G.RexHealDB, DEFAULTS)

    -- Migration durchführen
    Migrate(_G.RexHealDB)

    return _G.RexHealDB
end

-- ✅ API bleibt wie gewünscht: RH:DB() liefert profile (kein AceDB Umbau)
function RH:DB()
    local db = self:GetDB()
    db.profile = db.profile or {}
    return db.profile
end

function RH:ResetProfile()
    local db = self:GetDB()
    db.profile = DeepCopy(DEFAULTS.profile)
end

function RH:Debug(msg)
    local db = self:DB()
    if not db.general or not db.general.debug then return end
    print("|cff33ff99RexHeal|r:", msg)
end
