--require "ISUI/ISPanel"

require "ISUI/ISCollapsableWindow"

WQSGuiUtils = {}

WQS_AntennaGui = ISCollapsableWindow:derive("WQS_AntennaGui");
WQS_AntennaGui.instance = nil;

local function roundstring(_val)
    return tostring(WQSGuiUtils.roundNum(_val, 2));
end


function WQS_AntennaGui.OnOpenPanel()
    if WQS_AntennaGui.instance == nil then
        local HQGuititle = getText("IGUI_WQS_AntennaMainLabel") or "Antenna"
        local fsize = getCore():getOptionFontSize()
        --local ww=790+tonumber(fsize)*45
        local ww = 850
        if (fsize == 2) then
            ww = ww + 80
        end
        if (fsize == 3) then
            ww = ww + 160
        end
        if (fsize == 4) then
            ww = ww + 280
        end
        WQS_AntennaGui.instance = WQS_AntennaGui:new(ww, 560, HQGuititle);
        WQS_AntennaGui.instance:initialise();
        WQS_AntennaGui.instance:instantiate();
    end

    WQS_AntennaGui.instance:addToUIManager();
    WQS_AntennaGui.instance:setVisible(true);

    return WQS_AntennaGui.instance;
end

function WQS_AntennaGui:initialise()
    ISCollapsableWindow.initialise(self);

    self.firstTableName = false;
end

function WQS_AntennaGui:createChildren()
    ISCollapsableWindow.createChildren(self);
    local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
    local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.NewMedium)
    local col = { one = 26, two = 46, three = 28 }
    local row = { one = 13, two = 95 }

    -- local AlternativeRichFullGuiScreen=WQSGuiUtils.addRichTextPanel(self, "AlternativeRichFullGuiScreen", self.cfg.padL, self.cfg.padT,WQSGuiUtils.calcW(self,0,100),WQSGuiUtils.calcH(self,0,100))
    -- self.AlternativeRichFullGuiScreen=AlternativeRichFullGuiScreen

    local rich1 = WQSGuiUtils.addRichTextPanel(self, " <CENTRE> <SIZE:large> Antenna ", self.cfg.padL, self.cfg.padT,
        WQSGuiUtils.calcW(self, 0), WQSGuiUtils.calcH(self, 0, row.one))

    --self.tableNamesList = ISScrollingListBox:new(10, 50, 200, self.height - 100);

    local sy = rich1.height + self.cfg.padT + self.cfg.spacing
    --print("rich "..tostring(rich1.height))
    --rich1:setVisible(false);
    self.richHeader = rich1

    self.tableNamesList = ISScrollingListBox:new(self.cfg.padL, sy, WQSGuiUtils.calcW(self, 0, col.one),
        WQSGuiUtils.calcH(self, 50, row.two));
    self.tableNamesList:initialise();
    self.tableNamesList:instantiate();
    self.tableNamesList.itemheight = FONT_HGT_MEDIUM + 0; --22
    self.tableNamesList.selected = 0;
    self.tableNamesList.joypadParent = self;
    --self.tableNamesList.font = UIFont.NewSmall;
    self.tableNamesList.font = UIFont.NewMedium;
    self.tableNamesList.doDrawItem = self.drawTableNameList;
    self.tableNamesList.drawBorder = true;
    self.tableNamesList.onmousedown = WQS_AntennaGui.OnTableNamesListMouseDown;
    self.tableNamesList.target = self;

    self:addChild(self.tableNamesList);

    --local scx=self.cfg.padL+WQSGuiUtils.calcW(self,0,30)+self.cfg.padL
    local scx = self.cfg.padL + self.tableNamesList.width + self.cfg.spacing
    local wwsp = WQSGuiUtils.calcW(self, self.cfg.padL, col.two)


    --sy=sy+rich2.height+self.cfg.spacing
    self.infoList = ISScrollingListBox:new(scx, sy, wwsp, WQSGuiUtils.calcH(self, 50, row.two));
    self.infoList:initialise();
    self.infoList:instantiate();
    self.infoList.itemheight = FONT_HGT_SMALL + 4; --22;
    self.infoList.selected = 0;
    self.infoList.joypadParent = self;
    self.infoList.font = UIFont.NewSmall;
    self.infoList.doDrawItem = self.drawInfoList;
    self.infoList.drawBorder = true;
    self.infoList.onmousedown = WQS_AntennaGui.OnInfoListMouseDown;
    self.infoList.target = self;
    self.infoList.SelectedData = nil;

    self:addChild(self.infoList);

    local scx2 = scx + self.infoList.width + self.cfg.spacing
    local wwsp2 = WQSGuiUtils.calcW(self, self.cfg.padL, col.three)
    local txtf = ""
    local rich2 = WQSGuiUtils.addRichTextPanel(self, txtf, scx2, sy, wwsp2, WQSGuiUtils.calcH(self, 50, row.two))
    self.richDescCol = rich2

    local buty = sy + self.infoList.height + self.cfg.spacing

    local ButReqNewExtrPoint = WQSGuiUtils.addButton(self, "ButReqNewExtrPoint", scx, buty, wwsp, FONT_HGT_SMALL + 8,
        getText("IGUI_WQS_AntennaReqNewExtractionPoint"), WQS_AntennaGui.onClickMainActionBut);
    self.ButReqNewExtrPoint = ButReqNewExtrPoint

    local closebut = WQSGuiUtils.addButton(self, "close", scx2, buty, wwsp2, FONT_HGT_SMALL + 8,
        getText("IGUI_WQS_CloseLabel"), WQS_AntennaGui.onClickClose, nil, WQS_Shared.BorderColor5);
    --local y, obj = WQSGuiUtils.addButton(self,"close",self.width-(180+self.cfg.padR),buty,180,20,getText("IGUI_CraftUI_Close"),WQS_AntennaGui.onClickClose);

    self:populateList();
