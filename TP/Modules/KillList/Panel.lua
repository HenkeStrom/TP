local _, T = ...

-- Kill List page in the <TP> main window.

local K = T.KillList
local Wd = T.Widgets

local ROWS, ROW_H, LIST_TOP = 11, 22, -70
local rows, offset = {}, 0
local panel, nameBox, reasonBox, countText

local function doAdd()
    local name = nameBox:GetText()
    K.AddPlayer(name ~= "" and name or nil, reasonBox:GetText())
    nameBox:SetText(""); reasonBox:SetText("")
    nameBox:ClearFocus(); reasonBox:ClearFocus()
end

local function makeRow(parent, i)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(490, ROW_H)
    r:SetPoint("TOPLEFT", 4, LIST_TOP - (i - 1) * ROW_H)
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)

    local function col(font, x, w)
        local fs = Wd.Text(r, font)
        fs:SetPoint("LEFT", x, 0)
        fs:SetWidth(w)
        fs:SetWordWrap(false)
        return fs
    end
    r.name = col("GameFontHighlight", 4, 130)
    r.owner = col("GameFontDisableSmall", 138, 100)
    r.reason = col("GameFontHighlightSmall", 242, 120)
    r.seen = col("GameFontDisableSmall", 366, 100)

    r.del = CreateFrame("Button", nil, r, "UIPanelCloseButton")
    r.del:SetSize(22, 22)
    r.del:SetPoint("RIGHT", 2, 0)
    r.del:SetScript("OnClick", function() if r.key then K.RemoveKey(r.key) end end)
    r.del:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Ta bort från listan")
        GameTooltip:Show()
    end)
    r.del:SetScript("OnLeave", function() GameTooltip:Hide() end)

    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(T.ClassColored(e.t, e.c))
        GameTooltip:AddLine("Tillagd av " .. e.o .. ", " .. T.Ago(e.ts), 1, 1, 1)
        if K.IsWildcard(e) then
            GameTooltip:AddLine("Utan efternamn: varnar för alla som heter " .. e.t .. ".", 0.7, 0.7, 0.7, true)
        end
        if e.r ~= "" then GameTooltip:AddLine(e.r, 1, 0.82, 0, true) end
        local s = K.db.seen[T.Lower(e.t)]
        if s then
            GameTooltip:AddLine("Senast sedd: " .. (s.name or e.t) .. ", " .. (s.zone or "?") .. ", " .. T.Ago(s.time), 0.7, 0.7, 0.7)
        end
        if not K.IsMine(e) then GameTooltip:AddLine("Bara " .. e.o .. " kan ta bort detta.", 0.6, 0.6, 0.6) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

function K:BuildPanel(parent)
    panel = parent

    countText = Wd.Text(parent, "GameFontDisableSmall")
    countText:SetPoint("TOPRIGHT", -8, -52)

    nameBox = Wd.EditBox(parent, 150, "Namn (tomt = target)")
    nameBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Namn")
        GameTooltip:AddLine("Skriv Förnamn Efternamn.", 1, 1, 1)
        GameTooltip:AddLine("Bara förnamn = varnar för alla med det förnamnet.", 1, 1, 1)
        GameTooltip:AddLine("Tomt = lägger till ditt target.", 1, 1, 1)
        GameTooltip:Show()
    end)
    nameBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    nameBox:SetPoint("TOPLEFT", 14, -18)
    reasonBox = Wd.EditBox(parent, 190, "Anledning (valfritt)")
    reasonBox:SetPoint("LEFT", nameBox, "RIGHT", 14, 0)
    reasonBox:SetMaxLetters(K.REASON_MAX)
    nameBox:SetScript("OnEnterPressed", function() reasonBox:SetFocus() end)
    nameBox:SetScript("OnTabPressed", function() reasonBox:SetFocus() end)
    reasonBox:SetScript("OnEnterPressed", doAdd)
    local add = Wd.Button(parent, "Lägg till", 100, doAdd)
    add:SetPoint("LEFT", reasonBox, "RIGHT", 10, 0)

    for _, c in ipairs({ { 8, "Namn" }, { 142, "Tillagd av" }, { 246, "Anledning" }, { 370, "Senast sedd" } }) do
        local h = Wd.Text(parent, "GameFontNormalSmall", c[2])
        h:SetPoint("TOPLEFT", c[1], -52)
    end
    for i = 1, ROWS do rows[i] = makeRow(parent, i) end

    parent:EnableMouseWheel(true)
    parent:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta * 3
        K:RefreshPanel()
    end)

    -- options
    local y = LIST_TOP - ROWS * ROW_H - 12
    local snd = Wd.Check(parent, "Ljud", function() return K.db.sound end, function(on) K.db.sound = on end)
    snd:SetPoint("TOPLEFT", 4, y)
    local inst = Wd.Check(parent, "Varna i instanser/BG",
        function() return K.db.alertInInstances end, function(on) K.db.alertInInstances = on end)
    inst:SetPoint("LEFT", snd.label, "RIGHT", 12, 0)

    local cdLabel = Wd.Text(parent, "GameFontHighlightSmall", "Varna igen efter (s):")
    cdLabel:SetPoint("LEFT", inst.label, "RIGHT", 14, 0)
    local cd = Wd.EditBox(parent, 36)
    cd:SetPoint("LEFT", cdLabel, "RIGHT", 10, 0)
    cd:SetNumeric(true)
    cd:SetMaxLetters(4)
    local function saveCd()
        local n = tonumber(cd:GetText())
        if n and n >= 5 then K.db.alertCooldown = n end
        cd:SetText(tostring(K.db.alertCooldown))
        cd:ClearFocus()
    end
    cd:SetScript("OnEnterPressed", saveCd)
    cd:SetScript("OnEditFocusLost", saveCd)
    cd:SetScript("OnShow", function(self) self:SetText(tostring(K.db.alertCooldown)) end)
    cd:SetText(tostring(K.db.alertCooldown))

    local test = Wd.Button(parent, "Testa varning", 100, function() K.TestAlert() end)
    test:SetPoint("TOPRIGHT", -8, y - 1)
end

function K:RefreshPanel()
    if not panel or not panel:IsVisible() then return end
    local list = K.ActiveList()
    offset = math.max(0, math.min(offset, #list - ROWS))
    countText:SetText(#list .. " listade")
    for i = 1, ROWS do
        local r, item = rows[i], list[i + offset]
        if item then
            local e = item.e
            local s = K.db.seen[T.Lower(e.t)]
            r.key, r.entry = item.key, e
            local label = T.ClassColored(e.t, (s and s.class) or e.c)
            if K.IsWildcard(e) then label = label .. " |cff888888(alla)|r" end
            r.name:SetText(label)
            r.owner:SetText(e.o)
            r.reason:SetText(e.r)
            -- only the nearest place ("Astranaar", not "Astranaar, Ashenvale") so the time fits
            local place = s and (s.zone or "?"):match("^([^,]+)")
            r.seen:SetText(s and (place .. " · " .. T.Ago(s.time):gsub(" sedan", "")) or "-")
            if K.IsMine(e) then r.del:Show() else r.del:Hide() end
            r:Show()
        else
            r.key, r.entry = nil, nil
            r:Hide()
        end
    end
end
