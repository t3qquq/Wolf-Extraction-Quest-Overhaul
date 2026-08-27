local pt = "Contents/mods/Wolf Extraction Quest/media/lua/shared/"

require(pt .. "WQS_RepeaterData")
require(pt .. "WQS_ExtractionData")
require(pt .. "WQS_Shared")

--local Rd=require("/lua/shared/WQS_RepeaterData.lua")
-- local WQS_RepeaterData={}
-- WQS_RepeaterData = {
--     ["Valley Station"] = {
--         {
--             ["name"] = "Knox Bank",
--             ["y"] = 5745,
--             ["x"] = 13656,
--         },
--         {
--             ["name"] = "Shooting Range",
--             ["y"] = 5442,
--             ["x"] = 13266,
--         },
--     },
--     ["West Point"] = {
--         {
--             ["name"] = "Knox Bank",
--             ["y"] = 6914,
--             ["x"] = 11913,
--         },
--         {
--             ["name"] = "Fossoil",
--             ["y"] = 7140,
--             ["x"] = 12069,
--         },
--         {
--             ["name"] = "Picnic area",
--             ["y"] = 7364,
--             ["x"] = 12033,
--         },
--         {
--             ["name"] = "Cemetary",
--             ["y"] = 6710,
--             ["x"] = 11069,
--         },
--     },
--     ["March Ridge"] = {
--         {
--             ["name"] = "Post Office",
--             ["y"] = 12713,
--             ["x"] = 10107,
--         },
--         {
--             ["name"] = "Church",
--             ["y"] = 12794,
--             ["x"] = 10328,
--         },
--     },
--     ["Muldraugh"] = {
--         {
--             ["name"] = "Chapel",
--             ["y"] = 9711,
--             ["x"] = 10723,
--         },
--         {
--             ["name"] = "Adult Education Center",
--             ["y"] = 9904,
--             ["x"] = 10638,
--         },
--         {
--             ["name"] = "All you can eat",
--             ["y"] = 9437,
--             ["x"] = 10619,
--         },
--         {
--             ["name"] = "Warehouse",
--             ["y"] = 10103,
--             ["x"] = 10694,
--         },
--         {
--             ["name"] = "Railyard",
--             ["x"] = 11655,
--             ["y"] = 9985
--         },

--     },
--     ["Rosewood"] = {
--         {
--             ["name"] = "Medical",
--             ["y"] = 11526,
--             ["x"] = 8089,
--         },
--         {
--             ["name"] = "Construction Site",
--             ["y"] = 11841,
--             ["x"] = 8219,
--         },
--         {
--             ["name"] = "Drive In",
--             ["x"] = 8426,
--             ["y"] = 12240
--         },
--         {
--             ["name"] = "Army Quarter",
--             ["x"] = 9118,
--             ["y"] = 11814
--         },
--     },
--     ["Dixie"] = {
--         {
--             ["name"] = "Picnic dining area",
--             ["y"] = 8858,
--             ["x"] = 11556,
--         },
--         {
--             ["name"] = "Molans Used Cars",
--             ["y"] = 8367,
--             ["x"] = 11687,
--         },
--     },
--     ["Doe Valley"] = {
--         {
--             ["name"] = "Warehouses",
--             ["y"] = 10020,
--             ["x"] = 6734,
--         },
--         {
--             ["name"] = "Military Store",
--             ["x"] = 5464,
--             ["y"] = 9511
--         },
--     },
--     ["Riverside"] = {
--         {
--             ["name"] = "Hardware Store",
--             ["y"] = 5327,
--             ["x"] = 6364,
--         },
--         {
--             ["name"] = "Food Market",
--             ["y"] = 5392,
--             ["x"] = 5969,
--         },
--         {
--             ["name"] = "Police Station",
--             ["y"] = 5261,
--             ["x"] = 6082,
--         },
--         {
--             ["name"] = "Burgers",
--             ["y"] = 5263,
--             ["x"] = 5955,
--         },
--         {
--             ["name"] = "Country club",
--             ["x"] = 5765,
--             ["y"] = 6470
--         },
--     },
-- }
WQS = {}

