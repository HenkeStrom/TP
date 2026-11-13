local _, T = ...

-- Kill List sync protocol, on top of T.Comm (tag "KL"):
--
--   H \t hash              hello: "this is what I have" (on login and every 30 min)
--   D \t hash              "I'm about to send my full list" (answer to a hello with a different hash)
--   E \t rec \n rec ...    one or more entries (live adds/removals and full-list dumps)
--
-- When someone says hello with a different hash, one random peer answers with a full dump; peers
-- with the same data as that peer stay quiet. The newcomer then dumps its own list too if it still
-- differs after merging (it had something the others lacked).

local K = T.KillList
local S = {}
K.Sync = S

S.TAG = "KL"
local HELLO_INTERVAL = 30 * 60
local MAX_MSG = T.Comm.MAX_PAYLOAD

local function send(msg) T.Comm.Send(S.TAG, msg) end

-- Packs serialized entries into as few "E" messages as fit.
function S.SendEntries(entries)
    local cur = "E"
    for _, e in ipairs(entries) do
        local rec = K.Serialize(e)
        local sep = (cur == "E") and "\t" or "\n"
        if #cur + #sep + #rec > MAX_MSG and cur ~= "E" then
            send(cur)
            cur, sep = "E", "\t"
        end
        cur = cur .. sep .. rec
    end
    if cur ~= "E" then send(cur) end
end

function S.SendAll()
    local all = {}
    for _, e in pairs(K.db.entries) do all[#all + 1] = e end
    S.SendEntries(all)
end

local pendingAnswer          -- token: I plan to answer a hello with a dump
local newcomerUntil = 0      -- I said hello recently
local lastDump = -math.huge
local awaiting               -- hash a dumping peer announced; nil once we match it

function S.Hello()
    newcomerUntil = GetTime() + 90
    send("H\t" .. K.Hash())
end

local function dumpNow()
    lastDump = GetTime()
    send("D\t" .. K.Hash())
    S.SendAll()
end

local function onHello(hash)
    if hash == K.Hash() or pendingAnswer then return end
    local token = {}
    pendingAnswer = token
    T.After(1 + math.random() * 6, function()
        if pendingAnswer ~= token then return end
        pendingAnswer = nil
        if K.enabled and GetTime() - lastDump > 20 then dumpNow() end
    end)
end

local function onDumpAnnounce(hash)
    -- Someone with the same data as me is already answering.
    if pendingAnswer and hash == K.Hash() then pendingAnswer = nil end
    if GetTime() < newcomerUntil and hash ~= K.Hash() then
        awaiting = hash
        newcomerUntil = 0
        T.After(45, function()
            if K.enabled and awaiting and awaiting ~= K.Hash() and GetTime() - lastDump > 20 then
                dumpNow()
            end
            awaiting = nil
        end)
    end
end

local function onEntries(body)
    local changed = {}
    for rec in body:gmatch("[^\n]+") do
        local e = K.Deserialize(rec)
        if e and K.Merge(e) then changed[#changed + 1] = e end
    end
    if awaiting and awaiting == K.Hash() then awaiting = nil end
    if #changed > 0 and K.OnEntriesChanged then K.OnEntriesChanged(changed) end
end

function S.OnMessage(payload)
    local op, body = payload:match("^(%u)\t(.*)$")
    if op == "H" then
        onHello(body)
    elseif op == "D" then
        onDumpAnnounce(body)
    elseif op == "E" then
        onEntries(body)
    end
end

T.Comm.Listen(S.TAG, K, S.OnMessage)

local ticking = false
function S.Start()
    T.After(8, S.Hello)
    if ticking then return end
    ticking = true
    local function tick()
        if K.enabled then S.Hello() end
        T.After(HELLO_INTERVAL, tick)
    end
    T.After(HELLO_INTERVAL, tick)
end
