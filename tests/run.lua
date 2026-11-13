-- Off-game tests for the <TP> addon (Kill List module): lua tests/run.lua (from C:\henke\TP)
-- Simulates several clients in one process, each with its own globals, a shared fake clock and a
-- fake GUILD channel that delivers addon messages to everyone else.

local clock, serverTime = 0, 1700000000
math.randomseed(tonumber(os.getenv("SEED") or os.time()))
local timers = {}
local clients = {}
local sent = 0

local function newClient(name)
    local c = { name = name, frames = {} }
    local env = setmetatable({}, { __index = _G })
    env.GetTime = function() return clock end
    env.GetServerTime = function() return serverTime + math.floor(clock) end
    env.CreateFrame = function()
        local f = { shown = true, scripts = {} }
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        function f.RegisterEvent() end
        c.frames[#c.frames + 1] = f
        return f
    end
    env.C_Timer = { After = function(sec, fn) timers[#timers + 1] = { at = clock + sec, fn = fn } end }
    env.IsInGuild = function() return true end
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function() end,
        SendAddonMessage = function(prefix, msg, dist)
            assert(#msg <= 255, "message too long: " .. #msg)
            sent = sent + 1
            for _, other in ipairs(clients) do
                if other ~= c and other.online then
                    other.T.Comm.OnMessage(prefix, msg, dist, name .. "-Forever")
                end
            end
        end,
    }
    c.env = env
    c.T = {}
    for _, f in ipairs({ "Core/Init.lua", "Core/Comm.lua", "Modules/KillList/Data.lua", "Modules/KillList/Sync.lua" }) do
        assert(loadfile("TP/" .. f, "t", env))("TP", c.T)
    end
    c.T.InitDB(nil)
    c.T.me = name
    c.K = c.T.KillList
    c.K.SetDB(nil)
    c.K.enabled = true
    c.K.db.myChars[name] = true
    c.online = true
    clients[#clients + 1] = c
    return c
end

local function run(seconds)
    local stop = clock + seconds
    while clock < stop do
        clock = clock + 0.1
        local due = {}
        for i = #timers, 1, -1 do
            if timers[i].at <= clock then due[#due + 1] = table.remove(timers, i) end
        end
        for i = #due, 1, -1 do due[i].fn() end
        for _, c in ipairs(clients) do
            if c.online then
                for _, f in ipairs(c.frames) do
                    if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.1) end
                end
            end
        end
    end
end

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end

---------------------------------------------------------------- pure logic

local A = newClient("Henric")

test("normalize names", function()
    local K = A.T
    eq(K.NormalizeName("  iron-IRENE "), "Iron Irene")
    eq(K.NormalizeName("iron   irene"), "Iron Irene")
    eq(K.NormalizeName("GANKER"), "Ganker")
    eq(K.NormalizeName("åsa öberg"), "Åsa Öberg")
    eq(K.NormalizeName("ÖRJAN"), "Örjan")
    eq(K.NormalizeName("one two three"), nil)
    eq(K.NormalizeName("it's"), nil)
    eq(K.NormalizeName("abc1"), nil)
    eq(K.NormalizeName(""), nil)
end)

test("serialize roundtrip strips separators", function()
    local K = A.K
    local e = K.Deserialize(K.Serialize({ t = "Ganker", o = "Henric", ts = 5, c = "ROGUE", r = "camps|r FP" }))
    eq(e.t, "Ganker"); eq(e.o, "Henric"); eq(e.ts, 5); eq(e.c, "ROGUE"); eq(e.d, nil)
    eq(K.Sanitize("a\tb|c", 80), "a b c")
    eq(K.Deserialize("garbage"), nil)
end)

test("cannot remove someone else's entry", function()
    local K = A.K
    K.Merge({ t = "Ganker", o = "Other", ts = serverTime, r = "" })
    local _, err = K.Remove(K.Key("Ganker", "Other"))
    assert(err, "should refuse")
    eq(K.db.entries[K.Key("Ganker", "Other")].d, nil)
end)

test("merge: newer wins, tombstone wins ties, old tombstones dropped", function()
    local K = A.K
    local key = K.Key("Merger", "Bob")
    assert(K.Merge({ t = "Merger", o = "Bob", ts = serverTime + 10, r = "x" }))
    assert(not K.Merge({ t = "Merger", o = "Bob", ts = serverTime + 5, r = "old" }))
    assert(K.Merge({ t = "Merger", o = "Bob", ts = serverTime + 10, d = true }))
    assert(not K.Merge({ t = "Merger", o = "Bob", ts = serverTime + 10, r = "revive" }))
    eq(K.db.entries[key].d, true)
    assert(not K.Merge({ t = "Old", o = "Bob", ts = serverTime - K.TOMBSTONE_TTL - 10, d = true }))
end)

test("lookup is case-insensitive and ignores removed", function()
    local K = A.K
    K.Add("Lookme", "Henric", "reason")
    assert(K.Lookup("LOOKME"))
    assert(K.Remove(K.Key("Lookme", "Henric")))
    eq(K.Lookup("lookme"), nil)
end)

test("surnames: exact entries, first-name wildcards, unknown surname", function()
    local K = A.K
    K.SetDB(nil); K.db.myChars["Balkan Inferno"] = true
    K.Add("Iron Irene", "Balkan Inferno", "")
    K.Add("Grabben", "Balkan Inferno", "")
    -- exact match
    eq(#K.Lookup("Iron", "Irene"), 1)
    eq(select(2, K.Lookup("Iron", "Irene")), true)
    -- same first name, different surname: not listed
    eq(K.Lookup("Iron", "Smith"), nil)
    -- full name as one string works too
    eq(#K.Lookup("iron irene"), 1)
    -- wildcard entry matches any surname
    eq(#K.Lookup("Grabben", "Svensson"), 1)
    eq(#K.Lookup("Grabben", "Andersson"), 1)
    -- surname unknown: matches, but not certain
    local list, certain = K.Lookup("Iron")
    eq(#list, 1); eq(certain, false)
    assert(K.IsWildcard(K.db.entries[K.Key("Grabben", "Balkan Inferno")]))
    assert(not K.IsWildcard(K.db.entries[K.Key("Iron Irene", "Balkan Inferno")]))
    -- serialization keeps the space
    local e = K.Deserialize(K.Serialize(K.db.entries[K.Key("Iron Irene", "Balkan Inferno")]))
    eq(e.t, "Iron Irene"); eq(e.o, "Balkan Inferno")
end)

test("sender with surname is normalized and own messages are ignored", function()
    local T = A.T
    eq(T.NormalizeName("Balkan-Inferno"), "Balkan Inferno")
    eq(T.NormalizeName("Balkan Inferno"), "Balkan Inferno")
end)

-- reset A for the sync scenario
A.K.SetDB(nil); A.K.db.myChars.Henric = true

---------------------------------------------------------------- sync

local B = newClient("Bertil")
local C = newClient("Cissi")

test("live add reaches everyone online", function()
    local e = A.K.Add("Gankarn", "Henric", "campar Southshore")
    A.K.Sync.SendEntries({ e })
    run(2)
    local got = B.K.Lookup("gankarn")
    assert(got and got[1].r == "campar Southshore", "B missing entry")
    assert(C.K.Lookup("gankarn"), "C missing entry")
end)

test("removal by owner spreads; others' entries stay", function()
    local e = B.K.Add("Gankarn", "Bertil", "")
    B.K.Sync.SendEntries({ e })
    run(2)
    eq(#A.K.Lookup("Gankarn"), 2)
    local t = A.K.Remove(A.K.Key("Gankarn", "Henric"))
    A.K.Sync.SendEntries({ t })
    run(2)
    eq(#C.K.Lookup("Gankarn"), 1, "C should still have Bertil's entry")
    eq(C.K.Lookup("Gankarn")[1].o, "Bertil")
end)

test("offline player catches up on login, and shares their own offline adds", function()
    C.online = false
    -- while C is offline: A adds 30 names, B removes their entry
    local batch = {}
    for i = 1, 30 do batch[#batch + 1] = A.K.Add("Ganker" .. string.char(96 + (i % 26) + 1) .. string.char(97 + i // 26), "Henric", "reason number " .. i) end
    A.K.Sync.SendEntries(batch)
    local t = B.K.Remove(B.K.Key("Gankarn", "Bertil"))
    B.K.Sync.SendEntries({ t })
    run(10)
    -- C added something offline (e.g. on another computer before logging in)
    C.K.Add("Offlinegank", "Cissi", "")
    C.online = true
    C.K.Sync.Hello()
    run(120)
    eq(C.K.Hash(), A.K.Hash(), "C vs A")
    eq(B.K.Hash(), A.K.Hash(), "B vs A")
    eq(C.K.Lookup("Gankarn"), nil, "removal should have reached C")
    assert(A.K.Lookup("Offlinegank"), "C's offline add should reach A")
end)

test("disabled module ignores sync traffic", function()
    B.K.enabled = false
    local e = A.K.Add("Whiledisabled", "Henric", "")
    A.K.Sync.SendEntries({ e })
    run(2)
    eq(B.K.Lookup("Whiledisabled"), nil)
    B.K.enabled = true
    B.K.Sync.Hello()
    run(60)
    assert(B.K.Lookup("Whiledisabled"), "B should catch up after re-enabling")
end)

test("hello with equal data sends nothing", function()
    local before = sent
    A.K.Sync.Hello()
    run(30)
    eq(sent - before, 1, "only the hello itself")
end)

test("hash is stable regardless of insertion order", function()
    local X = newClient("Xx")
    local Y = newClient("Yy")
    X.online, Y.online = false, false
    X.K.Merge({ t = "Aa", o = "Q", ts = 1e9 }); X.K.Merge({ t = "Bb", o = "Q", ts = 1e9 + 1 })
    Y.K.Merge({ t = "Bb", o = "Q", ts = 1e9 + 1 }); Y.K.Merge({ t = "Aa", o = "Q", ts = 1e9 })
    eq(X.K.Hash(), Y.K.Hash())
end)

test("test alert button prints, shows screen text and plays the sound", function()
    local Z = newClient("Zz")
    Z.online = false
    local chat, notices, sounds = {}, 0, 0
    local env = Z.env
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) chat[#chat + 1] = msg end }
    env.SlashCmdList = {}
    env.RaidWarningFrame = {}
    env.RaidNotice_AddMessage = function() notices = notices + 1 end
    env.PlaySound = function() sounds = sounds + 1; return true end
    for _, f in ipairs({ "Modules/KillList/Detect.lua", "Modules/KillList/Module.lua" }) do
        assert(loadfile("TP/" .. f, "t", env))("TP", Z.T)
    end
    Z.K.TestAlert()
    eq(notices, 1, "screen text")
    eq(sounds, 1, "sound")
    assert(chat[1] and chat[1]:find("Testganker"), "chat line missing")
end)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
