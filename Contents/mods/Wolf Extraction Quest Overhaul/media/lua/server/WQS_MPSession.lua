--[[
    WQS_MPSession.lua
    Authoritative extraction session, shared by a whole faction.

    Owns: extraction map choice, target repeater list, repeater activation,
          request gate, session timer, completion gate, run end.
    Clients hold no authority: they render a snapshot pushed by this module.

    Hosting:
      dedicated server  isServer() -> hosts, talks over the network
      coop host         the server process hosts, exactly like a dedicated one
      singleplayer      neither isServer() nor isClient(), and media/lua/server
                        is still loaded (GameLoadingState), so this very VM
                        hosts and the "network" calls short circuit into direct
                        function calls. That keeps SP and MP on one code path.

    Protocol module name: "WQS_MP"
      Client -> Server : Join / ToggleReady / AddRepeaterTarget /
                         ActivateRepeater / ReportDeath / Extracted
      Server -> Client : Sync / NoFaction / AddTargetOk / AddTargetFailed /
                         ReadyRejected
]]

WQS_MPSession = {}

local MODULE = "WQS_MP"
local POLL_DELAY_MS = 2000
local GMD_KEY = "WQS_MP"

--- Join fires every 3s before the first snapshot and every 30s after it, so
--- this one line dominates the server log on a long run. Kept out of
--- WQS_DebugLog_opt on purpose: that option gates the WQS_DBG diagnostics the
--- test plan needs switched on, and those must stay usable while this is off.
--- Flip to true when counting Join rate (join flood check).
local LOG_JOIN = false

-- session states
local ST_PRE = "PRE"           -- quest running, extraction not requested
local ST_PENDING = "PENDING"   -- request gate open, waiting for all ready
local ST_RUNNING = "RUNNING"   -- extraction event running, timer accumulating
local ST_UNLOCKED = "UNLOCKED" -- completion gate satisfied and latched
local ST_DONE = "DONE"         -- everyone extracted

--- Singleplayer has no faction and no username worth trusting (IsoPlayer
--- defaults to "Bob"), so one constant stands in for both. It must match
--- WQS_Session.SP_USER in shared/WQS_Shared.lua or the client would never
--- find itself in the roster.
local SP_KEY = "@sp"

--- Group modes, see sandbox option WQS_GroupMode_opt.
--- No solo fallback: modes 2 and 3 block a player who has no group instead of
--- quietly giving them a private session. A one man faction or a one man
--- safehouse is always possible, so "I want to play alone" is mode 1.
--- Because a key kind can never change inside one mode, a session is never
--- migrated and the promotion problem does not exist.
local GROUP_SOLO = 1           -- always personal, as in the original mod
local GROUP_FACTION_ONLY = 2   -- faction required, no faction means no quest
local GROUP_SAFEHOUSE_ONLY = 3 -- safehouse required, none means no quest

--- Session keys carry the kind that produced them. Without the prefix a
--- faction called "Bob" and a player called "Bob" would share one session.
local KEY_FACTION = "F:"
local KEY_PLAYER = "P:"
local KEY_SAFEHOUSE = "S:"


local ANTENNA_ITEM = "wqs_radioantenna"
local ACTIVATION_DISTANCE = 7 -- WQS_Shared.getRepeaterMaxActivationDistance()

local LastPoll = 0
local NoFactionLogged = {}
local NOFACTION_LOG_MS = 60000

--- Last session key each user resolved to. A key change is the only externally
--- visible effect of creating or leaving a faction or a safehouse, so it is
--- logged unconditionally: without it a "the session got rebuilt" report has
--- no timestamp to hang on and the 8-A cases cannot be told apart.
local LastKeyByUser = {}

--- Last group mode written to the console. Also acts as the "not logged yet"
--- flag, so the configuration dump is emitted from the poll loop rather than at
--- file load, where SandboxVars is not populated yet.
local LoggedGroupMode = nil

-- ##############################################################
-- hosting mode
-- ##############################################################

local function IsSinglePlayer()
    return (not isClient()) and (not isServer())
end

--- True in the VM that owns the sessions: the dedicated/coop server process,
--- or the singleplayer game itself.
local function IsHost()
    return not isClient()
end

WQS_MPSession.IsSinglePlayer = IsSinglePlayer
WQS_MPSession.IsHost = IsHost

local function GetUserKey(player)
    if IsSinglePlayer() then
        return SP_KEY
    end
    if not player then
        return nil
    end
    return player:getUsername()
end

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
-- transport
--
-- In SP there is no network and Events.OnServerCommand never fires, so the
-- snapshot is handed to the client cache directly.
-- ##############################################################

local function SendTo(player, command, args)
    if IsSinglePlayer() then
        WQS_Session.OnServerMessage(command, args or {})
        return
    end
    if not player then
        return
    end
    sendServerCommand(player, MODULE, command, args or {})
end

-- ##############################################################
-- faction helpers
-- ##############################################################

---Sandbox group mode. Read at use time, never cached: the server can change
---it between runs and there is always a default, so no fallback is needed.
local function GetGroupMode()
    return SandboxVars.WQS_GroupMode_opt
end

