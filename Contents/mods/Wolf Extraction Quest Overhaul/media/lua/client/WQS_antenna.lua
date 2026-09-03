WQSAntenna = {}

WQSAntenna.AntennaIsNear = nil
WQSTEMP = nil

-- local function WQSAcontextMenuOptions(player, context, worldobjects)
--     local item_type=nil
--     for i, testItem in ipairs(worldobjects) do
--         print("----testItem "..tostring(testItem))
--         print("-------getObjectName "..tostring(testItem:getObjectName()) )
--         print("-------:getSquare() "..tostring(testItem:getSquare()) )

--         if testItem:getSquare() then
--             local worldItems = testItem:getSquare():getWorldObjects();
--             print("-------:worldItems "..tostring(worldItems) )
--             if worldItems and not worldItems:isEmpty() then
--                 worldItem = worldItems:get(0);
--                 WQSTEMP=worldItem
--                 print("-------:zzz getName "..tostring(worldItem:getName()) )
--                 print("-------:zzz getType "..tostring(worldItem:getType()) )
--                 item_type=worldItem:getItem():getType()
--                 print("-------:zzz item_type "..tostring(item_type) )
--             end
--         end
--         print(tostring(item_type)..":== "..tostring(WQS_Shared.getAntennaItemId()) )
--         if ((item_type) and (item_type==WQS_Shared.getAntennaItemId())) then
--             context:addOption("Call the headquarters", testItem, WQSAntenna.CallHQ)
--             break
--         end
--     end
-- end

-- WQS.CallHQ = function()
--     print("----CallHQ "..tostring(testItem:getType()))
-- end



-- Events.OnFillWorldObjectContextMenu.Add(WQSAcontextMenuOptions);

local LastMainStatusCheck = getTimeInMillis()

local function AntennaStatusCheckUpdate()
    local NOWZ = getTimeInMillis() -- getMinutes() --os.time() --getTimeInMillis()
    local delay = 4000

    if (NOWZ - LastMainStatusCheck) > delay then
        LastMainStatusCheck = getTimeInMillis()
        WQSAntenna.AntennaStatusCheck() --cerca 9 celle, perciò x ottimizzare viene chiamata ogni 4 sec
        WQSAntenna.CheckStatusOfRepeaters()
    end
end

---ritorna nil se l'iten non è nella square oppure { theitem = item, world_square = square }
function IsItemOnSquare(square, ItemTypeToFind)
    local res = nil
    local wobs = square and square:getWorldObjects() or nil
    if wobs ~= nil then
        for i = 1, wobs:size() do
            local obj = wobs:get(i - 1)
            local item = obj:getItem()
            if (item) then
                local item_type = item:getType()
                local item_fulltype = item:getFullType()
                if (item) and (item_type == ItemTypeToFind or item_fulltype == ItemTypeToFind) then
                    --print("trovato")
                    --res = { theitem = item, world_square = square }
                    return { theitem = item, world_square = square }
                end
            end
        end
    end
    return res
end

--cerca un item attorno ad una square per un tile in tutte le direzioni partendo dal centro
function IsItemOnGroundNear(squareToCheck, ItemTypeToFind)
    --print("getNearMaterialOnGround "..tostring(squareToCheck))
    if not (squareToCheck) or not (ItemTypeToFind) then
        print("IsItemOnGroundNear ERROR: squareToCheck or ItemTypeToFind NULL")
        return nil
    end
    local result = nil
    local found = nil
    local range = 1
    for x = squareToCheck:getX() - range, squareToCheck:getX() + range do
        for y = squareToCheck:getY() - range, squareToCheck:getY() + range do
            local square = getCell():getGridSquare(x, y, squareToCheck:getZ())
            found = IsItemOnSquare(square, ItemTypeToFind) or nil
            if found then
                return found
            end
        end
    end
    return result
end

