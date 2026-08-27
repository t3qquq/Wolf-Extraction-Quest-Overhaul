require "ISUI/ISCollapsableWindow"

WQS_GPSWindow = ISCollapsableWindow:derive("WQS_GPSWindow");
GuiAlreadyCreated = false
LAST_GUI_UPDATE = getTimeInMillis()
FinalPopup = nil
ModalPopup = nil

function WQS_GPSWindow:initialise()
	ISCollapsableWindow.initialise(self);
end

function WQS_GPSWindow:new(x, y, width, height)
	local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
	local o = ISCollapsableWindow:new(x, y, width, height);
	setmetatable(o, self)
	self.__index = self
	o.title = getText("IGUI_WQS_GuiTitle") or "Extraction Tracker";
	o.pin = true;
	o.resizable = true;
	o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 };
	o.dim = { btnWid = 100, btnHgt = math.max(25, FONT_HGT_SMALL + 3 * 2), MainPadding = 20 };
	WQS_GPSWindow.instance = o

	return o;
end

function WQS_GPSWindow:createChildren()
	-- local HCR=0.25
	-- local HCG=0.42
	-- local HCB=0.63

	-- local CR=0.37
	-- local CG=0.47
	-- local CB=0.54
	--print("btnHgt="..self.instance.dim.btnHgt)

	local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

	--local btnWid = 100
	--local btnHgt = math.max(25, FONT_HGT_SMALL + 3 * 2)
	--local MainPadding = 20
	local MainPadding = self.instance.dim.MainPadding
	local btnWid = self.instance.dim.btnWid
	local btnHgt = self.instance.dim.btnHgt

	local TextPanelH = (self:getHeight() - MainPadding - btnHgt - MainPadding) + 5
	local TextPanelW = math.floor(self:getWidth() - MainPadding * 1.8)
	btnWid = TextPanelW

	ISCollapsableWindow.createChildren(self);

	--self.nvnGPSBody = ISRichTextPanel:new(0, 25, 250, 120);
	self.nvnGPSBody = ISRichTextPanel:new(MainPadding, 10 + MainPadding, TextPanelW, TextPanelH);

	self.nvnGPSBody:initialise();
	self.nvnGPSBody:instantiate();
	self.nvnGPSBody.anchorLeft = true;
	self.nvnGPSBody.anchorTop = true;

	self.nvnGPSBody:noBackground()
	self.nvnGPSBody:setMargins(0, 0, 0, 0)
	--self.nvnGPSBody.font = UIFont.Medium

	--self.nvnGPSBody.textDirty = true;	
	self:addChild(self.nvnGPSBody);

	--local width = getTextManager():MeasureStringX(UIFont.Small, v.title) + 10

	local BtnY = self:getHeight() - MainPadding - btnHgt

	self.ReqExtrBut = ISButton:new(MainPadding, BtnY, btnWid, btnHgt, getText("IGUI_WQS_ReqExtraction"), self,
		WQS.BeginExtraction)
	self.ReqExtrBut.internal = "REQUEST_EXTRACTION_BUTTON";
	self.ReqExtrBut.anchorTop = false
	self.ReqExtrBut.anchorBottom = true
	self.ReqExtrBut:initialise();
	self.ReqExtrBut:instantiate();
	--self.ReqExtrBut.borderColor = {r=1, g=0.6, b=0, a=1.0};
	self.ReqExtrBut.borderColor = WQS_Shared.BorderColor
	self.ReqExtrBut.backgroundColor = WQS_Shared.BGColor;
	self.ReqExtrBut.backgroundColorMouseOver = WQS_Shared.BGColorMouseOver;
	-- self.ReqExtrBut.backgroundColor = {r=0.4, g=0.4, b=0.4, a=1.0};
	-- self.ReqExtrBut.backgroundColorMouseOver = {r=0.6, g=0.6, b=0.6, a=1.0};	
	self.ReqExtrBut:setVisible(false);
	self:addChild(self.ReqExtrBut);

	self.CompleteExtrBut = ISButton:new(MainPadding, BtnY, btnWid, btnHgt, getText("IGUI_WQS_CompleteExtraction"), self,
		WQS.CompleteExtraction)
	self.CompleteExtrBut.internal = "COMPLETE_EXTRACTION_BUTTON";
	self.CompleteExtrBut.anchorTop = false
	self.CompleteExtrBut.anchorBottom = true
	self.CompleteExtrBut:initialise();
	self.CompleteExtrBut:instantiate();
	--self.CompleteExtrBut.borderColor = {r=0, g=1, b=0, a=0.8};
	self.CompleteExtrBut.borderColor = WQS_Shared.BorderColor
	self.CompleteExtrBut.backgroundColor = WQS_Shared.BGColor;
	self.CompleteExtrBut.backgroundColorMouseOver = WQS_Shared.BGColorMouseOver;
	-- self.CompleteExtrBut.backgroundColor = {r=0.4, g=0.4, b=0.4, a=1.0};
	-- self.CompleteExtrBut.backgroundColorMouseOver = {r=0.6, g=0.6, b=0.6, a=1.0};	
	self.CompleteExtrBut:setVisible(false);
	self:addChild(self.CompleteExtrBut);

	self.ManageAntennaBut = ISButton:new(MainPadding, BtnY, btnWid, btnHgt, getText("IGUI_WQS_ManageAntenna"), self,
		WQS.ContactHQ)
	self.ManageAntennaBut.internal = "MANAGE_ANTENNA_BUTTON";
	self.ManageAntennaBut.anchorTop = false
	self.ManageAntennaBut.anchorBottom = true
	self.ManageAntennaBut:initialise();
	self.ManageAntennaBut:instantiate();
	--self.ManageAntennaBut.borderColor = {r=1, g=0.93, b=0.47, a=0.8};
	self.ManageAntennaBut.borderColor = WQS_Shared.BorderColor
	self.ManageAntennaBut.backgroundColor = WQS_Shared.BGColor;
	self.ManageAntennaBut.backgroundColorMouseOver = WQS_Shared.BGColorMouseOver;
	self.ManageAntennaBut:setVisible(false);
	self:addChild(self.ManageAntennaBut);
