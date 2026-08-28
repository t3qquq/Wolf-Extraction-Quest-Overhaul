--[[
    WQS_MPSession.lua
    Server-authoritative faction extraction session for MP.

    Owns: extraction map choice, target repeater list, repeater activation,
          request gate, session timer, completion gate.
    Clients hold no authority: they render a snapshot pushed by this module.

    Protocol module name: "WQS_MP"
      Client -> Server : Join / ToggleReady / AddRepeaterTarget / ActivateRepeater / ReportDeath
      Server -> Client : Sync
]]

WQS_MPSession = {}

local MODULE = "WQS_MP"
local POLL_DELAY_MS = 2000
local GMD_KEY = "WQS_MP"

-- session states
local ST_PRE = "PRE"           -- quest running, extraction not requested
local ST_PENDING = "PENDING"   -- request gate open, waiting for all ready
local ST_RUNNING = "RUNNING"   -- extraction event running, timer accumulating
local ST_UNLOCKED = "UNLOCKED" -- completion gate satisfied and latched
local ST_DONE = "DONE"         -- everyone extracted

local LastPoll = 0

-- ##############################################################
-- storage
-- ##############################################################

local function GetStore()
    local d = ModData.getOrCreate(GMD_KEY)
    if not d.Sessions then
        d.Sessions = {}
    end
    return d
end

-- ##############################################################
-- faction helpers
-- ##############################################################

---@return string|nil factionKey
function WQS_MPSession.GetFactionKey(username)
    if not username then
        return nil
    end
    local f = Faction.getPlayerFaction(username)
    if not f then
        return nil
    end
    return f:getName()
end

--- NOTE: Faction.getPlayers() does NOT contain the owner (see Faction.java addPlayer),
--- so the roster must be built as {owner} + players.
local function GetFactionRoster(factionKey)
    local out = {}
    local f = Faction.getFaction(factionKey)
    if not f then
        return out
    end
    local seen = {}
    local owner = f:getOwner()
    if owner then
        table.insert(out, owner)
        seen[owner] = true
    end
    local pls = f:getPlayers()
    if pls then
        for i = 0, pls:size() - 1 do
            local u = pls:get(i)
            if u and not seen[u] then
                table.insert(out, u)
                seen[u] = true
            end
        end
    end
    return out
end

local function GetOnlineMap()
    local map = {}
    local pls = getOnlinePlayers()
    if not pls then
        return map
    end
    for i = 0, pls:size() - 1 do
        local p = pls:get(i)
        if p and p:getUsername() then
            map[p:getUsername()] = p
        end
    end
    return map
end

--- Effective roster = snapshot roster - dead - offline.
--- Dead is permanent, offline is temporary (rejoin restores membership).
local function GetEffectiveRoster(sess, onlineMap)
    local out = {}
    for i = 1, #sess.Roster do
        local u = sess.Roster[i]
        if not sess.Dead[u] and onlineMap[u] then
            table.insert(out, u)
        end
    end
    return out
end

-- ##############################################################
-- extraction map / zone
-- ##############################################################

local function GetMapDataByItem(mapItem)
    if not mapItem then
        return nil
    end
    for k, v in pairs(WQS_ExtractionPointsData) do
        if v.MapItem == mapItem then
            return v
        end
    end
    return nil
end

--- Server side reimplementation of the client zone test
--- (WQS.ComposeExtractionStats: Distance_isok and Zlevel_isok).
--- Z is floored here: the client compared a float getZ() to an int with ==,
--- which is fragile on stairs/ramps.
local function IsPlayerInZone(player, mapData)
    if not player or not mapData then
        return false
    end
    local dx = player:getX() - mapData.MapCenterAreaX
    local dy = player:getY() - mapData.MapCenterAreaY
    local dist = math.sqrt((dx * dx) + (dy * dy))
    if dist > mapData.AreaRadiusFromCenter then
        return false
    end
    if math.floor(player:getZ() + 0.5) ~= mapData.MapCenterAreaZ then
        return false
    end
    return true
end

local function ContainsLower(s, needle)
    if not s then
        return false
    end
    return string.find(string.lower(s), needle, 1, true) ~= nil