--- MP: the original deleted active repeaters from the local list whenever the
--- antenna item was not found on its square. That cannot stay client side: the
--- list is faction wide, so any single client could wipe the whole team's
--- progress, and an unloaded chunk looks identical to a stolen antenna.
--- Instead the missing antenna is only reported; the server re-proves it and
--- owns the decision (see Handlers["DeactivateRepeater"]).
--- Throttled per repeater because this runs every 4s and the server may
--- legitimately reject the report for a while (unloaded square on its side).
local DeactivateReported = {}
local DEACTIVATE_REPORT_MS = 10000

WQSAntenna.CheckStatusOfRepeaters = function()
    local RepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")
    if not RepeaterList then
        return {}
    end
    local now = getTimeInMillis()
    for k, SingleRepeater in pairs(RepeaterList) do
        -- ax/ay/az, not x/y/z: the latter is the target building and the
        -- antenna is allowed to stand anywhere within ACTIVATION_DISTANCE of
        -- it, so checking the target tile reported a missing antenna on every
        -- single pass. A snapshot without ax means the server did not send the
        -- antenna position, and guessing would only produce false reports.
        local ax, ay, az = SingleRepeater.ax, SingleRepeater.ay, SingleRepeater.az
        local square = nil
        if ax and ay then
            square = getCell():getGridSquare(ax, ay, az or 0)
        end
        if square then
            if not IsItemOnSquare(square, WQS_Shared.getAntennaItemId()) then
                local target = SingleRepeater.activeForTargetRep
                if target and target.area and target.name then
                    local last = DeactivateReported[k]
                    if not last or (now - last) > DEACTIVATE_REPORT_MS then
                        DeactivateReported[k] = now
                        print("WQS_MP repeater " .. tostring(k) ..
                            " antenna missing on a loaded square, reporting deactivation")
                        WQS_Session.Send("DeactivateRepeater", {
                            area = target.area,
                            name = target.name,
                        })
                    end
                end
            else
                DeactivateReported[k] = nil
            end
        end
    end
    return RepeaterList
end


--- MP: the active list is keyed by target location on the server, not by the
--- local item id, so identity is resolved by position instead.
WQSAntenna.CurrentAntennaIsRepeater = function()
    local ant = WQSAntenna.GetAntennaItemFound()
    if not (ant and ant.theitem and ant.world_square and ant.world_square:isOutside() and ant.theitem:getID()) then
        return false
    end
    local AntWorldItem = ant.theitem:getWorldItem()
    if not (AntWorldItem and AntWorldItem:getX()) then
        return false
    end

    local ax = AntWorldItem:getX()
    local ay = AntWorldItem:getY()
    local maxDist = WQS_Shared.getRepeaterMaxActivationDistance()

    local RepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")
    if not RepeaterList then
        return false
    end
    for k, Rep in pairs(RepeaterList) do
        if Rep.x and WQS.getDistance(ax, ay, Rep.x, Rep.y) <= maxDist then
            return true
        end
    end
    return false
end

-- MP: target repeater selection moved to server/WQS_MPSession.lua.
-- RemoveRepeatersTooCloseToExtrPoints and PickRandomRepeaterPosition used to
-- run here with a local ZombRand, which is exactly why every client ended up
-- with a different repeater list. They are gone on purpose.
-- The old RemoveRepeatersTooCloseToExtrPoints also nil'd entries out of the
-- shared WQS_RepeaterData table, permanently damaging it for any later run.


--da finire
-- WQSAntenna.getNearestTargetRepeater = function(x,y,z)
-- local ret={}
-- local TargetRepeaterList=WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
-- if ( not(TargetRepeaterList) or  WQS_Shared.TableIsEmptyOrNil(TargetRepeaterList) or
--      (WQS_Shared.CountTableItems(TargetRepeaterList)==0) ) then
--     return ret
-- end
-- for i, Rep in ipairs(TargetRepeaterList) do		
--     local dist = WQS.getDistance(x,y,Rep.x,Rep.y);
--     --print(dist)
--     if dist<=WQS_Shared.getRepeaterMaxActivationDistance() and Rep.ActivatedRepeaterHere==nil then
--         return true --TODO check se ci sono altri repeater già attivi qui
--     end
-- end
-- end