WQS_MPSession.GetGroupMode = GetGroupMode

---Safehouse a player belongs to, as owner or as member.
---SafeHouse.hasSafehouse already checks both lists, and returns the first
---match when the server allows owning several.
local function GetPlayerSafehouse(username)
    if not username then
        return nil
    end
    if not SafeHouse then
        print("WQS_MP WARN SafeHouse class unavailable, safehouse mode blocks everyone")
        return nil
    end
    return SafeHouse.hasSafehouse(username)
end

---Session key of a safehouse.
---NOT SafeHouse:getId(): that id embeds the creation timestamp
---(x .. "," .. y .. " at " .. currentTimeMillis) and is never serialised, so
---load() mints a brand new one on every server restart and every session
---would be orphaned. The origin corner is stable across save/load instead.
local function SafehouseKey(sh)
    return KEY_SAFEHOUSE .. tostring(sh:getX()) .. "," .. tostring(sh:getY())
end

---@return string|nil factionKey
function WQS_MPSession.GetFactionKey(username)
    if IsSinglePlayer() then
        return SP_KEY
    end
    if not username then
        return nil
    end

    local mode = GetGroupMode()

    if mode == GROUP_FACTION_ONLY then
        local f = Faction.getPlayerFaction(username)
        if f then
            return KEY_FACTION .. f:getName()
        end
        return nil
    end

    if mode == GROUP_SAFEHOUSE_ONLY then
        local sh = GetPlayerSafehouse(username)
        if sh then
            return SafehouseKey(sh)
        end
        return nil
    end

    -- GROUP_SOLO: every player runs their own quest, faction and safehouse
    -- membership are ignored on purpose
    return KEY_PLAYER .. username
end

--- Appends {owner} + members of a java list, skipping duplicates.
--- Both Faction.getPlayers() and SafeHouse.getPlayers() may omit the owner
--- (see Faction.addPlayer and SafeHouse.updateSafehousePlayersConnected,
--- which tests getPlayers().contains() OR getOwner().equals()), so the owner
--- is always inserted first and then deduplicated.
local function CollectRoster(owner, players)
    local out = {}
    local seen = {}
    if owner then
        table.insert(out, owner)
        seen[owner] = true
    end
    if players then
        for i = 0, players:size() - 1 do
            local u = players:get(i)
            if u and not seen[u] then
                table.insert(out, u)
                seen[u] = true
            end
        end
    end
    return out
end

--- Finds a safehouse back from its session key.
--- Kept keyed by origin corner rather than held as an object reference,
--- because the safehouse list is rebuilt on load.
--- SafeHouse.canBeSafehouse does NOT reject a building that is already
--- claimed, and addSafeHouse derives the corner from the building def, so two
--- players claiming the same building produce two safehouses with identical
--- coordinates. They would silently share one session, so the collision is
--- reported instead of being papered over.
local function GetSafehouseByKey(factionKey)
    if not SafeHouse then
        return nil
    end
    local list = SafeHouse.getSafehouseList()
    if not list then
        return nil
    end
    local found = nil
    local hits = 0
    for i = 0, list:size() - 1 do
        local sh = list:get(i)
        if sh and SafehouseKey(sh) == factionKey then
            hits = hits + 1
            if not found then
                found = sh
            end
        end
    end
    if hits > 1 then
        print("WQS_MP WARN " .. hits .. " safehouses share the origin " .. tostring(factionKey) ..
            ", their members end up in one session")
    end
    return found
end

--- True when the group behind a session key no longer exists.
--- The key carries a prefix now, so it can never be handed to
--- Faction.getFaction as is: that would report every session as gone and the
--- poll loop would destroy all of them on the next tick.
--- A solo session has no backing group and therefore never expires here.
local function IsGroupGone(factionKey)
    if factionKey == SP_KEY then
        return false
    end

    local kind = string.sub(factionKey, 1, 2)
    local rest = string.sub(factionKey, 3)

    if kind == KEY_PLAYER then
        return false
    end
    if kind == KEY_SAFEHOUSE then
        return GetSafehouseByKey(factionKey) == nil
    end
    if kind == KEY_FACTION then
        return Faction.getFaction(rest) == nil
    end
    return false
end
local function GetFactionRoster(factionKey)
    local out = {}
    if factionKey == SP_KEY then
        table.insert(out, SP_KEY)
        return out
    end

    local kind = string.sub(factionKey, 1, 2)
    local rest = string.sub(factionKey, 3)

    -- solo session: the roster is exactly the one player
    if kind == KEY_PLAYER then
        table.insert(out, rest)
        return out
    end

    if kind == KEY_SAFEHOUSE then
        local sh = GetSafehouseByKey(factionKey)
        if not sh then
            -- safehouse gone (destroyed or released): leave the roster empty,
            -- SyncRoster prunes the session down and the gates stop waiting
            return out
        end
        return CollectRoster(sh:getOwner(), sh:getPlayers())
    end

    if kind == KEY_FACTION then
        local f = Faction.getFaction(rest)
        if not f then
            return out
        end
        return CollectRoster(f:getOwner(), f:getPlayers())
    end

    print("WQS_MP WARN unknown session key kind: " .. tostring(factionKey))
    return out
