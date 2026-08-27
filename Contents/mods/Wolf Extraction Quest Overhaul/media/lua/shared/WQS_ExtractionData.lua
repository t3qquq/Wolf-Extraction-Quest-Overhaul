WQS_ExtractionPointsData = {}
WQS_PreferredSpawnPointsData = {}
WQS_SharedData = {}
WQS_MapUIData={} --contiene l'area (e la legenda) da mostrare nella ui della mappa per le estrazioni vanilla

WQS_ModdedMapsExtractionZones = {}

--un cerchio con centro MapCenterAreaX,MapCenterAreaY e raggio AreaRadiusFromCenter
ExtractionMap = {}
ExtractionMap.new = function(MapItem,MapCenterAreaX,MapCenterAreaY,MapCenterAreaZ,MapGuiLabel,AreaRadiusFromCenter,PreferredZlevelSpawn,PreferredSpawnPointPerc,ModMapFolder)
   local self = {}
   self.MapItem = MapItem or ""
   self.MapCenterAreaX = MapCenterAreaX or 0
   self.MapCenterAreaY = MapCenterAreaY or 0
   self.MapCenterAreaZ = MapCenterAreaZ or 0
   self.AreaRadiusFromCenter = AreaRadiusFromCenter or 8
   self.PreferredZlevelSpawn = PreferredZlevelSpawn or nil
   self.MapGuiLabel = MapGuiLabel or MapItem
   self.PreferredSpawnPointPerc = PreferredSpawnPointPerc or 60 --la percentuale che gli Zed vengano spawnati negli spawnpoint preferiti invece che a caso, 60 è la percentuale di default
   self.ModMapFolder = ModMapFolder or "" --usato dalle mappe non vanilla,è la cartella dove sta la mappa della mod, esempio: raven creek -> media/maps/RavenCreek
   return self
end


--fake random map
WQS_ExtractionPointsData[1] = ExtractionMap.new("random")

--Louisville Bridge Road - Changed to Mega Mall
WQS_ExtractionPointsData[2] = ExtractionMap.new("WQS_item_list.wqs_map_louisville1",11307,8492,3,"Mega Mall")   
WQS_PreferredSpawnPointsData["WQS_item_list.wqs_map_louisville1"]= {
    {x=11340,y=8486,z=3},
    {x=11325,y=8465,z=3},
    {x=11325,y=8496,z=3},
    {x=11317,y=8463,z=2},
    {x=11311,y=8451,z=3},
    {x=11263,y=8479,z=3},
    {x=11358,y=8519,z=3}
    }
--Louisville Ohio Mall Roof
WQS_ExtractionPointsData[3] = ExtractionMap.new("WQS_item_list.wqs_map_louisville2",13616,1343,5,"Louisville Ohio Mall",8,2)
WQS_PreferredSpawnPointsData["WQS_item_list.wqs_map_louisville2"]= {
    {x=13632,y=1323,z=2},
    {x=13623,y=1332,z=2},
    {x=13637,y=1319,z=2},
    {x=13620,y=1325,z=2},
    {x=13639,y=1330,z=2}
    }
--Louisville Central Hospital Roof
WQS_ExtractionPointsData[4] = ExtractionMap.new("WQS_item_list.wqs_map_louisville3",12945,2040,3,"Louisville Central Hospital")
WQS_PreferredSpawnPointsData["WQS_item_list.wqs_map_louisville3"]= {
    {x=12925,y=2031,z=2},
    {x=12932,y=2038,z=2},
    {x=12928,y=2037,z=2},
    {x=12941,y=2041,z=2},
    {x=12933,y=2028,z=2}
    }