--controlla se il repeater che si vuole attivare si trova vicino uno dei repeater target e se non è stato già attivato altro repeater qui
--ritorna la posizione nell'array del repeater target più vicino a quello che vogliamo attivare
--altrimenti ritorna falso
-- WQSAntenna.CanActivateRepeaterHere = function(x, y, z)
--     local TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
--     if (not (TargetRepeaterList) or WQS_Shared.TableIsEmptyOrNil(TargetRepeaterList) or
--             (WQS_Shared.CountTableItems(TargetRepeaterList) == 0)) then
--         return false
--     end
--     for i, Rep in ipairs(TargetRepeaterList) do
--         --for i, Rep in pairs(TargetRepeaterList) do
--         local dist = WQS.getDistance(x, y, Rep.x, Rep.y);
--         --print(dist)
--         if dist <= WQS_Shared.getRepeaterMaxActivationDistance() and Rep.ActivatedRepeaterHere == nil then
--             return i
--         end
--     end
--     return false
-- end


--funzione solo per ADMIN usata per debug
WQSAntenna.AdminTeleportToTargetRepeater = function(TargetRepArrayPos)
    TargetRepArrayPos = TargetRepArrayPos or 1
    local TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
    if TargetRepeaterList and not (WQS_Shared.TableIsEmptyOrNil(TargetRepeaterList)) then
        local Rep = TargetRepeaterList[TargetRepArrayPos]
        if Rep then
            print(WQS_Shared.Dump(Rep));
            local playerObj = getSpecificPlayer(0)
            if not playerObj then return end
            playerObj:setX(Rep.x)
            playerObj:setY(Rep.y)
            playerObj:setZ(0.0)
            playerObj:setLx(Rep.x)
            playerObj:setLy(Rep.y)
        end
    end
end


---riceve le coordinate di un repeater che si vuole attivare
---ritorna il targetRepeater per cui sarebbe possibile attivare il repeater oppure {} se non è alla distanza giusta
---è come FindTargetRepeaterForActivation ma IGNORA se ci sono altri repeate attivi lì,
---utile per capire a quale target repeater è associanto un repeater attivo
WQSAntenna.FindTargetRepeaterForThisCoords = function(x, y)
    return WQSAntenna.FindTargetRepeaterForActivation(x, y, true);
end

---riceve le coordinate di un repeater che si vuole attivare
---ritorna il targetRepeater per cui sarebbe possibile attivare il repeater oppure {} se non è alla distanza giusta o c'è già un repeater attivato lì
WQSAntenna.FindTargetRepeaterForActivation = function(x, y, isNotForActivation)
    isNotForActivation = isNotForActivation or false
    local TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
    local ActiveRepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")

    local thereAreOtherRepActivatedHere = false --deve essere false
    local TargetRepeaterForActivation = {}

    if (not (TargetRepeaterList) or WQS_Shared.TableIsEmptyOrNil(TargetRepeaterList) or
            (WQS_Shared.CountTableItems(TargetRepeaterList) == 0)) then
        return false
    end

    if not ActiveRepeaterList then
        ActiveRepeaterList = {}
    end

    --controllo se sono nel range di attivazione di uno dei target repeater
    for i, Rep in pairs(TargetRepeaterList) do
        local dist = WQS.getDistance(x, y, Rep.x, Rep.y);
        -- print(dist)
        if dist <= WQS_Shared.getRepeaterMaxActivationDistance() then
            --controllo se ci sono altri repeater attivati per questo target repeater
            --print("distance is ok")
            for key, ActiveRep in pairs(ActiveRepeaterList) do
                -- was: ActiveRep.activeForTargetRep == Rep
                -- Table identity does not survive ModData serialization nor the
                -- server snapshot, so it silently never matched. Compare by key.
                local atr = ActiveRep.activeForTargetRep
                if atr and atr.area == Rep.area and atr.name == Rep.name then
                    thereAreOtherRepActivatedHere = true
                    --print("Other repater already active for this target!")
                end
            end
            if not (thereAreOtherRepActivatedHere) or (isNotForActivation and thereAreOtherRepActivatedHere) then
                TargetRepeaterForActivation = Rep
                break
            end
        end
    end
    return TargetRepeaterForActivation
