-- Contains classes and/or functions that may be needed into client and/or server files
WQS_Shared = {}
WQS_SharedGuiUtil = {}

--- Verbose diagnostics, off by default (sandbox option WQS_DebugLog_opt).
--- A single completed run already emits around a thousand tagged lines, so
--- anything that fires per tick or per snapshot stays behind this flag: a real
--- error is worthless once it is buried. Turn it on for testing only.
--- Read at call time, never cached; sandbox values always exist after load.
function WQS_Shared.DLog(msg)
    if SandboxVars.WQS_DebugLog_opt then
        print("WQS_DBG " .. msg)
    end
end

-- WQS_Shared.BGColor = {r=0.37, g=0.47, b=0.54, a=1.0}
-- WQS_Shared.BGColorMouseOver = {r=0.25, g=0.42, b=0.63, a=1.0}; --blu ok
-- WQS_Shared.BorderColor = {r=0.5, g=0.5, b=1, a=0.7};

WQS_Shared.BGColor1 = { r = 0.13, g = 0.52, b = 0.82, a = 1.0 } --blu1 ok
WQS_Shared.BGColor2 = { r = 0.26, g = 0.5, b = 0.93, a = 1.0 }  --blu2 chiaro
WQS_Shared.BGColor3 = { r = 0.37, g = 0.47, b = 0.54, a = 1.0 } --verdino
WQS_Shared.BGColor4 = { r = 0.41, g = 0.59, b = 0.45, a = 1.0 } --verde
WQS_Shared.BGColor5 = { r = 0.95, g = 0.81, b = 0.44, a = 1.0 } --giallino chiaro #f2cf70

WQS_Shared.BorderColor1 = WQS_Shared.BGColor1
WQS_Shared.BorderColor2 = WQS_Shared.BGColor2
WQS_Shared.BorderColor3 = { r = 1, g = 0.93, b = 0.47, a = 0.8 }
WQS_Shared.BorderColor4 = { r = 1, g = 0.93, b = 0.77, a = 0.8 }
WQS_Shared.BorderColor5 = { r = 0.74, g = 0.75, b = 0.77, a = 0.9 }

WQS_Shared.BGColor = { r = 0.25, g = 0.42, b = 0.63, a = 1.0 }; --blu ok
WQS_Shared.BGColorMouseOver = { r = 0.41, g = 0.59, b = 0.45, a = 1.0 }
--WQS_Shared.BorderColor =WQS_Shared.BGColorMouseOver
WQS_Shared.BGColorMouseOver = WQS_Shared.BGColor2 --1
WQS_Shared.BorderColor = WQS_Shared.BorderColor3

--WQS_COLTIT = " <RGB:0.13,0.52,0.82> "
WQS_COLTIT = " <RGB:0.20,0.55,0.85>  "
WQS_COLSUBTIT = " <RGB:0.95,0.81,0.44> "
WQS_COLWHITE = " <RGB:1,1,1> "
WQS_SMALL = " <SIZE:small> "
WQS_H2 = " <H2> "
WQS_BR = " <LINE> "
WQS_SPACE = " <SPACE> "
WQS_COLGREEN = " <RGB:0.4,0.9,0> "
WQS_COLGREEN = " <RGB:0,0.8,0> "
--WQS_COLGREEN = " <RGB:0.39,0.85,0.20> "
WQS_COLRED = " <RGB:1,0,0> "
--WQS_COLSUBTIT2 = " <RGB:1,1,0> " --giallo
--WQS_COLSUBTIT2 = " <RGB:0,1,1> " --cyano
--WQS_COLSUBTIT2 = " <RGB:0.5,1,0.83> " --acquamarina
--WQS_COLSUBTIT2 = " <RGB:0.4,0.8,0.66> " --mediumaquamarine
--WQS_COLSUBTIT2 = " <RGB:0,0.8,0.82> " --turquoise
--WQS_COLSUBTIT2 = " <RGB:0.12,0.70,0.66> " --lightseagreen
--WQS_COLSUBTIT2 = " <RGB:0.12,0.56,1> " --dodgerblue
--WQS_COLSUBTIT2 = " <RGB:0.12,0.72,1> "     --dodgerblue
WQS_COLSUBTIT2 = " <RGB:0.20,0.66,0.85> "


--#f58500 -> color(srgb 0.96 0.52 0)

WQS_Shared.GuiCol = function(col, txt, restoreWhite)
    restoreWhite = restoreWhite or true
    local ret = col .. txt
    if restoreWhite then
        ret = ret .. WQS_COLWHITE
    end
    return ret
end

