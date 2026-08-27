--[[
per aggiungere un nuovo punto di estrazione:
1) aggiungi l'opzione Sandbox_WQS_ZoneMap_optlist_optionXXXX(media/lua/shared/Translate/EN/Sandbox_EN.txt)
2) Aggiorna numValues (+1) (media/sandbox-options.txt)
3) aggiungi mappa in (media/scripts/WQS_items.txt)
4) aggiungi la definizione della nuova mappa in (media/lua/client/ISUI/Maps/WQS_ISMapDefinitions.lua)
5) aggiungi la nuova mappa nell'array WQS_ExtractionPointsData (media/lua/shared/WQS_ExtractionData.lua)
 ]]
WQS = {}
-- WQS_extraction_map_list = WQS_Shared.getExtractionPointsData()
-- WQS_PreferredSpawnPointsList = WQS_Shared.getPreferredSpawnPointsData()
GlobalExtractionDataIsSet = false

WQS_STATES = {
    ["CURRENT"] = nil,
    ["QUEST_NOT_STARTED"] = 0.8,
    ["PRE_EXTRACTION"] = 1, -- quest started
    ["EXTRACTION_CAN_BE_STARTED"] = 1.1,
    ["EXTRACTION_RUNNING"] = 2,
    ["EXTRACTION_CAN_BE_COMPLETED"] = 2.1,
    ["EXTRACTION_CAN_BE_COMPLETED_BUT_WRONG_ZONE"] = 2.2,
    ["EXTRACTION_COMPLETED"] = 3,

    ["EXTRACTION_ENDED"] = 4
}

WQS_GAMEMODES = {
    ["CURRENT"] = nil,
    ["CLASSIC_QUICK_MODE"] = 1,
    ["ANTENNA_MODE"] = 2
}

WQS_EXTRACTION_START_TIME = nil
WQS_EXTRACTION_ELAPSED_TIME = 0
WQS_EXTRACTION_TIME_LEFT = 0
-- WQS_EXTRACTION_DURATION_MILLISEC=2*(60*1000) --il primo num sono i minuti, il valore è in millisecondi
WQS_EXTRACTION_DURATION_TIME_MIN = 4 * 60
WQS_EXTRACTION_DIFFICULTY_MULTIPLIER = 1
WQS_GLOBAL_DIFFICULTY_BALANCE_MULTIPLIER = 1
WQS_PREVSTATE = nil

--[[
test
for i=1,100 do
    --tutti escludendo quelli con random e louisville (random no lousiville)
    kk=WQS_Shared.RandomMapKeyButExcludeIfContain(WQS_extraction_map_list,"random","louisville")
    print(WQS_extraction_map_list[kk].MapItem)
    end

    for i=1,100 do
        --tutti i louisville escludendo quelli con random (random only lousiville)
kk=WQS_Shared.RandomMapKeyButExcludeIfContain(WQS_extraction_map_list,"random","louisville",false,true)
print(WQS_extraction_map_list[kk].MapItem)
end

    for i=1,100 do
        --tutti escludendo quelli con random (random)
kk=WQS_Shared.RandomMapKeyButExcludeIfContain(WQS_extraction_map_list,"random")
print(WQS_extraction_map_list[kk].MapItem)
end

 ]]

-- ############## Config & settings
WQS.setCurretExtractionMap = function(MapItem, ZoneMapRandomOption)
    local ExtractionMapList = WQS_Shared.getExtractionPointsData()
    local ExtractionPointData = WQS.getExtractionData(MapItem)
    local pl = WQS.GetCurrentPlayer();

    if not (pl) then
        return nil
    end

    local myModData = pl:getModData();

    local extraction_map = nil

    if (ExtractionPointData) and (ExtractionPointData.MapItem == "random") then
        local rndstr = ExtractionPointData.MapItem
        local loustr = "louisville"
        local emap_key = 2

        -- random all zones
        if (ZoneMapRandomOption == "random_all_zones") then
            emap_key = WQS_Shared.RandomMapKeyButExcludeIfContain(ExtractionMapList, rndstr)
            print(" #### WQS ZoneMap random opt: pick from all zones id=" .. emap_key)
        end

        -- Random only Louisville zones
        if (ZoneMapRandomOption == "random_only_louisville") then
            emap_key = WQS_Shared.RandomMapKeyButExcludeIfContain(ExtractionMapList, rndstr, loustr, false, true)
            print(" #### WQS ZoneMap random opt: pick only Louisville zones id=" .. emap_key)
        end

        -- Random excluding Louisville zones
        if (ZoneMapRandomOption == "random_excluding_louisville") then
            emap_key = WQS_Shared.RandomMapKeyButExcludeIfContain(ExtractionMapList, rndstr, loustr)
            print(" #### WQS ZoneMap random opt: pick excluding Louisville zones id=" .. emap_key)
        end

        extraction_map = ExtractionMapList[emap_key].MapItem or ExtractionMapList[2].MapItem;
        print(" ### WQS ZoneMap random key=" .. emap_key .. " map=" .. tostring(extraction_map));
        myModData.PlayerExtractionMap = extraction_map
        -- dopo aver selezionato un punto di estrazione casuale lo salvo
    elseif not (ExtractionPointData == nil) and (ExtractionPointData.MapCenterAreaX) then
        extraction_map = ExtractionPointData.MapItem
        print(" ### WQS ZoneMap fixed " .. tostring(extraction_map));
        myModData.PlayerExtractionMap = extraction_map
    else
        extraction_map = ExtractionMapList[2].MapItem
        print(" ### WQS ZoneMap ERROR, fallback on default " .. tostring(extraction_map));
        myModData.PlayerExtractionMap = extraction_map
    end
    return extraction_map
end