end

function WQS_AntennaGui:onClickMainActionBut()
    --self:close();
    -- print("onClickMainActionBut "..self.infoList.SelectedData.MapItem.." rnd opt="..self.infoList.SelectedData.RandomZoneOpt)
    --print("onClickMainActionBut "..tostring(self.infoList.SelectedData.RandomZoneOpt))
    local selData = self.infoList.SelectedData
    if (selData) and (selData.MapItem) and (selData.RandomZoneOpt) then
        WQS.setCurretExtractionMap(selData.MapItem, selData.RandomZoneOpt)
        WQS.SetQuestAsStarted()
        self:close();
        local ln = " <LINE> "
        local cmap = WQS.getExtractionData(WQS.getCurretExtractionMap())
        local MapLabel = ""
        if (cmap) and (cmap.MapGuiLabel) then
            MapLabel = cmap.MapGuiLabel
        end
        local NewExtrDone = getText("IGUI_WQS_ReqNewExtractionPointDone") .. ln .. MapLabel .. ln
        local MapCraftInfo = getText("IGUI_WQS_ExtractionMapCraftInfo")
        local txtfinal = ln .. " <CENTRE> <H1> " .. NewExtrDone .. " <H2> <CENTRE> " .. ln .. ln .. MapCraftInfo .. ln
        WQS_ModalWin(txtfinal, nil, 400, 250)
    end
end

function WQS_AntennaGui:onClickClose()
    self:close();
end

function WQS_AntennaGui:onClickRefresh()
    self:populateList();
end

-- function WQS_AntennaGui:setHeader(_self,header_txt)
--     _self.richHeader.text=" <H1> <CENTRE> "..header_txt
--     _self.richHeader:paginate();
-- end

function WQS_AntennaGui:OnTableNamesListMouseDown(item)
    self:populateInfoList(item);
end

