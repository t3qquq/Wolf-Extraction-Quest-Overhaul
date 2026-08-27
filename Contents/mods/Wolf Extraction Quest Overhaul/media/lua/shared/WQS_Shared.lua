-- Contains classes and/or functions that may be needed into client and/or server files
WQS_Shared = {}
WQS_SharedGuiUtil = {}

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

WQS_Shared.getWQSPlayerModData = function(key)
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
    local rr = 1
    if (ZombRand) then
        rr = ZombRand(#t) + 1
    else
        rr = math.random(1, #t)
    end
    --local rr = math.random(1, #t)
    local retval = nil
    --print(rr .. " > " .. tostring(t[rr]))
    if t[rr] then
        --print("ret " .. rr .. " " .. tostring(t[rr]))
        retval = t[rr]
    else
        --print("again " .. rr .. " " .. tostring(t[rr]))
        retval = WQS_Shared.PickRandomObjFromTableIfNotNil(t)
    end
    return retval
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