WQS_Shared.HaveItemInInventory = function(itemType)
    local player = WQS.GetCurrentPlayer();
    if player then
        local count = player:getInventory():getItemCountRecurse(itemType) or 0
        if count > 0 then
            -- print(" ### WQS have item "..itemType)
            return true
        end
    end
    return false
end

WQS_Shared.IsActiveRepeatersMode = function()
    --return SandboxVars.WQS_RepeatersMode_opt or false;
    if SandboxVars.WQS_RepeatersModeHowMany_opt > 0 then
        return true
    end
    return false
end

WQS_Shared.getRepeaterFragmentLocationItemId = function(get_full_id)
    local ret = nil
    if (get_full_id) then
        ret = "WQS_item_list.wqs_repeater_location_fragment"
    else
        ret = "wqs_repeater_location_fragment"
    end
    return ret
end

WQS_Shared.getExtractionItemId = function(get_full_id)
    local ret = nil
    if (get_full_id) then
        ret = "Radio.WalkieTalkie5"
    else
        ret = "WalkieTalkie5"
    end

    return ret
    -- return WQS_ExtractionItem or "WalkieTalkie5"
end

WQS_Shared.getAntennaItemId = function(get_full_id)
    local ret = ""
    if (get_full_id) then
        ret = "WQS_item_list.wqs_radioantenna"
    else
        ret = "wqs_radioantenna"
    end
    return ret
end

WQS_Shared.getRepeaterDynamicMapItemId = function(get_full_id)
    local ret = ""
    if (get_full_id) then
        ret = "WQS_item_list.wqs_repeater_map_dynamic"
    else
        ret = "wqs_repeater_map_dynamic"
    end
    return ret
end

WQS_Shared.getRepeaterMaxActivationDistance = function()
    local ret = 7
    return ret
end

-- ##############################################################
-- MP SESSION SNAPSHOT (server authoritative)
--
-- The faction session lives on the server (server/WQS_MPSession.lua).
-- This client side cache holds the last snapshot pushed by the server and
-- exposes it read only. Nothing here may mutate session state: every change
-- goes through WQS_Session.Send and comes back as a new snapshot.
-- ##############################################################

WQS_Session = {}

WQS_Session.MODULE = "WQS_MP"
WQS_Session.Data = nil
WQS_Session.HasFaction = true
WQS_Session.LastJoinAttempt = 0
WQS_Session.NoFactionUntil = 0

--- Singleplayer stand in for both the faction key and the username.
--- Must match SP_KEY in server/WQS_MPSession.lua: the client finds itself in
--- the roster by name, and IsoPlayer:getUsername() is "Bob" by default in SP.
WQS_Session.SP_USER = "@sp"

WQS_Session.IsSinglePlayer = function()
    return (not isClient()) and (not isServer())
end

WQS_Session.Get = function()
    return WQS_Session.Data
end

WQS_Session.IsReady = function()
    return WQS_Session.Data ~= nil
end

WQS_Session.GetState = function()
    if not WQS_Session.Data then
        return "NONE"
    end
    return WQS_Session.Data.state
end

WQS_Session.IsUnlocked = function()
    local s = WQS_Session.GetState()
    return (s == "UNLOCKED") or (s == "DONE")
end

WQS_Session.IsRunning = function()
    return WQS_Session.GetState() == "RUNNING"
end

WQS_Session.IsPending = function()
    return WQS_Session.GetState() == "PENDING"
end

WQS_Session.GetSelfName = function()
    if WQS_Session.IsSinglePlayer() then
        return WQS_Session.SP_USER
    end
    local pl = WQS.GetCurrentPlayer()
    if not pl then
        return nil
    end
    return pl:getUsername()
end

WQS_Session.GetSelfMember = function()
    local d = WQS_Session.Data
    if not d or not d.members then
        return nil
    end
    local me = WQS_Session.GetSelfName()
    for i = 1, #d.members do
        if d.members[i].u == me then
            return d.members[i]
        end
    end
    return nil
end

WQS_Session.IsSelfReady = function()
    local m = WQS_Session.GetSelfMember()
    return (m ~= nil) and (m.ready == true)
end

--- True only while this player is a live participant of a running session.
--- The extraction event loop (zombie spawning) is gated on this: a dead or
--- already extracted member must not keep spawning for the rest of the team.
WQS_Session.IsSelfParticipating = function()
    if not WQS_Session.IsRunning() and not WQS_Session.IsUnlocked() then
        return false
    end
    local m = WQS_Session.GetSelfMember()
    if not m then
        return false -- dead or dropped from the effective roster
    end
    if m.extracted then
        return false
    end
    return true