--Louisville Fossoil factory Roof - Changed to LV International Airport Gate A4
WQS_ExtractionPointsData[5] = ExtractionMap.new("WQS_item_list.wqs_map_louisville4",13097,4631,1,"LV International Airport Gate A4") 
WQS_PreferredSpawnPointsData["WQS_item_list.wqs_map_louisville4"]= {
    {x=13111,y=4620,z=0},
    {x=13080,y=4620,z=1},
    {x=13080,y=4624,z=1},
    {x=13079,y=4621,z=0},
    {x=13087,y=4623,z=1}
    }

--Louisville Orio Offices Roof
WQS_ExtractionPointsData[6] = ExtractionMap.new("WQS_item_list.wqs_map_louisville5",12765,1620,6,"Louisville Orio Offices")
WQS_PreferredSpawnPointsData["WQS_item_list.wqs_map_louisville5"]= {
    {x=12767,y=1615,z=5},
    {x=12757,y=1619,z=5},
    {x=12764,y=1611,z=5},
    {x=12786,y=1619,z=5}
    }

--Muldraugh Mass-Genfac Roof - Changed to Lake Cumberland Mall
WQS_ExtractionPointsData[7] = ExtractionMap.new("WQS_item_list.wqs_map_muldraugh1",15935, 7911,5,"Lake Cumberland Mall")
WQS_PreferredSpawnPointsData["WQS_item_list.wqs_map_muldraugh1"]= {
    {x=15926,y=7906,z=3},
    {x=15923,y=7921,z=5},
    {x=15950,y=7899,z=5},
    {x=15963,y=7918,z=5},
    {x=15911,y=7903,z=5},
    {x=15946,y=7922,z=4},
    {x=15916,y=7911,z=4},
    {x=15917,y=7918,z=4}
    }

--Muldraugh Soccer Field - Changed to Over the River Bridge
WQS_ExtractionPointsData[8] = ExtractionMap.new("WQS_item_list.wqs_map_muldraugh2",11211, 6396,4,"Over the River Bridge")
WQS_PreferredSpawnPointsData["WQS_item_list.wqs_map_muldraugh2"]= {
    {x=11205,y=6398,z=3},
    {x=11220,y=6394,z=3},
    {x=11209,y=6412,z=4},
    {x=11219,y=6412,z=4},
    {x=11232,y=6392,z=4},
    {x=11230,y=6385,z=4}
    }


--March Ridge Cinema - Changed to Research Facility Helipad
WQS_ExtractionPointsData[9] = ExtractionMap.new("WQS_item_list.wqs_map_march_ridge1",5731, 12508,0,"Research Facility Helipad",8,0)
WQS_PreferredSpawnPointsData["WQS_item_list.wqs_map_march_ridge1"]= {
    {x=5711,y=12489,z=0},
    {x=5710,y=12505,z=0},
    {x=5721,y=12531,z=0},
    {x=5737,y=12532,z=0},
    {x=5724,y=12476,z=0},
    {x=5750,y=12488,z=0},
    {x=5771,y=12524,z=0}
    }

--Rosewood Penitentiary prison
WQS_ExtractionPointsData[10] = ExtractionMap.new("WQS_item_list.wqs_map_rosewood1",7669, 11883,0,"Rosewood Penitentiary",7,0,90)
WQS_PreferredSpawnPointsData["WQS_item_list.wqs_map_rosewood1"]= {
    {x=7669,y=11869,z=0},
    {x=7661,y=11868,z=0},
    {x=7671,y=11867,z=0},
    {x=7665,y=11901,z=0},
    {x=7663,y=11898,z=0},
    {x=7680,y=11904,z=0},
    {x=7657,y=11904,z=0},
    {x=7660,y=11890,z=0},
    {x=7658,y=11860,z=0},
    {x=7683,y=11889,z=0}
    }


---riguardano la GUI MAP  che si apre consultanto la mappa dinamica (SOLO per MAPPE VANILLA)

local LVx = 11700
local LVy = 900
local LVw = 300 * 4
local LVh = 300 * 4
local LVdx = 300 * 3
local LVdy = 300 * 3
local LVbadgeHgt = 150
function WQS_LvGridX1(col)
	return LVx + LVdx * col