---ritorna i dati della mappa corrente di estrazione oppure array vuoto
WQS.getCurretMapExtractionData = function()
    local CurretExtractionMap = WQS.getCurretExtractionMap()
    local ret = {}
    if CurretExtractionMap then
        local MapData = WQS.getExtractionData(CurretExtractionMap)
        if (MapData) and not (WQS_Shared.TableIsEmptyOrNil(MapData)) and (MapData.MapCenterAreaX) then
            ret = MapData
        end
    end
    return ret
end


---ritorna il NOME (mappa.MapItem) della zona di estrazione corrente
WQS.getCurretExtractionMap = function()
    -- function setExtractionMap(ZoneMap,ExtractionMapList)
    local ZoneMap = SandboxVars.WQS_ZoneMap_opt or 2;
    local pl = WQS.GetCurrentPlayer();

    if not (pl) then
        return nil
    end

    local myModData = pl:getModData();
    local ZoneMap_random_opt = SandboxVars.WQS_ZoneMap_random_opt or 1;

    local ExtractionMapList = WQS_Shared.getExtractionPointsData()

    local extraction_map = nil

    -- print(" ### WQS setExtractionMap key=" .. ZoneMap .. " ZoneMap_random_opt=" .. tostring(ZoneMap_random_opt))
    if not (myModData.PlayerExtractionMap == nil) then
        extraction_map = myModData.PlayerExtractionMap
        sbxval = ExtractionMapList[ZoneMap].MapItem
        -- print(" ### WQS ZoneMap from PlayerModData" .. tostring(extraction_map) .. " SandboxVal=" .. sbxval);
    else
        local randopt = "fixed"

        -- random all zones
        if (ZoneMap_random_opt == 1) then
            randopt = "random_all_zones"
        end
        -- Random only Louisville zones
        if (ZoneMap_random_opt == 2) then
            randopt = "random_only_louisville"
        end
        -- Random excluding Louisville zones
        if (ZoneMap_random_opt == 3) then
            randopt = "random_excluding_louisville"
        end

        extraction_map = WQS.setCurretExtractionMap(ExtractionMapList[ZoneMap].MapItem, randopt)
    end
    -- print (extraction_map)
    return extraction_map
end



local function setSandboxVars()

end



WQS.setGlobalExtractionData = function()
    print(" ### WQS setGlobalExtractionData started");

    -- WQS_extraction_map_list = WQS_Shared.getExtractionPointsData()
    -- WQS_PreferredSpawnPointsList = WQS_Shared.getPreferredSpawnPointsData()

    -- WQS_ZoneMap_random_opt = SandboxVars.WQS_ZoneMap_random_opt or 1;

    -- WQS_ZoneMap = SandboxVars.WQS_ZoneMap_opt or 2;
    -- WQS_extraction_map = setExtractionMap(WQS_ZoneMap) or WQS_extraction_map_list[2].MapItem

    WQS_DeadlineDays = tonumber(SandboxVars.WQS_DeadlineDays_opt) or 0;
    WQS_SignalActiveDays = tonumber(SandboxVars.WQS_WaitForSignalDuration_opt) or 0;
    WQS_ExtractionEventHours = tonumber(SandboxVars.WQS_ExtractionEventHoursDuration_opt) or 3;

    -- WQS_EXTRACTION_DURATION_MILLISEC=(WQS_ExtractionEventHours*60)*(60*1000)
    WQS_EXTRACTION_DURATION_TIME_MIN = WQS_ExtractionEventHours * 60
    WQS_EXTRACTION_DIFFICULTY_MULTIPLIER = SandboxVars.WQS_ExtractionEventDifficulty_opt or 1

    WQS_EXTRACTION_DIFFICULTY_MULTIPLIER = WQS_EXTRACTION_DIFFICULTY_MULTIPLIER *
        WQS_GLOBAL_DIFFICULTY_BALANCE_MULTIPLIER

    GlobalExtractionDataIsSet = true
end

WQS.getMapPreferredZlevelSpawn = function()
    local CurretExtractionMap = WQS.getCurretExtractionMap()
    local MapData = WQS.getExtractionData(CurretExtractionMap)
    if MapData and MapData.PreferredZlevelSpawn then
        return MapData.PreferredZlevelSpawn
    end
    return nil
end

WQS.getMapPreferredSpawnPointPerc = function()
    local CurretExtractionMap = WQS.getCurretExtractionMap()
    local MapData = WQS.getExtractionData(CurretExtractionMap)
    if MapData and MapData.PreferredSpawnPointPerc then
        return MapData.PreferredSpawnPointPerc or 50
    end
    return 50
end

WQS.QuestNotStarted = function()
    local qs = false
    if WQS.GameModeIs("ANTENNA_MODE") then
        local pl = WQS.GetCurrentPlayer();
        if pl then
            local myModData = pl:getModData();
            if not (myModData.WQS) then
                myModData.WQS = {}
            end
            if (myModData.WQS.QuestStarted == false) or (myModData.WQS.QuestStarted == nil) then
                qs = WQS.CurrentStateIs("QUEST_NOT_STARTED")
            elseif (myModData.WQS.QuestStarted == true) then
                qs = false
            end
        end
        -- qs=WQS.GameModeIs("ANTENNA_MODE") and WQS.CurrentStateIs("QUEST_NOT_STARTED")
    end
    return qs
end

WQS.SetQuestAsStarted = function()
    -- if WQS.QuestNotStarted() and (WQS.GameModeIs("ANTENNA_MODE")) then
    WQS.SetState("PRE_EXTRACTION")
    local pl = WQS.GetCurrentPlayer();
    if pl then
        local myModData = pl:getModData();
        if not (myModData.WQS) then
            myModData.WQS = {}
        end
        myModData.WQS.QuestStarted = true
        myModData.WQS.QuestStartHoursSurvived = pl:getHoursSurvived()
    end

    --  else
    --   print("WQS SetQuestAsStarted failed: quest already started or not antenna game mode ")
    -- end
