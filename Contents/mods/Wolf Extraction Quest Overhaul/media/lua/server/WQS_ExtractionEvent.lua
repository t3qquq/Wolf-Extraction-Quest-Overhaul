--[[
1 Meteo normale, spawno zombie e rumori d
2 Temporali, spawno zombie
3 Temporali forti + rumore elicottero che non può atterrare
maggiore di 3 -> finalee
 ]]
local SpawnCFG = {}

-- numero di partenza di zombie da spawnare PER STAGE, si incrementa ad ogni stage, numero modificato dopo, inutile questo valore
SpawnCFG.total_to_spawn = 6
-- https://onecompiler.com/lua/3z98b5d9x

-- SpawnCFG.zombie_multiplier_per_spawn = 1 --quanti zombie per volta deve spawnare (di solito 1)

-- SpawnCFG.spawn_location_needed = 9
SpawnCFG.spawn_location_maxloops = 25
SpawnCFG.spawn_min_dist_from_player = 25

local SpawnedZedList = ArrayList.new()
local failsafe_spawn_loc = {}
local already_spawned = 0

local oldstage = -1
local ExtractionCurrentStage = -1

local SayDelayedList = {}
local ExecDelayedList = {}
local LastExtractionEventCheck = getTimeInMillis()
local AlreadyEmittedSoundPerStage = 0
local AdditionalZedSpawned = 0

-- SpawnCFG.total_to_spawn=math.floor(6*PopulationMultiplier)

local function GetMinuteStageDuration()
    local num_stages = 3
    local stage_duration = WQS_EXTRACTION_DURATION_TIME_MIN / num_stages -- 180/3=60
    return stage_duration
end

local function GetCurrentExtractionStage()
    local single_stage_duration = GetMinuteStageDuration()
    local stage = (math.ceil(WQS_EXTRACTION_ELAPSED_TIME / single_stage_duration))
    return stage
end


function WQS_ExtractionEventCheckUpdate()
    local NOWZ = getTimeInMillis() -- getMinutes() --os.time() --getTimeInMillis()
    local delay = 4000

    if (NOWZ - LastExtractionEventCheck) > delay then
        LastExtractionEventCheck = getTimeInMillis()
        WQS_ExtractionEvent()
    end
end

function StartStorm(h_duration)
    local default_duration = (math.ceil((GetMinuteStageDuration() * 2) / 60) - 1) or 3
    h_duration = h_duration or default_duration
    print("WQS Starting STORM duration hours=" .. h_duration)
    getGameTime():setThunderDay(true)
    if isClient() then --multiplayer
        --8 è STAGE_TROPICAL_STORM ma se lo passo non lo prende perciò uso direttamente il numero
        local pl = WQS.GetCurrentPlayer()
        local args = { stage = 8, duration = h_duration }
        print("WQS Starting STORM request from a client stage=" .. tostring(args["stage"]) .. " hours=" ..
            args["duration"])
        sendClientCommand(pl, "WQS_ServerSideModule", "WQS_DoStartStorm", args)
        return
    else
        getClimateManager():stopWeatherAndThunder()
        getClimateManager():triggerCustomWeatherStage(WeatherPeriod.STAGE_TROPICAL_STORM, h_duration);
    end
end

function StopStorm()
    if isServer() then
        getClimateManager():transmitStopWeather()
    else
        getClimateManager():stopWeatherAndThunder()
    end
end

-- spawnHorde(regionSpawn.x,regionSpawn.y,regionSpawn.x2,regionSpawn.y2,regionSpawnZ, 250);