end


---Ritorna true se l'antenna a cui sono vicino è attivabile come repeater
WQSAntenna.isCurrentAntennaActivableAsRepeater = function()
    local ret = false
    local ant = WQSAntenna.GetAntennaItemFound()
    if ant then
        local AntWorldItem = ant.theitem:getWorldItem()
        if AntWorldItem and AntWorldItem:getX() then
            local TargetRepeaterForActivation = WQSAntenna.FindTargetRepeaterForActivation(AntWorldItem:getX(),
                AntWorldItem:getY())
            if TargetRepeaterForActivation and TargetRepeaterForActivation.x then
                ret = true
            end
        end
    end
    return ret
end

--- MP: activation is a request now. One antenna per target location satisfies
--- the whole faction, so members can split up and cover different sites.
--- Deactivation is deliberately not exposed: a single member must not be able
--- to erase faction progress.
WQSAntenna.ToggleRepeaterMode = function()
    local ant = WQSAntenna.GetAntennaItemFound()
    if not (ant and ant.theitem and ant.world_square and ant.world_square:isOutside() and ant.theitem:getID()) then
        return
    end

    local AntId = tostring(ant.theitem:getID())

    if WQSAntenna.CurrentAntennaIsRepeater() then
        print("WQS_MP antenna " .. AntId .. " already active for the faction, nothing to do")
        return
    end

    local AntWorldItem = ant.theitem:getWorldItem()
    if not (AntWorldItem and AntWorldItem:getX()) then
        return
    end

    local TargetRepeaterForActivation = WQSAntenna.FindTargetRepeaterForActivation(AntWorldItem:getX(),
        AntWorldItem:getY())
    if not (TargetRepeaterForActivation and TargetRepeaterForActivation.x) then
        print("WQS_MP antenna " .. AntId .. " WRONG activation place!")
        return
    end

    WQS_Session.Send("ActivateRepeater", {
        x = AntWorldItem:getX(),
        y = AntWorldItem:getY(),
        z = AntWorldItem:getZ(),
    })
    print("WQS_MP antenna " .. AntId .. " activation requested")
end


-- WQSAntenna.ToggleRepeaterMode_OLD = function()
--     local ant = WQSAntenna.GetAntennaItemFound()
--     if (ant and ant.theitem and ant.world_square and ant.world_square:isOutside() and ant.theitem:getID()) then
--         local RepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")
--         if not RepeaterList then
--             RepeaterList = {}
--         end
--         local AntId = tostring(ant.theitem:getID())

--         if not (WQSAntenna.CurrentAntennaIsRepeater()) then --SET AS REPEATER
--             local AntWorldItem = ant.theitem:getWorldItem()
--             if AntWorldItem and AntWorldItem:getX() then
--                 local canActivateAtTarget = WQSAntenna.CanActivateRepeaterHere(AntWorldItem:getX(), AntWorldItem:getY(),
--                     AntWorldItem:getZ())
--                 if canActivateAtTarget and canActivateAtTarget > 0 then
--                     RepeaterList[AntId] = {
--                         x = AntWorldItem:getX(),
--                         y = AntWorldItem:getY(),
--                         z = AntWorldItem:getZ(),
--                         targetRep = canActivateAtTarget
--                     }
--                     WQS_Shared.setWQSPlayerModData("ActiveRepeaterList", RepeaterList)
--                     print("Antenna " .. AntId .. " IS a repeater now!")

