local _, T = ...

-- Main window: sidebar with "Allmänt" + one entry per module, content area on the right.
-- Every module page gets a generic header (title, description, "Aktiverad" checkbox).

local UI = {}
T.UI = UI

local W, H, SIDEBAR = 660, 440, 140
local frame, content
local pages, navButtons = {}, {}
local current

---------------------------------------------------------------- widgets (shared with modules)

local Wd = {}
T.Widgets = Wd

function Wd.Button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

function Wd.EditBox(parent, w, label)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(w, 20)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    if label then
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("BOTTOMLEFT", eb, "TOPLEFT", -4, 2)
        fs:SetText(label)
    end
    return eb
end

function Wd.Check(parent, label, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(label)
    cb.label = fs
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    cb:SetScript("OnShow", function(self) self:SetChecked(get()) end)
    cb:SetChecked(get())
    return cb
end

function Wd.Text(parent, font, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(text) end
    return fs
end

---------------------------------------------------------------- general page

local function buildGeneral(parent)
    local y = -10
    local title = Wd.Text(parent, "GameFontNormalLarge", "|cff33ff99<TP>|r guild-addon")
    title:SetPoint("TOPLEFT", 10, y)
    local ver = Wd.Text(parent, "GameFontDisableSmall", "Version " .. T.version .. " · av Balkan Inferno")
    ver:SetPoint("LEFT", title, "RIGHT", 10, 0)

    y = y - 36
    local mm = Wd.Check(parent, "Visa minimap-knapp",
        function() return not T.db.settings.minimap.hide end,
        function(on) T.db.settings.minimap.hide = not on; T.Minimap.Update() end)
    mm:SetPoint("TOPLEFT", 8, y)

    y = y - 36
    local h = Wd.Text(parent, "GameFontNormal", "Funktioner")
    h:SetPoint("TOPLEFT", 10, y)
    for _, id in ipairs(T.moduleOrder) do
        local mod = T.modules[id]
        y = y - 26
        local cb = Wd.Check(parent, mod.title,
            function() return mod.db.enabled end,
            function(on) T.SetEnabled(id, on); UI.RefreshNav() end)
        cb:SetPoint("TOPLEFT", 8, y)
        if mod.desc then
            local d = Wd.Text(parent, "GameFontDisableSmall", mod.desc)
            d:SetPoint("LEFT", cb.label, "RIGHT", 8, 0)
        end
    end

    y = y - 44
    local sh = Wd.Text(parent, "GameFontNormal", "Synk")
    sh:SetPoint("TOPLEFT", 10, y)
    y = y - 18
    local info = Wd.Text(parent, "GameFontHighlightSmall",
        "Data synkas automatiskt med alla i guilden som har addonet och är online.")
    info:SetPoint("TOPLEFT", 10, y)

    y = y - 22
    local syncNow = Wd.Button(parent, "Synka nu", 90, function()
        if not (IsInGuild and IsInGuild()) then T.Print("Du är inte med i en guild."); return end
        for _, m in pairs(T.modules) do if m.enabled and m.OnSyncNow then m:OnSyncNow() end end
        T.Print("Synk skickad.")
    end)
    syncNow:SetPoint("TOPLEFT", 10, y)
end

---------------------------------------------------------------- module pages

local function buildModulePage(mod, parent)
    local title = Wd.Text(parent, "GameFontNormalLarge", mod.title)
    title:SetPoint("TOPLEFT", 10, -10)
    local en = Wd.Check(parent, "Aktiverad",
        function() return mod.db.enabled end,
        function(on) T.SetEnabled(mod.id, on); UI.RefreshNav() end)
    en:SetPoint("TOPRIGHT", -70, -8)
    local body = CreateFrame("Frame", nil, parent)
    body:SetPoint("TOPLEFT", 0, -36)
    body:SetPoint("BOTTOMRIGHT", 0, 0)
    mod:BuildPanel(body)
end

local function getPage(id)
    if pages[id] then return pages[id] end
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()
    p:Hide()
    if id == "general" then buildGeneral(p) else buildModulePage(T.modules[id], p) end
    pages[id] = p
    return p
end

function UI.Select(id)
    if not T.modules[id] then id = "general" end
    for pid, p in pairs(pages) do if pid ~= id then p:Hide() end end
    current = id
    getPage(id):Show()
    local mod = T.modules[id]
    if mod and mod.RefreshPanel then mod:RefreshPanel() end
    UI.RefreshNav()
end

function UI.RefreshNav()
    for _, b in ipairs(navButtons) do
        local mod = T.modules[b.id]
        local label = mod and mod.title or "Allmänt"
        if mod and not mod.db.enabled then label = "|cff808080" .. label .. "|r" end
        b.text:SetText(label)
        if b.id == current then b.sel:Show() else b.sel:Hide() end
    end
end

local function navButton(id, i)
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(SIDEBAR - 16, 24)
    b:SetPoint("TOPLEFT", 10, -44 - (i - 1) * 26)
    b.id = id
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetColorTexture(0.2, 1, 0.6, 0.18)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    b.text = Wd.Text(b, "GameFontHighlight")
    b.text:SetPoint("LEFT", 8, 0)
    b:SetScript("OnClick", function() UI.Select(id) end)
    navButtons[#navButtons + 1] = b
end

local function build()
    frame = CreateFrame("Frame", "TPMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.04, 0.05, 0.05, 0.94)
        frame:SetBackdropBorderColor(0.2, 0.9, 0.55, 1)
    end
    tinsert(UISpecialFrames, "TPMainFrame") -- Esc closes it

    local title = Wd.Text(frame, "GameFontNormalLarge", "|cff33ff99<TP>|r")
    title:SetPoint("TOPLEFT", 16, -14)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.2, 0.9, 0.55, 0.3)
    divider:SetPoint("TOPLEFT", SIDEBAR, -40)
    divider:SetPoint("BOTTOMLEFT", SIDEBAR, 12)
    divider:SetWidth(1)

    content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", SIDEBAR + 8, -32)
    content:SetPoint("BOTTOMRIGHT", -10, 10)

    navButton("general", 1)
    for i, id in ipairs(T.moduleOrder) do navButton(id, i + 1) end
    frame:Hide()
end

function UI.Show(id)
    if not frame then build() end
    frame:Show()
    UI.Select(id or current or T.moduleOrder[1] or "general")
end

function UI.Toggle(id)
    if frame and frame:IsShown() and (not id or id == current) then frame:Hide() else UI.Show(id) end
end

function UI.IsShowing(id)
    return frame and frame:IsShown() and current == id
end