function WQS_AntennaGui:OnInfoListMouseDown(item)
    local SelectedData = { MapItem = nil, RandomZoneOpt = nil }
    local coldesc = ""

    if item == "#header#" then
        self.ButReqNewExtrPoint.title = ""
        coldesc = " <H2> <CENTRE> " .. getText("IGUI_WQS_ReqNewExtractionPointDesc")
        WQS_AntennaGui:setDescCol(self, coldesc)
        self.infoList.SelectedData = SelectedData
        return
    end
    --print("item " .. tostring(item))

    local MapData = {}
    if WQS.ExtractionDataExist(item) then
        --print("ExtractionDataExist for" .. item)
        MapData = WQS.getExtractionData(item)
    end
    if (item and MapData and not (WQS_Shared.TableIsEmptyOrNil(MapData))) then
        --print("MapData is valid")
        local newExtrTarget = MapData.MapGuiLabel or "---"
        self.ButReqNewExtrPoint.title = getText("IGUI_WQS_SetExtractionToBut") .. " " .. newExtrTarget

        local pl = WQS.GetCurrentPlayer();
        local distance = -1
        if pl then
            distance = WQS.getDistance(pl:getX(), pl:getY(), MapData.MapCenterAreaX, MapData.MapCenterAreaY);
        end

        coldesc = " <H2> <CENTRE> " ..
            getText("IGUI_WQS_ReqNewExtractionPointDesc") ..
            " <LINE> <LINE> <H1> " ..
            newExtrTarget .. " <LINE> <SIZE:small> " .. getText("IGUI_WQS_Distance") .. ": " .. distance .. "m"
        WQS_AntennaGui:setDescCol(self, coldesc)

        SelectedData = { MapItem = MapData.MapItem, RandomZoneOpt = "fixed" }
    elseif item == "random_all_zones" then
        self.ButReqNewExtrPoint.title = getText("IGUI_WQS_RandomOpt1")
        coldesc = " <H2> <CENTRE> " ..
            getText("IGUI_WQS_ReqNewExtractionPointDesc") .. " <LINE> <LINE> <H1> " .. getText("IGUI_WQS_RandomOpt1")
        WQS_AntennaGui:setDescCol(self, coldesc)
        SelectedData = { MapItem = "random", RandomZoneOpt = item }
    elseif item == "random_only_louisville" then
        self.ButReqNewExtrPoint.title = getText("IGUI_WQS_RandomOpt2")
        coldesc = " <H2> <CENTRE> " ..
            getText("IGUI_WQS_ReqNewExtractionPointDesc") .. " <LINE> <LINE> <H1> " .. getText("IGUI_WQS_RandomOpt2")
        WQS_AntennaGui:setDescCol(self, coldesc)
        SelectedData = { MapItem = "random", RandomZoneOpt = item }
    elseif item == "random_excluding_louisville" then
        self.ButReqNewExtrPoint.title = getText("IGUI_WQS_RandomOpt3")
        coldesc = " <H2> <CENTRE> " ..
            getText("IGUI_WQS_ReqNewExtractionPointDesc") .. " <LINE> <LINE> <H1> " .. getText("IGUI_WQS_RandomOpt3")
        WQS_AntennaGui:setDescCol(self, coldesc)
        SelectedData = { MapItem = "random", RandomZoneOpt = item }
    else
        self.ButReqNewExtrPoint.title = ""
        coldesc = " <H2> <CENTRE> " .. getText("IGUI_WQS_ReqNewExtractionPointDesc")
        WQS_AntennaGui:setDescCol(self, coldesc)
    end
    self.infoList.SelectedData = SelectedData
end

function WQS_AntennaGui:populateList()
    self.tableNamesList:clear();
    local rnep

    if WQS_Shared.IsActiveRepeatersMode() then
        if WQSAntenna.isSignalActiveAndStrong() then
            rnep = getText("IGUI_WQS_ContactHQ") or "Headquarter Operations"
            self.tableNamesList:addItem(rnep, "ReqNewExtrPoint");
            self:populateInfoList("ReqNewExtrPoint");
        else
            self:populateInfoList("RepeaterMode");
        end
        rnep = getText("IGUI_WQS_AntennaRepeaterMode") or "Repeater Mode"
        self.tableNamesList:addItem(rnep, "RepeaterMode");
    else
        rnep = getText("IGUI_WQS_ContactHQ") or "Headquarter Operations"
        self.tableNamesList:addItem(rnep, "ReqNewExtrPoint");
        self:populateInfoList("ReqNewExtrPoint");
    end

    --self.tableNamesList:addItem("Request new extraction point1", "ReqNewExtrPoint1");
    --self:populateInfoList("ReqNewExtrPoint");