end

local function GetOnlineMap()
    local map = {}
    if IsSinglePlayer() then
        local p = getSpecificPlayer(0)
        if p then
            map[SP_KEY] = p -- dead players stay in, ReconcileDeaths needs them
        end
        return map
    end
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

local function HasOnline(onlineMap)
    for k, v in pairs(onlineMap) do
        return true
    end
    return false
end

--- Effective roster = current roster - dead - offline.
--- Dead is cleared again on respawn (see ReconcileDeaths), offline is
--- temporary (rejoin restores membership).
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

--- Kahlua has no next(), so per user flag tables are pruned by rebuilding.
local function PruneByRoster(t, inRoster)
    local out = {}
    if not t then
        return out
    end
    for k, v in pairs(t) do
        if inRoster[k] then
            out[k] = v
        end
    end
    return out
end

--- Rebuilds the roster from the live faction.
--- The roster used to be a one shot snapshot taken at session creation, which
--- broke three ways at once: someone who left the faction stayed in the
--- effective roster and both gates waited forever on a player whose commands
--- were now rejected; someone who joined afterwards was never in Broadcast's
--- loop so they never received a single snapshot; and neither could ever be
--- repaired without wiping the session.
local function SyncRoster(factionKey, sess)
    local fresh = GetFactionRoster(factionKey)

    local same = (#fresh == #sess.Roster)
    if same then
        for i = 1, #fresh do
            if sess.Roster[i] ~= fresh[i] then
                same = false
            end
        end
    end
    if same then
        return false
    end

    local inRoster = {}
    for i = 1, #fresh do
        inRoster[fresh[i]] = true
    end

    sess.Roster = fresh
    sess.Ready = PruneByRoster(sess.Ready, inRoster)
    sess.Arrived = PruneByRoster(sess.Arrived, inRoster)
    sess.Dead = PruneByRoster(sess.Dead, inRoster)
    sess.Extracted = PruneByRoster(sess.Extracted, inRoster)

    print("WQS_MP roster resynced faction=" .. factionKey .. " members=" .. #fresh)
    return true
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
--- (WQS.getActualExtractionStats: Distance_isok and Zlevel_isok).
--- Z is floored on both sides now: comparing a float getZ() to an int with ==
--- disagreed with the server on stairs and ramps.
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

--- Resolves one of the "random_*" options of the headquarters menu into a
--- concrete zone. Shared by session creation and by the SetExtractionMap
--- command, so both sides obey the same Louisville filters.
local function RollExtractionMap(randOptName)
    local pool = {}
    for k, v in pairs(WQS_ExtractionPointsData) do
        local item = v.MapItem
        if item and item ~= "" and not ContainsLower(item, "random") then
            local isLou = ContainsLower(item, "louisville")
            local take = true
            if randOptName == "random_only_louisville" then
                take = isLou
            elseif randOptName == "random_excluding_louisville" then
                take = not isLou
            end
            if take then
                table.insert(pool, item)
            end
        end
    end
    if #pool == 0 then
        print("WQS_MP ERROR RollExtractionMap: empty pool for " .. tostring(randOptName))
        return nil
    end
    return pool[ZombRand(#pool) + 1]
end

--- Picks the session extraction map once, from the sandbox options.
local function PickExtractionMap(factionKey)
    -- Singleplayer save compatibility: an existing character already has a
    -- zone written into its ModData by the pre session code. Rerolling here
    -- would move the extraction point of a run already in progress.
    if factionKey == SP_KEY then
        local p = getSpecificPlayer(0)
        if p then
            local md = p:getModData()
            if md and md.PlayerExtractionMap and md.PlayerExtractionMap ~= "" then
                print("WQS_MP reusing the extraction map stored on the character: " ..
                    tostring(md.PlayerExtractionMap))
                return md.PlayerExtractionMap
            end
        end
    end

    local zoneIdx = SandboxVars.WQS_ZoneMap_opt
    local randOpt = SandboxVars.WQS_ZoneMap_random_opt

    local fixed = WQS_ExtractionPointsData[zoneIdx]
    if fixed and fixed.MapItem ~= "random" and fixed.MapItem ~= "" then
        return fixed.MapItem
    end

    local randName = "random_all_zones"
    if randOpt == 2 then
        randName = "random_only_louisville"
    elseif randOpt == 3 then
        randName = "random_excluding_louisville"
    end

    local rolled = RollExtractionMap(randName)
    if not rolled then
        print("WQS_MP ERROR PickExtractionMap: empty pool, falling back to index 2")
        return WQS_ExtractionPointsData[2].MapItem
    end
    return rolled
end

--- True if the MapItem really is a registered extraction zone.
local function IsKnownExtractionMap(item)
    if not item then
        return false
    end
    for k, v in pairs(WQS_ExtractionPointsData) do
        if v and v.MapItem == item and v.MapCenterAreaX and v.MapCenterAreaX > 0 then
            return true
        end
    end
    return false
end

-- ##############################################################
-- repeater targets
-- ##############################################################

local function RepeaterKey(rep)
    return tostring(rep.area) .. "|" .. tostring(rep.name)
end

--- Repeater candidates, minus the ones sitting on top of an extraction point.
--- Ported from WQSAntenna.RemoveRepeatersTooCloseToExtrPoints, but non
--- destructive: the original nil'd entries out of the shared WQS_RepeaterData
--- table, permanently damaging it for every later run.
--- Cached across calls: the pool only depends on the loaded map set and on the
--- extraction points, neither of which changes once a session is running.
--- AddRepeaterTarget used to rebuild the whole thing on every fragment.
local RepeaterPoolCache = nil
local RepeaterPoolZoneCount = -1

local function CountExtractionPoints()
    local n = 0
    for k, v in pairs(WQS_ExtractionPointsData) do
        n = n + 1
    end
    return n
end

local function BuildRepeaterPool()
    -- Modded extraction zones are registered from OnServerStarted, so the
    -- table can still grow after the first call. Rebuild when it does.
    local zoneCount = CountExtractionPoints()
    if RepeaterPoolCache and RepeaterPoolZoneCount == zoneCount then
        return RepeaterPoolCache
    end

    local pool = {}
    local dropMod, dropBounds, dropNear = 0, 0, 0
    local missing = {}

    for rk, rep in pairs(WQS_RepeaterData) do
        if rep and rep.x and rep.y then
            local drop = nil

            -- Gate 1: the map mod's map folder has to be in Map=, not just
            -- the mod itself enabled in Mods=/WorkshopItems=. A mod can be
            -- active (its Lua/scripts loaded) while its map was never added
            -- to Map=, in which case the cells this repeater sits on were
            -- never merged into the world at all.
            local reqMod = WQS_Shared.GetRepeaterRequiredMod(rep)
            if reqMod and not WQS_Shared.IsMapLoaded(reqMod) then
                drop = "mod"
                missing[reqMod] = (missing[reqMod] or 0) + 1
            end

            -- Gate 2: safety net for locations with no requirement entry.
            if not drop and not WQS_Shared.IsInsideLoadedMap(rep.x, rep.y) then
                drop = "bounds"
                print("WQS_MP WARN repeater outside loaded map, no requirement entry: area=" ..
                    tostring(rep.area) .. " name=" .. tostring(rep.name) ..
                    " x=" .. tostring(rep.x) .. " y=" .. tostring(rep.y))
            end

            -- Gate 3: unchanged, keep repeaters away from extraction points.
            if not drop then
                for pk, pdata in pairs(WQS_ExtractionPointsData) do
                    if pdata and pdata.MapCenterAreaX and pdata.MapCenterAreaX > 0 then
                        local dx = rep.x - pdata.MapCenterAreaX
                        local dy = rep.y - pdata.MapCenterAreaY
                        if math.sqrt((dx * dx) + (dy * dy)) < 130 then
                            drop = "near_extraction"
                        end
                    end
                end
            end

            if not drop then
                table.insert(pool, rep)
            elseif drop == "mod" then
                dropMod = dropMod + 1
            elseif drop == "bounds" then
                dropBounds = dropBounds + 1
            else
                dropNear = dropNear + 1
            end
        end
    end

    for modId, n in pairs(missing) do
        print("WQS_MP repeater map not installed: " .. modId .. " (" .. n .. " locations dropped)")
    end
    print("WQS_MP repeater pool built: usable=" .. #pool ..
        " droppedByMissingMap=" .. dropMod ..
        " droppedOutOfBounds=" .. dropBounds ..
        " droppedNearExtraction=" .. dropNear)

    RepeaterPoolCache = pool
    RepeaterPoolZoneCount = zoneCount
    return pool
end

--- Picks one repeater far enough from the already chosen ones.
--- The retry counter used to be skipped whenever dist was exactly 0, which is
--- precisely the case of re-drawing an already chosen repeater, so a small
--- pool could spin this loop forever and hang the server thread.
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
            end
        end
        if good then
            return pick
        end
        fail = fail + 1
    end

    -- Distance rules cannot be met with this pool. Anything not already on the
    -- list is still a valid objective, a duplicate is not.
    for i = 1, #pool do
        local dup = false
        for j = 1, #chosen do
            if pool[i].x == chosen[j].x and pool[i].y == chosen[j].y then
                dup = true
            end
        end
        if not dup then
            print("WQS_MP WARN PickRepeater: spacing rules unsatisfiable, using any free spot")
            return pool[i]
        end
    end

    print("WQS_MP ERROR PickRepeater: candidate pool exhausted")
    return nil
end

local function GetMaxRepeaters()
    return SandboxVars.WQS_RepeatersModeHowMany_opt
end

local function IsRepeatersMode()
    return GetMaxRepeaters() > 0
end

--- Server side proof that an antenna really is where the client says it is.
local function AntennaOnSquare(x, y, z)
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then
        return false
    end
    local objs = sq:getWorldObjects()
    if not objs then
        return false
    end
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        local item = obj and obj:getItem() or nil
        if item and item:getType() == ANTENNA_ITEM then
            return true
        end
    end
    return false
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
        ExtractionMap = PickExtractionMap(factionKey),
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

--- Full wipe. Used when the whole faction is dead (the run failed, repeater
--- progress is lost and fragments must be collected again), when the faction
--- itself is gone, and when a finished run has no one left to show it to.
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

function WQS_MPSession.GetDurationMinutes()
    local h = SandboxVars.WQS_ExtractionEventHoursDuration_opt
    return h * 60
end

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

function WQS_MPSession.CountActive(sess)
    local n = 0
    for k, v in pairs(sess.ActiveRepeaters) do
        n = n + 1
    end
    return n
end

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

--- Pushes the snapshot to every online member of the roster.
--- Offline members are skipped; they get a fresh snapshot on their next Join.
local function Broadcast(factionKey, sess)
    local onlineMap = GetOnlineMap()
    local snap = BuildSnapshot(factionKey, sess, onlineMap)
    local sent = 0
    for i = 1, #sess.Roster do
        local p = onlineMap[sess.Roster[i]]
        if p then
            SendTo(p, "Sync", snap)
            sent = sent + 1
        end
    end
    WQS_Shared.DLog("broadcast faction=" .. factionKey .. " to=" .. sent ..
        " roster=" .. #sess.Roster .. " targets=" .. #snap.targets ..
        " active=" .. tostring(snap.activeCount) .. " state=" .. tostring(snap.state))
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

--- Session timer.
--- With ConfinedMode on, the timer pauses instead of resetting anyone's
--- progress. Who has to be inside for it to keep running is picked by
--- WQS_ConfinedTimerRule_opt:
---   1 = every effective member (one straggler pauses the whole run)
---   2 = at least one effective member (the run keeps going while someone holds
---       the zone, so a death run back does not freeze the clock)
--- ConfinedMode is deliberately ignored once the completion gate has latched:
--- the only thing that stops the spawner is reaching stage 4, and stage 4 only
--- exists past the full duration, so the clock has to keep going no matter who
--- wanders off after the unlock.
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

    if sess.State == ST_RUNNING and SandboxVars.WQS_ConfinedMode_opt == true then
        local mapData = GetMapDataByItem(sess.ExtractionMap)
        if SandboxVars.WQS_ConfinedTimerRule_opt == 2 then
            local anyInside = false
            for i = 1, #eff do
                if IsPlayerInZone(onlineMap[eff[i]], mapData) then
                    anyInside = true
                    break
                end
            end
            if not anyInside then
                return -- paused, progress preserved
            end
        else
            for i = 1, #eff do
                if not IsPlayerInZone(onlineMap[eff[i]], mapData) then
                    return -- paused, progress preserved
                end
            end
        end
    end

    sess.ElapsedMinutes = sess.ElapsedMinutes + delta

    -- Park the clock inside stage 4 (ceil(elapsed / (duration/3)) == 4) so the
    -- ending stays latched: WQS_ExtractionEvent bails out entirely above 4 and
    -- would never run the spawn stop.
    local maxElapsed = (WQS_MPSession.GetDurationMinutes() * 4) / 3
    if sess.ElapsedMinutes > maxElapsed then
        sess.ElapsedMinutes = maxElapsed
    end
end

--- Keeps the per member "in the zone" flags fresh for the roster line.
local function RefreshArrived(sess, onlineMap)
    local mapData = GetMapDataByItem(sess.ExtractionMap)
    local eff = GetEffectiveRoster(sess, onlineMap)
    for i = 1, #eff do
        local u = eff[i]
        sess.Arrived[u] = IsPlayerInZone(onlineMap[u], mapData)
    end
    return eff
end

--- Completion gate: after the timer expires, every effective member must stand
--- in the zone. Once satisfied the state latches to UNLOCKED and never falls
--- back, so the button cannot flicker while the horde pushes people around.
local function EvaluateCompletionGate(factionKey, sess, onlineMap)
    local eff = RefreshArrived(sess, onlineMap)

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

--- Run end: everybody still in the run has confirmed the end modal.
--- ST_DONE used to be declared and never assigned, which left a finished
--- faction stuck in UNLOCKED forever, across server restarts included.
local function EvaluateDoneGate(factionKey, sess, onlineMap)
    if sess.State ~= ST_UNLOCKED then
        return false
    end
    local eff = GetEffectiveRoster(sess, onlineMap)
    if #eff == 0 then
        return false
    end
    for i = 1, #eff do
        if not sess.Extracted[eff[i]] then
            return false
        end
    end

    sess.State = ST_DONE
    print("WQS_MP run finished faction=" .. factionKey .. " members=" .. #eff)
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

--- Everyone in the roster is dead -> the run failed.
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

--- Safety net for deaths the client never reported (crash right on death), and
--- the way back in: the exclusion belongs to the dead character, not to the
--- account, so a player who respawns rejoins the run. Without the second half
--- a single death locked that player out of every gate until the whole faction
--- wiped.
local function ReconcileDeaths(factionKey, sess, onlineMap)
    local changed = false
    for i = 1, #sess.Roster do
        local u = sess.Roster[i]
        local p = onlineMap[u]
        if p then
            if p:isDead() then
                if MarkDead(factionKey, sess, u, "reconcile-isDead") then
                    changed = true
                end
            elseif sess.Dead[u] then
                sess.Dead[u] = nil
                print("WQS_MP member rejoined after respawn faction=" .. factionKey .. " user=" .. u)
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
    local anyoneOnline = HasOnline(onlineMap)

    for factionKey, sess in pairs(store.Sessions) do
        -- pairs() iterates a snapshot of the keys (KahluaTableImpl), so a key
        -- removed during the loop still comes back with a nil value
        if sess then
            local changed = false
            local gone = anyoneOnline and IsGroupGone(factionKey)

            if gone then
                DestroySession(factionKey, "faction no longer exists")
            else
                if SyncRoster(factionKey, sess) then
                    changed = true
                end
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

                    if sess.State == ST_RUNNING or sess.State == ST_UNLOCKED then
                        AdvanceTimer(factionKey, sess, onlineMap)
                        changed = true -- timer moved, clients need the tick
                    end

                    if sess.State == ST_RUNNING then
                        if EvaluateCompletionGate(factionKey, sess, onlineMap) then
                            changed = true
                        end
                    elseif sess.State == ST_UNLOCKED then
                        RefreshArrived(sess, onlineMap)
                        if EvaluateDoneGate(factionKey, sess, onlineMap) then
                            changed = true
                        end
                    end

                    if sess.State == ST_DONE and #GetEffectiveRoster(sess, onlineMap) == 0 then
                        DestroySession(factionKey, "run finished and nobody left in it")
                    elseif changed then
                        Broadcast(factionKey, sess)
                    end
                end
            end
        end
    end
end

--- Modes 2 and 3 lean entirely on vanilla group features, and PlayerSafehouse
--- is false by default, so picking mode 3 on a stock server locks every player
--- out with no visible cause. Say so once instead of failing quietly.
local function LogGroupConfig()
    local mode = SandboxVars.WQS_GroupMode_opt
    local so = getServerOptions()
    local faction, safehouse = nil, nil
    if so then
        faction = so:getBoolean("Faction")
        safehouse = so:getBoolean("PlayerSafehouse")
    end
    print("WQS_MP group config mode=" .. tostring(mode) ..
        " serverFaction=" .. tostring(faction) ..
        " serverPlayerSafehouse=" .. tostring(safehouse))
    if mode == GROUP_FACTION_ONLY and faction == false then
        print("WQS_MP ERROR group mode 2 requires server option Faction=true, nobody can extract")
    end
    if mode == GROUP_SAFEHOUSE_ONLY and safehouse == false then
        print("WQS_MP ERROR group mode 3 requires server option PlayerSafehouse=true, nobody can extract")
    end
end

local function OnTickPoll()
    if not IsHost() then
        return
    end
    local now = getTimeInMillis()
    if (now - LastPoll) < POLL_DELAY_MS then
        return
    end
    LastPoll = now
    -- An admin can change the group mode at runtime through the server sandbox
    -- options UI, and SandboxOptions.toLua() fires no Lua event. The old one
    -- shot log then described a mode that was no longer in effect, and the
    -- Faction / PlayerSafehouse mismatch warning was never re-evaluated.
    -- Comparing on the poll tick catches every path without a UI hook.
    local mode = SandboxVars.WQS_GroupMode_opt
    if LoggedGroupMode ~= mode then
        if LoggedGroupMode ~= nil then
            print("WQS_MP group mode changed at runtime from=" .. tostring(LoggedGroupMode) ..
                " to=" .. tostring(mode) ..
                ", sessions keyed for the previous mode are now unreachable")
        end
        LoggedGroupMode = mode
        LogGroupConfig()
    end
    PollSessions()
end

-- ##############################################################
-- command handlers
-- ##############################################################

local Handlers = {}

--- Client announces itself. Creates the faction session on first contact.
Handlers["Join"] = function(sess, factionKey, player, args)
    local u = GetUserKey(player)
    -- Gated by LOG_JOIN: throttling keeps this from flooding, but at one line
    -- per 3-30s it still buries the rest of the log on a long run. Turn it on
    -- when the Join rate itself is what is being measured.
    if LOG_JOIN then
        print("WQS_MP join faction=" .. factionKey .. " user=" .. u ..
            " state=" .. tostring(sess.State) .. " targets=" .. #sess.Targets ..
            " active=" .. tostring(WQS_MPSession.CountActive(sess)))
    end
    -- a rejoining member is restored unless their character is currently dead
    if player:isDead() then
        MarkDead(factionKey, sess, u, "join-isDead")
    elseif sess.Dead[u] then
        sess.Dead[u] = nil
        print("WQS_MP member rejoined after respawn faction=" .. factionKey .. " user=" .. u)
    end
    return true
end

--- Request gate toggle. Re-pressing clears the flag; when the last ready flag
--- is cleared the session falls back to PRE so a crash cannot deadlock it.
Handlers["ToggleReady"] = function(sess, factionKey, player, args)
    local u = GetUserKey(player)

    if sess.State ~= ST_PRE and sess.State ~= ST_PENDING then
        print("WQS_MP ToggleReady rejected, state=" .. sess.State .. " user=" .. u)
        SendTo(player, "ReadyRejected", { reason = "state" })
        return false
    end
    if sess.Dead[u] then
        print("WQS_MP ToggleReady rejected, dead user=" .. u)
        SendTo(player, "ReadyRejected", { reason = "dead" })
        return false
    end
    if IsRepeatersMode() and WQS_MPSession.CountActive(sess) < GetMaxRepeaters() then
        print("WQS_MP ToggleReady rejected, signal too weak user=" .. u)
        SendTo(player, "ReadyRejected", { reason = "signal" })
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
--- The answer is acknowledged either way, because the fragments are already
--- gone by the time the client asks: a silent rejection destroyed them.
Handlers["AddRepeaterTarget"] = function(sess, factionKey, player, args)
    if not IsRepeatersMode() then
        print("WQS_MP AddRepeaterTarget rejected, repeaters mode is off")
        SendTo(player, "AddTargetFailed", { reason = "mode" })
        return false
    end
    if #sess.Targets >= GetMaxRepeaters() then
        print("WQS_MP AddRepeaterTarget rejected, list full faction=" .. factionKey)
        SendTo(player, "AddTargetFailed", { reason = "full" })
        return false
    end
    local pool = BuildRepeaterPool()
    local pick = PickRepeater(pool, sess.Targets)
    if not pick then
        print("WQS_MP ERROR AddRepeaterTarget: no candidate available")
        SendTo(player, "AddTargetFailed", { reason = "nocandidate" })
        return false
    end
    table.insert(sess.Targets, { area = pick.area, name = pick.name, x = pick.x, y = pick.y, z = pick.z or 0 })
    print("WQS_MP target added faction=" .. factionKey ..
        " area=" .. tostring(pick.area) .. " name=" .. tostring(pick.name) ..
        " total=" .. #sess.Targets)
    SendTo(player, "AddTargetOk", {})
    return true
end

--- Activates a target repeater. One antenna per location satisfies the whole
--- faction, so members can split up and cover different sites.
--- Everything in args is checked against the world: the previous version took
--- the coordinates on faith, so one edited client could light up every
--- repeater of its faction from anywhere on the map, at any point of the run.
Handlers["ActivateRepeater"] = function(sess, factionKey, player, args)
    local u = GetUserKey(player)
    local ax = args.x
    local ay = args.y
    local az = args.z or 0
    if not ax or not ay then
        return false
    end

    -- repeaters are the prerequisite for requesting extraction; lighting one
    -- up mid run means nothing
    if sess.State ~= ST_PRE and sess.State ~= ST_PENDING then
        print("WQS_MP ActivateRepeater rejected, state=" .. sess.State .. " user=" .. u)
        return false
    end

    local pdx = player:getX() - ax
    local pdy = player:getY() - ay
    if math.sqrt((pdx * pdx) + (pdy * pdy)) > (ACTIVATION_DISTANCE + 2) then
        print("WQS_MP ActivateRepeater rejected, player is not next to the claimed antenna user=" .. u)
        return false
    end
    if math.floor(player:getZ() + 0.5) ~= math.floor(az + 0.5) then
        print("WQS_MP ActivateRepeater rejected, z level mismatch user=" .. u)
        return false
    end
    if not AntennaOnSquare(ax, ay, az) then
        print("WQS_MP ActivateRepeater rejected, no antenna on the claimed square user=" .. u)
        return false
    end

    for i = 1, #sess.Targets do
        local t = sess.Targets[i]
        local key = RepeaterKey(t)
        if not sess.ActiveRepeaters[key] then
            local dx = ax - t.x
            local dy = ay - t.y
            if math.sqrt((dx * dx) + (dy * dy)) <= ACTIVATION_DISTANCE then
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

--- Antenna pickup. The original mod dropped a repeater from the active list
--- as soon as the antenna item was no longer on its square, so one antenna
--- could never light up two places at once. That check used to live on the
--- client, where it could not stay: the list is faction wide now, and an
--- unloaded chunk is indistinguishable from a removed antenna, so a client
--- walking away would wipe the team's progress.
--- The report is therefore only a hint. Everything is re-proved here:
--- the reporter has to stand next to the repeater, the server has to be able
--- to see that square itself, and the antenna has to be genuinely absent from
--- the server's own view. A client that lies, that is out of range, or that
--- disagrees with the server about the tile (see the antenna coordinate
--- mismatch, WQS_antenna.lua) changes nothing.
Handlers["DeactivateRepeater"] = function(sess, factionKey, player, args)
    local u = GetUserKey(player)
    if not args.area or not args.name then
        return false
    end
    local key = tostring(args.area) .. "|" .. tostring(args.name)

    local act = sess.ActiveRepeaters[key]
    if not act then
        return false
    end

    local pdx = player:getX() - act.x
    local pdy = player:getY() - act.y
    if math.sqrt((pdx * pdx) + (pdy * pdy)) > (ACTIVATION_DISTANCE + 2) then
        print("WQS_MP DeactivateRepeater rejected, reporter is not next to the repeater key=" ..
            key .. " user=" .. u)
        return false
    end

    -- an unloaded square on the server side proves nothing either way
    if not getCell():getGridSquare(act.x, act.y, act.z) then
        print("WQS_MP DeactivateRepeater rejected, square not loaded server side key=" ..
            key .. " user=" .. u)
        return false
    end
    if AntennaOnSquare(act.x, act.y, act.z) then
        print("WQS_MP DeactivateRepeater rejected, antenna still on the square key=" ..
            key .. " user=" .. u)
        return false
    end

    sess.ActiveRepeaters[key] = nil
    print("WQS_MP repeater deactivated faction=" .. factionKey ..
        " key=" .. key .. " by=" .. u)
    return true
end

--- Headquarters menu: request a different extraction zone for the faction.
--- The zone is session state, so the old client side WQS.setCurretExtractionMap
--- wrote it into the caller's own ModData where nobody, not even the caller,
--- would ever read it again.
Handlers["SetExtractionMap"] = function(sess, factionKey, player, args)
    local u = GetUserKey(player)

    -- changing the destination mid run would teleport the objective under
    -- everybody's feet, and after the unlock it would undo the ending
    if sess.State ~= ST_PRE then
        print("WQS_MP SetExtractionMap rejected, state=" .. sess.State .. " user=" .. u)
        return false
    end

    local item = args.item
    local randOptName = args.randOpt

    local chosen = nil
    if item == "random" then
        chosen = RollExtractionMap(randOptName)
    elseif IsKnownExtractionMap(item) then
        chosen = item
    end

    if not chosen then
        print("WQS_MP SetExtractionMap rejected, unknown zone=" .. tostring(item) .. " user=" .. u)
        return false
    end
    if chosen == sess.ExtractionMap then
        print("WQS_MP SetExtractionMap no-op, already map=" .. tostring(chosen) .. " user=" .. u)
        return false
    end

    sess.ExtractionMap = chosen
    print("WQS_MP extraction map changed faction=" .. factionKey ..
        " map=" .. tostring(chosen) .. " by=" .. u)
    return true
end

Handlers["ReportDeath"] = function(sess, factionKey, player, args)
    return MarkDead(factionKey, sess, GetUserKey(player), "client-report")
end

--- Player confirmed the end modal and is leaving.
Handlers["Extracted"] = function(sess, factionKey, player, args)
    if sess.State ~= ST_UNLOCKED and sess.State ~= ST_DONE then
        return false
    end
    local u = GetUserKey(player)
    sess.Extracted[u] = true
    print("WQS_MP extracted faction=" .. factionKey .. " user=" .. u)
    return true
end

local function LogNoFaction(u, command)
    local now = getTimeInMillis()
    local last = NoFactionLogged[u]
    if last and (now - last) < NOFACTION_LOG_MS then
        return
    end
    NoFactionLogged[u] = now
    print("WQS_MP command rejected, no faction user=" .. tostring(u) .. " cmd=" .. tostring(command))
end

--- Never throttled: a key transition means a session was joined, left or
--- swapped, which happens a handful of times per session at most.
local function LogKeyChange(u, factionKey)
    local cur = factionKey or "<none>"
    local prev = LastKeyByUser[u]
    if prev == cur then
        return
    end
    LastKeyByUser[u] = cur
    print("WQS_MP key changed user=" .. tostring(u) ..
        " from=" .. tostring(prev or "<unset>") .. " to=" .. cur)
end

local function DispatchCommand(player, command, args)
    if not player then
        return
    end

    local u = GetUserKey(player)
    local factionKey = WQS_MPSession.GetFactionKey(u)
    LogKeyChange(u, factionKey)

    if not factionKey then
        -- The recipe has already consumed the fragments by the time the command
        -- arrives, and NoFaction alone never reaches OnAddTargetResult, so
        -- without this reply the craft destroys four fragments silently.
        if command == "AddRepeaterTarget" then
            SendTo(player, "AddTargetFailed", { reason = "nogroup" })
        end
        -- an empty table deserialises as nil on the client, so never send {}
        SendTo(player, "NoFaction", { t = 1 })
        LogNoFaction(u, command)
        return
    end

    local sess = WQS_MPSession.GetSession(factionKey, true)
    if not sess then
        return
    end

    -- the roster has to be current before any gate arithmetic happens,
    -- otherwise a command from a fresh member is counted against a stale list
    local rosterChanged = SyncRoster(factionKey, sess)

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
    if changed or rosterChanged or command == "Join" then
        Broadcast(factionKey, sess)
    end
end

local function OnClientCommand(module, command, player, args)
    if not isServer() then
        return
    end
    if module ~= MODULE then
        return
    end
    DispatchCommand(player, command, args or {})
end

--- Singleplayer entry point: WQS_Session.Send calls this instead of going
--- through sendClientCommand, which no event would ever deliver.
function WQS_MPSession.LocalCommand(command, args)
    if not IsSinglePlayer() then
        return
    end
    DispatchCommand(getSpecificPlayer(0), command, args or {})
end

Events.OnClientCommand.Add(OnClientCommand)
Events.OnTick.Add(OnTickPoll)

print("WQS_MP session module loaded, host=" .. tostring(IsHost()) .. " sp=" .. tostring(IsSinglePlayer()))
