if not RexHeal then return end
local RH = RexHeal

RH.ALWAYS_RED_DISPEL_DOT = true

-- ---------------------------------------------------------
-- GetDispelType (Midnight safe)
-- ---------------------------------------------------------
function RH:GetDispelType(unit)
    if not unit or not UnitExists(unit) then return nil end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end

    for i = 1, 40 do
        local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
        if not a then break end

        -- KEIN Vergleich, KEIN Lookup, nur Existenz prüfen
        if a.dispelName then
            return true
        end
    end

    return nil
end

-- ---------------------------------------------------------
-- ApplyDispelDot
-- ---------------------------------------------------------
function RH:ApplyDispelDot(frame, unit)
    if not frame or not frame.dispelDot then return end

    local hasDispel = self:GetDispelType(unit)

    if hasDispel then
        frame.dispelDot:SetColorTexture(1, 0.15, 0.15, 1)
        frame.dispelDot:Show()
    else
        frame.dispelDot:Hide()
    end
end