end

WQS.SetQuestAsNOTStarted = function()
    -- if not(WQS.QuestNotStarted()) and (WQS.GameModeIs("ANTENNA_MODE"))then
    WQS.SetState("QUEST_NOT_STARTED")
    local pl = WQS.GetCurrentPlayer();
    if pl then
        local myModData = pl:getModData();
        if not (myModData.WQS) then
            myModData.WQS = {}
        end
        myModData.WQS.QuestStarted = false
        myModData.WQS.QuestStartHoursSurvived = 0
    end
    -- end
end

WQS.getActualExtractionStats = function(player)
    local ret = {}
    ret.SignalHoursLeft_isok = true -- deve essere true qui
    ret.HoursLeft_isok = true       -- deve essere true qui
    ret.Distance_isok = false
    ret.IsInsideExtractionArea = false
    ret.Zlevel_isok = false
    ret.HoursLeft_isok = false
    ret.CanRequestExtraction = false
    ret.WeAreNearAntenna = false
    ret.AntennaTooCloseToExtrPoint = false
    ret.CanUseAntenna = false
    ret.QuestNotStarted = false -- deve essere false qui
    ret.AntennaIsInside = false

    ret.SignalStrenght_isok = true
    ret.SignalStrenght_active = 0 -- deve essere 0 qui
    ret.SignalStrenght_needed = 0 -- deve essere 0 qui

    local CurretExtractionMap = WQS.getCurretExtractionMap()
    local MapData = WQS.getExtractionData(CurretExtractionMap)

    if (MapData == nil) then
        print(" #### WQS ERROR MapData is NIL: " .. CurretExtractionMap)
        return {}
    end

    if WQS.ThereIsErrorInExtractionData(MapData) then
        print(" #### WQS ERROR MAP INIT: " .. CurretExtractionMap)
        return {}
    end

    ret.MapData = MapData

    ret.MapNameLabel = MapData.MapGuiLabel or ""

    local distance = WQS.getDistance(player:getX(), player:getY(), MapData.MapCenterAreaX, MapData.MapCenterAreaY);
    ret.Distance_val = distance
    if (distance <= MapData.AreaRadiusFromCenter) then
        ret.Distance_isok = true
    end
    if (distance <= MapData.AreaRadiusFromCenter * 4) then
        ret.IsInsideExtractionArea = true
    end

    local dir = WQS_Shared.CardinalDirTxt(player, MapData.MapCenterAreaX, MapData.MapCenterAreaY, ret.Distance_val)
    ret.CardinalDir = dir or ""
    ret.Zlevel_val = MapData.MapCenterAreaZ
    if (player:getZ() == MapData.MapCenterAreaZ) then
        ret.Zlevel_isok = true
        -- player:Say("The height level is wrong! "..tostring(player:getZ()).." -> "..MapData.MapCenterAreaZ );
    end

    ret.SignalHoursLeft_isok = true
    local signal_hours_left = WQS.getHoursLeftToSignalActivation()
    if signal_hours_left > 0 then
        ret.SignalHoursLeft_isok = false
        ret.SignalHoursLeft_val = signal_hours_left
    end

    local hours_left = WQS.getHoursLeftToDeadline()
    -- local in_time=true
    if (hours_left ~= false) then
        ret.HoursLeft_IsEnabled = true
        -- local hls=string.format("%.2f", hours_left)
        ret.HoursLeft_val = hours_left
        if (hours_left >= 0) then
            ret.HoursLeft_isok = true
            -- player:Say(tostring(hls).." hours left to reach extraction zone");
            -- in_time=true
        else
            -- player:Say("Too late baby, too late. ")
            ret.HoursLeft_isok = false
            -- in_time=false
        end
    else
        ret.HoursLeft_IsEnabled = false
        ret.HoursLeft_isok = true
    end

    ret.HaveExtractionItem = WQS_Shared.HaveItemInInventory(WQS_Shared.getExtractionItemId())
    -- ret.QuestNotStarted =WQS.GameModeIs("ANTENNA_MODE") and WQS.CurrentStateIs("QUEST_NOT_STARTED")
    ret.QuestNotStarted = WQS.QuestNotStarted()
    ret.QuestAlreadyStarted = not (ret.QuestNotStarted)

    if (WQSAntenna.CheckIfAntennaIsNear()) then
        -- print("antenna near")
        ret.WeAreNearAntenna = true

        local ant = WQSAntenna.GetAntennaItemFound()
        if ((ant) and (ant.world_square)) then
            ret.AntennaIsInside = not (ant.world_square:isOutside());
        end
        -- per usare l'antenna devo essere almeno 48 tile lontano dal punto di estrazione
        -- if  (distance < MapData.AreaRadiusFromCenter * 6)  then
        if ((distance < MapData.AreaRadiusFromCenter * 6) and ret.QuestAlreadyStarted) then
            ret.AntennaTooCloseToExtrPoint = true
            -- print("AntennaTooCloseToExtrPoint")
        end

        if not (ret.AntennaTooCloseToExtrPoint) and (ret.SignalHoursLeft_isok) and (ret.HaveExtractionItem) and
            not (ret.AntennaIsInside) then
            ret.CanUseAntenna = true
            -- print("CanUseAntenna YES")
        end
    end

    if (ret.QuestNotStarted and ret.SignalHoursLeft_isok) then
        ret.NeedAntennaToStartQuest = true
    end

    if WQS_Shared.IsActiveRepeatersMode() then
        local activeRep = WQSAntenna.getNumOfActiveRepeaters()
        local neededRep = WQSAntenna.getMaxNumOfTargetRepeaters()
        ret.SignalStrenght_active = activeRep
        ret.SignalStrenght_needed = neededRep
        if (activeRep < neededRep) then
            ret.SignalStrenght_isok = false
            ret.SignalStrenght_statTxt = WQSAntenna.getTargetRepeatersStatsTxt()
        end
    end

    if ((ret.Distance_isok) and (ret.Zlevel_isok) and (ret.HoursLeft_isok) and (ret.HaveExtractionItem) and
            (ret.SignalHoursLeft_isok) and (ret.QuestAlreadyStarted) and (ret.SignalStrenght_isok)) then
        ret.CanRequestExtraction = true
    end
    return ret