--                     --salvo in TargetRepeaterList che ho attivato una antenna in quel target
--                     local TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
--                     if TargetRepeaterList and TargetRepeaterList[canActivateAtTarget] then
--                         TargetRepeaterList[canActivateAtTarget].ActivatedRepeaterHere = tostring(AntId)
--                         WQS_Shared.setWQSPlayerModData("TargetRepeaterList", TargetRepeaterList)
--                     end
--                 else
--                     print("Antenna " .. AntId .. " WRONG activation place!")
--                 end
--             end
--         else
--             if RepeaterList and RepeaterList[AntId] then --UNSET AS REPEATER
--                 local tr = RepeaterList[AntId].targetRep
--                 if tr and tr > 0 then
--                     local TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
--                     if TargetRepeaterList and TargetRepeaterList[tr] then
--                         TargetRepeaterList[tr].ActivatedRepeaterHere = nil
--                         WQS_Shared.setWQSPlayerModData("TargetRepeaterList", TargetRepeaterList)
--                     end
--                 end


--                 RepeaterList[AntId] = nil
--                 WQS_Shared.setWQSPlayerModData("ActiveRepeaterList", RepeaterList)
--                 print("Antenna " .. AntId .. " is NOT a repeater anymore")
--             end
--         end
--     end
-- end



WQSAntenna.getMaxNumOfTargetRepeaters = function()
    local rpmax = SandboxVars.WQS_RepeatersModeHowMany_opt or 4
    return rpmax
end

WQSAntenna.getNumOfActiveRepeaters = function()
    local RepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")
    if not RepeaterList then
        return 0
    else
        return WQS_Shared.CountTableItems(RepeaterList)
    end
end

WQSAntenna.getNumOfKnownRepeaterLocation = function()
    local TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
    if not TargetRepeaterList then
        return 0
    else
        return WQS_Shared.CountTableItems(TargetRepeaterList)
    end
end


WQSAntenna.isThisTargetRepeaterActive = function(targetRep)
    local ActiveRepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")
    if (ActiveRepeaterList) then
        for k, Rep in pairs(ActiveRepeaterList) do
            -- print("targetrep area" .. WQS_Shared.Dump(targetRep.area))
            if Rep.activeForTargetRep and Rep.activeForTargetRep.area == targetRep.area and Rep.activeForTargetRep.name == targetRep.name then
                --print("Found " .. WQS_Shared.Dump(Rep.activeForTargetRep.area))
                return true
            end
        end
    end
    return false
end

