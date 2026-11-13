local ADDON, T = ...

-- Core of the <TP> guild addon: saved variables, module registry, events and shared helpers.
--
-- A module is a table registered with T.RegisterModule(id, mod):
--   title, desc        shown in the main window
--   defaults           initial contents of mod.db (TPDB.modules[id])
--   OnInit(mod)        after saved variables load
--   OnEnable(mod)      at login if enabled, and when switched on in the UI
--   OnDisable(mod)     when switched off in the UI
--   BuildPanel(mod, parent)  creates the module's page in the main window (once)
--   RefreshPanel(mod)  called when its page is shown

T.name = ADDON
T.version = "0.4.0"
T.modules, T.moduleOrder = {}, {}

T.Now = function() return GetServerTime and GetServerTime() or time() end

function T.Print(msg, tag)
    local head = "|cff33ff99<TP>|r"
    if tag then head = head .. " |cffff3333" .. tag .. ":|r" end
    DEFAULT_CHAT_FRAME:AddMessage(head .. " " .. tostring(msg))
end

local function fill(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then dst[k] = {}; fill(dst[k], v) else dst[k] = v end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            fill(dst[k], v)
        end
    end
    return dst
end
T.FillDefaults = fill

local CORE_DEFAULTS = {
    settings = { minimap = { angle = 215, hide = false } },
    modules = {},
}

function T.InitDB(db)
    db = fill(db or {}, CORE_DEFAULTS)
    T.db = db
    for _, id in ipairs(T.moduleOrder) do
        local mod = T.modules[id]
        db.modules[id] = fill(db.modules[id] or {}, mod.defaults or {})
        if db.modules[id].enabled == nil then db.modules[id].enabled = true end
        mod.db = db.modules[id]
        if mod.OnInit then mod:OnInit() end
    end
    return db
end

---------------------------------------------------------------- modules

function T.RegisterModule(id, mod)
    mod.id = id
    mod.enabled = false
    T.modules[id] = mod
    T.moduleOrder[#T.moduleOrder + 1] = id
    return mod
end

function T.SetEnabled(id, on)
    local mod = T.modules[id]
    on = on and true or false
    mod.db.enabled = on
    if on == mod.enabled then return end
    mod.enabled = on
    if on and mod.OnEnable then mod:OnEnable() end
    if not on and mod.OnDisable then mod:OnDisable() end
end

function T.EnableModules()
    for _, id in ipairs(T.moduleOrder) do
        if T.modules[id].db.enabled then T.SetEnabled(id, true) end
    end
end

---------------------------------------------------------------- events
-- Handlers owned by a module only run while that module is enabled.

local handlers = {}
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, h in ipairs(handlers[event]) do
        if not h.mod or h.mod.enabled then h.fn(...) end
    end
end)

function T.RegisterEvent(event, mod, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(eventFrame.RegisterEvent, eventFrame, event) -- tolerate events this client lacks
    end
    table.insert(handlers[event], { mod = mod, fn = fn })
end

-- Diagnostics: when the game blocks something this addon did, say exactly what it was.
-- Registered first thing so it also catches calls made while the UI loads.
local blocked = {}
T.blocked = blocked
local diag = CreateFrame("Frame")
pcall(diag.RegisterEvent, diag, "ADDON_ACTION_FORBIDDEN")
pcall(diag.RegisterEvent, diag, "ADDON_ACTION_BLOCKED")
diag:SetScript("OnEvent", function(_, event, addon, func)
    if addon ~= ADDON then return end
    local what = tostring(func) .. " (" .. event .. ")"
    blocked[#blocked + 1] = what
    if T.db then T.db.lastBlocked = what end
    if DEFAULT_CHAT_FRAME then T.Print("|cffff4444Blockerat anrop:|r " .. what) end
end)

function T.After(sec, fn)
    if C_Timer and C_Timer.After then C_Timer.After(sec, fn) end
end

---------------------------------------------------------------- names

-- Lowercase that also handles Latin-1 letters like Å Ä Ö É Ü (UTF-8 C3 80..C3 9E -> C3 A0..C3 BE).
function T.Lower(s)
    s = string.lower(s)
    s = s:gsub("\195([\128-\158])", function(b)
        if b == "\151" then return "\195" .. b end -- multiplication sign, not a letter
        return "\195" .. string.char(b:byte() + 32)
    end)
    return s
end

local function upperFirst(s)
    local c3 = s:match("^\195([\160-\190])")
    if c3 and c3 ~= "\183" then
        return "\195" .. string.char(c3:byte() - 32) .. s:sub(3)
    end
    return s:sub(1, 1):upper() .. s:sub(2)
end

-- WoW: Forever names are "First Last": UnitName() returns the two parts separately (where the
-- realm used to be) and GetUnitName() joins them with a space. Only the full name is unique; a
-- first name on its own is used as a wildcard ("anyone called First").
--
-- "iron irene" / "Iron-Irene" / "  IRON " -> "Iron Irene" / "Iron Irene" / "Iron".
-- Returns nil for empty / invalid input (more than two parts, digits, punctuation).
function T.NormalizeName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("[%s%-]+", " "):gsub("^ ", ""):gsub(" $", "")
    local parts = {}
    for p in name:gmatch("%S+") do
        if #p > 24 or p:find("[%d%p%c]") then return nil end
        parts[#parts + 1] = upperFirst(T.Lower(p))
    end
    if #parts < 1 or #parts > 2 then return nil end
    return table.concat(parts, " ")
end

function T.SplitName(full)
    local first, last = full:match("^(%S+) (%S+)$")
    if first then return first, last end
    return full, nil
end

local function isSecret(v) return issecretvalue and v ~= nil and issecretvalue(v) end

-- Returns "First Last" (or "First" if the surname is unknown), first, last; nil if unreadable.
function T.UnitFullName(unit)
    local ok, first, last = pcall(UnitName, unit)
    if not ok or isSecret(first) or isSecret(last) or type(first) ~= "string" or first == "" then return nil end
    if last == "" then last = nil end
    local full = T.NormalizeName(last and (first .. " " .. last) or first)
    if not full then return nil end
    return full, T.SplitName(full)
end

function T.ClassColored(name, class)
    local c = class and class ~= "" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then
        return string.format("|cff%02x%02x%02x%s|r", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), name)
    end
    return "|cffff4040" .. name .. "|r"
end

function T.Ago(ts)
    local d = T.Now() - ts
    if d < 3600 then return math.max(1, math.floor(d / 60)) .. " min sedan" end
    if d < 86400 then return math.floor(d / 3600) .. " h sedan" end
    return math.floor(d / 86400) .. " d sedan"
end