end

--- Picks the session extraction map once, from the sandbox options.
local function PickExtractionMap()
    local zoneIdx = SandboxVars.WQS_ZoneMap_opt
    local randOpt = SandboxVars.WQS_ZoneMap_random_opt

    local fixed = WQS_ExtractionPointsData[zoneIdx]
    if fixed and fixed.MapItem ~= "random" and fixed.MapItem ~= "" then
        return fixed.MapItem
    end

    -- build candidate pool
    local pool = {}
    for k, v in pairs(WQS_ExtractionPointsData) do
        local item = v.MapItem
        if item and item ~= "" and not ContainsLower(item, "random") then
            local isLou = ContainsLower(item, "louisville")
            local take = true
            if randOpt == 2 then       -- only Louisville
                take = isLou
            elseif randOpt == 3 then   -- excluding Louisville
                take = not isLou
            end
            if take then
                table.insert(pool, item)
            end
        end
    end

    if #pool == 0 then
        print("WQS_MP ERROR PickExtractionMap: empty pool, falling back to index 2")
        return WQS_ExtractionPointsData[2].MapItem
    end
    return pool[ZombRand(#pool) + 1]
end

-- ##############################################################
-- repeater targets
-- ##############################################################

local function RepeaterKey(rep)
    return tostring(rep.area) .. "|" .. tostring(rep.name)
end

--- Repeater candidates, minus the ones sitting on top of an extraction point.
--- Ported from WQSAntenna.RemoveRepeatersTooCloseToExtrPoints, but non destructive:
--- the original nil'd entries out of the shared WQS_RepeaterData table.
local function BuildRepeaterPool()
    local pool = {}
    for rk, rep in pairs(WQS_RepeaterData) do
        if rep and rep.x and rep.y then
            local ok = true
            for pk, pdata in pairs(WQS_ExtractionPointsData) do
                if pdata and pdata.MapCenterAreaX and pdata.MapCenterAreaX > 0 then
                    local dx = rep.x - pdata.MapCenterAreaX
                    local dy = rep.y - pdata.MapCenterAreaY
                    if math.sqrt((dx * dx) + (dy * dy)) < 130 then
                        ok = false
                    end
                end
            end
            if ok then
                table.insert(pool, rep)
            end
        end
    end
    return pool
end

--- Picks one repeater far enough from the already chosen ones.
local function PickRepeater(pool, chosen)
    if #pool == 0 then
        return nil
    end
    local fail = 0
    while fail <= 50 do
        local pick = pool[ZombRand(#pool) + 1]
        local good = true
        for i = 1, #chosen do
            local c = chosen[i]
            local dx = pick.x - c.x
            local dy = pick.y - c.y
            local dist = math.sqrt((dx * dx) + (dy * dy))
            local mindist = 380 * #chosen
            if fail > 20 then
                mindist = 100
            end
            if (pick.x == c.x and pick.y == c.y) or (dist < mindist) then
                good = false
                if dist > 0 then
                    fail = fail + 1
                end
            end
        end
        if good then
            return pick
        end
    end
    print("WQS_MP WARN PickRepeater: too many failed picks, returning random")
    return pool[ZombRand(#pool) + 1]
end

local function GetMaxRepeaters()
    return SandboxVars.WQS_RepeatersModeHowMany_opt or 0
end

local function IsRepeatersMode()
    return GetMaxRepeaters() > 0
end

-- ##############################################################
-- session lifecycle
-- ##############################################################

local function NewSession(factionKey)
    local sess = {
        State = ST_PRE,
        Roster = GetFactionRoster(factionKey),
        Dead = {},
        Ready = {},
        Arrived = {},
        Extracted = {},
        ExtractionMap = PickExtractionMap(),
        Targets = {},
        ActiveRepeaters = {},
        ElapsedMinutes = 0,
        LastStampMinutes = nil,
        StormStage = -1,
    }
    print("WQS_MP session created faction=" .. factionKey ..
        " map=" .. tostring(sess.ExtractionMap) .. " roster=" .. #sess.Roster)
    return sess
end

function WQS_MPSession.GetSession(factionKey, createIfMissing)
    if not factionKey then
        return nil
    end
    local store = GetStore()
    local sess = store.Sessions[factionKey]
    if not sess and createIfMissing then
        sess = NewSession(factionKey)
        store.Sessions[factionKey] = sess
    end
    return sess
end

--- Full wipe. Used when the whole faction is dead: the run failed,
--- repeater progress is lost and fragments must be collected again.
local function DestroySession(factionKey, reason)
    local store = GetStore()
    if store.Sessions[factionKey] then
        store.Sessions[factionKey] = nil
        print("WQS_MP session destroyed faction=" .. factionKey .. " reason=" .. tostring(reason))
    end
end

-- ##############################################################
-- shared world effects (storm, sound)
--
-- Zombie spawning stays on the clients on purpose: each participant spawns
-- around themselves, so a bigger faction faces proportionally more zombies.
-- Storm and sound are different: they are global or positional world effects,
-- so N clients firing the same request produces N duplicates. Both are
-- funnelled through the claim helpers below.
-- ##############################################################

local SOUND_DEDUP_RADIUS = 40
local SOUND_DEDUP_WINDOW_MS = 5000
local RecentSounds = {}

--- Current extraction stage derived from the authoritative session timer,
--- mirroring GetCurrentExtractionStage in WQS_ExtractionEvent.lua.
function WQS_MPSession.GetExtractionStage(sess)
    local duration = WQS_MPSession.GetDurationMinutes()
    if duration <= 0 then
        return 0
    end
    local single = duration / 3
    return math.ceil(sess.ElapsedMinutes / single)
end

--- Returns true for the first client that asks to start the storm for this
--- extraction stage, false for every other member of the same faction.
--- Without this the storm is stopped and restarted once per player, which
--- visibly resets the weather at every stage transition.
function WQS_MPSession.ClaimStorm(player)
    if not player then
        return false
    end
    local factionKey = WQS_MPSession.GetFactionKey(player:getUsername())
    if not factionKey then
        return true -- no session to arbitrate, let it through
    end
    local sess = WQS_MPSession.GetSession(factionKey, false)
    if not sess then
        return true
    end
    local stage = WQS_MPSession.GetExtractionStage(sess)
    if sess.StormStage == stage then
        print("WQS_MP storm suppressed, already started for stage " .. stage ..
            " faction=" .. factionKey)
        return false
    end
    sess.StormStage = stage
    print("WQS_MP storm claimed stage=" .. stage .. " faction=" .. factionKey ..
        " by=" .. player:getUsername())
    return true
end

--- Positional dedup: the same sound requested near the same spot within the
--- dedup window is played once. Members spread across the map still each get
--- their own cue; once they converge on the extraction zone the overlapping
--- copies collapse into one.
function WQS_MPSession.ClaimSound(soundname, x, y)
    local now = getTimeInMillis()

    local kept = {}
    for i = 1, #RecentSounds do
        local s = RecentSounds[i]
        if (now - s.t) < SOUND_DEDUP_WINDOW_MS then
            table.insert(kept, s)
        end
    end
    RecentSounds = kept

    for i = 1, #RecentSounds do
        local s = RecentSounds[i]
        if s.name == soundname then
            local dx = x - s.x
            local dy = y - s.y
            if math.sqrt((dx * dx) + (dy * dy)) <= SOUND_DEDUP_RADIUS then
                return false
            end
        end
    end

    table.insert(RecentSounds, { name = soundname, x = x, y = y, t = now })
    return true
end

-- ##############################################################
-- snapshot / sync
-- ##############################################################

local function BuildSnapshot(factionKey, sess, onlineMap)
    local eff = GetEffectiveRoster(sess, onlineMap)

    local members = {}
    local readyCount = 0
    local arrivedCount = 0
    for i = 1, #eff do
        local u = eff[i]
        local isReady = sess.Ready[u] and true or false
        local isArrived = sess.Arrived[u] and true or false
        if isReady then
            readyCount = readyCount + 1
        end
        if isArrived then
            arrivedCount = arrivedCount + 1
        end
        table.insert(members, {
            u = u,
            ready = isReady,
            arrived = isArrived,
            extracted = sess.Extracted[u] and true or false,
        })
    end

    local targets = {}
    for i = 1, #sess.Targets do
        local t = sess.Targets[i]
        local act = sess.ActiveRepeaters[RepeaterKey(t)]
        table.insert(targets, {
            area = t.area,
            name = t.name,
            x = t.x,
            y = t.y,
            z = t.z or 0,
            active = act and true or false,
            by = act and act.by or "",
        })
    end

    return {
        faction = factionKey,
        state = sess.State,
        map = sess.ExtractionMap,
        elapsed = sess.ElapsedMinutes,
        duration = WQS_MPSession.GetDurationMinutes(),
        members = members,
        readyCount = readyCount,
        readyTotal = #eff,
        arrivedCount = arrivedCount,
        arrivedTotal = #eff,
        targets = targets,
        maxTargets = GetMaxRepeaters(),
        activeCount = WQS_MPSession.CountActive(sess),
    }
end

function WQS_MPSession.CountActive(sess)
    local n = 0
    for k, v in pairs(sess.ActiveRepeaters) do
        n = n + 1
    end
    return n
end

function WQS_MPSession.GetDurationMinutes()
    local h = SandboxVars.WQS_ExtractionEventHoursDuration_opt
    return h * 60
end

--- Pushes the snapshot to every online member of the snapshot roster.
--- Offline members are skipped; they get a fresh snapshot on their next Join.
local function Broadcast(factionKey, sess)
    local onlineMap = GetOnlineMap()
    local snap = BuildSnapshot(factionKey, sess, onlineMap)
    for i = 1, #sess.Roster do
        local p = onlineMap[sess.Roster[i]]
        if p then
            sendServerCommand(p, MODULE, "Sync", snap)
        end
    end
end

WQS_MPSession.Broadcast = Broadcast

-- ##############################################################
-- gates
-- ##############################################################

--- Request gate: every effective member has pressed request.
local function EvaluateRequestGate(factionKey, sess, onlineMap)
    if sess.State ~= ST_PENDING then
        return false
    end
    local eff = GetEffectiveRoster(sess, onlineMap)
    if #eff == 0 then
        return false
    end
    for i = 1, #eff do
        if not sess.Ready[eff[i]] then
            return false
        end
    end

    sess.State = ST_RUNNING
    sess.ElapsedMinutes = 0
    sess.LastStampMinutes = getGameTime():getMinutesStamp()
    print("WQS_MP request gate satisfied faction=" .. factionKey .. " members=" .. #eff)
    return true
end

--- Session timer. With ConfinedMode on, the timer only advances while every
--- effective member is inside the zone; a single member stepping out pauses
--- the whole run instead of resetting their progress.
local function AdvanceTimer(factionKey, sess, onlineMap)
    local now = getGameTime():getMinutesStamp()
    if not sess.LastStampMinutes then
        sess.LastStampMinutes = now
        return
    end
    local delta = now - sess.LastStampMinutes
    sess.LastStampMinutes = now
    if delta <= 0 then
        return
    end

    local eff = GetEffectiveRoster(sess, onlineMap)
    if #eff == 0 then
        return
    end

    if SandboxVars.WQS_ConfinedMode_opt == true then
        local mapData = GetMapDataByItem(sess.ExtractionMap)
        for i = 1, #eff do
            if not IsPlayerInZone(onlineMap[eff[i]], mapData) then
                return -- paused, progress preserved
            end
        end
    end

    sess.ElapsedMinutes = sess.ElapsedMinutes + delta
end

--- Completion gate: after the timer expires, every effective member must stand
--- in the zone. Once satisfied the state latches to UNLOCKED and never falls
--- back, so the button cannot flicker while the horde pushes people around.
local function EvaluateCompletionGate(factionKey, sess, onlineMap)
    local mapData = GetMapDataByItem(sess.ExtractionMap)
    local eff = GetEffectiveRoster(sess, onlineMap)

    for i = 1, #eff do
        local u = eff[i]
        sess.Arrived[u] = IsPlayerInZone(onlineMap[u], mapData)
    end

    if sess.State ~= ST_RUNNING then
        return false
    end
    if sess.ElapsedMinutes < WQS_MPSession.GetDurationMinutes() then
        return false
    end
    if #eff == 0 then
        return false
    end
    for i = 1, #eff do
        if not sess.Arrived[eff[i]] then
            return false
        end
    end

    sess.State = ST_UNLOCKED
    print("WQS_MP completion gate latched faction=" .. factionKey .. " members=" .. #eff)
    return true
end

-- ##############################################################
-- death / disconnect
-- ##############################################################

local function MarkDead(factionKey, sess, username, reason)
    if sess.Dead[username] then
        return false
    end
    sess.Dead[username] = true
    sess.Ready[username] = nil
    sess.Arrived[username] = nil
    print("WQS_MP member down faction=" .. factionKey .. " user=" .. username .. " reason=" .. tostring(reason))
    return true
end

--- Everyone in the snapshot roster is dead -> the run failed.
local function IsWipe(sess)
    if #sess.Roster == 0 then
        return false
    end
    for i = 1, #sess.Roster do
        if not sess.Dead[sess.Roster[i]] then
            return false
        end
    end
    return true
end

--- Safety net for deaths the client never reported (crash right on death):
--- an online player whose character is dead is promoted to Dead here.
local function ReconcileDeaths(factionKey, sess, onlineMap)
    local changed = false
    for i = 1, #sess.Roster do
        local u = sess.Roster[i]
        local p = onlineMap[u]
        if p and not sess.Dead[u] and p:isDead() then
            if MarkDead(factionKey, sess, u, "reconcile-isDead") then
                changed = true
            end
        end
    end
    return changed
end

-- ##############################################################
-- poll loop
-- ##############################################################

local function PollSessions()
    local store = GetStore()
    local onlineMap = GetOnlineMap()

    for factionKey, sess in pairs(store.Sessions) do
        local changed = false

        if ReconcileDeaths(factionKey, sess, onlineMap) then
            changed = true
        end

        if IsWipe(sess) then
            DestroySession(factionKey, "faction wipe")
        else
            if sess.State == ST_PENDING then
                if EvaluateRequestGate(factionKey, sess, onlineMap) then
                    changed = true
                end
            end

            if sess.State == ST_RUNNING then
                AdvanceTimer(factionKey, sess, onlineMap)
                if EvaluateCompletionGate(factionKey, sess, onlineMap) then
                    changed = true
                end
                changed = true -- timer moved, clients need the tick
            end

            if changed then
                Broadcast(factionKey, sess)
            end
        end
    end
end

local function OnTickPoll()
    if not isServer() then
        return
    end
    local now = getTimeInMillis()
    if (now - LastPoll) < POLL_DELAY_MS then
        return
    end
    LastPoll = now
    PollSessions()
end

-- ##############################################################
-- command handlers
-- ##############################################################

local Handlers = {}

--- Client announces itself. Creates the faction session on first contact.
Handlers["Join"] = function(sess, factionKey, player, args)
    local u = player:getUsername()
    -- a rejoining member is restored unless they are flagged dead
    if player:isDead() then
        MarkDead(factionKey, sess, u, "join-isDead")
    end
    return true
end

--- Request gate toggle. Re-pressing clears the flag; when the last ready flag
--- is cleared the session falls back to PRE so a crash cannot deadlock it.
Handlers["ToggleReady"] = function(sess, factionKey, player, args)
    local u = player:getUsername()

    if sess.State ~= ST_PRE and sess.State ~= ST_PENDING then
        print("WQS_MP ToggleReady rejected, state=" .. sess.State .. " user=" .. u)
        return false
    end
    if sess.Dead[u] then
        return false
    end
    if IsRepeatersMode() and WQS_MPSession.CountActive(sess) < GetMaxRepeaters() then
        print("WQS_MP ToggleReady rejected, signal too weak user=" .. u)
        return false
    end

    if sess.Ready[u] then
        sess.Ready[u] = nil
    else
        sess.Ready[u] = true
        sess.State = ST_PENDING
    end

    local any = false
    for k, v in pairs(sess.Ready) do
        any = true
    end
    if not any then
        sess.State = ST_PRE
    end

    print("WQS_MP ToggleReady user=" .. u .. " ready=" .. tostring(sess.Ready[u] and true or false))
    return true
end

--- Consumes a repeater location fragment: adds one target to the session.
Handlers["AddRepeaterTarget"] = function(sess, factionKey, player, args)
    if not IsRepeatersMode() then
        return false
    end
    if #sess.Targets >= GetMaxRepeaters() then
        print("WQS_MP AddRepeaterTarget rejected, list full faction=" .. factionKey)
        return false
    end
    local pool = BuildRepeaterPool()
    local pick = PickRepeater(pool, sess.Targets)
    if not pick then
        print("WQS_MP ERROR AddRepeaterTarget: no candidate available")
        return false
    end
    table.insert(sess.Targets, { area = pick.area, name = pick.name, x = pick.x, y = pick.y, z = pick.z or 0 })
    print("WQS_MP target added faction=" .. factionKey ..
        " area=" .. tostring(pick.area) .. " name=" .. tostring(pick.name) ..
        " total=" .. #sess.Targets)
    return true
end

--- Activates a target repeater. One antenna per location satisfies the whole
--- faction, so members can split up and cover different sites.
Handlers["ActivateRepeater"] = function(sess, factionKey, player, args)
    local u = player:getUsername()
    local ax = args.x
    local ay = args.y
    local az = args.z or 0
    if not ax or not ay then
        return false
    end

    local maxDist = 7 -- WQS_Shared.getRepeaterMaxActivationDistance()
    for i = 1, #sess.Targets do
        local t = sess.Targets[i]
        local key = RepeaterKey(t)
        if not sess.ActiveRepeaters[key] then
            local dx = ax - t.x
            local dy = ay - t.y
            if math.sqrt((dx * dx) + (dy * dy)) <= maxDist then
                sess.ActiveRepeaters[key] = { by = u, x = ax, y = ay, z = az }
                print("WQS_MP repeater activated faction=" .. factionKey ..
                    " key=" .. key .. " by=" .. u)
                return true
            end
        end
    end
    print("WQS_MP ActivateRepeater rejected, no target in range user=" .. u)
    return false
end

Handlers["ReportDeath"] = function(sess, factionKey, player, args)
    return MarkDead(factionKey, sess, player:getUsername(), "client-report")
end

--- Player confirmed the end modal and is leaving.
Handlers["Extracted"] = function(sess, factionKey, player, args)
    if sess.State ~= ST_UNLOCKED and sess.State ~= ST_DONE then
        return false
    end
    sess.Extracted[player:getUsername()] = true
    print("WQS_MP extracted faction=" .. factionKey .. " user=" .. player:getUsername())
    return true
end

local function OnClientCommand(module, command, player, args)
    if not isServer() then
        return
    end
    if module ~= MODULE then
        return
    end
    if not player then
        return
    end

    local u = player:getUsername()
    local factionKey = WQS_MPSession.GetFactionKey(u)
    if not factionKey then
        sendServerCommand(player, MODULE, "NoFaction", {})
        print("WQS_MP command rejected, no faction user=" .. tostring(u) .. " cmd=" .. tostring(command))
        return
    end

    local sess = WQS_MPSession.GetSession(factionKey, true)
    if not sess then
        return
    end

    local h = Handlers[command]
    if not h then
        print("WQS_MP unknown command=" .. tostring(command))
        return
    end

    local ok, changed = pcall(h, sess, factionKey, player, args or {})
    if not ok then
        print("WQS_MP ERROR handler failed cmd=" .. tostring(command) .. " err=" .. tostring(changed))
        return
    end

    -- Join always answers the caller even when nothing changed,
    -- otherwise a reconnecting client would sit on an empty UI.
    if changed or command == "Join" then
        Broadcast(factionKey, sess)
    end
end

Events.OnClientCommand.Add(OnClientCommand)
Events.OnTick.Add(OnTickPoll)

print("WQS_MP server session module loaded")
