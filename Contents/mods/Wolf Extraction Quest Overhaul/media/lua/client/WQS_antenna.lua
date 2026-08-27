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

WQSAntenna.CheckStatusOfRepeaters = function()
    local RepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")
    if not RepeaterList then
        return {}
    end
    for k, v in pairs(RepeaterList) do
        local SingleRepeater = RepeaterList[k]
        --print(k.."===>"..WQS_Shared.Dump(SingleRepeater))
        local square = getCell():getGridSquare(SingleRepeater.x, SingleRepeater.y, SingleRepeater.z)
        if square then --se sono lontano la cella non è caricata e quindi esco senza far nulla
            --sono in una cella caricata nelle vicinanze del repeater, quindi mi assicuro che sia ancora lì
            local RepeaterIsThere = IsItemOnSquare(square, WQS_Shared.getAntennaItemId())

            if RepeaterIsThere then
                --print("Repeater "..k.." is there!")
            else
                RepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")
                print("Repeater " .. k .. " is NOT there, removing it from list!")
                if RepeaterList then
                    -- local tr = RepeaterList[k].targetRep
                    -- if tr and tr > 0 then
                    --     local TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
                    --     if TargetRepeaterList and TargetRepeaterList[tr] then
                    --         TargetRepeaterList[tr].ActivatedRepeaterHere = nil
                    --         WQS_Shared.setWQSPlayerModData("TargetRepeaterList", TargetRepeaterList)
                    --     end
                    -- end
                    RepeaterList[k] = nil
                    WQS_Shared.setWQSPlayerModData("ActiveRepeaterList", RepeaterList)
                end
            end
        end
    end
    RepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")
    return RepeaterList
end


WQSAntenna.CurrentAntennaIsRepeater = function()
    local ant = WQSAntenna.GetAntennaItemFound()
    if (ant and ant.theitem and ant.world_square and ant.world_square:isOutside() and ant.theitem:getID()) then
        --print(ant.theitem)
        --print(ant.theitem:getID())
        local AntId = tostring(ant.theitem:getID())
        local RepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")
        if RepeaterList and RepeaterList[AntId] then
            return true
        end
    end
    return false
end

--rimuovo i repeaters troppo vicini agli extr point, usato da PickRandomRepeaterPosition
WQSAntenna.RemoveRepeatersTooCloseToExtrPoints = function()
    --escludo le posizioni dei repeater troppo vicini ai punti di estrazione
    for pkey, pdata in pairs(WQS_ExtractionPointsData) do
        --print(pdata.MapItem)
        if pdata and pdata.MapCenterAreaX then
            for rkey, repeater in pairs(WQS_RepeaterData) do
                local dist = WQS.getDistance(repeater.x, repeater.y, pdata.MapCenterAreaX, pdata.MapCenterAreaY)
                if dist < 130 then
                    print("removing " .. pdata.MapItem .. "->" .. repeater.name .. " distance " .. dist)
                    WQS_RepeaterData[rkey] = nil
                end
            end
        end
    end
end

---ritorna la posizione di un repeater random escludendo quelli già presi e quelli troppo vicini:
---{["area"] = "West Point", ["name"] = "Cemetary", ["x"] = 11069, ["y"] = 6710}
--- OtherRepeaterList contiene la posizione dei repeater già piazzati oppure {} se non ce ne sono es:
--- local OtherRepeaterList = { { x = 11687, y = 8367 }, { x = 8219, y = 11841 } }
--- OtherRepeaterList deve avere MASSIMO 4 elementi altrimenti non riuscirà a trovare punti validi
WQSAntenna.PickRandomRepeaterPosition = function(OtherRepeaterList)
    local pick
    local ret = {}
    local isOk = false
    local isGoodPick = true
    WQSAntenna.RemoveRepeatersTooCloseToExtrPoints() --rimuovo i repeaters troppo vicini agli extr point
    if OtherRepeaterList and not (WQS_Shared.TableIsEmptyOrNil(OtherRepeaterList)) then
        local fail = 0
        while not (isOk) do
            pick = WQS_Shared.PickRandomObjFromTableIfNotNil(WQS_RepeaterData)
            isGoodPick = true
            for key, rep in pairs(OtherRepeaterList) do
                local dist = WQS.getDistance(pick.x, pick.y, rep.x, rep.y)
                --print("dist "..dist)
                local mindist = 380 * #OtherRepeaterList --380 distanza e max 4 altri punti in OtherRepeaterList
                if fail > 20 then
                    mindist = 100
                    --print("reset dist to 100>"..dist)
                end
                if (pick.x == rep.x and pick.y == rep.y) or (dist < mindist) then
                    --print(fail.."=cf NOT isGoodPick " .. pick.x .. "=" .. rep.x.." d="..dist.."<"..mindist)
                    isGoodPick = false
                    if dist > 0 then --considero falliti solo i punti con distanza sbagliata
                        --print(fail.."=cf NOT isGoodPick " .. pick.x .. "=" .. rep.x.." d="..dist.."<"..mindist)
                        fail = fail + 1
                    end
                end
            end
            if (isGoodPick) then
                isOk = true
                ret = pick
            end
            if fail > 50 then
                isOk = true
                print(" WQS ERROR PickRandomRepeaterPosition too many failed pick")
            end
        end
    else
        ret = WQS_Shared.PickRandomObjFromTableIfNotNil(WQS_RepeaterData)
        -- print(" r= " .. tostring(ret))
    end
    return ret