end



WQS.ComposeExtractionStatsTxt = function(playerObj)
    local stats_raw = {}

    stats_raw = WQS.getActualExtractionStats(playerObj)

    if (WQS_Shared.TableIsEmptyOrNil(stats_raw)) then
        print(" WQS ERROR getActualExtractionStats")
        return {}
    end

    -- if not (stats_raw) then
    --     print(" WQS ERROR getActualExtractionStats")
    --     return {}
    -- end
    -- local MainLabel=getText("ContextMenu_MainLabel")
    local stats = {}
    stats.data = {}
    stats.data = stats_raw

    stats.MainLabel = getText("IGUI_WQS_MainLabel") or "Extractionz"
    stats.MapGuiLabel = stats_raw.MapNameLabel

    -- local ReqExtractionLabel=getText("ContextMenu_ReqExtractionLabel")
    -- stats.ReqExtractionLabel="Request Extraction"	
    stats.ReqExtractionLabel = getText("IGUI_WQS_ReqExtraction") or "Request Extractionz"
    stats.CompleteExtractionLabel = getText("IGUI_WQS_CompleteExtraction") or "Complete Extractionz"

    stats.ZlevelLabel = getText("IGUI_WQS_ZlevelLabel") or "Elevationz"
    stats.ZlevelLabel = stats.ZlevelLabel .. ":  "

    stats.SignalStrenghtLabel = getText("IGUI_WQS_SignalStrenghtLabel") or "Signal Strenght"
    stats.SignalStrenghtLabel = stats.SignalStrenghtLabel .. ":  "

    stats.HoursLeftLabel = getText("IGUI_WQS_HoursLeftLabel") or "Hours leftz"
    --stats.HoursLeftLabel = stats.HoursLeftLabel .. ":  "

    stats.TooLateLabel = getText("IGUI_WQS_TooLateLabel") or "Too latez"

    stats.MissingExtractionItemTxt = getText("IGUI_WQS_MissingExtractionItemTxt") or
        "You need a military walkie talkie in inventory to request extractionz"

    stats.SignalNotActiveTxt = getText("IGUI_WQS_SignalNotActiveTxt") or "Radio signal activation:"
    stats.AntennaTooCloseToExtrPointTxt = getText("IGUI_WQS_AntennaTooCloseToExtrPointTxt") or
        "Antenna too close to extraction zone."
    stats.NeedAntennaToStartQuestTxt = getText("IGUI_WQS_NeedAntennaToStartQuestTxt") or
        "You need to be near an antenna to contact headquarters and request extraction"
    stats.NeedContactHQToStartQuestTxt = getText("IGUI_WQS_NeedContactHQToStartQuestTxt") or
        "Contact headquarter to request extraction."
    stats.AntennaMustBeOutsideTxt = getText("IGUI_WQS_AntennaMustBeOutsideTxt") or "Antenna must be outside."
    stats.NeedMoreRepeatersTxt = getText("IGUI_WQS_AntennaRepeatersNeedMore") or
        "Radio signal too weak, activate more repeaters."
    stats.TooLate = getText("IGUI_WQS_TooLateLabel") or "Too late baby, too late. Is over."
    stats.DeadLine = getText("IGUI_WQS_DeadLineLabel") or "Deadline"


    stats.ShowAlternativeGui = false
    stats.ShowAlternativeGuiTxt = ""

    stats.DistanceLabel = getText("IGUI_WQS_Distance") or "Distance"

    --stats.DistanceLabel = WQS_COLWHITE .. stats.DistanceLabel .. ": " .. tostring(stats_raw.Distance_val) .. "m "
    stats.DistanceLabel = WQS_COLWHITE .. stats.DistanceLabel .. ": "

    if stats_raw.Distance_isok then
        --stats.DistanceLabel = stats.DistanceLabel .. " OK! "
        stats.DistanceLabel = stats.DistanceLabel ..
            WQS_SPACE .. WQS_Shared.GuiCol(WQS_COLGREEN, tostring(stats_raw.Distance_val) .. "m  OK! ")
    else
        --stats.DistanceLabel = stats.DistanceLabel .. " " .. stats_raw.CardinalDir
        stats.DistanceLabel = stats.DistanceLabel ..
            WQS_SPACE .. WQS_Shared.GuiCol(WQS_COLSUBTIT, tostring(stats_raw.Distance_val) .. "m " ..
                stats_raw.CardinalDir)
    end

    local pz = string.format("%.0f", playerObj:getZ())
    local tz = string.format("%.0f", stats_raw.Zlevel_val)
    local sr = tostring(pz) .. "/" .. tostring(tz)

    if stats_raw.Zlevel_isok then
        --stats.ZlevelLabel = stats.ZlevelLabel .. tostring(sr) .. " OK! "
        stats.ZlevelLabel = stats.ZlevelLabel ..
            WQS_SPACE .. WQS_Shared.GuiCol(WQS_COLGREEN, tostring(sr) .. "  " .. " OK! ")
    else
        --stats.ZlevelLabel = stats.ZlevelLabel .. tostring(sr)
        stats.ZlevelLabel = stats.ZlevelLabel .. WQS_SPACE .. WQS_Shared.GuiCol(WQS_COLSUBTIT, tostring(sr))
    end

    local sStr = tostring(stats_raw.SignalStrenght_active) .. "/" .. tostring(stats_raw.SignalStrenght_needed)
    if (stats_raw.SignalStrenght_needed == 0) or (stats_raw.SignalStrenght_needed == nil) then
        sStr = ""
    end

    if stats_raw.SignalStrenght_isok then
        --stats.SignalStrenghtLabel = stats.SignalStrenghtLabel .. sStr .. " OK! "
        stats.SignalStrenghtLabel = stats.SignalStrenghtLabel ..
            WQS_SPACE .. WQS_Shared.GuiCol(WQS_COLGREEN, tostring(sStr) .. "  " .. " OK! ")
    else
        stats.SignalStrenghtLabel = stats.SignalStrenghtLabel .. " " .. sStr
        stats.ShowAlternativeGui = true
        stats.ShowAlternativeGuiTxt = stats.ShowAlternativeGuiTxt ..
            WQS_H2 .. WQS_COLTIT .. " <LEFT> " .. stats.SignalStrenghtLabel .. WQS_COLWHITE .. WQS_BR
        stats.ShowAlternativeGuiTxt =
            stats.ShowAlternativeGuiTxt .. WQS_SMALL .. stats.NeedMoreRepeatersTxt .. WQS_BR
        stats.ShowAlternativeGuiTxt = stats.ShowAlternativeGuiTxt .. tostring(stats_raw.SignalStrenght_statTxt)

        --   stats.HoursLeftLabel = getText("IGUI_WQS_HoursLeftLabel") or "Hours leftz"
        --     stats.HoursLeftLabel = stats.HoursLeftLabel .. ":  "
        local hours_left = WQS.getHoursLeftToDeadline()
        -- local in_time=true
        if (hours_left ~= false) and ((stats_raw.SignalHoursLeft_isok)) then
            if (hours_left >= 0) then
                local hls = string.format("%.2f", hours_left) .. " " .. string.lower(stats.HoursLeftLabel)
                stats.ShowAlternativeGuiTxt = stats.ShowAlternativeGuiTxt .. " <LINE> <H2> " ..
                    WQS_COLTIT .. stats.DeadLine .. WQS_BR .. WQS_SMALL .. WQS_COLWHITE .. hls .. " <LINE> "
            else
                stats.ShowAlternativeGuiTxt = stats.ShowAlternativeGuiTxt .. " <LINE> <H2> " ..
                    WQS_COLTIT .. stats.TooLate .. WQS_COLWHITE .. " <LINE> ";
                -- player:Say("Too late baby, too late. ")
            end
        end
        --quii
    end

    -- stats.HoursLeftLabel=stats.HoursLeftLabel.." ->"..tostring(stats_raw.test)
    if (stats_raw.HoursLeft_IsEnabled) then
        if stats_raw.HoursLeft_isok then
            local hls = string.format("%.2f", stats_raw.HoursLeft_val) .. " " .. string.lower(stats.HoursLeftLabel)
            --stats.HoursLeftLabel = stats.DeadLine .. ": " .. tostring(hls)
            stats.HoursLeftLabel = stats.DeadLine .. ": " .. WQS_SPACE .. WQS_Shared.GuiCol(WQS_COLGREEN, tostring(hls))
        else
            --stats.HoursLeftLabel = stats.TooLateLabel
            stats.HoursLeftLabel = WQS_Shared.GuiCol(WQS_COLRED, stats.TooLateLabel)
        end
    end

    if not (stats_raw.HaveExtractionItem) then
        stats.ShowAlternativeGui = true
        stats.ShowAlternativeGuiTxt =
            stats.ShowAlternativeGuiTxt .. " <LINE> <LEFT> " .. stats.MissingExtractionItemTxt .. " <LINE> "
    end

    stats.SignalHoursLeftLabel = ""
    if not (stats_raw.SignalHoursLeft_isok) then
        stats.ShowAlternativeGui = true -- true
        local hls = string.format("%.2f", stats_raw.SignalHoursLeft_val)
        stats.SignalHoursLeftLabel = stats.SignalNotActiveTxt .. ": " .. tostring(hls) .. " " ..
            string.lower(getText("IGUI_WQS_HoursLeftLabel"))
        stats.ShowAlternativeGuiTxt = stats.ShowAlternativeGuiTxt ..
            " <LINE> <H2> <LEFT> " .. WQS_COLTIT .. stats.SignalNotActiveTxt ..
            ": <LINE> <SIZE:small> " .. WQS_COLWHITE .. tostring(hls) .. " " ..
            string.lower(getText("IGUI_WQS_HoursLeftLabel"))
    end

    -- if (stats_raw.WeAreNearAntenna) then
    --     stats.ShowAlternativeGui = true
    --     stats.ShowAlternativeGuiTxt = " <H1> <LEFT> " .. getText("IGUI_WQS_AntennaMainLabel") .. " <LINE> <SIZE:small> "
    -- end

    if (stats_raw.AntennaTooCloseToExtrPoint) then
        stats.ShowAlternativeGui = true
        stats.ShowAlternativeGuiTxt = stats.ShowAlternativeGuiTxt .. " <LINE>  " ..
            stats.AntennaTooCloseToExtrPointTxt .. " <LINE> "
    end

    if (stats_raw.AntennaIsInside) then
        stats.ShowAlternativeGui = true
        stats.ShowAlternativeGuiTxt = stats.ShowAlternativeGuiTxt .. " <LINE> " ..
            stats.AntennaMustBeOutsideTxt .. " <LINE> "
    end

    if (stats_raw.NeedAntennaToStartQuest) then
        stats.ShowAlternativeGui = true
        if (stats_raw.WeAreNearAntenna) then
            stats.ShowAlternativeGuiTxt = stats.ShowAlternativeGuiTxt .. " <LINE> " ..
                stats.NeedContactHQToStartQuestTxt .. " <LINE> "
        else
            stats.ShowAlternativeGuiTxt = stats.ShowAlternativeGuiTxt .. " <LINE> " ..
                stats.NeedAntennaToStartQuestTxt .. " <LINE> "
        end
    end

    return stats