local function ForceEmitSoundOnPlayer(displace, added_range)
    displace = displace or 0
    added_range = added_range or 0
    local pl = WQS.GetCurrentPlayer()
    local range = 35 + (GetCurrentExtractionStage() * 2) +
        math.ceil(WQS_EXTRACTION_DIFFICULTY_MULTIPLIER * 15) -- 1.0-> range= 45 47 49  2.0->range= 58 60 62
    -- https://onecompiler.com/lua/3z9qufpnd
    -- old 13 26  https://onecompiler.com/lua/3z9qbvtks
    if not (pl) then
        return nil
    end
    range = range + math.ceil(added_range * 1) + (pl:getZ() * 1)

    local sLocationX = math.ceil(pl:getX() + displace)
    local sLocationY = math.ceil(pl:getY() + displace)
    if ((ZombRand(2) == 0) and (displace > 0)) then
        sLocationX = 0 - sLocationX;
    end
    -- getWorldSoundManager():addSound(hPlayer, hPlayer:getCurrentSquare():getX(), hPlayer:getCurrentSquare():getY(), hPlayer:getCurrentSquare():getZ(), 200, 10);
    addSound(pl, sLocationX, sLocationY, pl:getZ(), range, 100);
    -- print("Sound forced on player range="..range.." x "..sLocationX.."="..pl:getX()+displace.." y "..sLocationY.."="..pl:getY()+displace)
    print("Sound forced on player range=" .. range)

    assaultPlayer() -- ?
    -- SpawnedZedAlertRepath()
end

