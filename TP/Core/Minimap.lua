local _, T = ...

-- Minimap button: click opens the main window, drag moves it around the minimap.

local M = {}
T.Minimap = M

local atan2 = math.atan2 or math.atan
local button

local function place()
    -- Follow the minimap's real size (Forever's is larger than the classic 140 px), like LibDBIcon.
    local radius = (Minimap:GetWidth() / 2) + 5
    local a = math.rad(T.db.settings.minimap.angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * radius, math.sin(a) * radius)
end

local function onDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local px, py = GetCursorPosition()
    px, py = px / scale, py / scale
    T.db.settings.minimap.angle = math.deg(atan2(py - my, px - mx))
    place()
end

function M.Create()
    if button or not Minimap then return end
    button = CreateFrame("Button", "TPMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\Ability_Warrior_BattleShout")
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function() T.UI.Toggle() end)
    button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDragUpdate) end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff33ff99<TP>|r")
        GameTooltip:AddLine("Klicka: öppna", 1, 1, 1)
        GameTooltip:AddLine("Dra: flytta knappen", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Minimap:HookScript("OnSizeChanged", function() if button:IsShown() then place() end end)
    M.Update()
end

function M.Update()
    if not button then return end
    place()
    if T.db.settings.minimap.hide then button:Hide() else button:Show() end
end