end

WQS.ThereIsErrorInExtractionData = function(Edata)
    -- print(Edata.MapCenterAreaX)
    if ((Edata == nil) or (Edata.MapCenterAreaX == 0) or (Edata.MapCenterAreaY == 0) or (Edata.MapItem == '')) then
        print(" ### WQS ERROR: There Is Error In Extraction Data ")
        return true
    end
    return false
end

-- WQS.getCurretExtractionMap = function()
--     --return WQS_extraction_map
--     --WQS_extraction_map_list = WQS_Shared.getExtractionPointsData()
--     local cem=setExtractionMap()
--     return cem
-- end

--[[
WQS.getExtractionItemId = function(get_full_id)

    if (get_full_id) then
        ret="Radio.WalkieTalkie5"
    else
        ret="WalkieTalkie5"
    end

    return ret
    --return WQS_ExtractionItem or "WalkieTalkie5"
end
 ]]

WQS.getHoursLeftToSignalActivation = function()
    local ret
    ret = 0
    local pl = WQS.GetCurrentPlayer();
    if (WQS_SignalActiveDays > 0) and pl then
        local ddh = WQS_SignalActiveDays * 24
        -- local pl = getPlayer();
        ret = (ddh - pl:getHoursSurvived())
        if ret < 0 then
            ret = 0
        end
    end
    return ret