end

function WQS_AntennaGui:drawTableNameList(y, item, alt)
    local a = 0.9;
    local bh = 10
    bh = getTextManager():getFontHeight(self.font)

    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1 + bh, a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b);

    if self.selected == item.index then
        --self:drawRect(0, (y), self:getWidth(), self.itemheight - 1+bh, 0.3, 0.7, 0.35, 0.25);
        --self:drawRect(0, (y), self:getWidth(), self.itemheight - 1+bh, 0.8, 0.26, 0.5, 0.93);
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1 + bh, 0.8, 0.13, 0.52, 0.82);
        --self:drawRect(0, (y), self:getWidth(), self.itemheight - 1+bh, HCR, HCG, HCB, 1);
    end

    self:drawText(item.text, 10, y + bh / 2 - 1, 1, 1, 1, a, self.font);

    return y + self.itemheight + bh;
end

function WQS_AntennaGui:setHeader(_self, header_txt)
    _self.richHeader.text = " <H1> <CENTRE> " .. header_txt
    _self.richHeader:paginate();
end

function WQS_AntennaGui:OnClickToggleRepeaterMode()
    --print("ToggleRepeaterMode")
    WQSAntenna.ToggleRepeaterMode()

    if WQSAntenna.CurrentAntennaIsRepeater() then
        self.ButReqNewExtrPoint.title = getText("IGUI_WQS_AntennaDeactivateRepeaterMode")
    else
        self.ButReqNewExtrPoint.title = getText("IGUI_WQS_AntennaActivateRepeaterMode")
    end
    self:populateInfoList("RepeaterMode");
    self:close();
end

function WQS_AntennaGui:setDescCol(_self, dctxt)
    _self.richDescCol.text = dctxt
    _self.richDescCol:paginate();
end

