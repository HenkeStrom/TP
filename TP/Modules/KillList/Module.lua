local _, T = ...

-- Kill List: actions, events, slash command and module registration.

local K = T.KillList

function K.Print(msg) T.Print(msg, "Kill List") end

local function refresh() if K.RefreshPanel then K:RefreshPanel() end end

local function needEnabled()
    if K.enabled then return true end
    K.Print("Kill List är avstängd. Slå på den i <TP>-fönstret.")
    return false
end

-- name may be nil: use the current target.
function K.AddPlayer(name, reason)
    if not needEnabled() then return end
    local class
    local targetName = UnitExists("target") and UnitIsPlayer("target") and T.UnitFullName("target")
    if not name or name == "" then
        if not targetName then
            K.Print("Skriv ett namn eller ta en spelare i target.")
            return
        end
        name = targetName
        class = select(2, UnitClass("target"))
    else
        local typed = T.NormalizeName(name)
        if not typed then K.Print("Ogiltigt namn. Skriv Förnamn eller Förnamn Efternamn."); return end
        name = typed
        if targetName and (targetName == typed or T.SplitName(targetName) == typed) then
            class = select(2, UnitClass("target"))
        end
    end
    local seen = K.db.seen[T.Lower(name)]
    class = class or (seen and seen.class)
    local e, err = K.Add(name, T.me, reason, class)
    if not e then K.Print(err); return end
    K.Sync.SendEntries({ e })
    K.Print(T.ClassColored(e.t, e.c) .. " tillagd" .. (e.r ~= "" and (" (" .. e.r .. ")") or "") .. ".")
    if K.IsWildcard(e) then
        K.Print("|cffaaaaaaInget efternamn: varnar för alla som heter " .. e.t .. ".|r")
    end
    refresh()
end

function K.RemoveKey(key)
    if not needEnabled() then return end
    local e, err = K.Remove(key)
    if not e then K.Print(err); return end
    K.Sync.SendEntries({ e })
    K.Print(e.t .. " borttagen från listan.")
    refresh()
end

-- Removes the player's own entry for a name (checks all of their characters).
function K.RemoveName(name)
    name = T.NormalizeName(name)
    if not name then K.Print("Ange ett namn."); return end
    for char in pairs(K.db.myChars) do
        local key = K.Key(name, char)
        local e = K.db.entries[key]
        if e and not e.d then return K.RemoveKey(key) end
    end
    if K.Lookup(name) then
        K.Print("Du kan bara ta bort namn du själv har lagt till.")
    else
        K.Print(name .. " finns inte på listan.")
    end
end

function K.OnEntriesChanged(changed)
    if #changed <= 3 then
        for _, e in ipairs(changed) do
            if e.d then
                K.Print(e.o .. " tog bort " .. e.t .. ".")
            else
                K.Print(e.o .. " lade till " .. T.ClassColored(e.t, e.c) .. (e.r ~= "" and (" (" .. e.r .. ")") or "") .. ".")
            end
        end
    else
        K.Print(#changed .. " ändringar synkade.")
    end
    refresh()
end

function K.TestAlert()
    -- t is required: Alert asks K.IsWildcard(e), which reads e.t
    K.Detect.Alert("Testganker", { { t = "Testganker", o = T.me or "?", r = "testvarning", c = "ROGUE" } }, "ROGUE", true)
end

---------------------------------------------------------------- lifecycle

function K:OnEnable()
    self.db.myChars[T.me] = true
    K.Prune()
    K.Sync.Start()
end

function K:OnSyncNow()
    K.Sync.Hello()
end

T.RegisterEvent("PLAYER_TARGET_CHANGED", K, function() K.Detect.CheckUnit("target") end)
T.RegisterEvent("UPDATE_MOUSEOVER_UNIT", K, function() K.Detect.CheckUnit("mouseover") end)
T.RegisterEvent("NAME_PLATE_UNIT_ADDED", K, function(unit) K.Detect.CheckUnit(unit) end)

---------------------------------------------------------------- slash: /kl

local HELP = {
    "/kl - öppna Kill List",
    "/kl add Förnamn Efternamn, anledning - lägg till (komma före anledningen)",
    "/kl add - lägg till ditt target",
    "/kl remove <namn> - ta bort ditt eget tillägg",
    "/kl list - skriv ut listan i chatten",
    "/kl test - testvarning",
    "Inställningar finns i fönstret (/tp eller minimap-knappen).",
}

SLASH_TPKILLLIST1 = "/kl"
SLASH_TPKILLLIST2 = "/killlist"
SlashCmdList.TPKILLLIST = function(input)
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" then
        T.UI.Toggle(K.id)
    elseif cmd == "add" then
        -- "Förnamn Efternamn, anledning" - the comma separates the name from the reason
        local name, reason = rest:match("^([^,]*),%s*(.*)$")
        if not name then name, reason = rest, "" end
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" and not T.NormalizeName(name) then
            K.Print("Skriv: /kl add Förnamn Efternamn, anledning")
            return
        end
        K.AddPlayer(name ~= "" and name or nil, reason)
    elseif cmd == "remove" or cmd == "del" or cmd == "rm" then
        K.RemoveName(rest)
    elseif cmd == "list" then
        local list = K.ActiveList()
        if #list == 0 then K.Print("Listan är tom.") end
        for _, item in ipairs(list) do
            local e = item.e
            K.Print(T.ClassColored(e.t, e.c) .. " - " .. e.o .. (e.r ~= "" and (": " .. e.r) or ""))
        end
    elseif cmd == "test" then
        K.TestAlert()
    else
        for _, line in ipairs(HELP) do K.Print(line) end
    end
end

T.RegisterModule("killlist", K)
