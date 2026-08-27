--riferimento
--/steamapps/common/ProjectZomboid/projectzomboid/media/lua/client/ISUI/Maps/ISMapDefinitions.lua
--steamapps/workshop/content/108600/2800337234/mods/Trelai_4x4_Steam/media/lua/client/ISUI/Maps/Trelai_ISMapDefinition.lua
--TrelaiStory2
--steamapps/workshop/content/108600/2801061750/mods/aadvzmbmod2/media/lua/client/ISUI/Maps/Client_AAdvZmbMod_ISMapDefinitions.lua


--require "Maps/ISMapDefinitions"
--require "ISUI/Maps/ISMapDefinitions"
--require "ISMapDefinitions"

local MINZ = 0

local function overlayPNG(mapUI, x, y, scale, layerName, tex, alpha)
	local texture = getTexture(tex)
	if not texture then return end
	local mapAPI = mapUI.javaObject:getAPIv1()
	local styleAPI = mapAPI:getStyleAPI()
	local layer = styleAPI:newTextureLayer(layerName)
	layer:setMinZoom(MINZ)
	layer:addFill(MINZ, 255, 255, 255, (alpha or 1.0) * 255)
	layer:addTexture(MINZ, tex)
	layer:setBoundsInSquares(x, y, x + texture:getWidth() * scale, y + texture:getHeight() * scale)
end





function CommonMapCalc(mapUI, MapItemName, startX, startY, citylegend, MapFolder)
	--MapItemName è il nome dell'item (in WQS_items.txt) che spawna e mostra questa mappa
	--local MapItemName="WQS_item_list.wqs_map_louisville1"


	if not (MapFolder) or (MapFolder == "") then
		MapFolder = "media/maps/Muldraugh, KY"
	end

	--print("WQS MapFolder="..MapFolder)

	local centerpoint = 48 / 2 --48 è la larghezza del pointer png che appare sulla mappa
	local MapData = WQS.getExtractionData(MapItemName)
	citylegend = citylegend or 0

	if not(MapData) or WQS.ThereIsErrorInExtractionData(MapData) then
		print(" #### WQS ERROR MAP INIT: " .. MapItemName)
		return false
	end

	--local mapAPI = mapUI.javaObject:getAPIv1()

	MapUtils.initDirectoryMapData(mapUI, MapFolder)
	MapUtils.initDefaultStyleV1(mapUI)
	--replaceWaterStyle(mapUI) --non funziona
	-- la larghezza della mappa è 1200 -> screen mappa ingame, ritaglia mappa, ridimensiona a 1200 larghezza, prendi coordinate
	if citylegend == 0 then
		overlayPNG(mapUI, startX, startY, 1.0, "legend", "media/textures/worldMap/LouisvilleBadge.png")
	end
	if citylegend == 1 then
		overlayPNG(mapUI, 11093, 9222, 0.666, "badge", "media/textures/worldMap/MuldraughBadge.png")
	end
	if citylegend == 2 then
		overlayPNG(mapUI, 9769, 12492, 0.666, "badge", "media/textures/worldMap/MarchRidgeBadge.png")
	end
	if citylegend == 3 then
		overlayPNG(mapUI, 7958, 11962, 0.666, "badge", "media/textures/worldMap/RosewoodBadge.png")
	end

	local pointx = MapData.MapCenterAreaX - startX
	local pointy = MapData.MapCenterAreaY - startY
	--11700+0+900-32
	local finalx = (startX + pointx) - centerpoint
	local finaly = (startY + pointy) - centerpoint

	--print(pointx..","..pointy)
	--print(finalx..","..finaly)
	overlayPNG(mapUI, finalx, finaly, 1.0, "legend2", "media/ui/img/point_on_map2.png")
	MapUtils.overlayPaper(mapUI)
	--return mapAPI
end


--WQS_item_list.wqs_map_louisville1



LootMaps.Init.WQS_DynamicMap = function(mapUI)
	--local MName=WQS.getCurretExtractionMap()

	if (WQS.QuestNotStarted()) then
       return
    end

	local MData = WQS.getCurretMapExtractionData()
	--MData.MapItem(mapUI)
	
	if (MData) and not(WQS_Shared.TableIsEmptyOrNil(MData)) and (MData.MapCenterAreaX) then

		local MSizeHoriz=1600
		local MSizeVert=1000
		MSizeHoriz=math.floor(MSizeHoriz/2)
		MSizeVert=math.floor(MSizeVert/2)
		MGui={}
		MGui.Sx=MData.MapCenterAreaX-MSizeHoriz
		MGui.Sy=MData.MapCenterAreaY-MSizeVert
		MGui.Ex=MData.MapCenterAreaX+MSizeHoriz
		MGui.Ey=MData.MapCenterAreaY+MSizeVert
		MGui.CityLegend=-1

		if WQS_MapUIData[MData.MapItem] then
			MGui=WQS_MapUIData[MData.MapItem]
			MGui.CityLegend=MGui.CityLegend or -1
			--DrawCityLegend(mapUI,1,0,0)
		end

		CommonMapCalc(mapUI, MData.MapItem,MGui.Sx, MGui.Sy, MGui.CityLegend,MData.ModMapFolder)
		--CommonMapCalc(mapUI, MData.MapItem, MData.MapCenterAreaX, MData.MapCenterAreaY, MGui.CityLegend,MData.ModMapFolder)
		local mapAPI = mapUI.javaObject:getAPIv1()

		mapAPI:setBoundsInSquares(MGui.Sx,MGui.Sy,MGui.Ex,MGui.Ey)
	end
