PercMult = 1     --tutte le percentuali di drop vengono moltiplicate per questo valore

FragmentPerc = 6 --percentuale base di drop dei frammenti dagli zombie generici

OutfitList = {}
OutfitList['ArmyCamoDesert'] = 22 --percentuale da 1 a 100
OutfitList['ArmyCamoGreen'] = 22
OutfitList['PrivateMilitia'] = 18
OutfitList['Police'] = 10
OutfitList['PoliceState'] = 10
OutfitList['ArmyInstructor'] = 10

OutfitList['Survivalist'] = 8
OutfitList['Survivalist02'] = 8
OutfitList['Survivalist03'] = 8

OutfitList['Ranger'] = 6
OutfitList['PrisonGuard'] = 6
OutfitList['Fireman'] = 5


-- function executed for each zombie death
local function WQSOnZombieDead(zombie)
    --tutte le percentuali di drop vengono moltiplicate per questo valore
    PercMult = SandboxVars.WQS_ItemInZombieLootMultiplier_opt or 1
    FragmentPerc = 3 * PercMult --percentuale base di drop dei frammenti dagli zombie generici
    --in realtà la percentuale reale alla fine è un terzo di quella calcolata qui, quindi di base è 1%
    --dati: kill 600zombie -> 3 frammenti

    local outfit = tostring(zombie:getOutfitName())
    local zombieInventory = zombie:getInventory()
    local itemType = WQS_Shared.getExtractionItemId(true)
    local RepeaterFragmentItemType = WQS_Shared.getRepeaterFragmentLocationItemId(true)
    local isRepMode = WQS_Shared.IsActiveRepeatersMode()
    local myRand

    local check1 = outfit and zombieInventory and itemType

    if (not (check1)) then
        --print("check1 fail")
        return
    end
    --print("outfit "..outfit)
    --print("PercMult=" .. PercMult .. " outfit=" .. outfit .. " frag perc=" .. FragmentPerc);

    if OutfitList[outfit] ~= nil then -- è un outfit giusto!
        local myPerc = OutfitList[outfit] * PercMult
        myRand = ZombRand(101)
        print("PercMult=" ..
            PercMult .. " outfit=" .. outfit .. " frag perc=" .. FragmentPerc .. " roll=" .. myRand .. "<" .. myPerc);
        --print("percentuale per " .. outfit .. "=" .. (myPerc) .. " rand=" .. myRand)
        if (myRand <= myPerc) then
            zombieInventory:AddItem(itemType)
            print("-added " .. itemType .. " outfit=" .. outfit .. "roll" .. myRand .. "<" .. myPerc)
        end

        myRand = ZombRand(101)
        --print(" second rand=" .. myRand)
        if (myRand <= math.ceil(myPerc * 1) and isRepMode) then
            zombieInventory:AddItem(RepeaterFragmentItemType)
            print("RepeaterFragmentItem added " ..
                RepeaterFragmentItemType .. " outfit=" .. outfit .. " zombieInventory " .. tostring(zombieInventory))
        else
            --print("bad luck " .. outfit .. " val" .. myPerc)
        end
    elseif isRepMode then
        myRand = ZombRand(101)
        --print(myRand .. " -> " .. FragmentPerc)
        if ((outfit == "Generic01") or (outfit == "Generic02")) and (myRand <= FragmentPerc) then -- 2.5%
            zombieInventory:AddItem(RepeaterFragmentItemType)
            print("added " ..
                RepeaterFragmentItemType ..
                " outfit=" .. outfit .. " FragmentPerc=" .. FragmentPerc .. " roll=" .. myRand)
        end
    end
end

Events.OnZombieDead.Add(WQSOnZombieDead)


--pl = getPlayer();
--addZombiesInOutfit(pl:getX() + 2 ,pl:getY()+2, 0, 1, 'ArmyCamoDesert', 0)