function WQS_AntennaGui:populateInfoList(_name)
    self.infoList:clear();
    WQS_AntennaGui:setHeader(self, "")

    if not _name then
        self.infoList:addItem("No data.", nil);
        return;
    end
    --print("Attempting to draw table = "..tostring(_name));

    if _name == "ReqNewExtrPoint" then
        local rnep = getText("IGUI_WQS_ContactHQ") or "Headquarter Operations"
        local CurretExtractionMap = WQS.getCurretExtractionMap()
        local MapData = WQS.getExtractionData(CurretExtractionMap)
        local current = "---"
        self.ButReqNewExtrPoint:setVisible(true)

        --print("ReqNewExtrPoint")
        if (MapData and MapData.MapGuiLabel) then
            current = MapData.MapGuiLabel
        end

        if not (WQS.QuestNotStarted()) then
            local CurExtrLabel = getText("IGUI_WQS_CurrentExtrZone") or "Current Extraction Zone"
            WQS_AntennaGui:setHeader(self, rnep .. " <LINE> <SIZE:small> (" .. CurExtrLabel .. ": " .. current .. ")")
        else
            WQS_AntennaGui:setHeader(self, rnep)
        end

        --WQS_AntennaGui:setHeader(self,rnep.." <LINE> <SIZE:small> ("..current..")")
        --self.infoList:addItem("ReqNewExtrPoint....."..tostring(_name), nil);
        --self.richDescCol.text=" <H2> <CENTRE> "..getText("IGUI_WQS_ReqNewExtractionPointDesc")
        WQS_AntennaGui:setDescCol(self, " <H2> <CENTRE> " .. getText("IGUI_WQS_ReqNewExtractionPointDesc"))

        self.infoList.doDrawItem = self.drawInfoList;
        self.infoList.onmousedown = WQS_AntennaGui.OnInfoListMouseDown;
        self.ButReqNewExtrPoint:setOnClick(WQS_AntennaGui.onClickMainActionBut)
        self.ButReqNewExtrPoint.title = getText("IGUI_WQS_AntennaReqNewExtractionPoint")


        self.infoList:addItem(getText("IGUI_WQS_AntennaReqNewExtractionPoint"), "#header#");
        self.infoList:addItem(getText("IGUI_WQS_RandomOpt1"), "random_all_zones");
        self.infoList:addItem(getText("IGUI_WQS_RandomOpt2"), "random_only_louisville");
        self.infoList:addItem(getText("IGUI_WQS_RandomOpt3"), "random_excluding_louisville");
        local riga = self.infoList:addItem("-------", nil);
        self.infoList.selected = riga.itemindex

        local added_item
        for k, v in pairs(WQS_ExtractionPointsData) do
            local mapLabel = WQS_ExtractionPointsData[k].MapGuiLabel
            local mapItemId = WQS_ExtractionPointsData[k].MapItem
            local mapX = WQS_ExtractionPointsData[k].MapCenterAreaX
            --print(mapLabel,mapItemId,mapX)
            if ((mapLabel) and (mapItemId) and not (mapX == 0)) then
                if WQS_Shared.IsModdedMap(mapItemId) then
                    mapLabel = mapLabel .. " (M)"
                end
                added_item = self.infoList:addItem(mapLabel, mapItemId);
                -- if (mapItemId==CurretExtractionMap) then
                --     self.infoList.selected=added_item.itemindex
                -- end
            end
        end
    elseif _name == "RepeaterMode" then
        local rnep = getText("IGUI_WQS_AntennaRepeaterMode")
        local repLabel = getText("IGUI_WQS_Zone") or "Zone"
        local repActiveLabel = getText("IGUI_WQS_AntennaRepeaterActive") or "Repeater Currently Active"
        WQS_AntennaGui:setHeader(self, rnep)

        self.ButReqNewExtrPoint:setVisible(true)
        --self.infoList.height=150
        self.infoList.doDrawItem = self.drawInfoListNotSelectable
        self.infoList.onmousedown = nil;
        self.infoList:addItem(repActiveLabel, "#header#");
        self.ButReqNewExtrPoint:setOnClick(WQS_AntennaGui.OnClickToggleRepeaterMode)
        self.infoList.SelectedData = nil

        local repColDesc = ""
        --repColDesc = " <H2> <CENTRE> " .. getText("IGUI_WQS_KnownRepeaterLocations") .. " <LINE> "
        --repColDesc = repColDesc ..WQSAntenna.getNumOfKnownRepeaterLocation() .. "/" .. WQSAntenna.getMaxNumOfTargetRepeaters()

        local lb = " <LINE> "
        local hr = " ---------------- "
        local knownRepLoc = getText("IGUI_WQS_KnownRepeaterLocations") or "Known Repeater Locations"
        local signalStrLabel = getText("IGUI_WQS_SignalStrenghtLabel") or "Signal Strenght"
        local collectFragmentAdvice = getText("IGUI_WQS_CollectFragmentAdvice")
        local activeRep = WQSAntenna.getNumOfActiveRepeaters()
        local neededRep = WQSAntenna.getMaxNumOfTargetRepeaters()
        local qStat = lb ..
            WQSAntenna.getNumOfKnownRepeaterLocation() .. "/" .. WQSAntenna.getMaxNumOfTargetRepeaters()
        local ret = " <SIZE:small> " --<ORANGE> <INDENT:20> <RGB:1,1,1> ???
        ret = ret .. " <H2> <CENTRE> " .. knownRepLoc .. " " .. qStat .. "  <SIZE:small>  <LINE> "

        if (WQSAntenna.getNumOfKnownRepeaterLocation() < neededRep) then
            ret = ret .. " <LINE> <SIZE:small> " .. collectFragmentAdvice
        else
            ret = ret .. " <LINE> <SIZE:small> " .. getText("IGUI_WQS_HaveAllTargetAntennaRepeaterLocations")
        end
        ret = ret .. lb .. lb .. hr .. lb .. lb ..
            " <H2> <CENTRE> " .. signalStrLabel .. lb .. activeRep .. "/" .. neededRep .. "  <SIZE:small>  <LINE> "

        if activeRep < neededRep then
            ret = ret .. " <LINE> <SIZE:small> " .. getText("IGUI_WQS_AntennaRepeatersNeedMoreDet")
        end
        repColDesc = ret

        WQS_AntennaGui:setDescCol(self, repColDesc)

        if WQSAntenna.CurrentAntennaIsRepeater() then
            self.ButReqNewExtrPoint.title = getText("IGUI_WQS_AntennaDeactivateRepeaterMode")
        elseif (WQSAntenna.isCurrentAntennaActivableAsRepeater()) then
            self.ButReqNewExtrPoint.title = getText("IGUI_WQS_AntennaActivateRepeaterMode")
        else
            self.ButReqNewExtrPoint:setVisible(false)
        end
        --self.ButReqNewExtrPoint.title=getText("IGUI_WQS_AntennaActivateRepeaterMode")
        --self.ButReqNewExtrPoint.title=getText("IGUI_WQS_AntennaDeactivateRepeaterMode")

        --WQS_AntennaGui:setDescCol(self," <H2> <CENTRE> "..getText("IGUI_WQS_ReqNewExtractionPointDesc"))

        local ActiveRepeaterList = WQSAntenna.CheckStatusOfRepeaters()
        --print("ActiveRepeaterList "..WQS_Shared.Dump(ActiveRepeaterList))
        if (ActiveRepeaterList) then
            for k, v in pairs(ActiveRepeaterList) do
                local Rep = ActiveRepeaterList[k]
                local RepId = tostring(k)
                local RepItemName = "    -> " .. repLabel .. " " .. RepId .. " (" .. Rep.x .. "," .. Rep.y .. ")"

                local tryActivate = WQSAntenna.FindTargetRepeaterForThisCoords(Rep.x, Rep.y)
                --print(WQS_Shared.Dump(tryActivate));
                if tryActivate and not (WQS_Shared.TableIsEmptyOrNil(tryActivate)) and tryActivate.area then
                    RepItemName = "    -> " .. repLabel .. ": " .. tryActivate.area .. " " .. tryActivate.name
                end

                self.infoList:addItem(RepItemName, RepId);
            end
        end
    else
        WQS_AntennaGui:setHeader(self, "Option not implemented")
        self.infoList:addItem("Table not found." .. tostring(_name), nil);
    end