WQSAntenna.getTargetRepeatersStatsTxt = function()
    local TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
    --local ActiveRepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")

    local pl = WQS.GetCurrentPlayer();
    if not (pl) then
        return ""
    end
    local youCanPlace = getText("IGUI_WQS_CanPlaceRepeater") or "You can activate in this area."
    local knownRepLoc = getText("IGUI_WQS_KnownRepeaterLocations") or "Known Repeater Locations"
    local collectFragmentAdvice = getText("IGUI_WQS_CollectFragmentAdvice") or "Collect more repeater fragment location"
    local repeaterIsActive = getText("IGUI_WQS_RepeaterIsActive") or "Repeater Active"
    local li = ">"
    local ret = " <SIZE:small>  <LINE> " --<ORANGE> <INDENT:20> <RGB:1,1,1> ???
    if not (TargetRepeaterList) or WQS_Shared.TableIsEmptyOrNil(TargetRepeaterList) then
        ret = " <LINE> " .. collectFragmentAdvice .. " <LINE> "
    else
        -- r=0.13, g=0.52, b=0.82
        ret = ret .. WQS_COLTIT .. " <SIZE:medium> " .. knownRepLoc .. ": " .. "  <SIZE:small> <LINE> <LINE> "
        for key, Rep in pairs(TargetRepeaterList) do
            local dist = WQS.getDistance(pl:getX(), pl:getY(), Rep.x, Rep.y);
            local dirId = WQS_Shared.CardinalDirId(pl, Rep.x, Rep.y, dist)
            -- ----------------
            local pz = math.floor(pl:getZ() + 0.5)
            local tz = Rep.z or 0

            local tryActivate = WQSAntenna.FindTargetRepeaterForActivation(Rep.x, Rep.y)

            -- Exactly one of the three states applies, so they are a single
            -- chain now instead of the old "build a string, then blank it out
            -- again further down" sequence.
            local statusTxt = ""
            -- ----------------
            if WQSAntenna.isThisTargetRepeaterActive(Rep) then
                statusTxt = WQS_COLGREEN .. repeaterIsActive .. WQS_COLWHITE
            elseif (pz ~= tz) or (dist >= WQS_Shared.getRepeaterMaxActivationDistance()) then
                -- Written as one translated sentence rather than three values
                -- glued together, so word order stays the translator's problem.
                -- The floor delta only appears once the player is within
                -- getRepeaterFloorHintDistance() -- at range it is not
                -- actionable yet and just adds clutter next to the one number
                -- (distance) that matters for navigation.
                --
                -- NOTHING inside the sentence may carry its own colour tag.
                -- A tag closes the current text chunk and the next chunk resumes
                -- at exactly the x the previous one ended at, and <SPACE> does
                -- not reliably reopen that gap here, so every tag dropped into
                -- the middle of the sentence welded the words on either side of
                -- it together (distance welded onto the heading). The line is
                -- therefore built as plain text first and wrapped in a single
                -- colour afterwards, which is what the original code did before
                -- the per-value colouring was introduced.
                local distArg = dist .. "m"
                local dirName = WQS_Shared.CardinalDirName(dirId)
                local dirArrow = WQS_Shared.CardinalDirArrow(dirId)
                local showFloor = dist < WQS_Shared.getRepeaterFloorHintDistance()

                -- The floor mismatch is signalled by recolouring the entire
                -- line instead of just the delta, since a colour switch cannot
                -- happen mid-sentence without breaking the spacing.
                local lineCol = WQS_COLSUBTIT

                if showFloor then
                    if pz ~= tz then
                        lineCol = WQS_COLWARN
                    end
                    local deltaArg = WQS_Shared.FloorDeltaTxt(pz, tz)

                    if dirId == "" then
                        -- Directly above or below the player: there is no heading
                        -- to print and "(  )" would just be noise.
                        statusTxt = getTextOrNull("IGUI_WQS_RepeaterDistLineNoDir", distArg, deltaArg)
                        if not (statusTxt) then
                            statusTxt = distArg .. ", " .. deltaArg
                        end
                    else
                        statusTxt = getTextOrNull("IGUI_WQS_RepeaterDistLine", distArg, dirName, dirArrow, deltaArg)
                        if not (statusTxt) then
                            statusTxt = distArg .. " " .. dirName .. " " .. dirArrow .. ", " .. deltaArg
                        end
                    end
                else
                    if dirId == "" then
                        statusTxt = getTextOrNull("IGUI_WQS_RepeaterDistLineFarNoDir", distArg)
                        if not (statusTxt) then
                            statusTxt = distArg
                        end
                    else
                        statusTxt = getTextOrNull("IGUI_WQS_RepeaterDistLineFar", distArg, dirName, dirArrow)
                        if not (statusTxt) then
                            statusTxt = distArg .. " " .. dirName .. " " .. dirArrow
                        end
                    end
                end

                statusTxt = lineCol .. statusTxt .. WQS_COLWHITE
            elseif not (WQS_Shared.TableIsEmptyOrNil(tryActivate)) then
                statusTxt = WQS_COLGREEN .. youCanPlace .. WQS_COLWHITE
            end

            -- Name plus the floor it sits on, then the status sentence indented
            -- under it, then a blank line so several repeaters do not read as one
            -- block. Both indents also catch the wrap on a long name or a long
            -- sentence, keeping the continuation aligned instead of dropping it
            -- back to the margin.
            --
            -- The floor used to be tagged a dimmer colour, which put a tag
            -- between the name and the floor and glued them into
            -- the floor welded onto the name. Both are one plain run now.
            ret = ret .. " <INDENT:8> " .. WQS_COLWHITE .. li .. " " ..
                WQS_Shared.GetRepeaterLabel(Rep) .. " " .. WQS_Shared.FloorTxt(tz) .. " <LINE> "
            ret = ret .. " <INDENT:18> " .. statusTxt .. " <LINE> <LINE> <INDENT:0> "
        end
    end
    return ret