end

WQS.getHoursLeftToDeadline = function()
    local ret
    local pl = WQS.GetCurrentPlayer();

    if not (pl) then
        return nil
    end

    local myModData = pl:getModData();
    if not (myModData.WQS) then
        myModData.WQS = {}
    end
    local QuestStartHoursSurvived = myModData.WQS.QuestStartHoursSurvived or 0
    if (WQS_DeadlineDays > 0) then
        local ddh = QuestStartHoursSurvived + (WQS_DeadlineDays * 24) + (WQS_SignalActiveDays * 24)
        -- local ddh = QuestStartHoursSurvived+(WQS_DeadlineDays * 24) + WQS.getHoursLeftToSignalActivation()
        if QuestStartHoursSurvived >= WQS_SignalActiveDays * 24 then
            ddh = QuestStartHoursSurvived + (WQS_DeadlineDays * 24)
        end
        -- local pl = getPlayer();
        -- local pl = WQS.GetCurrentPlayer();
        ret = (ddh - pl:getHoursSurvived())
    else
        ret = false
    end
    return ret
end

WQS.getDistance = function(x1, y1, x2, y2)
    return math.ceil(math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2))
end

WQS.BeginExtraction = function()
    print("BeginExtraction Prev state: " .. WQS.GetState())
    WQS.SetState("EXTRACTION_RUNNING")
    -- WQS_EXTRACTION_START_TIME=getTimeInMillis()
    WQS_EXTRACTION_START_TIME = getGameTime():getMinutesStamp() -- game minutes
    -- print("WQS_EXTRACTION_START_TIME="..WQS_EXTRACTION_START_TIME)
end

WQS.CompleteExtraction = function()
    print("CompleteExtraction Prev state: " .. WQS.GetState())
    WQS.SetState("EXTRACTION_COMPLETED")
    setShowPausedMessage(false) -- TODO da testare
    WQS_ModalWin(getText("IGUI_WQS_EndModal"), WQS_GoToMenu)
    setGameSpeed(0)
    pauseSoundAndMusic()
    -- WQS_FinalModalWin()
end

WQS.ContactHQ = function()
    -- print("ContactHQ ")
    WQS_AntennaGui.OnOpenPanel()
end

WQS.SetState = function(state)
    -- print("Changed state: old="..WQS_STATES["CURRENT"].." NEW="..WQS_STATES[state])
    WQS_STATES["CURRENT"] = WQS_STATES[state]
    if not (WQS_STATES["CURRENT"] == WQS_PREVSTATE) then
        if (WQS_PREVSTATE) then
            getSoundManager():playUISound("WQSBlip")
        end
        WQS_PREVSTATE = WQS_STATES["CURRENT"]
    end
end

WQS.GetState = function()
    if not (WQS_STATES["CURRENT"]) then
        WQS_STATES["CURRENT"] = WQS_STATES["PRE_EXTRACTION"]
    end
    return WQS_STATES["CURRENT"]
end

WQS.CurrentStateIs = function(state)
    if WQS.GetState() == WQS_STATES[state] then
        return true
    end
    return false
end

---ritorna true se esistono i dati di estrazione per la key passata
--- esempio WQS.ExtractionDataExist("WQS_item_list.wqs_map_louisville1")
WQS.ExtractionDataExist = function(MapItemName)
    local ret = false

    if not (MapItemName) then
        return false
    end
    -- utile se faccio il reload dello script
    if not (GlobalExtractionDataIsSet) then
        WQS.setGlobalExtractionData()
    end
    local MapListData = WQS_Shared.getExtractionPointsData()
    for k, v in pairs(MapListData) do
        -- print(string.lower(v.MapItem))
        if (string.lower(v.MapItem) == string.lower(MapItemName)) then
            return true
        end
    end
    return false
end

-- WQS.getExtractionData("WQS_item_list.wqs_map_louisville1")
-- ############## Mod func

