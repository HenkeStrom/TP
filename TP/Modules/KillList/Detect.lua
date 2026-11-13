local _, T = ...

-- Spots listed players via target, mouseover and nameplates, then shows a raid-warning style alert.
-- (Not the combat log: registering COMBAT_LOG_EVENT_UNFILTERED is a suspect for the "blocked from
-- an action only available to the Blizzard UI" popup on Forever, so it is left out.)

local K = T.KillList
local D = {}
K.Detect = D

local lastAlert = {}

local function zoneText()
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local sub = GetSubZoneText and GetSubZoneText() or ""
    if sub ~= "" and sub ~= zone then return sub .. ", " .. zone end
    return zone
end

local function inInstance()
    if not IsInInstance then return false end
    return IsInInstance() and true or false
end

-- certain = false when we couldn't read the player's surname.
function D.Alert(name, entries, class, force, certain)
    local lk = T.Lower(name)
    local now = GetTime()
    if not force and lastAlert[lk] and now - lastAlert[lk] < K.db.alertCooldown then return end
    if not force and not K.db.alertInInstances and inInstance() then return end
    lastAlert[lk] = now

    local owners, reasons = {}, {}
    local onlyWildcards = true
    for _, e in ipairs(entries) do
        owners[#owners + 1] = e.o
        if e.r and e.r ~= "" then reasons[#reasons + 1] = e.r end
        class = class or (e.c ~= "" and e.c) or nil
        if not K.IsWildcard(e) then onlyWildcards = false end
    end
    local who = T.ClassColored(name, class)
    -- Chat line first: it uses nothing that can fail, so it shows even if the parts below break.
    local line = who .. " syns i " .. zoneText() .. " - listad av " .. table.concat(owners, ", ")
    if #reasons > 0 then line = line .. " (" .. table.concat(reasons, "; ") .. ")" end
    if certain == false then
        line = line .. " |cffaaaaaa- efternamnet okänt, kan vara fel person|r"
    elseif onlyWildcards and not force then
        line = line .. " |cffaaaaaa- listad utan efternamn, kan vara fel person|r"
    end
    K.Print(line)

    -- force = the test button: report what the screen text and the sound actually did.
    local report = force and function(msg) K.Print("|cffaaaaaaTest: " .. msg .. "|r") end or function() end

    if RaidNotice_AddMessage and RaidWarningFrame then
        local ok, err = pcall(RaidNotice_AddMessage, RaidWarningFrame, "KILL LIST: " .. who .. " är nära!",
            ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.2, b = 0.2 })
        report(ok and "skärmtext visad." or ("skärmtext misslyckades: " .. tostring(err)))
    else
        report("skärmtext saknas i den här klienten (RaidNotice_AddMessage/RaidWarningFrame).")
    end

    if K.db.sound then
        local played, how = D.PlaySound()
        report(played and ("ljud spelat via " .. how .. ". Hörs inget: kolla att ljud är på i spelet.")
            or ("ljud gick inte att spela: " .. how))
    else
        report("ljud är avstängt (kryssrutan Ljud).")
    end
end

-- Tries the raid warning sound a few ways, since clients differ in which ones they accept.
-- Returns true + the way that worked, or false + what each attempt answered.
function D.PlaySound()
    local tried = {}
    local function try(label, fn, arg)
        if not fn then tried[#tried + 1] = label .. ": finns inte"; return false end
        local ok, willPlay = pcall(fn, arg, "Master")
        if ok and willPlay then return true end
        tried[#tried + 1] = label .. ": " .. (ok and "spelades inte" or tostring(willPlay))
        return false
    end
    if try("PlaySound", PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) then return true, "PlaySound" end
    if try("PlaySoundFile(id)", PlaySoundFile, 567397) then return true, "PlaySoundFile(id)" end
    if try("PlaySoundFile(sökväg)", PlaySoundFile, "Sound\\Interface\\RaidWarning.ogg") then
        return true, "PlaySoundFile(sökväg)"
    end
    return false, table.concat(tried, "; ")
end

-- Remembered under the full name and the first name, so first-name-only rows also show it.
local function recordSeen(name, class)
    local s = K.db.seen[T.Lower(name)] or {}
    s.name, s.zone, s.time = name, zoneText(), T.Now()
    if class and class ~= "" then s.class = class end
    K.db.seen[T.Lower(name)] = s
    local first, last = T.SplitName(name)
    if last then K.db.seen[T.Lower(first)] = s end
    if K.RefreshPanel then K:RefreshPanel() end
end

-- name is "First Last", or just "First" when the surname is unknown.
function D.Check(name, class)
    if not name or name == "" then return end
    local first, last = T.SplitName(name)
    local entries, certain = K.Lookup(first, last)
    if not entries then return end
    recordSeen(name, class)
    D.Alert(name, entries, class, false, certain)
end

function D.CheckUnit(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    local full = T.UnitFullName(unit)
    if not full or not K.Lookup(full) then return end
    local _, class = UnitClass(unit)
    D.Check(full, class)
end