end
WQSAntenna.CanAddMoreTargetRepeaters = function()
    local TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
    if not TargetRepeaterList then
        TargetRepeaterList = {}
    end
    if (#TargetRepeaterList < WQSAntenna.getMaxNumOfTargetRepeaters()) then
        return true
    end
    return false
end

WQSAntenna.isSignalActiveAndStrong = function()
    local ret = true
    if WQS_Shared.IsActiveRepeatersMode() then
        local activeRep = WQSAntenna.getNumOfActiveRepeaters()
        local neededRep = WQSAntenna.getMaxNumOfTargetRepeaters()
        if (activeRep < neededRep) then
            ret = false
        end
    end
    local signal_hours_left = WQS.getHoursLeftToSignalActivation()
    if signal_hours_left > 0 then
        ret = false
    end
    return ret
end

--distribution 2398274461/mods/Save Our Station - Knox Country/media/lua/server/items/SWWS_KnoxCountry_Distributions.lua
---Genera una lista di NumTargetRepeaters repeaters e la salva nella playermoddata WQS.TargetRepeaterList
---NumTargetRepeaters MASSIMO 4!
--- The session owns the list. We only ask it to add entries; the result comes
--- back as a Sync snapshot and is shared by the whole faction.
--- Note that each request is answered individually (AddTargetOk /
--- AddTargetFailed), so asking for more than one at a time is only safe when
--- the caller does not need to know which of them succeeded.
WQSAntenna.GenerateTargetRepeaterList = function(ForceAdd, EraseExistingRepeaters, NumTargetRepeaters)
    NumTargetRepeaters = NumTargetRepeaters or 3

    if not (WQS_Shared.IsActiveRepeatersMode()) then
        return false
    end

    if NumTargetRepeaters > WQSAntenna.getMaxNumOfTargetRepeaters() then
        NumTargetRepeaters = WQSAntenna.getMaxNumOfTargetRepeaters()
    end

    -- EraseExistingRepeaters is a no-op: only the session may clear the faction
    -- list, and it does so by destroying itself on a wipe.
    if EraseExistingRepeaters then
        print("WQS_MP WARN EraseExistingRepeaters ignored, the session owns the list")
    end

    for i = 1, NumTargetRepeaters, 1 do
        WQS_Session.Send("AddRepeaterTarget", {})
        print("WQS_MP requested target repeater " .. i .. "/" .. NumTargetRepeaters)
    end
    return true
end


WQSAntenna.GetAntennaItemFound = function()
    return WQSAntenna.AntennaIsNear
end

WQSAntenna.CheckIfAntennaIsNear = function()
    local ant_cond = (WQSAntenna.AntennaIsNear) and (WQSAntenna.AntennaIsNear ~= false) and
        (WQSAntenna.AntennaIsNear ~= nil)
    if (ant_cond) then
        return true
    end
    return false
end

WQSAntenna.AntennaStatusCheck = function()
    local player = WQS.GetCurrentPlayer();
    if player then
        local sq = player:getSquare()
        WQSAntenna.AntennaIsNear = IsItemOnGroundNear(sq, WQS_Shared.getAntennaItemId())
    end
end

Events.OnPlayerUpdate.Add(AntennaStatusCheckUpdate);


-- sq = getSquare(9818,10353, 0)
-- IsItemOnGroundNear(sq,WQS_Shared.getAntennaItemId())

-- special=sq:getWorldObjects()
-- it=special:get(0)
-- print(it:getX())
-- pl = WQS.GetCurrentPlayer();
-- myModData2 = pl:getModData();
-- myModData2.antenna= it

-- local props = v:getSprite() and v:getSprite():getProperties() or nil


-- pl = WQS.GetCurrentPlayer();sq=pl:getSquare();
-- ant=IsItemOnGroundNear(sq,WQS_Shared.getAntennaItemId());print(ant);print(ant.theitem);

-- mdata=ant.theitem:getModData()

-- mdata.test=33

-- ant:setNoPicking(true)

-- if v:getSquare() then
--     local worldItems = v:getSquare():getWorldObjects();
--     if worldItems and not worldItems:isEmpty() then
--         worldItem = worldItems:get(0);
--     end
-- end