end

function WQS_OpenTrackerGui()
	if WQS_GPSWindow.instance then
		WQS_GPSWindow:setVisible(true);
		WQS_GPSWindow:addToUIManager();
		--WQS_GPSWindowUpdate()
		WQSCheckFlip = false;
	else
		WQS_GPSWindowCreate()
	end
end

function WQS_GPSWindowCreate()
	if WQS_GPSWindow.instance then
		WQS_GPSWindow.instance:close()
	end

	local fsize = getCore():getOptionFontSize()
	local winw = getTextManager():MeasureStringX(UIFont.AutoNormMedium, "You need a military walkie talkie 12345")
	local winw = 40 + winw --padding 20 da un lato e 20 dall'altro
	local winh = math.floor(0 + getTextManager():MeasureStringY(UIFont.AutoNormMedium, "You") * (14.5 - fsize / 8)) + 50

	if (fsize == 1) then
		winh = winh + 50
	end
	if (fsize == 2) then
		winh = winh + 30
	end
	WQS_GPSWindow = WQS_GPSWindow:new(20, 500, winw, winh);

	--WQS_GPSWindow = WQS_GPSWindow:new(20, 500, 260, 225);
	WQS_GPSWindow:addToUIManager();
	WQS_GPSWindow:setVisible(true);
	WQS_GPSWindow.pin = true;
	WQS_GPSWindow.resizable = true;
	GuiAlreadyCreated = true
end