end

WQS_Session.GetReadyCount = function()
    local d = WQS_Session.Data
    if not d then return 0 end
    return d.readyCount or 0
end

WQS_Session.GetReadyTotal = function()
    local d = WQS_Session.Data
    if not d then return 0 end
    return d.readyTotal or 0
end

WQS_Session.GetArrivedCount = function()
    local d = WQS_Session.Data
    if not d then return 0 end
    return d.arrivedCount or 0
end

WQS_Session.GetArrivedTotal = function()
    local d = WQS_Session.Data
    if not d then return 0 end
    return d.arrivedTotal or 0
end

WQS_Session.GetElapsedMinutes = function()
    local d = WQS_Session.Data
    if not d then return 0 end
    return d.elapsed or 0
end

WQS_Session.GetDurationMinutes = function()
    local d = WQS_Session.Data
    if not d then return 0 end
    return d.duration or 0
end

WQS_Session.GetTimeLeftMinutes = function()
    return WQS_Session.GetDurationMinutes() - WQS_Session.GetElapsedMinutes()
end

WQS_Session.GetExtractionMap = function()
    local d = WQS_Session.Data
    if not d then return nil end
    return d.map
end

--- Roster line for the tracker: green = condition met, red = still missing.
--- Which condition is coloured depends on the gate currently open.
WQS_Session.GetMemberRosterTxt = function(useArrived)
    local d = WQS_Session.Data
    if not d or not d.members or #d.members == 0 then
        return ""
    end
    local ret = ""
    for i = 1, #d.members do
        local m = d.members[i]
        local ok = false
        if useArrived then
            ok = m.arrived
        else
            ok = m.ready
        end
        if ok then
            ret = ret .. WQS_COLGREEN .. m.u .. WQS_COLWHITE .. "  "
        else
            ret = ret .. WQS_COLRED .. m.u .. WQS_COLWHITE .. "  "
        end
    end
    return ret
end

--- Sends a command to the session host.
--- In MP that is the server, over the wire. In SP the host module lives in
--- this same Lua state and no event would ever deliver a client command, so
--- the call is handed over directly. Without this branch the whole mod was
--- dead in singleplayer: every command was dropped and the snapshot stayed nil
--- forever, which pinned the state machine at "NONE".
WQS_Session.Send = function(command, args)
    if isClient() then
        sendClientCommand(WQS_Session.MODULE, command, args or {})
        return true
    end
    if isServer() then
        print("WQS_MP Send ignored, this is the server: " .. tostring(command))
        return false
    end
    if WQS_MPSession and WQS_MPSession.LocalCommand then
        WQS_MPSession.LocalCommand(command, args or {})
        return true
    end
    print("WQS_MP Send failed, session module not loaded yet: " .. tostring(command))
    return false
end

--- Join is both the first contact and the reconnect repair path.
--- It used to fire every few seconds forever; the server pushes changes on its
--- own, so once a snapshot is held this is only a slow heartbeat. A player
--- with no faction backs off entirely instead of filling the server log.
WQS_Session.RequestJoin = function()
    local now = getTimeInMillis()

    if (not WQS_Session.HasFaction) and (now < WQS_Session.NoFactionUntil) then
        WQS_Shared.DLog("join skipped, no group backoff " ..
            tostring(WQS_Session.NoFactionUntil - now) .. "ms left")
        return
    end

    local wait = 3000
    if WQS_Session.Data ~= nil then
        wait = 30000
    end
    if (now - WQS_Session.LastJoinAttempt) < wait then
        WQS_Shared.DLog("join throttled, " ..
            tostring(wait - (now - WQS_Session.LastJoinAttempt)) .. "ms left")
        return
    end
    WQS_Session.LastJoinAttempt = now
    -- Unconditional: capped at one per 30s once a snapshot is held, one per 3s
    -- before that. Measuring the delay between a group edit and the resulting
    -- session swap is impossible without a timestamp on this side.
    print("WQS_MP join requested, snapshot=" .. tostring(WQS_Session.Data ~= nil) ..
        " hasGroup=" .. tostring(WQS_Session.HasFaction))
    WQS_Session.Send("Join", {})
end