---@diagnostic disable-next-line: duplicate-set-field
WQS.getDistance2 = function(x1, y1, x2, y2)
    return math.ceil(math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2))
end
---@diagnostic disable-next-line: duplicate-set-field
WQS_Shared.PickRandomObjFromTable2 = function(t)
    --local rr = ZombRand(#t) + 1
    --return t[rr]
    local rr = math.random(1, #t)
    print(rr)
    return t[rr]
end


--local f=WQS_RepeaterData["Rosewood"][1].x
--print("sss2 "..tostring(f))
--print("sss "..tostring(rr))

--print(WQS_Shared.Dump(WQS_RepeaterData))
print("---------")

function RemoveRepeatersTooCloseToExtrPoints()
    --escludo le posizioni dei repeater troppo vicini ai punti di estrazione
    for pkey, pdata in pairs(WQS_ExtractionPointsData) do
        --print(pdata.MapItem)
        if pdata and pdata.MapCenterAreaX then
            for rkey, repeater in pairs(WQS_RepeaterData) do
                local dist = WQS.getDistance(repeater.x, repeater.y, pdata.MapCenterAreaX, pdata.MapCenterAreaY)
                if dist < 130 then
                    print("removing "..pdata.MapItem .. "->" .. repeater.name .. " distance " .. dist)
                    WQS_RepeaterData[rkey] = nil
                end
            end
        end
    end
end

function PickRandomRepeaterPosition(OtherRepeaterList)
    local pick
    local ret = {}
    local isOk = false
    local isGoodPick = true
    local dist=0
    if OtherRepeaterList then
        local fail=0
   
        while not (isOk) do
            pick = WQS_Shared.PickRandomObjFromTableIfNotNil(WQS_RepeaterData)
            isGoodPick = true
         
            for key, rep in pairs(OtherRepeaterList) do
                dist = WQS.getDistance(pick.x, pick.y, rep.x, rep.y)
                --print("dist "..dist)
                local mindist=380*#OtherRepeaterList
                if fail>20 then
                    mindist=100
                    print((fail+1).."=cf reset dist to 100>"..dist)
                end
   
                if (pick.x == rep.x and pick.y == rep.y) or (dist<mindist) then                    
                    --ret=PickRandomRepeaterPosition(OtherRepeaterList)
                    isGoodPick = false
                    if dist>0 then
                        print((fail+1).."=cf NOT isGoodPick " .. pick.x .. "=" .. rep.x.." d="..dist.."<"..mindist)  
                        fail=fail+1                                          
                    end
                else
                    --print("Goodpick! "..dist)                 
                end
            end
            if (isGoodPick) then
                --print("dist="..dist)
                isOk = true
                ret = pick
                fail=0
            end
            if fail>50 then
                isOk = true
                print(" ERROR PickRandomRepeaterPosition too many failed pick")   
            end
        end
    else
        ret = WQS_Shared.PickRandomObjFromTableIfNotNil(WQS_RepeaterData)
        print(" r= " .. tostring(ret))
    end
    return ret
end

--https://stackoverflow.com/questions/49625463/lua-sort-array-by-key-values
RemoveRepeatersTooCloseToExtrPoints()
--print(WQS_Shared.Dump(WQS_RepeaterData))
--local r1 = PickRandomRepeaterPosition()
local my = { 
   -- { x = 11687, y = 8367 }, { x = 8219, y = 11841 },  
   -- { x = 10694, y = 10103 }, { x = 5464, y = 9511 },  
    --{ x = 9118, y = 11814 }, { x = 11655, y = 9985 } 
} --Molans Used Cars, Military Store,Army Quarter,Railyard
for ki = 1, 10000, 1 do
for i = 1, 4, 1 do
    local r1 = PickRandomRepeaterPosition(my)
    table.insert(my,r1)
    print(i..") ret=" .. WQS_Shared.Dump(r1.area.." "..r1.name))
end
my = {}
print(ki.." ----------")
end
-- local r1 = PickRandomRepeaterPosition(my)
-- print(WQS_Shared.Dump(r1.name))