local function WQS_GPSWindowUpdate()
	if not (GuiAlreadyCreated) then
		WQS_GPSWindowCreate()
	end

	local player = WQS.GetCurrentPlayer();
	if player then
		--local roundedZ=string.format("%.2f", z)
		local ComposedStat = {}
		ComposedStat = WQS.ComposeExtractionStatsTxt(player)

		if WQS_Shared.TableIsEmptyOrNil(ComposedStat) then
			print(" WQS ERROR ComposedStat")
			return nil
		end

		-- if not(ComposedStat) then
		-- 	print(" WQS ERROR ComposedStat")
		-- 	return nil
		-- end

		local data = {}
		data = ComposedStat.data

		local CurrentStateLabel = getText("IGUI_WQS_StatusExtraction1") or "Extraction zone not reachedz"

		WQS_GPSWindow.ReqExtrBut:setVisible(false)
		WQS_GPSWindow.CompleteExtrBut:setVisible(false)
		WQS_GPSWindow.ManageAntennaBut:setVisible(false)

		if ((WQS.CurrentStateIs("EXTRACTION_CAN_BE_STARTED"))) then
			WQS_GPSWindow.ReqExtrBut:setVisible(true)
			--WQS.SetState("EXTRACTION_CAN_BE_STARTED")
			CurrentStateLabel = getText("IGUI_WQS_StatusExtraction2") or "Extraction can be requestedz"
		end

		if (WQS.CurrentStateIs("EXTRACTION_RUNNING")) then
			CurrentStateLabel = getText("IGUI_WQS_StatusExtraction3") or "Extraction in progress"
			local land = getText("IGUI_WQS_StatusExtraction6") or "Expected arrival in"
			CurrentStateLabel = CurrentStateLabel .. " <LINE> " .. land .. ": " .. WQS_EXTRACTION_TIME_LEFT .. " min "
		end

		if (WQS.CurrentStateIs("EXTRACTION_CAN_BE_COMPLETED_BUT_WRONG_ZONE")) then
			CurrentStateLabel = getText("IGUI_WQS_StatusExtraction5") or
				"Extraction can be completeted, go to extraction zone!"
		end

		if (WQS.CurrentStateIs("EXTRACTION_CAN_BE_COMPLETED")) then
			CurrentStateLabel = getText("IGUI_WQS_StatusExtraction4") or "Extraction can be completetedz"
			WQS_GPSWindow.CompleteExtrBut:setVisible(true)
		end


		if (WQS.CurrentStateIs("EXTRACTION_COMPLETED")) then
			CurrentStateLabel = getText("IGUI_WQS_StatusExtraction9") or "Extraction completetedz"
		end

		--i tag devono avere prima e dopo uno spazio!
		local GuiTxt = ""

		if (ComposedStat.ShowAlternativeGui) then
			GuiTxt = ComposedStat.ShowAlternativeGuiTxt or "ShowAlternativeGui"
		else
			GuiTxt = " <H1> <LEFT> " .. WQS_COLTIT .. ComposedStat.MainLabel .. " <RGB:1,1,1> <LINE> <SIZE:small> "
			GuiTxt = GuiTxt ..
				" <LEFT> " .. WQS_COLSUBTIT2 .. ComposedStat.MapGuiLabel .. WQS_COLWHITE .. WQS_BR .. WQS_BR
			--DEVE ESSERCI LO SPAZIO PRIMA e DOPO DI <LINE>
			GuiTxt = GuiTxt .. " <LEFT> <H2> " ..
				ComposedStat.DistanceLabel .. " <LINE> " --DEVE ESSERCI LO SPAZIO PRIMA e DOPO DI <LINE>
			GuiTxt = GuiTxt .. " <LEFT> " .. ComposedStat.ZlevelLabel .. " <LINE> "
			GuiTxt = GuiTxt .. " <LEFT> " .. ComposedStat.SignalStrenghtLabel .. " <LINE> "
			--local hours_left=WQS.getHoursLeftToDeadline()
			if (data.HoursLeft_IsEnabled) then
				GuiTxt = GuiTxt .. " <LEFT> " .. ComposedStat.HoursLeftLabel .. " <LINE> "
			end
			--GuiTxt = GuiTxt.." <LINE> <H2> "..CurrentStateLabel.." <SIZE:small> "
			GuiTxt = GuiTxt .. " <SIZE:small> <LINE> <SIZE:small> " .. CurrentStateLabel
		end

		if (data.CanUseAntenna) then
			WQS_GPSWindow.ManageAntennaBut:setVisible(true)
		end

		--local GuiTxt = x .. ", " .. y .. "\nAzltitude: " .. roundedZ;		
		--WQS_GPSWindow.nvnGPSBody.textDirty = true;
		--WQS_GPSWindow:setWidth(400)
		--GuiTxt=WQSTEST
		WQS_GPSWindow.nvnGPSBody.text = GuiTxt;
		--print(WQS_GPSWindow.nvnGPSBody.height)
		--WQS_GPSWindow:setHeight(WQS_GPSWindow.nvnGPSBody.height+WQS_GPSWindow.dim.btnHgt+WQS_GPSWindow.dim.MainPadding*2)
		WQS_GPSWindow.nvnGPSBody:paginate();

		local myh = WQS_GPSWindow.nvnGPSBody.height
		local FullContentHeight = myh + WQS_GPSWindow.dim.btnHgt + WQS_GPSWindow.dim.MainPadding * 4
		WQS_GPSWindow:setHeight(FullContentHeight)
		--WQS_GPSWindow:setVisible(true); --questo impedisce che venga chiusa
	end