end
function WQS_LvGridY1(row)
	return LVy + LVdy * row - LVbadgeHgt
end
function WQS_LvGridX2(col)
	return WQS_LvGridX1(col) + LVw - 1
end
function WQS_LvGridY2(row)
	return WQS_LvGridY1(row) + LVh - 1 + LVbadgeHgt
end

WQS_MapUIData["WQS_item_list.wqs_map_louisville1"] = {
    Sx = WQS_LvGridX1(0),         --map GUI start x
    Sy = WQS_LvGridY1(0),         --map GUI start y
    Ex = WQS_LvGridX2(0),         --map GUI end x
    Ey = WQS_LvGridY2(0),         --map GUI end y
    CityLegend = 0
}
--Ohio Mall Roof	
WQS_MapUIData["WQS_item_list.wqs_map_louisville2"] = {
    Sx = WQS_LvGridX1(1),         --map GUI start x
    Sy = WQS_LvGridY1(0),         --map GUI start y
    Ex = WQS_LvGridX2(1),         --map GUI end x
    Ey = WQS_LvGridY2(0),         --map GUI end y
    CityLegend = 0
}
--Central Hospital Roof	
WQS_MapUIData["WQS_item_list.wqs_map_louisville3"] = {
    Sx = WQS_LvGridX1(1),         --map GUI start x
    Sy = WQS_LvGridY1(1),         --map GUI start y
    Ex = WQS_LvGridX2(1),         --map GUI end x
    Ey = WQS_LvGridY2(1),         --map GUI end y
    CityLegend = 0
}
--Louisville Fossoil factory Roof
WQS_MapUIData["WQS_item_list.wqs_map_louisville4"] = {
    Sx = WQS_LvGridX1(0),         --map GUI start x
    Sy = WQS_LvGridY1(0),         --map GUI start y
    Ex = WQS_LvGridX2(0),         --map GUI end x
    Ey = WQS_LvGridY2(0),         --map GUI end y
    CityLegend = 0
}
--Louisville Orio Offices Roof	
WQS_MapUIData["WQS_item_list.wqs_map_louisville5"] = {
    Sx = WQS_LvGridX1(0),         --map GUI start x
    Sy = WQS_LvGridY1(0),         --map GUI start y
    Ex = WQS_LvGridX2(0),         --map GUI end x
    Ey = WQS_LvGridY2(0),         --map GUI end y
    CityLegend = 0
}
--Muldraugh Mass-Genfac Roof Map Gui
WQS_MapUIData["WQS_item_list.wqs_map_muldraugh1"] = {
    Sx = 10540,         --map GUI start x
    Sy = 9240,          --map GUI start y
    Ex = 11217,         --map GUI end x
    Ey = 10696,         --map GUI end y
    CityLegend = 1
}
--Muldraugh Soccer Field Map Gui		
WQS_MapUIData["WQS_item_list.wqs_map_muldraugh2"] = {
    Sx = 10540,         --map GUI start x
    Sy = 9240,          --map GUI start y
    Ex = 11217,         --map GUI end x
    Ey = 10696,         --map GUI end y
    CityLegend = 1
}
--March Ridge Cinema Map Gui	
WQS_MapUIData["WQS_item_list.wqs_map_march_ridge1"] = {
    Sx = 9700,          --map GUI start x
    Sy = 12470,         --map GUI start y
    Ex = 10579,         --map GUI end x
    Ey = 13199,         --map GUI end y
    CityLegend = 2
}
--Rosewood Penitentiary prison Map Gui
WQS_MapUIData["WQS_item_list.wqs_map_rosewood1"] = {
    Sx = 7520,          --map GUI start x
    Sy = 11450,         --map GUI start y
    Ex = 8604,          --map GUI end x
    Ey = 12139,         --map GUI end y
    CityLegend = 3
}




