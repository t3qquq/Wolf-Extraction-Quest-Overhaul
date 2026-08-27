function WQS_ExtractionItem_context(player, context, items)
	local playerObj = WQS.GetCurrentPlayer(player)
	local containerList = ISInventoryPaneContextMenu.getContainers(playerObj)
	local testItem = nil;
	local editItem = nil;
	for i, v in ipairs(items) do
		testItem = v;
		if not instanceof(v, "InventoryItem") then
			--print(#v.items);
			if #v.items == 2 then
				editItem = v.items[1];
			end
			testItem = v.items[1];
		else
			editItem = v
		end
	end
	--print("----aaa "..tostring(testItem:getType()))

	if ((testItem) and (testItem:getType() == WQS_Shared.getExtractionItemId())) then
		local ComposedStat = WQS.ComposeExtractionStatsTxt(playerObj)

		if WQS_Shared.TableIsEmptyOrNil(ComposedStat) then
			print(" WQS ERROR ComposedStat")
			return nil
		end

		local data = {}
		data = ComposedStat.data

		--local option = context:addOption(MainLabel,player,WQS_GPSWindowToggle);
		local option = context:addOption(ComposedStat.MainLabel);

		local subMenu = context:getNew(context)
		context:addSubMenu(option, subMenu)

		local subOption_first = nil
		local subOption_OpenGui = subMenu:addOption(getText("IGUI_WQS_GuiTitle"), player, WQS_OpenTrackerGui)

		--print("QuestNotStarted="..tostring(data.QuestNotStarted))
		if data.QuestNotStarted then
			local line = subMenu:addOption(ComposedStat.NeedContactHQToStartQuestTxt)
			line.notAvailable = true
			return
		end

		if (WQS.CurrentStateIs("EXTRACTION_CAN_BE_STARTED")) then
			subOption_first = subMenu:addOption(ComposedStat.ReqExtractionLabel, player, WQS.BeginExtraction)
		elseif (WQS.CurrentStateIs("EXTRACTION_CAN_BE_COMPLETED")) then
			subOption_first = subMenu:addOption(ComposedStat.CompleteExtractionLabel, player, WQS.CompleteExtraction)
		end

		if (not (ComposedStat.data.CanRequestExtraction) and (subOption_first)) then
			subOption_first.notAvailable = true
		end


		-- local bullet=" >"
		-- local line=subMenu:addOption("--------")
		-- line.notAvailable = true
		-- if ComposedStat.data.SignalHoursLeft_isok then				

		-- 	subMenu:addOption(bullet..ComposedStat.DistanceLabel)
		-- 	subMenu:addOption(bullet..ComposedStat.ZlevelLabel)

		-- 	if (ComposedStat.data.HoursLeft_IsEnabled) then
		-- 		subMenu:addOption(bullet..ComposedStat.HoursLeftLabel)
		-- 	end

		-- else
		-- 	subMenu:addOption(bullet..ComposedStat.SignalHoursLeftLabel)	
		-- end
		-- line=subMenu:addOption("--------")
		-- line.notAvailable = true
	end

	--context:addOption(getText("Set Waypoint Manually"), player, SetGPSCode, canWaypoint );
end

Events.OnPreFillInventoryObjectContextMenu.Add(WQS_ExtractionItem_context)

local function OpenTrackerGui_context(player, context, worldObjects)
	context:addOption(getText("IGUI_WQS_GuiTitle"), worldObjects, WQS_OpenTrackerGui)
	--context:addOption("Sandbox Options", worldObjects,function() changesandboxoptions(26) end)
end
Events.OnFillWorldObjectContextMenu.Add(OpenTrackerGui_context)