end

function WQS_AntennaGui:drawInfoList(y, item, alt)
    local a = 0.9;
    local bh = 4
    local font = self.font


    if self.selected == item.index and not (item.item == "#header#") then
        -- self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15);
        --self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.25, 0.42, 0.63, 1);
        --self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.41, 0.59, 0.85, 1);
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1 + bh, 0.8, 0.26, 0.5, 0.93);
    end

    if item.item == "#header#" then
        font = UIFont.NewMedium;
        bh = getTextManager():getFontHeight(font) + 2
        --self:drawRect(0, (y), self:getWidth(), self.itemheight - 1+bh, 0.8, 0.26, 0.5, 0.93);
        --self:drawRect(0, (y), self:getWidth(), self.itemheight - 1+bh, 0.8, 0.13, 0.52, 0.82);
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1 + bh, 0.8, 0.25, 0.42, 0.63);
        self:drawText(item.text, 10, y + bh / 2 - 1, 1, 1, 1, a, font);
    else
        self:drawText(item.text, 10, y + bh / 2 + 1, 1, 1, 1, a, font);
        self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1 + bh, a, self.borderColor.r, self.borderColor.g,
            self.borderColor.b);
    end

    --self:drawText( item.text, 10, y + bh/2+1, 1, 1, 1, a, self.font);

    return y + self.itemheight + bh;
end