end


local function WQS_GPSWindowToggle()
	WQS_GPSWindowUpdate()
	if WQSCheckFlip == false then
		WQS_GPSWindow:setVisible(false);
		WQS_GPSWindow:removeFromUIManager();
		WQSCheckFlip = true;
	else
		WQS_GPSWindow:setVisible(true);
		WQS_GPSWindow:addToUIManager();
		WQSCheckFlip = false;
	end
end



local function RefreshWinOnPlayerUpdate()
	--local NOWZ=getGameTime():getLastTimeOfDay() --getMinutes() --os.time() --getTimeInMillis()
	local NOWZ = getTimeInMillis() --getMinutes() --os.time() --getTimeInMillis()
	local delay = 1000

	if (NOWZ - LAST_GUI_UPDATE) > delay then
		LAST_GUI_UPDATE = getTimeInMillis()
		WQS_GPSWindowUpdate()
	end
end

local function WQS_GPSWindowOnPlayerDeath()
	WQS_GPSWindow:setVisible(false);
	WQS_GPSWindow:removeFromUIManager();
	if WQS_GPSWindow.instance then
		WQS_GPSWindow.instance:close()
	end
	WQSCheckFlip = true;
end

function WQS_GoToMenu()
	getCore():exitToMenu()
end

--[[
function WQS_FinalModalWin()
	
	if (FinalPopup) and (FinalPopup:isVisible()) then
		--print("Finalgui gia aperta")
		return
	end
	--ISModalRichText:new(x, y, width, height, text, yesno, target, onclick, player, param1, param2)

	local xx=getCore():getScreenWidth()/2-398
	local yy=getCore():getScreenHeight()/2-300

    FinalPopup = ISModalRichText:new(xx,yy,756,600, getText("IGUI_WQS_EndModal"), false,nil,WQS_GoToMenu);
    FinalPopup:initialise();
    FinalPopup.backgroundColor = {r=0, g=0, b=0, a=0.9};
    FinalPopup.alwaysOnTop = true;
    FinalPopup.chatText:paginate();
    FinalPopup:setY(getCore():getScreenHeight()/2-(FinalPopup:getHeight()/2));
    FinalPopup:setVisible(true);
    FinalPopup:addToUIManager();
    FinalPopup.prevFocus = self;
end
 ]]
function WQS_ModalWin(mcontent, onlick, ww, hh)
	mcontent = mcontent or ""
	onlick = onlick or nil
	ww = ww or 756
	hh = hh or 700

	local halfw = math.floor(ww / 2)
	local halfh = math.floor(hh / 2)

	if (ModalPopup) and (ModalPopup:isVisible()) then
		--print("Finalgui gia aperta")
		return
	end
	--ISModalRichText:new(x, y, width, height, text, yesno, target, onclick, player, param1, param2)

	local xx = getCore():getScreenWidth() / 2 - halfw --398
	local yy = getCore():getScreenHeight() / 2 - halfh --300

	ModalPopup = ISModalRichText:new(xx, yy, ww, hh, mcontent, false, nil, onlick);
	--ModalPopup = ISModalRichText:new(xx,yy,756,600, mcontent, false,nil,onlick);
	ModalPopup:initialise();
	ModalPopup.backgroundColor = { r = 0, g = 0, b = 0, a = 0.9 };
	ModalPopup.alwaysOnTop = true;
	ModalPopup.chatText:paginate();
	ModalPopup:setY(getCore():getScreenHeight() / 2 - (ModalPopup:getHeight() / 2));
	ModalPopup:setVisible(true);
	ModalPopup:addToUIManager();
	ModalPopup.prevFocus = self;
end

--Events.OnGameStart.Add(WQS_GPSWindowCreate);
--Events.OnGameStart.Add(WQS_GPSWindowUpdate);
--Events.OnCreatePlayer.Add(WQS_GPSWindowCreate);

--Events.OnCreatePlayer.Add(WQS_GPSWindowUpdate);

Events.OnPlayerUpdate.Add(RefreshWinOnPlayerUpdate); --chiamo l'update della gui ogni tot secondi x ottimizzare
Events.OnPlayerMove.Add(WQS_GPSWindowUpdate);

Events.OnPlayerDeath.Add(WQS_GPSWindowOnPlayerDeath);

--Events.OnKeyPressed.Add(nvnGPSKeyUp);
