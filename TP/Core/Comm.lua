local _, T = ...

-- Shared addon-message layer for all modules. One prefix for the whole addon; each message starts
-- with the module's tag ("KL:..."). Only goes to (and is only accepted from) the guild, through
-- one throttled queue (the server allows short bursts per prefix, then about one message a second).

local C = {}
T.Comm = C

C.PREFIX = "TPGuild"
C.MAX_PAYLOAD = 240 -- 255 minus room for the module tag

local ChatInfo = C_ChatInfo
local listeners = {}

local function sendRaw(msg, dist, target)
    if ChatInfo and ChatInfo.SendAddonMessage then
        return ChatInfo.SendAddonMessage(C.PREFIX, msg, dist, target)
    elseif SendAddonMessage then
        return SendAddonMessage(C.PREFIX, msg, dist, target)
    end
end

function C.Init()
    if ChatInfo and ChatInfo.RegisterAddonMessagePrefix then
        ChatInfo.RegisterAddonMessagePrefix(C.PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(C.PREFIX)
    end
end

-- Where messages go right now: list of { dist, target }. The addon is for one guild only.
function C.Destinations()
    if IsInGuild and IsInGuild() then return { { "GUILD" } } end
    return {}
end

local queue, tokens, MAX_TOKENS, REFILL = {}, 8, 8, 1.2
local acc = 0
local pump = CreateFrame("Frame")
pump:Hide()
pump:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    if acc >= REFILL then
        tokens = math.min(MAX_TOKENS, tokens + math.floor(acc / REFILL))
        acc = acc % REFILL
    end
    while tokens > 0 and #queue > 0 do
        local m = table.remove(queue, 1)
        tokens = tokens - 1
        for _, d in ipairs(C.Destinations()) do
            pcall(sendRaw, m, d[1], d[2])
        end
    end
    if #queue == 0 and tokens >= MAX_TOKENS then self:Hide() end
end)

function C.Send(tag, payload)
    queue[#queue + 1] = tag .. ":" .. payload
    pump:Show()
end

-- fn(payload, sender) is only called while mod is enabled; sender is a normalized name, never you.
function C.Listen(tag, mod, fn)
    listeners[tag] = { mod = mod, fn = fn }
end

function C.OnMessage(prefix, msg, dist, sender)
    if prefix ~= C.PREFIX or dist ~= "GUILD" or type(msg) ~= "string" then return end
    sender = T.NormalizeName(sender)
    if not sender or sender == T.me then return end
    local tag, payload = msg:match("^(%w+):(.*)$")
    local l = tag and listeners[tag]
    if l and (not l.mod or l.mod.enabled) then l.fn(payload, sender, dist) end
end