function WQS_AntennaGui:drawInfoListNotSelectable(y, item, alt)
    local a = 0.9;
    local bh = 6
    local font = self.font

    if item.item == "#header#" then
        font = UIFont.NewMedium;
        bh = getTextManager():getFontHeight(font) + 2
        --bh=10
        --self:drawRect(0, (y), self:getWidth(), self.itemheight - 1+bh, 0.8, 0.26, 0.5, 0.93);
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1 + bh, 0.8, 0.25, 0.42, 0.63);
        self:drawText(item.text, 10, y + bh / 2 - 1, 1, 1, 1, a, font);
    else
        self:drawText(item.text, 10, y + bh / 2 + 1, 1, 1, 1, a, font);
    end

    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1 + bh, a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b);




    --print(WQS_Shared.Dump(item))
    return y + self.itemheight + bh;
end

function WQS_AntennaGui:prerender()
    ISCollapsableWindow.prerender(self);
    --self:populateList();
end

function WQS_AntennaGui:update()
    ISCollapsableWindow.update(self);
end

function WQS_AntennaGui:close()
    self:setVisible(false);
    self:removeFromUIManager();
    WQS_AntennaGui.instance = nil
end

function WQS_AntennaGui:new(width, height, title)
    local o = {};

    local x = getCore():getScreenWidth() * 0.5 - width * 0.5;
    local y = getCore():getScreenHeight() * 0.5 - height * 0.5;
    --o = ISPanel:new(x, y, width, height);
    o = ISCollapsableWindow:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;
    o.variableColor = { r = 0.9, g = 0.55, b = 0.1, a = 1 };
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 };
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 };
    o.buttonBorderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 };
    o.zOffsetSmallFont = 25;
    o.pin = true;
    o.resizable = true;
    o.title = title;
    --o.cfg = {padL=10,padT=25,padR=10,padB=18};
    local headwinsize = getTextManager():MeasureStringY(UIFont.AutoNormMedium, "You") + 10
    o.cfg = { padL = 10, padT = headwinsize, padR = 10, padB = 50, spacing = 10 }; --padT=25

    return o;
end

--WQS_AntennaGui.OnOpenPanel()



---utils gui
function WQSGuiUtils.calcW(_self, startx, perc)
    _self.cfg.padR = _self.cfg.padR or _self.cfg.padL
    perc = perc or 100
    perc = perc / 100
    local ww = math.floor((_self:getWidth() - (_self.cfg.padL + _self.cfg.padR)) * perc)
    ww = ww - startx
    --print("ww "..ww.." getWidth=".._self:getWidth().." padL=".._self.cfg.padL.." perc="..perc)
    return ww
end

function WQSGuiUtils.calcH(_self, starty, perc)
    _self.cfg.padB = _self.cfg.padB or (_self.cfg.padT / 2) + 5
    perc = perc or 100
    perc = perc / 100
    local ww = math.floor((_self:getHeight() - (_self.cfg.padT + _self.cfg.padB)) * perc)
    ww = ww - starty
    --print("hh "..ww.." getHeight=".._self:getHeight().." padT=".._self.cfg.padT.." padB=".._self.cfg.padB.." perc="..perc)
    return ww
end

function WQSGuiUtils.okModal(_text, _centered, _width, _height, _posX, _posY)
    local posX = _posX or 0;
    local posY = _posY or 0;
    local width = _width or 230;
    local height = _height or 120;
    local centered = _centered;
    local txt = _text;
    local core = getCore();

    -- center the modal if necessary
    if centered then
        posX = core:getScreenWidth() * 0.5 - width * 0.5;
        posY = core:getScreenHeight() * 0.5 - height * 0.5;
    end

    local modal = ISModalDialog:new(posX, posY, width, height, txt, false, nil, nil);
    modal:initialise();
    modal:addToUIManager();
end