local function FindSpawnLocation()
    -- howmany = howmany or SpawnCFG.spawn_location_needed
    local cPlayer = WQS.GetCurrentPlayer()

    if not (cPlayer) then
        return {}
    end

    local pLocation = cPlayer:getCurrentSquare();
    local mapcurrent = WQS.getCurretExtractionMap()
    local PreferredSpawnPointsList = WQS_Shared.getPreferredSpawnPointsData()
    local zLocationX = 0;
    local zLocationY = 0;
    local canSpawn = false;
    local pick_from_failsafe = false
    local sl = {}
    sl.x = nil
    local target_z = 0

    if not (pLocation) then
        print("########### WQS FindSpawnLocation ERROR -> Player square not found!!")
        return {}
    end

    local use_preferred_spawn_loc = WQS_Shared.RandomPerc(WQS.getMapPreferredSpawnPointPerc())

    -- print("use_preferred_spawn_loc "..tostring(use_preferred_spawn_loc))
    -- print("mapcurrent "..mapcurrent)
    -- print("pref "..WQS_Shared.Dump(PreferredSpawnPointsList[mapcurrent]))

    if (use_preferred_spawn_loc) and not (PreferredSpawnPointsList[mapcurrent] == nil) then
        --print("### WQS FindSpawnLocation from PreferredSpawnPointsList")
        local PrefSpawn = WQS_Shared.PickRandomObjFromTable(PreferredSpawnPointsList[mapcurrent])
        --print("PrefSpawn "..WQS_Shared.Dump(PrefSpawn))
        if PrefSpawn.x then
            local p = cPlayer
            local LosResult = tostring(LosUtil.lineClear(p:getCell(), PrefSpawn.x, PrefSpawn.y, PrefSpawn.z, p:getX(),
                p:getY(), p:getZ(), false))
            LosResult = string.lower(LosResult)
            print("##### PreferredSpawnPoint (" ..
                WQS.getMapPreferredSpawnPointPerc() ..
                "%) -> " .. PrefSpawn.x .. "," .. PrefSpawn.y .. " z=" .. PrefSpawn.z)
            --local losr=LosResult:find("blocked", 1, true)
            if (LosResult:find("blocked", 1, true)) then
                --print("##### Los blocked, CAN spawn at -> "..PrefSpawn.x..","..PrefSpawn.y.." z="..PrefSpawn.z)
                sl.x = PrefSpawn.x
                sl.y = PrefSpawn.y
                sl.z = PrefSpawn.z or 0
                return sl
            else
                --print("###### Los is clear, player can see it, NOT spawn at -> "..PrefSpawn.x..","..PrefSpawn.y.." z="..PrefSpawn.z)
            end
        end
    end


    -- La distanza a cui spawnano gli zombie è minore quanto maggiore è la Z level del player
    SpawnCFG.spawn_min_dist_from_player = (SpawnCFG.spawn_min_dist_from_player - (math.floor(pLocation:getZ() * 1.5))) or
        15

    if SpawnCFG.spawn_min_dist_from_player < 15 then
        SpawnCFG.spawn_min_dist_from_player = 15
    end

    for i = 1, SpawnCFG.spawn_location_maxloops do
        -- print("loop: "..i)

        -- uno o due piani sotto il player
        local varianceZ = 1
        -- print("pl z="..pLocation:getZ().." variancez= "..varianceZ)
        if ZombRand(6) == 0 then
            varianceZ = 2
        end
        target_z = (pLocation:getZ() - varianceZ)

        local PreferredZlevel = WQS.getMapPreferredZlevelSpawn()
        if not (PreferredZlevel == nil) then
            target_z = PreferredZlevel
            -- print(" # setting target_z to PreferredZlevel="..target_z)
        end

        if target_z < 0 then
            target_z = 0
        end

        --se devo spawnare zed sotto il player riduco la distanza
        if target_z < pLocation:getZ() then
            SpawnCFG.spawn_min_dist_from_player = 6 + ZombRand(5)
        end

        if ZombRand(2) == 0 then
            zLocationX = ZombRand(5) - 5 + SpawnCFG.spawn_min_dist_from_player;
            zLocationY = ZombRand(SpawnCFG.spawn_min_dist_from_player * 2) - SpawnCFG.spawn_min_dist_from_player;
            if ZombRand(2) == 0 then
                zLocationX = 0 - zLocationX;
            end
        else
            zLocationY = ZombRand(5) - 5 + SpawnCFG.spawn_min_dist_from_player;
            zLocationX = ZombRand(SpawnCFG.spawn_min_dist_from_player * 2) - SpawnCFG.spawn_min_dist_from_player;
            if ZombRand(2) == 0 then
                zLocationY = 0 - zLocationY;
            end
        end
        zLocationX = zLocationX + pLocation:getX();
        zLocationY = zLocationY + pLocation:getY();

        -- local spawnSpace = getWorld():getCell():getGridSquare(zLocationX, zLocationY, 0);
        local spawnSpace = getWorld():getCell():getGridSquare(zLocationX, zLocationY, target_z);

        if spawnSpace then
            local isSafehouse = SafeHouse.getSafeHouse(spawnSpace);
            -- if spawnSpace:isSafeToSpawn() and spawnSpace:isOutside() and isSafehouse == nil then
            local cond = true
            if pLocation:getZ() > 1 then
                cond = not (spawnSpace:isOutside())
                -- print("cond "..tostring(cond))
            end
            if (spawnSpace:isSafeToSpawn()) and (isSafehouse == nil) and (cond) then
                canSpawn = true;
                pick_from_failsafe = false
                sl.x = zLocationX
                sl.y = zLocationY
                sl.z = target_z or 0
                table.insert(failsafe_spawn_loc, sl)
                -- print("OK Found place to spawn: " .. "x: " .. tostring(sl.x) .. " y: " .. tostring(sl.y))
                break
            end
        else
            -- print("Warning: Zombie Spawn Space not Loaded.");
            pick_from_failsafe = true
        end
        if i >= SpawnCFG.spawn_location_maxloops then
            -- print("Search many times and still can't find a place to spawn zombie.")
            pick_from_failsafe = true
        end
    end

    if ((pick_from_failsafe) and (#sl == 0) and (#failsafe_spawn_loc > 0)) then
        local rr = ZombRand(#failsafe_spawn_loc) + 1
        sl = failsafe_spawn_loc[rr]
        print("Picking from failsafe " .. "x: " .. tostring(sl.x) .. " y: " .. tostring(sl.y) .. " z:" .. sl.z)
    end

    if (sl.x) then
        -- print("ret ok")
        return sl
    end
    return {}
end

local function SpawnZed(x, y, z, howmany, is_smart)
    howmany = howmany or 1
    is_smart = is_smart or true
    is_smart = true --people complain, force disabled

    local COGNITION_SMART = 1
    local MEMORY_LONG = 1
    local HEARING_SENSIBLE = 1
    local OriginalCognition = getSandboxOptions():getOptionByName("ZombieLore.Cognition"):getValue()
    local OriginalMemory = getSandboxOptions():getOptionByName("ZombieLore.Memory"):getValue()
    local OriginalHearing = getSandboxOptions():getOptionByName("ZombieLore.Hearing"):getValue()
    local pl = WQS.GetCurrentPlayer()
    local zed = nil

    if x then
        if isClient() then
            --print("*** WQS SpawnZed: Player is client, this is Multiplayer");
            --print("*** ("..x..","..y.." z="..z..") n="..howmany);
            local args = { zedx = x, zedy = y, zedz = z, howmanyzed = howmany, is_smart = is_smart }
            sendClientCommand(pl, "WQS_ServerSideModule", "WQS_DoServerSpawn", args)
            return
        else
            --print("*** WQS SpawnZed: Not server or client, this is Singleplayer");

            if is_smart then
                getSandboxOptions():set("ZombieLore.Cognition", COGNITION_SMART)
                getSandboxOptions():set("ZombieLore.Memory", MEMORY_LONG)
                getSandboxOptions():set("ZombieLore.Hearing", HEARING_SENSIBLE)
            end
            -- spawnHorde(spawn_location.x, spawn_location.y, pl:getX(), pl:getY(),spawn_location.z, 1);

            -- due alla volta ne spawna
            zed = addZombiesInOutfit(x, y, z, howmany, nil, nil);
            if zed then
                zed:get(0):DoZombieStats()
                zed:get(0):makeInactive(true)
                zed:get(0):makeInactive(false)

                --zed:get(0):addAggro(pl, 250)
                --zed:get(0):spotted(pl, true)
                --zed:get(0):pathToCharacter(pl)
            end
            -- SpawnedZedList:add(zed:get(0))

            if is_smart then
                getSandboxOptions():set("ZombieLore.Cognition", OriginalCognition)
                getSandboxOptions():set("ZombieLore.Memory", OriginalMemory)
                getSandboxOptions():set("ZombieLore.Hearing", OriginalHearing)
            end
        end
    end
end

local function SpawnManager()
    local spawn_location = {}
    local additional_spawn_loc = {}
    local pl = WQS.GetCurrentPlayer()
    local zed = nil

    if (already_spawned < SpawnCFG.total_to_spawn) then
        -- trovo il player, trovo un tile spawnabile almeno distante min_distance, lo salvo in una lista
        spawn_location = FindSpawnLocation()

        --if (spawn_location) and not (spawn_location.x == nil) then
        if not (WQS_Shared.TableIsEmptyOrNil(spawn_location)) and not (spawn_location.x == nil) then
            local zxspawn = math.floor(1.5 + (WQS_EXTRACTION_DIFFICULTY_MULTIPLIER ^ 2))
            -- default 2
            SpawnZed(spawn_location.x, spawn_location.y, spawn_location.z, zxspawn, true)
            already_spawned = already_spawned + 1
            print("---Spawned: (" ..
                zxspawn .. ") " .. already_spawned * zxspawn .. "/" .. SpawnCFG.total_to_spawn * zxspawn ..
                " at " .. spawn_location.x .. "," .. spawn_location.y .. " z=" .. spawn_location.z)

            ForceEmitSoundOnPlayer()
        else
            -- print("spawn_location null")
        end
    else
        -- if ZombRand(2) == 0 then
        --ForceEmitSoundOnPlayer()
        --  end

        -- 6 sono 18 ogni 80 minuti->0.225/min ->13.5/ogni 60 min
        -- 7 sono 10 ogni 80 min -> 0.125/min -> 7.5 ogni 60 min --11
        local baseprob = 25

        if isClient() then
            --ForceEmitSoundOnPlayer()--multiplayer  faccio sempre rumore
            baseprob = 40 --se è mp c'è + probabilità di spawnare additional zed
        end

        --ForceEmitSoundOnPlayer()
        ForceEmitSoundOnPlayer(ZombRand(1), ExtractionCurrentStage + ZombRand(5))

        local additional_prob = GetCurrentExtractionStage() * 10
        if WQS_Shared.RandomPerc(baseprob + additional_prob) then
            --if ZombRand(additional_prob) == 0 then
            additional_spawn_loc = FindSpawnLocation()
            --if (additional_spawn_loc) and not (additional_spawn_loc.x == nil) then
            if not (WQS_Shared.TableIsEmptyOrNil(additional_spawn_loc)) and not (additional_spawn_loc.x == nil) then
                -- addZombiesInOutfit(additional_spawn_loc.x, additional_spawn_loc.y, additional_spawn_loc.z, 1, nil, nil);
                local nz = 1 +
                    ZombRand(math.floor(GetCurrentExtractionStage() + WQS_EXTRACTION_DIFFICULTY_MULTIPLIER / 2))
                SpawnZed(additional_spawn_loc.x, additional_spawn_loc.y, additional_spawn_loc.z, nz, true)
                AdditionalZedSpawned = AdditionalZedSpawned + nz
                local at = " at " ..
                    additional_spawn_loc.x .. "," .. additional_spawn_loc.y .. "," .. additional_spawn_loc.z
                print("Spawning " .. nz .. " additional zombie total=" .. AdditionalZedSpawned .. " " .. at)
            end
        end
    end
end

local function CheckForSomethingToSay()
    local NOWZ = getTimeInMillis()
    for k, v in pairs(SayDelayedList) do
        if ((NOWZ >= k) and (SayDelayedList[k])) then
            -- say
            local pl = WQS.GetCurrentPlayer()
            if (pl) then
                pl:Say(SayDelayedList[k]);
            end
            --print("CheckForSomethingToSay >>" .. SayDelayedList[k])
            SayDelayedList[k] = nil -- rimuovo la cosa da dire
        end
    end
end

-- function CheckForSomethingToExec()
--     local NOWZ = getTimeInMillis()
--     for k, v in pairs(ExecDelayedList) do
--         if ((NOWZ >= k) and (ExecDelayedList[k])) then
--             -- say

--             print("CheckForSomethingToExec >>" .. ExecDelayedList[k])
--             getfenv()[ExecDelayedList[k]]();
--             --ExecDelayedList[k]();
--             ExecDelayedList[k] = nil -- rimuovo la cosa da dire
--         end
--     end
-- end

local function SetSayDelayed(delaysec, texttosay)
    local NOWZ = getTimeInMillis()
    local keyz = (NOWZ + (delaysec * 1000))
    SayDelayedList[keyz] = texttosay
end

-- function SetExecDelayed(delaysec, func)
--     local NOWZ = getTimeInMillis()
--     local keyz = (NOWZ + (delaysec * 1000))
--     ExecDelayedList[keyz] = func
-- end

local function UpdateNumToSpawnFromPopMultiplier()
    -- local PopMultiplier = getSandboxOptions():getOptionByName("ZombieConfig.PopulationMultiplier"):getValue() or 1
    local PopMultiplier = WQS_EXTRACTION_DIFFICULTY_MULTIPLIER or 1
    -- SpawnCFG.total_to_spawn=1+math.ceil(1*PopMultiplier)
    -- https://onecompiler.com/lua/3z98b5d9x

    -- https://onecompiler.com/lua/3z9r23x24
    -- SpawnCFG.total_to_spawn = 2 + math.ceil(8.5 * PopMultiplier) -- 1.0-> 12 14 16  tot=42   2.0-> 20 22 24  tot=66

    -- https://onecompiler.com/lua/3zaegnnqf
    -- 1.0-> 13 15 17  tot=90  2.0-> 21 23 25  tot=138 3.0-> 28 30 32  tot=180
    SpawnCFG.total_to_spawn = 2 + math.ceil(7.8 * PopMultiplier + 0.5) + 1000 +
        (ExtractionCurrentStage * 3) -- 1.0-> 12 14 16  tot=84   2.0-> 20 22 24  tot=132  3.0-> 28 30 32  tot=180

    if ExtractionCurrentStage > 0 then
        -- incremento un po' il numero da spawnare in base allo stage
        local stage_incr = math.floor(ExtractionCurrentStage * 2)
        if ExtractionCurrentStage > 1 then
            stage_incr = math.floor(ExtractionCurrentStage * 2.5)
        end
        SpawnCFG.total_to_spawn = SpawnCFG.total_to_spawn + stage_incr
    end
    -- SpawnCFG.total_to_spawn=SpawnCFG.total_to_spawn*2
    -- SpawnCFG.zombie_multiplier_per_spawn=math.floor(PopMultiplier+0.5)
end

local function EmitSoundOnPlayer()
    local pl = WQS.GetCurrentPlayer()
    local max_sound_per_stage = 3 + ExtractionCurrentStage + math.ceil(WQS_EXTRACTION_DIFFICULTY_MULTIPLIER * 2)
    if (AlreadyEmittedSoundPerStage < max_sound_per_stage) then
        -- https://onecompiler.com/lua/3z9q9byy3
        AlreadyEmittedSoundPerStage = AlreadyEmittedSoundPerStage + 1
        -- addSound(pl, pl:getX(), pl:getY(), pl:getZ(), range, range);
        ForceEmitSoundOnPlayer(0, ExtractionCurrentStage)
        print("Sound on player max_sound_per_stage=" .. max_sound_per_stage .. " AlreadyEmitted=" ..
            AlreadyEmittedSoundPerStage)
    end
end


function WQS_PlaySound(soundnamez)
    if isClient() then --multiplayer
        local pl = WQS.GetCurrentPlayer()
        local args = { soundname = soundnamez }
        sendClientCommand(pl, "WQS_ServerSideModule", "WQS_PlaySound", args)
    else
        getSoundManager():playUISound(soundnamez)
    end
end

WQS_ExtractionEvent = function()
    ExtractionCurrentStage = GetCurrentExtractionStage()
    local sound_freq = 7 -- più è basso più è frequente
    local pl = WQS.GetCurrentPlayer()
    local HeliMainSound = "WQSHeli3"
    local HeliSecondSound = "WQSHeli2"
    local HeliQuickSound = "WQSHeli1"
    -- local HeliMainSoundDuration=72*1000 --72secondi

    if ((ExtractionCurrentStage > 4) or (ExtractionCurrentStage < 0)) then
        --print("--------exit STAGE: " .. ExtractionCurrentStage)
        return
    end

    -- if (ExtractionCurrentStage >0) and (ExtractionCurrentStage <4) then
    --     if WQS_Shared.RandomPerc(50) then
    --         ForceEmitSoundOnPlayer(ZombRand(5), ExtractionCurrentStage)
    --     end
    -- end
    -- SetSayDelayed(8,"test..")
    CheckForSomethingToSay()
    --CheckForSomethingToExec()

    if not (ExtractionCurrentStage == oldstage) then
        print("--------NEW STAGE: " .. ExtractionCurrentStage)
        oldstage = ExtractionCurrentStage
        already_spawned = 0             -- resetto così ricomincia lo spawn ad ogni fase
        AlreadyEmittedSoundPerStage = 0 -- resetto così ricomincia l'emissione di suoni ad ogni fase

        -- EmitSoundOnPlayer(true) --suono al cambio stage così gli zombie non si dimenticano del player
        UpdateNumToSpawnFromPopMultiplier()

        if not (ExtractionCurrentStage == 0) then
            ForceEmitSoundOnPlayer(0, ExtractionCurrentStage)
        end

        if (ExtractionCurrentStage == 1) then -- decollo elicottero
            -- local dur=tostring(GetMinuteStageDuration()*2)
            SetSayDelayed(1, "bZzz..")
            SetSayDelayed(5, getText("IGUI_WQS_Heli0"))
        end

        if (ExtractionCurrentStage == 2) then -- Temporali
            StartStorm()
        end

        if (ExtractionCurrentStage == 3) then -- Elicottero
            print("Helicopter near")
            WQS_PlaySound(HeliMainSound)
            --tolgo la nebbia dalla tropical storm
            --rimane forzata fino a che non sloggo e riloggo, bah :/
            if WQS_EXTRACTION_DIFFICULTY_MULTIPLIER < 1.5 then
                local fog = getClimateManager():getClimateFloat(5);
                fog:setEnableAdmin(true)
                fog:setAdminValue(0.0);
            end

            -- local rain = getClimateManager():getClimateFloat(3);
            -- rain:setEnableAdmin(true)
            -- rain:setAdminValue(0.9);

            -- local wind = getClimateManager():getClimateFloat(6);
            -- wind:setEnableAdmin(true)
            -- wind:setAdminValue(1);

            if (getClimateManager():isRaining() or getClimateManager():isSnowing()) then
                SetSayDelayed(34, "bZz..")
                SetSayDelayed(38, "bZzZz.. zz..")
                SetSayDelayed(42, getText("IGUI_WQS_Heli1")) --bad weather, helicopter can't fly down
                SetSayDelayed(47, "bZz..")
                SetSayDelayed(56, getText("IGUI_WQS_Heli1"))
            end
        end

        -- stage 4 ed ho cliccato sul tasto completa
        if (ExtractionCurrentStage >= 4) then
            print("The END")
            already_spawned = 9999999 -- forzo lo stop dello spawn
            SpawnCFG.total_to_spawn = 0

            SetSayDelayed(2, "bZz..")
            SetSayDelayed(4, getText("IGUI_WQS_Heli2"))
            WQS_PlaySound(HeliQuickSound)
            -- StopStorm()
        end
    end

    if (ExtractionCurrentStage == 3) then
        local HSoundPlaying1 = getSoundManager():isPlayingUISound(HeliMainSound)
        local HSoundPlaying2 = getSoundManager():isPlayingUISound(HeliSecondSound)
        local HSoundPlaying3 = getSoundManager():isPlayingUISound(HeliQuickSound)

        local MusicIsBusy = (HSoundPlaying1 or HSoundPlaying2 or HSoundPlaying3)

        if ZombRand(sound_freq) == 0 and not (MusicIsBusy) then
            WQS_PlaySound(HeliQuickSound)
            -- EmitSoundOnPlayer(true)
            -- addSound(pl, pl:getX()+ZombRand(10), pl:getY()+ZombRand(10), pl:getZ(), 40, 40);
            -- ForceEmitSoundOnPlayer(ZombRand(15),ExtractionCurrentStage)
            EmitSoundOnPlayer()
            print("Sound near player because chopper")
            if (ZombRand(2) == 0) and (pl) then
                pl:Say("bZzZzz.. zz..");
            end
        elseif ZombRand(sound_freq) == 1 and not (MusicIsBusy) then
            WQS_PlaySound(HeliSecondSound)
            -- EmitSoundOnPlayer()
            ForceEmitSoundOnPlayer(40 + ZombRand(10), ExtractionCurrentStage + 2)
            -- addSound(pl, pl:getX()+40+ZombRand(10), pl:getY()+40+ZombRand(10), 0, 80, 80);
            print("Sound far from player, following chopper")
            if (ZombRand(4) == 0) and (pl) then
                pl:Say("bZz..");
            end
        end
    end

    if (not (ExtractionCurrentStage == 4) and not (ExtractionCurrentStage == 0)) then
        SpawnManager()
        --ForceEmitSoundOnPlayer(ZombRand(4), ExtractionCurrentStage+ZombRand(4))
        -- if ZombRand(sound_freq) == 0 then
        --     EmitSoundOnPlayer()
        -- end
    end
end

function WQS_FindField(o, fname)
    for i = 0, getNumClassFields(o) - 1 do
        local f = getClassField(o, i)
        if tostring(f) == fname then
            return f
        end
    end
end

--[[
test WQS_OnClientCommand

pl = WQS.GetCurrentPlayer()
args2 = { zedx = pl:getX(), zedy = pl:getY(), zedz = pl:getZ(),howmanyzed=1 }
sendClientCommand(pl,"WQS_ServerSideModule", "WQS_DoServerSpawn",args2)

args = { stage = 8, duration = 1 }
sendClientCommand(pl,"WQS_ServerSideModule", "WQS_DoStartStorm",args)
sendClientCommand(pl,"WQS_ServerSideModule", "WQS_DoStopStorm",{})

/reloadlua WQS_ExtractionEvent.lua
 ]]
-- Server receive Client command, spawn zombies around.
function WQS_OnClientCommand(WQS_module, WQS_command, WQS_player, WQS_args)
    --print("GAGAZ WQS_player:"..tostring(WQS_player).." WQS_module: "..tostring(WQS_module).." WQS_command:"..tostring(WQS_command).." WQS_args: "..tostring(WQS_args))
    if not isServer() then return end
    if WQS_module ~= "WQS_ServerSideModule" then
        --print(WQS_module.." module is not WQS_ServerSideModule");
        return
    end
    --print("*** WQS Player WQS_OnClientCommand "..WQS_player:getDisplayName().." has send ClientCommand, module: " .. WQS_module .. "  command: " .. WQS_command);

    if WQS_command == "WQS_DoStartStorm" then
        getGameTime():setThunderDay(true)
        getClimateManager():stopWeatherAndThunder()
        --getClimateManager():triggerCustomWeatherStage(8, 1);
        getClimateManager():triggerCustomWeatherStage(WQS_args["stage"], WQS_args["duration"]);
    end

    if WQS_command == "WQS_DoStopStorm" then
        getClimateManager():stopWeatherAndThunder()
    end

    if WQS_command == "WQS_PlaySound" then
        local sq = WQS_player:getCurrentSquare()
        --playServerSound("WQSHeli1",sq)
        if sq then
            playServerSound(WQS_args["soundname"], sq)
        end
    end

    if WQS_command == "WQS_DoServerSpawn" then
        --print("server has received WQS_DoServerSpawn command");

        local zedx = WQS_args["zedx"]
        local zedy = WQS_args["zedy"]
        local zedz = WQS_args["zedz"]
        local howmany = WQS_args["howmanyzed"]
        --local is_smart = WQS_args["is_smart"]
        local is_smart = false --people complain, disabled

        local zed = nil
        --questo if potenzia uno zed spawnato, la modifica a cognition però non sembra funzionare lato server
        if (is_smart) then
            local COGNITION_SMART = 1
            local MEMORY_LONG = 1
            local HEARING_SENSIBLE = 1
            --salvo i vecchi valori
            local OriginalCognition = getSandboxOptions():getOptionByName("ZombieLore.Cognition"):getValue()
            local OriginalMemory = getSandboxOptions():getOptionByName("ZombieLore.Memory"):getValue()
            local OriginalHearing = getSandboxOptions():getOptionByName("ZombieLore.Hearing"):getValue()
            --setto i nuovi
            getSandboxOptions():set("ZombieLore.Cognition", COGNITION_SMART)
            getSandboxOptions():set("ZombieLore.Memory", MEMORY_LONG)
            getSandboxOptions():set("ZombieLore.Hearing", HEARING_SENSIBLE)
            getSandboxOptions():applySettings()
            getSandboxOptions():sendToServer()

            --vero e proprio spawn
            zed = addZombiesInOutfit(zedx, zedy, zedz, howmany, nil, nil);
            --trikitrukki
            if (zed) then
                local spawned_zed = zed:get(0); --solo uno (il primo) degli zed viene modificato
                spawned_zed:makeInactive(true);
                spawned_zed:makeInactive(false);
                spawned_zed:DoZombieStats();
                spawned_zed:setTarget(WQS_player)
            end
            --rimetto i vecchi valori
            getSandboxOptions():set("ZombieLore.Cognition", OriginalCognition)
            getSandboxOptions():set("ZombieLore.Memory", OriginalMemory)
            getSandboxOptions():set("ZombieLore.Hearing", OriginalHearing)
            getSandboxOptions():applySettings()
            getSandboxOptions():sendToServer()
        else
            zed = addZombiesInOutfit(zedx, zedy, zedz, howmany, nil, nil);
        end
    end
end

Events.OnClientCommand.Add(WQS_OnClientCommand);
