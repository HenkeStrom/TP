local ADDON, T = ...

-- Loaded last: wires up saved variables, login and the /tp command.

T.RegisterEvent("ADDON_LOADED", nil, function(name)
    if name ~= ADDON then return end
    TPDB = T.InitDB(TPDB)
end)

T.RegisterEvent("PLAYER_LOGIN", nil, function()
    T.me = T.UnitFullName("player") or T.NormalizeName((UnitName("player")))
    T.Comm.Init()
    -- 0.2.0 had an optional sync channel; joining it at login is what the game blocked.
    local old = T.db.settings.channel
    if old then
        T.db.settings.channel, T.db.settings.password = nil, nil
        T.After(10, function()
            T.Print("Synk-kanalen är borttagen. Är du kvar i kanalen kan du lämna den med /leave " .. old)
        end)
    end
    T.Minimap.Create()
    -- anything blocked while the UI was loading was printed before chat existed; repeat it
    T.After(6, function()
        for _, what in ipairs(T.blocked) do T.Print("|cffff4444Blockerat anrop vid laddning:|r " .. what) end
    end)
    T.EnableModules()
end)

---------------------------------------------------------------- diagnostics (/tp names, /tp debug)
-- Shows exactly what the client hands addons for player names, since Forever has two-part names.

local function show(v)
    if issecretvalue and issecretvalue(v) then return "<hemligt värde>" end
    if v == nil then return "nil" end
    local ok, s = pcall(tostring, v)
    if not ok then return "<går inte att läsa>" end
    return "[" .. s .. "] (" .. type(v) .. ", " .. #s .. " byte)"
end

local function dumpUnit(unit)
    if not UnitExists(unit) then T.Print(unit .. ": finns inte"); return end
    local ok, a, b = pcall(UnitName, unit)
    T.Print(unit .. " UnitName: 1=" .. show(ok and a or nil) .. "  2=" .. show(ok and b or nil))
    if GetUnitName then
        local ok1, full = pcall(GetUnitName, unit, true)
        local ok2, short = pcall(GetUnitName, unit, false)
        T.Print(unit .. " GetUnitName(true)=" .. show(ok1 and full or nil) .. "  (false)=" .. show(ok2 and short or nil))
    end
    if UnitFullName then
        local ok3, x, y = pcall(UnitFullName, unit)
        T.Print(unit .. " UnitFullName: 1=" .. show(ok3 and x or nil) .. "  2=" .. show(ok3 and y or nil))
    end
end

T.RegisterEvent("CHAT_MSG_ADDON", nil, function(prefix, msg, dist, sender)
    if T.debug and prefix == T.Comm.PREFIX then
        T.Print("debug: avsändare " .. show(sender) .. " via " .. tostring(dist) ..
            " -> tolkas som " .. show(T.NormalizeName(sender)))
    end
    T.Comm.OnMessage(prefix, msg, dist, sender)
end)

SLASH_TPGUILD1 = "/tp"
SlashCmdList.TPGUILD = function(input)
    input = (input or ""):lower():gsub("%s", "")
    if input == "names" then
        dumpUnit("player")
        dumpUnit("target")
        T.Print("T.me = " .. show(T.me))
    elseif input == "debug" then
        T.debug = not T.debug
        T.Print("Debug " .. (T.debug and "på: visar avsändare för alla <TP>-meddelanden." or "av."))
    elseif input == "minimap" then
        T.db.settings.minimap.hide = not T.db.settings.minimap.hide
        T.Minimap.Update()
    elseif input == "" then
        T.UI.Toggle()
    else
        T.UI.Toggle(T.modules[input] and input or "general")
    end
end