--projectzomboid/media/lua/client/ISUI/ISButton.lua
function WQSGuiUtils.addButton(_self, _data, _x, _y, _w, _h, _title, _func, bgc, bordc, bgchover)
    local button = ISButton:new(_x, _y, _w, _h, _title, _self, _func);
    --ISButton:setTitle(title)
    --ISButton:setEnable(bEnabled)
    --button.textColor={r=0.5, g=0.5, b=1, a=0.7}
    bgc = bgc or WQS_Shared.BGColor
    bordc = bordc or WQS_Shared.BorderColor
    bgchover = bgchover or WQS_Shared.BGColorMouseOver

    button:initialise();
    button.backgroundColor = bgc;
    button.backgroundColorMouseOver = bgchover;
    button.borderColor = bordc;
    button.customData = _data;
    _self:addChild(button);
    return button;
end

function WQSGuiUtils.addComboBox(_self, _data, _x, _y, _w, _font, _func)
    local FONT_HGT = getTextManager():getFontHeight(_font);
    local comboBox = ISComboBox:new(_x, _y, _w, FONT_HGT, _self, _func);
    comboBox:initialise();
    comboBox.customData = _data;
    _self:addChild(comboBox);
    return comboBox:getY() + comboBox:getHeight(), comboBox;
end

function WQSGuiUtils.addTextEntryBox(_self, _data, _title, _x, _y, _w, _h)
    local entryBox = ISTextEntryBox:new(_title, _x, _y, _w, _h);
    entryBox:initialise();
    entryBox:instantiate();
    entryBox:setText("");
    entryBox.customData = _data;
    _self:addChild(entryBox);
    return entryBox:getY() + entryBox:getHeight(), entryBox;
end

function WQSGuiUtils.addLabel(_self, _data, _x, _y, _title, _font, _bLeft)
    local FONT_HGT = getTextManager():getFontHeight(_font);
    local label = ISLabel:new(_x, _y, FONT_HGT, _title, 1, 1, 1, 1.0, _font, _bLeft == nil and true or _bLeft);
    label:initialise();
    label:instantiate();
    label.customData = _data;
    _self:addChild(label);
    return label:getY() + label:getHeight(), label;
end

function WQSGuiUtils.addTickBox(_self, _data, _x, _y, _w, _h, _title, options, _func)
    local tickBox = ISTickBox:new(_x, _y, _w, _h, _title, _self, _func);
    tickBox.choicesColor = { r = 1, g = 1, b = 1, a = 1 };
    tickBox.backgroundColor = { r = 0, g = 0, b = 0, a = 0 };
    tickBox:initialise();
    tickBox:instantiate();
    tickBox.customData = _data;
    -- Must addChild *before* addOption() or ISUIElement:getKeepOnScreen() will restrict y-position to screen height
    _self:addChild(tickBox);
    for k, v in ipairs(options) do
        tickBox.selected[1] = v.ticked;
        tickBox:addOption(v.text);
    end
    return tickBox:getY() + tickBox:getHeight(), tickBox;
end

function WQSGuiUtils.addSlider(_self, _data, _x, _y, _w, _h, _func)
    local slider = ISSliderPanel:new(_x, _y, _w, _h, _self, _func);
    slider:initialise();
    slider:instantiate();
    slider.valueLabel = false;
    slider.customData = _data;
    _self:addChild(slider);
    return slider:getY() + slider:getHeight(), slider;
end

function WQSGuiUtils.addRichTextPanel(_self, _data, _x, _y, _w, _h, _func)
    _data = _data or ""
    _func = _func or nil

    --print("RichTextPanel ".._x..",".. _y.." w=".. _w.." h=".. _h)
    local richtext = nil

    richtext = ISRichTextPanel:new(_x, _y, _w, _h, _data, false, nil, _func);
    richtext:initialise();
    richtext:instantiate();

    richtext.text = _data

    --richtext:setAnchorBottom(true);
    --richtext:setAnchorRight(true);
    richtext:setAnchorTop(true);
    richtext:setAnchorLeft(true);
    --richtext.background = false;
    richtext.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 };
    richtext.drawBorder = true;
    richtext.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    richtext.autosetheight = false;
    --richtext.clip = true
    richtext:addScrollBars();
    richtext:paginate();
    richtext:setMargins(20, 10, 25, 10)

    _self:addChild(richtext);

    return richtext;
end