end

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
    TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
    if TargetRepeaterList and not (WQS_Shared.TableIsEmptyOrNil(TargetRepeaterList)) then
        Rep = TargetRepeaterList[TargetRepArrayPos]
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
                if ActiveRep.activeForTargetRep and ActiveRep.activeForTargetRep == Rep then
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

WQSAntenna.ToggleRepeaterMode = function()
    local ant = WQSAntenna.GetAntennaItemFound()
    if (ant and ant.theitem and ant.world_square and ant.world_square:isOutside() and ant.theitem:getID()) then
        local RepeaterList = WQS_Shared.getWQSPlayerModData("ActiveRepeaterList")
        if not RepeaterList then
            RepeaterList = {}
        end
        local AntId = tostring(ant.theitem:getID())

        if not (WQSAntenna.CurrentAntennaIsRepeater()) then --SET AS REPEATER
            local AntWorldItem = ant.theitem:getWorldItem()
            if AntWorldItem and AntWorldItem:getX() then
                local TargetRepeaterForActivation = WQSAntenna.FindTargetRepeaterForActivation(AntWorldItem:getX(),
                    AntWorldItem:getY())
                if TargetRepeaterForActivation and TargetRepeaterForActivation.x then
                    RepeaterList[AntId] = {
                        x = AntWorldItem:getX(),
                        y = AntWorldItem:getY(),
                        z = AntWorldItem:getZ(),
                        activeForTargetRep = TargetRepeaterForActivation
                    }
                    WQS_Shared.setWQSPlayerModData("ActiveRepeaterList", RepeaterList)
                    print("Antenna " .. AntId .. " IS a repeater now!")
                else
                    print("Antenna " .. AntId .. " WRONG activation place!")
                end
            end
        else
            if RepeaterList and RepeaterList[AntId] then --UNSET AS REPEATER
                RepeaterList[AntId] = nil
                WQS_Shared.setWQSPlayerModData("ActiveRepeaterList", RepeaterList)
                print("Antenna " .. AntId .. " is NOT a repeater anymore")
            end
        end
    end
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
            ret = ret .. " <INDENT:0> " .. WQS_COLWHITE .. li .. Rep.area .. " " .. Rep.name .. " <LINE> "
            local dist = WQS.getDistance(pl:getX(), pl:getY(), Rep.x, Rep.y);
            local dir = WQS_Shared.CardinalDirTxt(pl, Rep.x, Rep.y, dist)
            -- ----------------
            local pz = math.floor(pl:getZ() + 0.5)
            local tz = Rep.z or 0

            local tryActivate = WQSAntenna.FindTargetRepeaterForActivation(Rep.x, Rep.y)

            local distTxt = ""
            local canPlaceTxt = ""
            local isActiveTxt = ""
            -- ----------------
            if (pz ~= tz) or (dist >= WQS_Shared.getRepeaterMaxActivationDistance()) then
                distTxt = WQS_COLSUBTIT .. dist .. "m " .. dir .. " " .. tostring(pz) .. "/" .. tostring(tz) .. WQS_COLWHITE
            elseif not (WQS_Shared.TableIsEmptyOrNil(tryActivate)) then
                distTxt = ""
                canPlaceTxt = WQS_COLGREEN .. youCanPlace .. WQS_COLWHITE
            end
            if WQSAntenna.isThisTargetRepeaterActive(Rep) then
                isActiveTxt = WQS_COLGREEN .. repeaterIsActive .. WQS_COLWHITE
                distTxt = ""
                canPlaceTxt = ""
            end

            ret = ret .. "  <INDENT:7>  " .. distTxt .. " " .. canPlaceTxt .. " " .. isActiveTxt
            ret = ret .. " <LINE> <INDENT:0>"
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
WQSAntenna.GenerateTargetRepeaterList = function(ForceAdd, EraseExistingRepeaters, NumTargetRepeaters)
    ForceAdd = ForceAdd or false
    EraseExistingRepeaters = EraseExistingRepeaters or false
    NumTargetRepeaters = NumTargetRepeaters or 3 --MASSIMO 4!!

    if not (WQS_Shared.IsActiveRepeatersMode()) then
        return false
    end

    if NumTargetRepeaters > WQSAntenna.getMaxNumOfTargetRepeaters() then
        NumTargetRepeaters = WQSAntenna.getMaxNumOfTargetRepeaters()
    end --MASSIMO 4!!

    if EraseExistingRepeaters then
        WQS_Shared.deleteWQSPlayerModData("TargetRepeaterList")
    end

    local TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
    if not (TargetRepeaterList) or WQS_Shared.TableIsEmptyOrNil(TargetRepeaterList) or (ForceAdd) then
        for i = 1, NumTargetRepeaters, 1 do
            TargetRepeaterList = WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
            if not TargetRepeaterList then
                TargetRepeaterList = {}
            end
            local Trl = WQSAntenna.PickRandomRepeaterPosition(TargetRepeaterList)
            if WQSAntenna.CanAddMoreTargetRepeaters() then
                table.insert(TargetRepeaterList, Trl)
                WQS_Shared.setWQSPlayerModData("TargetRepeaterList", TargetRepeaterList)
                print("WQS GenerateTargetRepeaterList ADDED " .. Trl.area .. " - " .. Trl.name)
            else
                print("WQS GenerateTargetRepeaterList CANNOT add more repeaters " .. i)
            end
            --print("WQS GenerateInitialTargetRepeaterList Creating TargetRepeater n "..i)
            --print(WQS_Shared.Dump(Trl))
        end
    end
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