WQS.getExtractionData = function(MapItemName)
    local ret = nil

    if not (MapItemName) then
        return nil
    end
    -- print("WQS getExtractionData "..MapItemName.." WQS_extraction_map_list="..tostring(WQS_extraction_map_list))

    -- utile se faccio il reload dello script
    if not (GlobalExtractionDataIsSet) then
        WQS.setGlobalExtractionData()
    end

    local MapListData = WQS_Shared.getExtractionPointsData()
    for k, v in pairs(MapListData) do
        -- print(string.lower(v.MapItem))
        if (string.lower(v.MapItem) == string.lower(MapItemName)) then
            ret = MapListData[k]
            -- print("Found "..MapListData[k].PreferredZlevelSpawn)
        end
    end
    -- (misura estrema) se non trovo i dati di estrazione per la key passata setto una estrazione casuale
    if not (ret) then
        print(" ### WQS ERROR getExtractionData : MapData not found for key=" .. MapItemName .. ", setting it randomly");
        WQS.setCurretExtractionMap("random")
    end

    return ret
end

WQS.GiveFirstQuest = function()
    print(" ### WQS GiveFirstQuest");
    -- local pl = getPlayer();
    local pl = WQS.GetCurrentPlayer();
    if not (pl) then
        return nil
    end
    local inv = pl:getInventory();

    local extraction_map = inv:AddItem("WQS_item_list.wqs_map_dynamic");
    -- local extraction_map = inv:AddItem(tostring(WQS.getCurretExtractionMap()));

    -- if extraction_map then
    --     local cmap = WQS.getExtractionData(WQS.getCurretExtractionMap())
    --     if cmap then
    --         extraction_map:setName(cmap.MapGuiLabel .. " " .. getText("IGUI_WQS_ExtrMapLabel"))
    --     end
    -- end

    WQS_ModalWin(getText("IGUI_WQS_StartModal"))

    --print(" ### WQS Curret Extraction Map= " .. tostring(WQS.getCurretExtractionMap()));
end

local LastMainStatusCheck = getTimeInMillis()

local function MainStatusCheckUpdate()
    local NOWZ = getTimeInMillis() -- getMinutes() --os.time() --getTimeInMillis()
    local delay = 2000

    if (NOWZ - LastMainStatusCheck) > delay then
        LastMainStatusCheck = getTimeInMillis()
        WQS.MainStatusCheck()
    end
end

WQS.MainStatusCheck = function()
    local player = WQS.GetCurrentPlayer();

    if not (player) then
        return nil
    end

    local ST = WQS.getActualExtractionStats(player)

    if (WQS.CurrentStateIs("PRE_EXTRACTION") or WQS.CurrentStateIs("EXTRACTION_CAN_BE_STARTED")) then
        if ST and ST.CanRequestExtraction then
            WQS.SetState("EXTRACTION_CAN_BE_STARTED")
        else
            WQS.SetState("PRE_EXTRACTION")
        end
    end

    if (WQS.CurrentStateIs("EXTRACTION_RUNNING") or (WQS.CurrentStateIs("EXTRACTION_CAN_BE_COMPLETED_BUT_WRONG_ZONE")) or
            (WQS.CurrentStateIs("EXTRACTION_CAN_BE_COMPLETED"))) then
        WQS_DeadlineDays = 0 -- stop countdown deadline

        if not (WQS_EXTRACTION_START_TIME) then
            -- WQS_EXTRACTION_START_TIME = getTimeInMillis()
            WQS_EXTRACTION_START_TIME = getGameTime():getMinutesStamp() -- game minutes
        end
        -- WQS_EXTRACTION_ELAPSED_TIME = getTimeInMillis() - WQS_EXTRACTION_START_TIME
        WQS_EXTRACTION_ELAPSED_TIME = getGameTime():getMinutesStamp() - WQS_EXTRACTION_START_TIME
        WQS_EXTRACTION_TIME_LEFT = WQS_EXTRACTION_DURATION_TIME_MIN - WQS_EXTRACTION_ELAPSED_TIME

        -- WQS_ExtractionEvent()
        WQS_ExtractionEventCheckUpdate()

        if WQS_EXTRACTION_TIME_LEFT <= 0 then
            if ST.CanRequestExtraction then
                WQS.SetState("EXTRACTION_CAN_BE_COMPLETED")
            else
                WQS.SetState("EXTRACTION_CAN_BE_COMPLETED_BUT_WRONG_ZONE")
            end
        end

        if (SandboxVars.WQS_ConfinedMode_opt == true) then
            if not (ST.IsInsideExtractionArea) then
                player:Say(getText("IGUI_WQS_Out_Of_EZone"));
                getSoundManager():playUISound("WQSBlip")
                player:Say(getText("IGUI_WQS_Out_Of_EZone"));
                WQS.SetState("PRE_EXTRACTION")
            end
        end
    end
end

WQS.GetCurrentPlayer = function(num)
    num = num or 0
    local p = getSpecificPlayer(num)
    if not (p) then
        print("########### WQS - ERROR -> Player not found!! num=" .. tostring(num))
        return nil
    end
    return p
end

WQS.GameModeIs = function(gm)
    if (WQS_GAMEMODES["CURRENT"] == nil) then
        WQS.SetInitialStateFromGameMode()
    end
    if WQS_GAMEMODES["CURRENT"] == WQS_GAMEMODES[gm] then
        return true
    end
    return false
end

WQS.SetInitialStateFromGameMode = function()
    if (SandboxVars.WQS_GameModeExtended_opt == true) then
        WQS_GAMEMODES["CURRENT"] = WQS_GAMEMODES["ANTENNA_MODE"]
        WQS.SetState("QUEST_NOT_STARTED")
    else
        WQS_GAMEMODES["CURRENT"] = WQS_GAMEMODES["CLASSIC_QUICK_MODE"]
        WQS.SetState("PRE_EXTRACTION")
        -- WQS.SetQuestAsStarted()
    end
    if not (WQS.QuestNotStarted()) and (WQS.GameModeIs("ANTENNA_MODE")) then
        -- WQS.SetQuestAsStarted()
        WQS.SetState("PRE_EXTRACTION")
    end
