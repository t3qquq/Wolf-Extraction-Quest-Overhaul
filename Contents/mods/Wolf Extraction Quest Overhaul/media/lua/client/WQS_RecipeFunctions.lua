WQS_Recipe = {}

--- Number of fragments the "Assemble & update repeater map" recipe eats.
--- Must match WQS_recipe.txt.
WQS_Recipe.FRAGMENTS_PER_REQUEST = 4
WQS_Recipe.PendingTargetRequest = nil

function WQS_Recipe.DrawExtractionMap(recipe, result, player)
    local cmapId = WQS.getCurretExtractionMap()
    if not (cmapId) then
        -- the session has not told us the zone yet
        player:Say(getText("IGUI_WQS_MP_NoZoneYet"))
        return
    end

    if not (WQS_Shared.IsCurretExtractionOnModdedMap()) then
        local inv = player:getInventory();
        local extraction_map = inv:AddItem(tostring(cmapId));
        if extraction_map then
            local cmap = WQS.getExtractionData(cmapId)
            if cmap then
                extraction_map:setName(cmap.MapGuiLabel .. " " .. getText("IGUI_WQS_ExtrMapLabel"))
            end
        end
    else
        player:Say(getText("IGUI_WQS_MP_ModdedMapNoDraw"))
    end
end

--- The recipe has already consumed the fragments by the time this runs, so the
--- client cannot decide anything here on its own. It used to gate on
--- CanAddMoreTargetRepeaters, evaluated against a snapshot up to two seconds
--- old: two members crafting inside that window both saw a free slot, both said
--- "location added", and the server quietly dropped one of the two crafts.
--- Now the session answers, and a refusal refunds the fragments.
function WQS_Recipe.GenerateTargetRepeater(recipe, result, player)
    print("WQS_MP target repeater requested")
    if not (WQS_Shared.IsActiveRepeatersMode()) then
        return
    end

    WQS_Recipe.PendingTargetRequest = player
    WQS_Session.Send("AddRepeaterTarget", {})

    if not (WQS_Shared.HaveItemInInventory(WQS_Shared.getRepeaterDynamicMapItemId(true))) then
        local inv = player:getInventory();
        inv:AddItem(tostring(WQS_Shared.getRepeaterDynamicMapItemId(true)));
    end
end

WQS_Session.OnAddTargetResult = function(ok, args)
    local player = WQS_Recipe.PendingTargetRequest or WQS.GetCurrentPlayer()
    WQS_Recipe.PendingTargetRequest = nil
    if not (player) then
        return
    end

    if ok then
        player:Say(getText("IGUI_WQS_TargetAntennaRepeaterLocationAdded"))
        return
    end

    local reason = args and args.reason or ""
    player:getInventory():AddItems(WQS_Shared.getRepeaterFragmentLocationItemId(true),
        WQS_Recipe.FRAGMENTS_PER_REQUEST)

    if reason == "full" then
        player:Say(getText("IGUI_WQS_HaveAllTargetAntennaRepeaterLocations"))
    else
        player:Say(getText("IGUI_WQS_MP_TargetRequestFailed"))
    end
    print("WQS_MP target request rejected reason=" .. tostring(reason) .. ", fragments refunded")
end

--[[ require "ISUI/ISCollapsableWindow"
require "ISUI/ISCollapsableWindow"


MyUI = ISCollapsableWindow:derive("MyUI");

function MyUI:initialise()
    ISCollapsableWindow.initialise(self);
    self:create();
end

function MyUI:prerender() -- Call before render, it's for harder stuff that need init, ect
    ISCollapsableWindow.prerender(self);
    self:drawText("Hello world",0,0,1,1,1,1, UIFont.Small); -- You can put it in render() too
end

function MyUI:render() -- Use to render text and other
end

function MyUI:create() -- Use to make the elements
end

function MyUI:new(x, y, width, height)
    local o = {};
    o = ISCollapsableWindow:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;

    return o;
end

local myUI = MyUI:new(100, 100, 200, 200);
myUI:initialise();
 ]]


--[[
require "StashDescriptions/StashUtil";

WQS_Recipe = {}



function WQS_Recipe.RequestExtraction(recipe, result, player)
    --player:getInventory():AddItems("Base.BaseballBat", 1)
    --myUI:setVisible(true);
    --myUI:addToUIManager();


    local CurretExtractionMap=WQS.getCurretExtractionMap()
	local MapData=WQS.getExtractionData(CurretExtractionMap)

	if WQS.ThereIsErrorInExtractionData(MapData) then
		print(" #### WQS ERROR MAP INIT: "..MapItemName)
		return false
	end

    local distance = WQS.getDistance(player:getX(), player:getY(), MapData.MapCenterAreaX, MapData.MapCenterAreaY);

    if (distance>MapData.AreaRadiusFromCenter) then
        --player:Say("Too far! "..tostring(distance).." from "..CurretExtractionMap );
        player:Say("Too far from extraction zone! ("..tostring(distance)..")");
    end

    if (not(player:getZ()==MapData.MapCenterAreaZ) and (distance<MapData.AreaRadiusFromCenter*4) )then
        player:Say("The height level is wrong! "..tostring(player:getZ()).." -> "..MapData.MapCenterAreaZ );
    end

    local hours_left=WQS.getHoursLeftToDeadline()
    local in_time=true
    if (hours_left~=false) then
        if (hours_left>=0) then
            local hls=string.format("%.2f", hours_left)
            player:Say(tostring(hls).." hours left to reach extraction zone");
            in_time=true
        else
            player:Say("Too late baby, too late. ")
            in_time=false
        end
    end

    if ( (distance<=MapData.AreaRadiusFromCenter) and (player:getZ()==MapData.MapCenterAreaZ) and (in_time) )then
        player:Say("OK! Requesting Extraction "..tostring(distance).." -> "..CurretExtractionMap );
        testHelicopter();--dovrei fare una funzione simile mia invece di usare quella vanilla?
    end

    --per spawn item segnaposto cerca local newSprite = (IsoObject.new(getCell(), square, sprite_type));	


end

function WQS_Recipe.AskInstructionsExtraction(recipe, result, player)
    player:Say("ask extraction instructions here");


end

function WQS_Recipe.ReadInstructionsExtraction(recipe, result, player)
    player:Say("read extraction instructions here");
    --print(WQS.getExtractionData("WQS_item_list.wqs_map_louisville1").MapItem)
end




 ]]