end


LootMaps.Init.WQS_DynamicRepeaterMap = function(mapUI)

	--overlayPNG(mapUI, 10000, 9000, 1.0, "Bounty01", "media/ui/LootableMaps/Bounty01.png", 1.0)
	local centerpoint = 144 / 2 --144 è la larghezza del pointer png che appare sulla mappa
	local MSizeHoriz=1600
	local MSizeVert=1000

	local TargetRepeaterList=WQS_Shared.getWQSPlayerModData("TargetRepeaterList")
    if not(TargetRepeaterList) or WQS_Shared.TableIsEmptyOrNil(TargetRepeaterList) then
		return
	end

	local mapAPI = mapUI.javaObject:getAPIv1()
	MapUtils.initDirectoryMapData(mapUI, 'media/maps/Muldraugh, KY')
	MapUtils.initDefaultStyleV1(mapUI)	
	local sx,sy,ex,ey
	local xmax =0 
	local xmin =100000 
	local ymax =0 
	local ymin =100000 

	MSizeHoriz=500
	MSizeVert=500
	if  #TargetRepeaterList==1 then
		MSizeHoriz=5000
		MSizeVert=5000	
	end
	if  #TargetRepeaterList==2 then
		MSizeHoriz=1000
		MSizeVert=1000	
	end

	for i, Rep in ipairs(TargetRepeaterList) do		
		--print(i.." WQS_DynamicRepeaterMap")
		--print(WQS_Shared.Dump(Rep))
		sx = Rep.x-MSizeHoriz
		sy = Rep.y-MSizeVert
		ex = Rep.x+MSizeHoriz
		ey = Rep.y+MSizeVert

		if xmax<ex then xmax=ex end
		if xmin>sx then xmin=sx end
		if ymax<ey then ymax=ey end
		if ymin>sy then ymin=sy end

		local finalx = Rep.x - centerpoint
		local finaly = Rep.y - centerpoint
		--print(WQS_Shared.concat(sx, sy, ex, ey))
		overlayPNG(mapUI, finalx, finaly, 1.0, "RepeaterList"..tostring(i), "media/ui/img/point_on_map3.png")
		--MapUtils.overlayPaper(mapUI)
	end
	--print("bound="..WQS_Shared.concat(xmin, ymin, xmax, ymax))
	MapUtils.overlayPaper(mapUI)
	mapAPI:setBoundsInSquares(xmin, ymin, xmax, ymax)
end	

--- TODO: questi con Lootmaps nelle prossime versioni vanno eliminati tutti

--exportFuncs[namevar](...)
LootMaps.Init.WQS_LouisvilleMap1 = function(mapUI)
	--MapItemName è il nome dell'item (in WQS_items.txt) che spawna e mostra questa mappa
	local MName = "WQS_item_list.wqs_map_louisville1"
	CommonMapCalc(mapUI, MName, WQS_LvGridX1(0), WQS_LvGridY1(0))

	local mapAPI = mapUI.javaObject:getAPIv1()
	-- Show only this area from the full map.
	mapAPI:setBoundsInSquares(WQS_LvGridX1(0), WQS_LvGridY1(0), WQS_LvGridX2(0), WQS_LvGridY2(0))
end

--Ohio Mall Roof
LootMaps.Init.WQS_LouisvilleMap2 = function(mapUI)
	--MapItemName è il nome dell'item (in WQS_items.txt) che spawna e mostra questa mappa
	local MName = "WQS_item_list.wqs_map_louisville2"
	CommonMapCalc(mapUI, MName, WQS_LvGridX1(1), WQS_LvGridY1(0))

	local mapAPI = mapUI.javaObject:getAPIv1()
	-- Show only this area from the full map.
	mapAPI:setBoundsInSquares(WQS_LvGridX1(1), WQS_LvGridY1(0), WQS_LvGridX2(1), WQS_LvGridY2(0))
end