end


WQS.AddModdedMapExtractionZone = function(ModMapId, ZoneLabel, ModMapFolder, X, Y, Z, PrefSpawnPointList,
                                          PrefSpawnPointsPerc)
    if not (ModMapId) or not (ZoneLabel) or not (X) or not (Y) then
        print("### WQS addModdedMapExtractionZone ERROR : some params are nil")
        return false
    end

    -- Radius=Radius or 8
    -- PrefZlevelSpawn=PrefZlevelSpawn or nil
    local Radius = 8
    local PrefZlevelSpawn = nil
    Z = Z or 0
    PrefSpawnPointsPerc = PrefSpawnPointsPerc or nil
    PrefSpawnPointList = PrefSpawnPointList or {}

    local MapModIsActive = ActiveMods.getById("currentGame"):isModActive(ModMapId)
    if (MapModIsActive) then
        local MyId = ZoneLabel:gsub(" ", "-") .. "-" .. X .. "-" .. Y .. "-" .. Z
        --local MyId=X.."-"..Y.."-"..Z
        local ZoneId = "#modded_map#" .. ModMapId .. "_" .. MyId
        local ExtrData = ExtractionMap.new(ZoneId, X, Y, Z, ZoneLabel, Radius, PrefZlevelSpawn, PrefSpawnPointsPerc,
            ModMapFolder)
        table.insert(WQS_ExtractionPointsData, ExtrData)
        print(" ### WQS AddModdedMapExtractionZone -> Added <" .. ZoneLabel ..
            "> from mod " .. ModMapId .. " ZoneId=" .. ZoneId)
        if not (WQS_Shared.TableIsEmptyOrNil(PrefSpawnPointList)) then
            print(" ### WQS AddModdedMapExtractionZone -> Added PreferredSpawnPointsData key=" ..
                ZoneId .. " n. values=" .. #PrefSpawnPointList)
            WQS_PreferredSpawnPointsData[ZoneId] = PrefSpawnPointList
            -- if not(WQS_PreferredSpawnPointsData[ZoneId]) then
            --     WQS_PreferredSpawnPointsData[ZoneId]=PrefSpawnPointList
            -- end
            --table.insert(WQS_PreferredSpawnPointsData[ZoneId], PrefSpawnPointList)
        end
    end
end

--- aggiunge il punto di estrazione alla mappa globale del mondo
WQS.AddExtractionPointToWorldMap = function()
    local worldmap_render = ISWorldMap.render
    ---@diagnostic disable-next-line: duplicate-set-field
    ISWorldMap.render = function(self)
        worldmap_render(self)
        -- print (" ### WQS my ISWorldMap.render")
        local cmap = WQS.getExtractionData(WQS.getCurretExtractionMap())
        if cmap and (cmap.MapCenterAreaX) then
            local x = self.mapAPI:worldToUIX(cmap.MapCenterAreaX, cmap.MapCenterAreaY) - 3
            local y = self.mapAPI:worldToUIY(cmap.MapCenterAreaX, cmap.MapCenterAreaY) - 3

            self:drawRect(x - 4, y - 4, 8, 8, 1, 0, 1, 0) -- bordo
            self:drawRect(x - 3, y - 3, 6, 6, 1, 0.13, 0.52, 0.82)

            local member_name = cmap.MapGuiLabel
            local name_size = getTextManager():MeasureStringX(UIFont.NewSmall, member_name)
            self:drawRect(x - 4, y + 8, name_size + 8, 18, 0.5, 0, 0, 0)
            self:drawText(member_name, x, y + 9, 1, 1, 1, 1, UIFont.NewSmall)
        end
    end
end



WQS.OnStart = function()
    print("***** WQS started -> OnStart *****");
    WQS.setGlobalExtractionData()
    WQS.SetInitialStateFromGameMode()
    -- WQS.SetState("PRE_EXTRACTION")

    local pl = WQS.GetCurrentPlayer();

    -- if WQS_Shared.IsActiveRepeatersMode() then
    --     WQSAntenna.GenerateTargetRepeaterList(false,false,3)
    -- end

    if pl and not (WQS.QuestNotStarted()) then
        WQS.AddExtractionPointToWorldMap() -- TODO add sandbox option to toggle this
    end


    -- if it's a fresh spawn
    if (pl) and (pl:getHoursSurvived() < 0.2) then
        setSandboxVars();
        local inv = pl:getInventory();
        if (SandboxVars.WQS_StartWithExtractionItem_opt == true) then
            inv:AddItem(WQS_Shared.getExtractionItemId(true));
            print(" ### WQS Added " .. WQS_Shared.getExtractionItemId(true) .. " to player inventory")
        end
        if WQS.GameModeIs("CLASSIC_QUICK_MODE") then
            WQS.GiveFirstQuest();
        end
    end
end

local function OnInitGlobalModData()
    -- forageData = ModData.getOrCreate("forageData");
    WQS.setGlobalExtractionData()
    WQS.SetInitialStateFromGameMode()
    -- WQS.SetState("PRE_EXTRACTION")
end

-- Events.OnInitGlobalModData.Add(OnInitGlobalModData)

-- this code runs whenever a player is created (on spawn or respawn)
Events.OnCreatePlayer.Add(WQS.OnStart)

-- Events.EveryOneMinute.Add(WQS.MainStatusCheck)
Events.OnPlayerUpdate.Add(MainStatusCheckUpdate);

-- Events.OnMainMenuEnter.Add(WQS_ModalWin(getText("IGUI_WQS_StartModal")));
