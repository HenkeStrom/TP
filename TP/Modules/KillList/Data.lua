local _, T = ...

-- Kill List data model. Pure Lua (no WoW API) so it can be tested off-game.
--
-- Each entry is one person's listing of one target:
--   key = lower(target) .. ":" .. lower(owner)
--   { t = "Target", o = "Owner", r = "reason", c = "CLASS" or "", ts = serverTime, d = true when removed }
-- Two people listing the same target gives two entries, so removing yours never touches theirs.
-- Removals are kept as tombstones (d = true) so they spread to people who were offline.

local K = T.KillList or {}
T.KillList = K

K.title = "Kill List"
K.desc = "Delad lista över gankers, varnar när de syns"
K.TOMBSTONE_TTL = 60 * 24 * 3600   -- forget removals after 60 days
K.REASON_MAX = 80

K.defaults = {
    entries = {},
    myChars = {},
    seen = {},
    alertCooldown = 90,
    sound = true,
    alertInInstances = false,
}

local Lower = T.Lower

function K:OnInit()
    K.dirty = true
end

-- For tests: give the module a fresh database.
function K.SetDB(db)
    K.db = T.FillDefaults(db or {}, K.defaults)
    K.dirty = true
end

function K.Key(target, owner)
    return Lower(target) .. ":" .. Lower(owner)
end

local function sanitize(s, max)
    s = tostring(s or ""):gsub("[\t\n\r|]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #s > max then
        s = s:sub(1, max)
        s = s:gsub("[\192-\255][\128-\191]*$", "") -- don't leave half a UTF-8 character
    end
    return s
end
K.Sanitize = sanitize

---------------------------------------------------------------- merge

-- Returns true if the local data changed.
function K.Merge(e)
    if type(e) ~= "table" or not e.t or not e.o or type(e.ts) ~= "number" then return false end
    if e.d and e.ts < T.Now() - K.TOMBSTONE_TTL then return false end
    local key = K.Key(e.t, e.o)
    local cur = K.db.entries[key]
    if cur then
        if e.ts < cur.ts then return false end
        if e.ts == cur.ts and (cur.d or not e.d) then return false end
    end
    K.db.entries[key] = { t = e.t, o = e.o, r = e.r or "", c = e.c or "", ts = e.ts, d = e.d and true or nil }
    K.dirty = true
    return true
end

function K.IsMine(entry)
    return K.db.myChars[entry.o] == true
end

function K.Add(target, owner, reason, class)
    target = T.NormalizeName(target)
    if not target then return nil, "Ogiltigt namn." end
    local key = K.Key(target, owner)
    local cur = K.db.entries[key]
    local ts = T.Now()
    if cur and ts <= cur.ts then ts = cur.ts + 1 end
    local e = { t = target, o = owner, r = sanitize(reason, K.REASON_MAX), c = class or (cur and cur.c) or "", ts = ts }
    K.db.entries[key] = e
    K.dirty = true
    return e
end

-- Removes an entry the player owns (on any of their characters). Returns the tombstone or nil, err.
function K.Remove(key)
    local cur = K.db.entries[key]
    if not cur or cur.d then return nil, "Finns inte på listan." end
    if not K.IsMine(cur) then return nil, "Du kan bara ta bort namn du själv har lagt till." end
    local ts = T.Now()
    if ts <= cur.ts then ts = cur.ts + 1 end
    local e = { t = cur.t, o = cur.o, r = "", c = cur.c, ts = ts, d = true }
    K.db.entries[key] = e
    K.dirty = true
    return e
end

function K.Prune()
    local cutoff = T.Now() - K.TOMBSTONE_TTL
    for key, e in pairs(K.db.entries) do
        if e.d and e.ts < cutoff then K.db.entries[key] = nil; K.dirty = true end
    end
end

---------------------------------------------------------------- lookups

-- index[lower first name] = { { e = entry, last = lower surname or nil (wildcard) }, ... }
local index, hash
local function rebuild()
    index = {}
    local keys = {}
    for key, e in pairs(K.db.entries) do
        keys[#keys + 1] = key
        if not e.d then
            local first, last = T.SplitName(e.t)
            local lk = Lower(first)
            index[lk] = index[lk] or {}
            table.insert(index[lk], { e = e, last = last and Lower(last) })
        end
    end
    table.sort(keys)
    local h = 5381
    for _, key in ipairs(keys) do
        local e = K.db.entries[key]
        local s = key .. "	" .. e.ts .. (e.d and "x" or "")
        for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    end
    hash = string.format("%08x", h)
    K.dirty = false
end

-- An entry without a surname matches everyone with that first name.
function K.IsWildcard(e)
    return not e.t:find(" ")
end

-- Active entries matching a player, or nil. `first` may also be a full "First Last".
-- With a surname: exact entries plus first-name wildcards. Without one (unknown), every entry
-- with that first name matches, and the second return value (certain) is false.
function K.Lookup(first, last)
    if K.dirty then rebuild() end
    if not last then first, last = T.SplitName(first) end
    local list = index[Lower(first)]
    if not list then return nil end
    local ll = last and Lower(last)
    local out = {}
    for _, it in ipairs(list) do
        if not it.last or not ll or it.last == ll then out[#out + 1] = it.e end
    end
    if #out == 0 then return nil end
    return out, ll ~= nil
end

function K.Hash()
    if K.dirty then rebuild() end
    return hash
end

-- Sorted list of active entries for the UI.
function K.ActiveList()
    local list = {}
    for key, e in pairs(K.db.entries) do
        if not e.d then list[#list + 1] = { key = key, e = e } end
    end
    table.sort(list, function(a, b)
        if a.e.t ~= b.e.t then return Lower(a.e.t) < Lower(b.e.t) end
        return a.e.ts < b.e.ts
    end)
    return list
end

---------------------------------------------------------------- wire format

-- target \t owner \t ts \t deleted \t class \t reason
function K.Serialize(e)
    return table.concat({ e.t, e.o, tostring(e.ts), e.d and "1" or "0", e.c or "", e.r or "" }, "\t")
end

function K.Deserialize(s)
    local t, o, ts, d, c, r = s:match("^([^\t]+)\t([^\t]+)\t(%d+)\t([01])\t([^\t]*)\t([^\t]*)$")
    if not t then return nil end
    t, o = T.NormalizeName(t), T.NormalizeName(o)
    if not t or not o then return nil end
    return { t = t, o = o, ts = tonumber(ts), d = d == "1" or nil, c = c:match("^%u+$") or "", r = sanitize(r, K.REASON_MAX) }
end
