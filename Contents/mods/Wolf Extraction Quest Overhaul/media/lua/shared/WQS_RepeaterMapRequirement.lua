--- Which map mod each repeater location belongs to.
---
--- The ZG sub mod solved this by hard requiring every single map in mod.info,
--- so a server that did not run all of them could not load the mod at all.
--- Here the map list is a soft dependency instead: a repeater whose map is not
--- installed is dropped from the candidate pool at runtime and everything else
--- keeps working. Only the maps the extraction points themselves need stay in
--- mod.info as hard requires.
---
--- byArea      : area name -> mod id. Applies to every repeater of that area.
--- byRepeater  : "<area>|<name>" -> mod id. Overrides byArea for one entry.
---               false marks a single entry as vanilla, which is needed when
---               the area name alone would gate it wrongly.
---
--- A repeater with no entry here is treated as vanilla and stays available.
--- Mod ids must match the "id=" line of the map mod exactly, they are case
--- sensitive and some of them contain spaces.
---
--- Adding a new repeater on a modded map: put the location in
--- WQS_RepeaterData.lua and add its mod id here. Nothing else to touch.

WQS_RepeaterMapRequirement = {}

WQS_RepeaterMapRequirement.byArea = {
    ["Amusement Park"]           = "SimonMDValuTechAmusementPark",
    ["Bedford Falls"]            = "BedfordFalls",
    ["Cedar Hill"]               = "CedarHill",
    ["Chinatown"]                = "Chinatown",
    ["Chinatown Expansion"]      = "Chinatown expansion",
    ["Delta Creek"]              = "DeltaCreekMunitions",
    ["Dirkerdam"]                = "Dirkerdam",
    ["Elysium"]                  = "Elysium_Island",
    ["Fort Rock Ridge"]          = "Fort Rock Ridge",
    ["Grapeseed"]                = "Grapeseed",
    ["Greenleaf"]                = "Greenleaf",
    ["LV International Airport"] = "SimonMDLVInternationalAirport",
    ["Lake Cumberland"]          = "LCv2",
    ["Louisville Shipping Port"] = "SimonMDLVHarbor",
    ["Military Airfield"]        = "Militaryairport",
    ["Monmouth County"]          = "MonmouthCounty_new",
    ["New Tersh"]                = "NewTersh",
    ["Over the River"]           = "Otr",
    ["Overlook"]                 = "OverlookHotel",
    ["Petroville"]               = "Petroville",
    ["Pitstop"]                  = "Pitstop",
    ["Research Facility"]        = "rbr",
    ["Southwood"]                = "Southwood2.0",
    ["St Paulo's Hammer"]        = "SPH",
    ["Tandil"]                   = "Tandil",
    ["The Walking Dead"]         = "TWDprison",
    ["Trelai"]                   = "Trelai_4x4_Steam",
    ["Utopia"]                   = "Utopia",
}

WQS_RepeaterMapRequirement.byRepeater = {
    -- "The" is not an area name, the area/name split is wrong in the source
    -- data for these two. Keyed per repeater so the bad string stays harmless.
    ["The|Mall"]                       = "TheMallSouthMuldraughFIX",
    ["The|Museum"]                     = "TheMuseumID",

    -- Modded locations sitting inside a vanilla area. These are the ones the
    -- bounding box check cannot catch: without the map mod the cells are still
    -- loaded, just empty, so they have to be listed explicitly.
    ["Muldraugh|Military Base"]        = "muldraughmilitarybase",
    ["West Point|Court"]               = "WestPointExpansion",

    -- Vanilla locations kept explicit so nobody adds an area rule later that
    -- would gate them by accident.
    ["Muldraugh|Sunstar Motel"]        = false,
    ["Valley Station|Crossroads Mall"] = false,
}