--- Group membership changed, so the cached session key may be stale.
--- Both throttles have to be cleared, not just one: the no group backoff is a
--- hard return placed before the interval check, so resetting LastJoinAttempt
--- alone leaves the blocked to running transition waiting out the full 30s.
--- This only shortens the wait; the actual key comparison stays on the server,
--- which is why the reset is unconditional and does not inspect the group.
---
--- Vanilla fires both events behind a GameClient.bClient guard
--- (SafeHouse.java, GameClient.java), so they never reach a dedicated server
--- or singleplayer. Registering here is still safe because LuaEventManager
--- declares both names regardless of context.
local function WQS_OnGroupChanged(what)
    print("WQS_MP group event: " .. what)
    WQS_Session.LastJoinAttempt = 0
    WQS_Session.NoFactionUntil = 0
end

Events.SyncFaction.Add(function() WQS_OnGroupChanged("SyncFaction") end)
Events.OnSafehousesChanged.Add(function() WQS_OnGroupChanged("OnSafehousesChanged") end)

--- Overridden by the client files that own the matching UI feedback.
--- Defined here so the dedicated server, which never loads media/lua/client,
--- can still route a message without blowing up.
WQS_Session.OnAddTargetResult = function(ok, args) end
WQS_Session.OnReadyRejected = function(args) end

