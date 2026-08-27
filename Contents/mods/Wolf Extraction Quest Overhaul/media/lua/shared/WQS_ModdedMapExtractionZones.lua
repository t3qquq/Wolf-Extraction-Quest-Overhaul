function WQS_ModdedMapExtractionZoneInit()
    local ModMapId, ZoneLabel, ModMapFolder, ExtrPointX, ExtrPointY, ExtrPointZ, PrefSpawnPointsPerc
    local PrefSpawnPointList = {}

    --REQUIRED DATA - change to these values results in the need to request a new extraction from headquarters
    ModMapId = "RavenCreek"                --the mod id taken from mod.info map mod
    ZoneLabel = "Raven Creek Medical Center" --the name of the extraction point for the extraction tracker gui
    ModMapFolder = "media/maps/RavenCreek" --the folder inside the mod folder where we can find map data
    ExtrPointX = 3991                      --x coord of the center of the extraction area
    ExtrPointY = 11732                     --y coord of the center of the extraction area
    ExtrPointZ = 4                         ---z level of the extraction area

    --OPTIONAL DATA
    --- Preferred extraction points is a non-random chosen list of spawn points for the extraction event
    --- Those points are used (instead of the standard random ones) to compensate for the 
    --- stupidity of the AI and the occasionally weird pathfinding
    ---if the chosen point is visible to the player at the time of spawn it will not be used
    ---Recommended at least 4 points in different (opposite) positions
    PrefSpawnPointList = {
        { x = 3999, y = 11722, z = 4 },
        { x = 3992, y = 11723, z = 4 },
        { x = 3989, y = 11718, z = 4 },
        { x = 3983, y = 11718, z = 4 },
        { x = 3988, y = 11718, z = 4 },
        { x = 3988, y = 11718, z = 3 },
        { x = 4003, y = 11726, z = 4 },
        { x = 3988, y = 11718, z = 4 }
    }
    --- PrefSpawnPointsPerc is the percentage by which preferred extraction points will be chosen
    --- instead of the standard random ones, do not put this over 80
    PrefSpawnPointsPerc = 70

    WQS.AddModdedMapExtractionZone(ModMapId, ZoneLabel, ModMapFolder, ExtrPointX, ExtrPointY, ExtrPointZ,
        PrefSpawnPointList, PrefSpawnPointsPerc)
end

Events.OnGameStart.Add(WQS_ModdedMapExtractionZoneInit);