--Central Hospital Roof
LootMaps.Init.WQS_LouisvilleMap3 = function(mapUI)
	--MapItemName è il nome dell'item (in WQS_items.txt) che spawna e mostra questa mappa
	local MName = "WQS_item_list.wqs_map_louisville3"
	CommonMapCalc(mapUI, MName, WQS_LvGridX1(1), WQS_LvGridY1(1))

	local mapAPI = mapUI.javaObject:getAPIv1()
	-- Show only this area from the full map.
	mapAPI:setBoundsInSquares(WQS_LvGridX1(1), WQS_LvGridY1(1), WQS_LvGridX2(1), WQS_LvGridY2(1))
end

--Louisville Fossoil factory Roof
LootMaps.Init.WQS_LouisvilleMap4 = function(mapUI)
	--MapItemName è il nome dell'item (in WQS_items.txt) che spawna e mostra questa mappa
	local MName = "WQS_item_list.wqs_map_louisville4"
	CommonMapCalc(mapUI, MName, WQS_LvGridX1(0), WQS_LvGridY1(0))
	local mapAPI = mapUI.javaObject:getAPIv1()
	-- Show only this area from the full map.
	mapAPI:setBoundsInSquares(WQS_LvGridX1(0), WQS_LvGridY1(0), WQS_LvGridX2(0), WQS_LvGridY2(0))
end

--Louisville Orio Offices Roof
LootMaps.Init.WQS_LouisvilleMap5 = function(mapUI)
	--MapItemName è il nome dell'item (in WQS_items.txt) che spawna e mostra questa mappa
	local MName = "WQS_item_list.wqs_map_louisville5"
	CommonMapCalc(mapUI, MName, WQS_LvGridX1(0), WQS_LvGridY1(0))
	local mapAPI = mapUI.javaObject:getAPIv1()
	-- Show only this area from the full map.
	mapAPI:setBoundsInSquares(WQS_LvGridX1(0), WQS_LvGridY1(0), WQS_LvGridX2(0), WQS_LvGridY2(0))
end

--Muldraugh Mass-Genfac Roof
LootMaps.Init.WQS_MuldraughMap1 = function(mapUI)
	--MapItemName è il nome dell'item (in WQS_items.txt) che spawna e mostra questa mappa
	local MName = "WQS_item_list.wqs_map_muldraugh1"
	CommonMapCalc(mapUI, MName, 10540, 9240, 1)
	local mapAPI = mapUI.javaObject:getAPIv1()
	-- Show only this area from the full map.
	mapAPI:setBoundsInSquares(10540, 9240, 11217, 10696)
	--mapAPI:setBoundsInSquares(WQS_LvGridX1(0), WQS_LvGridY1(0), WQS_LvGridX2(0), WQS_LvGridY2(0))	
end

--Muldraugh Soccer Field
LootMaps.Init.WQS_MuldraughMap2 = function(mapUI)
	--MapItemName è il nome dell'item (in WQS_items.txt) che spawna e mostra questa mappa
	local MName = "WQS_item_list.wqs_map_muldraugh2"
	CommonMapCalc(mapUI, MName, 10540, 9240, 1)
	local mapAPI = mapUI.javaObject:getAPIv1()
	-- Show only this area from the full map.
	mapAPI:setBoundsInSquares(10540, 9240, 11217, 10696)
	--mapAPI:setBoundsInSquares(WQS_LvGridX1(0), WQS_LvGridY1(0), WQS_LvGridX2(0), WQS_LvGridY2(0))	
end

--March Ridge Cinema
LootMaps.Init.WQS_MarchRidgeMap1 = function(mapUI)
	--MapItemName è il nome dell'item (in WQS_items.txt) che spawna e mostra questa mappa
	local MName = "WQS_item_list.wqs_map_march_ridge1"
	CommonMapCalc(mapUI, MName, 9700, 12470, 2)
	local mapAPI = mapUI.javaObject:getAPIv1()
	-- Show only this area from the full map.
	mapAPI:setBoundsInSquares(9700, 12470, 10579, 13199)
	--mapAPI:setBoundsInSquares(WQS_LvGridX1(0), WQS_LvGridY1(0), WQS_LvGridX2(0), WQS_LvGridY2(0))	
end

--Rosewood Penitentiary prison
LootMaps.Init.WQS_RosewoodMap1 = function(mapUI)
	--MapItemName è il nome dell'item (in WQS_items.txt) che spawna e mostra questa mappa
	local MName = "WQS_item_list.wqs_map_rosewood1"
	CommonMapCalc(mapUI, MName, 7520, 11450, 3)
	local mapAPI = mapUI.javaObject:getAPIv1()
	-- Show only this area from the full map.
	mapAPI:setBoundsInSquares(7520, 11450, 8604, 12139)
	--mapAPI:setBoundsInSquares(WQS_LvGridX1(0), WQS_LvGridY1(0), WQS_LvGridX2(0), WQS_LvGridY2(0))	
end

-- function ISMap:canWrite()
--     local inv = self.character:getInventory();
--     return inv:containsTagRecurse("Write")
-- end