WQS_Session.OnServerMessage = function(command, args)
    if command == "Sync" then
        local hadSnapshot = WQS_Session.Data ~= nil
        WQS_Session.HasFaction = true
        WQS_Session.Data = args
        if not hadSnapshot then
            -- first snapshot after a join or a group swap: the only client side
            -- proof that targets and activations survived
            print("WQS_MP first sync, faction=" .. tostring(args and args.faction) ..
                " state=" .. tostring(args and args.state) ..
                " targets=" .. tostring(args and args.targets and #args.targets or 0) ..
                " active=" .. tostring(args and args.activeCount))
        else
            WQS_Shared.DLog("sync faction=" .. tostring(args and args.faction) ..
                " state=" .. tostring(args and args.state) ..
                " targets=" .. tostring(args and args.targets and #args.targets or 0) ..
                " active=" .. tostring(args and args.activeCount))
        end
    elseif command == "NoFaction" then
        WQS_Session.HasFaction = false
        WQS_Session.Data = nil
        WQS_Session.NoFactionUntil = getTimeInMillis() + 30000
        print("WQS_MP client: no faction or safehouse, extraction is locked")
    elseif command == "AddTargetOk" then
        WQS_Session.OnAddTargetResult(true, args or {})
    elseif command == "AddTargetFailed" then
        WQS_Session.OnAddTargetResult(false, args or {})
    elseif command == "ReadyRejected" then
        WQS_Session.OnReadyRejected(args or {})
    end
end

local function WQS_Session_OnServerCommand(module, command, args)
    if module ~= WQS_Session.MODULE then
        return
    end
    WQS_Session.OnServerMessage(command, args)
end

if isClient() then
    Events.OnServerCommand.Add(WQS_Session_OnServerCommand)
end

--- Legacy shape adapters.
--- The rest of the mod still reads "TargetRepeaterList" / "ActiveRepeaterList"
--- through getWQSPlayerModData in about 30 places. Instead of touching every
--- call site, those two keys are transparently served from the session
--- snapshot, so the read paths keep working unchanged.
local function SessionTargetsToLegacy()
    local d = WQS_Session.Data
    if not d or not d.targets then
        return {}
    end
    local out = {}
    for i = 1, #d.targets do
        local t = d.targets[i]
        out[i] = { area = t.area, name = t.name, x = t.x, y = t.y, z = t.z }
    end
    return out
end

local function SessionActiveToLegacy()
    local d = WQS_Session.Data
    if not d or not d.targets then
        return {}
    end
    local out = {}
    for i = 1, #d.targets do
        local t = d.targets[i]
        if t.active then
            out["srv" .. tostring(i)] = {
                x = t.x,
                y = t.y,
                z = t.z,
                by = t.by,
                activeForTargetRep = { area = t.area, name = t.name, x = t.x, y = t.y, z = t.z }
            }
        end
    end
    return out
end

WQS_Shared.getWQSPlayerModData = function(key)
    -- session owned keys never touch player ModData anymore
    if key == "TargetRepeaterList" then
        return SessionTargetsToLegacy()
    end
    if key == "ActiveRepeaterList" then
        return SessionActiveToLegacy()
    end

    local pl = WQS.GetCurrentPlayer();
    if not (pl) then
        return false
    end
    local myModData = pl:getModData();
    if key then
        return myModData["WQS"][key]
    else
        return myModData["WQS"]
    end
end

---setta una sottochiave di ModData[WQS] al valore indicato ModData.WQS.key=val
---WQS_Shared.setWQSPlayerModData("test","ciao") -> ModData.WQS.test="ciao"
WQS_Shared.setWQSPlayerModData = function(key, val)
    -- session owned keys are read only on the client: the server decides
    if key == "TargetRepeaterList" or key == "ActiveRepeaterList" then
        print("WQS_MP WARN blocked local write to server owned key: " .. tostring(key))
        return false
    end

    local pl = WQS.GetCurrentPlayer();

    if not (pl) then
        return false
    end
    local myModData = pl:getModData();
    myModData["WQS"][key] = val
    return true
end

---cancella una sottochiave di ModData[WQS] -> ModData.WQS.key=nil
---WQS_Shared.deleteWQSPlayerModData("test") -> ModData.WQS.test <- viene rimossa
WQS_Shared.deleteWQSPlayerModData = function(key)
    if key == "TargetRepeaterList" or key == "ActiveRepeaterList" then
        print("WQS_MP WARN blocked local delete of server owned key: " .. tostring(key))
        return false
    end
    local pl = WQS.GetCurrentPlayer();
    if not (pl) then
        return false
    end
    local myModData = pl:getModData();
    myModData["WQS"][key] = nil
    return true
end

---debug print the whole player ModData
WQS_Shared.PrintWQSPlayerModData = function(key)
    local pl = WQS.GetCurrentPlayer();
    if not (pl) then
        return false
    end
    local myModData = pl:getModData();
    print("--------ModData WQS." .. tostring(key) .. "----------")
    if key then
        print(tostring(WQS_Shared.Dump(myModData["WQS"][key])))
    else
        print(tostring(WQS_Shared.Dump(myModData["WQS"])))
    end
end


WQS_Shared.getExtractionPointsData = function(extraction_point_map, datakey)
    extraction_point_map = extraction_point_map or nil
    datakey = datakey or nil
    if (extraction_point_map == nil) then
        return WQS_ExtractionPointsData
    else
        return WQS_ExtractionPointsData[extraction_point_map]
    end
end

WQS_Shared.getPreferredSpawnPointsData = function(extraction_point_map)
    extraction_point_map = extraction_point_map or nil
    if (extraction_point_map == nil) then
        return WQS_PreferredSpawnPointsData
    else
        return WQS_PreferredSpawnPointsData[extraction_point_map]
    end
end

WQS_Shared.PickRandomObjFromTable = function(t)
    local rr = ZombRand(#t) + 1
    return t[rr]
end

---ritorna un elemento casuale dalla tabella a patto che non sia nullo
---@param t table
---@return table element
WQS_Shared.PickRandomObjFromTableIfNotNil = function(t)
    if not (t) or (#t == 0) then
        return nil
    end
    -- Kahlua does not implement math.random, so the old fallback branch was a
    -- "tried to call nil" waiting for ZombRand to go missing. ZombRand is the
    -- only random source that exists here. The unbounded recursion is gone
    -- too: a table of holes used to blow the stack.
    for i = 1, 50 do
        local rr = ZombRand(#t) + 1
        if t[rr] then
            return t[rr]
        end
    end
    for i = 1, #t do
        if t[i] then
            return t[i]
        end
    end
    return nil
end

-- riceve un numero da 0 a 100, estrae un num casuale tra 1 e 100, ritorna true se il num estratto è inferiore alla percentuale
WQS_Shared.RandomPerc = function(perc)
    local rr = ZombRand(100) + 1
    -- print("pick "..rr)
    if (rr <= perc) then
        return true
    end
    return false
end

WQS_Shared.RandomMapKeyButExcludeIfContain = function(mytab, excludeStrValOne, excludeStrValTwo, IncludeOne, IncludeTwo)
    local x = ZombRand(#mytab) + 1
    local valz = tostring(mytab[x].MapItem)
    local excludeMe = nil
    local excludeMe2 = nil
    excludeStrValTwo = excludeStrValTwo or false
    IncludeOne = IncludeOne or false
    IncludeTwo = IncludeTwo or false

    excludeStrValOne = string.lower(excludeStrValOne)
    local tabStrVal = string.lower(valz)
    excludeMe = tabStrVal:find(excludeStrValOne, 1, true)

    if (IncludeOne) then
        excludeMe = not (excludeMe)
    end

    if excludeStrValTwo then
        excludeMe2 = tabStrVal:find(excludeStrValTwo, 1, true)
        if (IncludeTwo) then
            excludeMe2 = not (excludeMe2)
        end
    end

    if (excludeMe or excludeMe2) then
        return WQS_Shared.RandomMapKeyButExcludeIfContain(mytab, excludeStrValOne, excludeStrValTwo, IncludeOne,
            IncludeTwo)
    end
    return x
end

WQS_Shared.RandomKeyFromTableExclude = function(mytab, exclude)
    local x = ZombRand(#mytab) + 1
    if x == exclude then
        return WQS_Shared.RandomKeyFromTableExclude(mytab, exclude)
    end
    return x
end

WQS_Shared.CardinalDirTxt = function(playerObj, destx, desty, distance)
    local x = math.floor(playerObj:getX() - destx)
    local y = math.floor(playerObj:getY() - desty)
    local north = nil
    local south = nil
    local east = nil
    local west = nil
    local text = ""

    if y < 0 then
        south = math.abs(y)
    end
    if y > 0 then
        north = math.abs(y)
    end
    if x > 0 then
        west = math.abs(x)
    end
    if x < 0 then
        east = math.abs(x)
    end
    if distance > 0 then
        if south then
            if west and west > (south * 2) then
                text = (text .. getText("IGUI_WQS_West"))
            elseif west and west > (south / 2) then
                text = (text .. getText("IGUI_WQS_Southwest"))
            elseif east and east > (south * 2) then
                text = (text .. getText("IGUI_WQS_East"))
            elseif east and east > (south / 2) then
                text = (text .. getText("IGUI_WQS_Southeast"))
            else
                text = (text .. getText("IGUI_WQS_South"))
            end
        elseif north then
            if west and west > (north * 2) then
                text = (text .. getText("IGUI_WQS_West"))
            elseif west and west > (north / 2) then
                text = (text .. getText("IGUI_WQS_Northwest"))
            elseif east and east > (north * 2) then
                text = (text .. getText("IGUI_WQS_East"))
            elseif east and east > (north / 2) then
                text = (text .. getText("IGUI_WQS_Northeast"))
            else
                text = (text .. getText("IGUI_WQS_North"))
            end
        elseif west then
            text = (text .. getText("IGUI_WQS_West"))
        elseif east then
            text = (text .. getText("IGUI_WQS_East"))
        end
    end
    return text
end

---ritorna true se il punto di estrazione corrente è su una mappa modded, altrimenti falso
WQS_Shared.IsCurretExtractionOnModdedMap = function()
    local CurrentMapId = string.lower(tostring(WQS.getCurretExtractionMap()))
    return WQS_Shared.IsModdedMap(CurrentMapId)
    -- local is_modded_str="#modded_map#"
    -- local is_modded_map = CurrentMapId:find(is_modded_str, 1, true)
    -- if (is_modded_map) then
    --     return true
    -- end
    -- return false
end

---Riceve un mod id e ritorna true se quella mod è attiva.
---ActiveMods("currentGame") viene popolato solo dal client: su un server
---dedicato getById crea un record vuoto e isModActive risponde sempre false.
---getActivatedMods è la lista che il server stesso ha caricato.
WQS_Shared.IsModActive = function(modId)
    if not (modId) then
        return false
    end
    local mods = getActivatedMods()
    if mods then
        for i = 0, mods:size() - 1 do
            if mods:get(i) == modId then
                return true
            end
        end
    end
    if ActiveMods then
        local am = ActiveMods.getById("currentGame")
        if am and am:isModActive(modId) then
            return true
        end
    end
    return false
end

---The server's servertest.ini Map= list, split on ";", e.g.
---{"Muldraugh, KY", "RavenCreek", "LCv2"}. This is the set of map folders
---actually merged into the world grid -- separate from Mods=/WorkshopItems=,
---which only decides whether a mod's Lua/scripts are loaded. A mod can be
---IsModActive() == true while its map folder is absent from Map=, in which
---case the mod's cells were never added to the world at all.
---Cached: like WQS_MapBounds, the option cannot change mid-session.
local WQS_LoadedMapFolders = nil

local function WQS_GetLoadedMapFolders()
    if WQS_LoadedMapFolders then
        return WQS_LoadedMapFolders
    end
    if not (getServerOptions) then
        return nil
    end
    local so = getServerOptions()
    local raw = so and so:getOption("Map")
    if not (raw) or raw == "" then
        return nil
    end

    local set = {}
    local parts = string.split(raw, ";")
    for i = 1, #parts do
        set[parts[i]] = true
    end
    WQS_LoadedMapFolders = set
    return set
end

---True when the map mod behind modId has at least one of its map folders
---actually present in Map=, i.e. the mod's cells are really in the world --
---not just whether the mod itself is enabled (see IsModActive above).
---getMapFoldersForMod is filesystem-based (zombie/gameStates/ChooseGameInfo),
---so it works the same on a dedicated server as on a client.
---Falls back to IsModActive when Map= cannot be read (e.g. singleplayer,
---where there is no servertest.ini), so a repeater is never dropped just
---because the check itself is inapplicable.
WQS_Shared.IsMapLoaded = function(modId)
    if not (modId) then
        return false
    end

    local loaded = WQS_GetLoadedMapFolders()
    if not (loaded) then
        return WQS_Shared.IsModActive(modId)
    end

    if not (getMapFoldersForMod) then
        return WQS_Shared.IsModActive(modId)
    end
    local folders = getMapFoldersForMod(modId)
    if not (folders) then
        return false
    end

    for i = 0, folders:size() - 1 do
        if loaded[folders:get(i)] then
            return true
        end
    end
    return false
end

---Returns the mod id a repeater location needs, or nil when it is vanilla.
---See media/lua/shared/WQS_RepeaterMapRequirement.lua for the table itself.
WQS_Shared.GetRepeaterRequiredMod = function(rep)
    if not (rep) or not (WQS_RepeaterMapRequirement) then
        return nil
    end

    local key = tostring(rep.area) .. "|" .. tostring(rep.name)
    local override = WQS_RepeaterMapRequirement.byRepeater[key]
    if override ~= nil then
        -- false means "explicitly vanilla", it has to win over the area rule
        if override == false then
            return nil
        end
        return override
    end

    return WQS_RepeaterMapRequirement.byArea[rep.area]
end

---Bounding box of every cell the world actually loaded, in world coordinates.
---Cached: the loaded map set cannot change during a session.
local WQS_MapBounds = nil

local function WQS_GetMapBounds()
    if WQS_MapBounds then
        return WQS_MapBounds
    end

    local world = getWorld()
    if not (world) then
        return nil
    end
    local grid = world:getMetaGrid()
    if not (grid) then
        return nil
    end

    local minCx, maxCx = grid:getMinX(), grid:getMaxX()
    local minCy, maxCy = grid:getMinY(), grid:getMaxY()
    -- IsoMetaGrid starts with minX/minY at +10000000 and maxX/maxY at
    -- -10000000, so an inverted box means the grid is not built yet. Do not
    -- cache that, the caller has to fall through as "unknown".
    if minCx > maxCx or minCy > maxCy then
        return nil
    end

    WQS_MapBounds = {
        x1 = minCx * 300,
        x2 = (maxCx + 1) * 300,
        y1 = minCy * 300,
        y2 = (maxCy + 1) * 300,
    }
    print(" ### WQS map bounds x=" .. WQS_MapBounds.x1 .. ".." .. WQS_MapBounds.x2 ..
        " y=" .. WQS_MapBounds.y1 .. ".." .. WQS_MapBounds.y2)
    return WQS_MapBounds
end

---True when the coordinates fall inside the loaded world.
---Safety net for repeaters whose map mod is not listed in
---WQS_RepeaterMapRequirement: without the map, their cells are outside the
---grid entirely. Returns true when the answer is unknown, so a missing entry
---can only ever keep a repeater, never drop a valid one.
WQS_Shared.IsInsideLoadedMap = function(x, y)
    if not (x) or not (y) then
        return true
    end
    local b = WQS_GetMapBounds()
    if not (b) then
        return true
    end
    return x >= b.x1 and x < b.x2 and y >= b.y1 and y < b.y2
end

---Registra una zona di estrazione appartenente a una mappa modded.
---Vive qui e non piu in client/WQS.lua perche un server dedicato carica
---media/lua/client soltanto per il checksum (LuaManager.LoadDirBase con
---skipRun), quindi la tabella WQS non esiste affatto sul server e la zona
---non entrava mai fra i candidati di PickExtractionMap.
WQS_Shared.AddModdedMapExtractionZone = function(ModMapId, ZoneLabel, ModMapFolder, X, Y, Z, PrefSpawnPointList,
                                                 PrefSpawnPointsPerc)
    if not (ModMapId) or not (ZoneLabel) or not (X) or not (Y) then
        print(" ### WQS AddModdedMapExtractionZone ERROR : some params are nil")
        return false
    end

    local Radius = 8
    local PrefZlevelSpawn = nil
    Z = Z or 0
    PrefSpawnPointsPerc = PrefSpawnPointsPerc or nil
    PrefSpawnPointList = PrefSpawnPointList or {}

    if not (WQS_Shared.IsModActive(ModMapId)) then
        return false
    end

    local MyId = ZoneLabel:gsub(" ", "-") .. "-" .. X .. "-" .. Y .. "-" .. Z
    local ZoneId = "#modded_map#" .. ModMapId .. "_" .. MyId

    -- OnGameStart can fire more than once (respawn, lua reload) and the server
    -- registers from OnServerStarted as well, so this has to be idempotent
    for k, v in pairs(WQS_ExtractionPointsData) do
        if v and (v.MapItem == ZoneId) then
            return false
        end
    end

    local ExtrData = ExtractionMap.new(ZoneId, X, Y, Z, ZoneLabel, Radius, PrefZlevelSpawn, PrefSpawnPointsPerc,
        ModMapFolder)
    table.insert(WQS_ExtractionPointsData, ExtrData)
    print(" ### WQS AddModdedMapExtractionZone -> Added <" .. ZoneLabel ..
        "> from mod " .. ModMapId .. " ZoneId=" .. ZoneId)

    if not (WQS_Shared.TableIsEmptyOrNil(PrefSpawnPointList)) then
        WQS_PreferredSpawnPointsData[ZoneId] = PrefSpawnPointList
        print(" ### WQS AddModdedMapExtractionZone -> Added PreferredSpawnPointsData key=" ..
            ZoneId .. " n. values=" .. #PrefSpawnPointList)
    end
    return true
end

WQS_Shared.IsModdedMap = function(MapId)
    local is_modded_str = "#modded_map#"
    local is_modded_map = MapId:find(is_modded_str, 1, true)
    if (is_modded_map) then
        return true
    end
    return false
end



--COMMON GENERAL UTILITY

WQS_Shared.CountTableItems = function(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

---Riceve in ingresso una stringa da in output la sua conversione in esadecimale
-- WQS_Shared.ToHex("abc") -> 616263
WQS_Shared.ToHex = function(str)
    str = tostring(str)
    return (str:gsub('.', function(c)
        return string.format('%02X', string.byte(c))
    end))
end

---Riceve in ingresso un valore esadecimale e da in output la sua conversione in stringa
-- WQS_Shared.FromHex("616263") -> abc
WQS_Shared.FromHex = function(str)
    str = tostring(str)
    return (str:gsub('..', function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

--- ritorna false se la tabella ha almeno un elemento, altrimenti true se non ha elementi o è nil
WQS_Shared.TableIsEmptyOrNil = function(myTable)
    if type(myTable) == 'table' then
        for _, _ in pairs(myTable) do
            return false
        end
        return true
    elseif not (myTable) then
        return true -- myTable is empty
    end
    return false
end

WQS_Shared.split = function(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    local i = 1
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end


--bb=WQS_Shared.concat("aa","bb","cc") ->  aa - bb - cc
WQS_Shared.concat = function(firstParam, ...)
    if select('#', ...) == 0 then
        return tostring(firstParam)
    end
    return tostring(firstParam) .. ' - ' .. WQS_Shared.concat(...)
end

--Translates a table into a comma-separated list of its (key,value)-pairs.
--Also translates subtables up to the specified depth.
--WQS_Shared.Dump({z=25,u=66,zza="yyyy"})->{u=66,z=25,zza="yyyy"}
WQS_Shared.Dump = function(object, depth)
    depth = depth or -1
    if type(object) == 'string' then
        return '"' .. object .. '"'
        --return  object
    elseif depth ~= 0 and type(object) == 'table' then
        local elementArray = {}
        local keyAsString
        for k, v in pairs(object) do
            keyAsString = type(k) == 'string' and (tostring(k)) or tostring(k)
            table.insert(elementArray, "\n" .. keyAsString .. '=' .. WQS_Shared.Dump(v, depth - 1))
        end
        return "{" .. table.concat(elementArray, ",") .. "\n}"
    end
    return tostring(object)
end

WQS_Shared.indexOf = function(table1, value)
    for i, v in ipairs(table1) do
        if v == value then
            return i
        end
    end
    return -1
end


--- Delays a function by a specified amount in milliseconds
--- <br> Credits for this function: Konijima
---@param func function
---@param delay number
WQS_Shared.DelayFunction = function(func, delay)
    delay = delay or 1;
    local ticks = 0;
    local canceled = false;

    local function onTick()
        if not canceled and ticks < delay then
            ticks = ticks + 1;
            return;
        end

        Events.OnTick.Remove(onTick);
        if not canceled then func(); end
    end

    Events.OnTick.Add(onTick);

    return function()
        canceled = true;
    end
end
--[[

function onHandleSettings()
    options = getSandboxOptions();

options:set("WQS_DeadlineDays_opt", 30)

options:toLua();
options:updateFromLua();

options:applySettings();
end

Events.OnResetLua.Add(onHandleSettings)
Events.OnMainMenuEnter.Add(onHandleSettings)
 ]]
