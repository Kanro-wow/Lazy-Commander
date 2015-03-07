local LCFrame = CreateFrame("Frame", "LazyCommander_Frame", UIParent)
local Realm = GetRealmName()
local Player = UnitName("player")
local CheckMarkTexture = "Interface\\RaidFrame\\ReadyCheck-Ready"
local CrossTexture = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local Frames = {}
local BuildingsData = C_Garrison.GetBuildings()
LCFrame:RegisterEvent("GARRISON_LANDINGPAGE_SHIPMENTS")




local Events = {
	"SHOW_LOOT_TOAST",
	"GARRISON_SHIPMENT_RECEIVED",
	"GARRISON_MISSION_LIST_UPDATE",
	"GARRISON_BUILDING_PLACED",
	"GARRISON_MISSION_NPC_CLOSED",
	"PLAYER_ENTERED_WORLD",
	"ZONE_CHANGED_NEW_AREA",
	"SHIPMENT_CRAFTER_INFO",
	"SHIPMENT_CRAFTER_OPENED",
	"SHIPMENT_CRAFTER_CLOSED",
}

LCFrame:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		self[event](self,...)
	else
		print('LazyCommander:',event,'has no function!')
	end
end)

if not LazyCommander_C then
	LazyCommander_C = {
		LastVisitedCache = 0,
		Hidden = false,
		Filter = {}
	}
end

if not LazyCommander then
	LazyCommander = {
		x = 200,
		y = 200,
		Unlocked = true
	}
end

local function GetString(Left,Right)
	if Left == nil and Right == nil then
		return nil
	else
		if Left == false or Right == false then
			Left = "?"
			Right = "?"
		end
		return Left.."/"..Right
	end
end

local function GetRealmTime()
	local t = {}
	_,t.month,t.day,t.year = CalendarGetDate()
	t.hour,t.min = GetGameTime()
	-- Not doing seconds, yet
	return time(t)
end

local function GetCacheIndicator(CacheCount)
	if CacheCount == false then
		return CrossTexture
	elseif CacheCount < 350 then
		return CheckMarkTexture
	else
		return CrossTexture
	end
end

local function GetCacheCount()
	if LazyCommander_C.LastVisitedCache == 0 then
		return false
	end

	local CacheCount = math.floor((GetRealmTime() - LazyCommander_C.LastVisitedCache)/600)
	if CacheCount > 500 then
		CacheCount = 500
	end
	return CacheCount
end

local function GetCacheCompletionTime(BuildingID)
	return LazyCommander_C.LastVisitedCache + 300000

end

local function GetMissionIndicator(Completed, Total)
	if Total == Completed and Completed > 0 then
		return CrossTexture
	elseif Total == 0 and Completed == 0 then
		return nil
	elseif Completed == 0 and Total > 0 then
		return CheckMarkTexture
	elseif Completed / Total > 0.5 then
		return CrossTexture
	elseif Completed / Total <= 0.5 then
		return CheckMarkTexture
	end
end

local function GetMissionCount()
	local Total = C_Garrison.GetInProgressMissions()
	local Completed = C_Garrison.GetCompleteMissions()

	return #Completed, #Total
end

local function GetWOIndicator(Capacity, Ready, Completed)
	if Ready == 0 and Completed == 0 then
		return nil
	elseif Completed - Ready >= 5 then
		return CheckMarkTexture
	else
		return CrossTexture
	end
end

local function GetWOCompletionTime(BuildingID)
	local _,_,_,WOComplete, WOTotal, CreationTime, Duration = C_Garrison.GetLandingPageShipmentInfo(BuildingID)
	if WOTotal == nil then return end
	local CompletionTime = CreationTime + (Duration * (WOTotal - WOComplete))
	return CompletionTime
end

local function GetWOCount(BuildingID)
	-- local name, texture, shipmentCapacity, shipmentsReady, shipmentsTotal, creationTime, duration, timeleftString, itemName, itemIcon, itemQuality, itemID = C_Garrison.GetLandingPageShipmentInfo(buildingID);
	local _,Texture, WOCapacity, WOComplete, WOTotal = C_Garrison.GetLandingPageShipmentInfo(BuildingID)
	if WOComplete == nil then
		WOComplete = 0
	end
	if WOTotal == nil then
		WOTotal = 0
	end
	return WOCapacity, WOComplete, WOTotal, Texture
end

local function HasWO(BuildingID)
	local _,_,WorkOrder = C_Garrison.GetLandingPageShipmentInfo(BuildingID)
	if WorkOrder ~= 0 and WorkOrder ~= nil then
		return true
	else
		return false
	end
end

local function UpdateIndicatorTexture(self, Indicator)
	if Indicator ~= nil then
		if not self.Indicator:IsShown() then
			self.Indicator:Show()
		end

		local CurrentTexture = self.Indicator:GetTexture()
		if CurrentTexture == nil or CurrentTexture ~= Indicator then
			self.Indicator:SetTexture(Indicator)
		end

	elseif self.Indicator:IsShown() then
		self.Indicator:Hide()
	end
end

local function UpdateString(self, String)
	if String == self.String:GetText() then
		return
	end
	if not String then
		self.String:SetText("")
		if self.String:IsShown() then
			self.String:Hide()
		end
	else
		self.String:SetText(String)
		if not self.String:IsShown() then
			self.String:Show()
		end
	end
end

local function UpdateCache()
	local CacheCount = GetCacheCount()
	local Indicator = GetCacheIndicator(CacheCount)
	UpdateIndicatorTexture(Frames["Cache"], Indicator)
	UpdateString(Frames["Cache"], GetString(CacheCount, 500))
end

local function TickerUpdateCache()
	local CacheCount = (GetRealmTime() - LazyCommander_C.LastVisitedCache)/600
	local Offset = CacheCount - math.floor(CacheCount)
	C_Timer.After((Offset*600)+60, function()
		UpdateCache()
		local ticker = C_Timer.NewTicker(600, UpdateCache)
	end)
end

local function UpdateWO(buildingID)
	if Frames[buildingID] then
		local WOCapacity, WOComplete, WOTotal = GetWOCount(buildingID)
		local Indicator = GetWOIndicator(WOCapacity, WOComplete, WOTotal)
		UpdateIndicatorTexture(Frames[buildingID], Indicator)
		UpdateString(Frames[buildingID], GetString(WOComplete, WOTotal))
	end
end

local function UpdateAllWO()
	C_Garrison.RequestLandingPageShipmentInfo()
end

local function UpdateMission()
	local Completed, Total = GetMissionCount()
	local Indicator = GetMissionIndicator(Completed, Total)
	UpdateIndicatorTexture(Frames["Completed"], Indicator)
	UpdateString(Frames["Completed"], GetString(Completed, Total))
end

local function ShowOrHideSubFrame(self, Show)
	if self:IsShown() ~= Show then
		if Show and self.Filtered == false then
			self:Show()
			self:SetHeight(30)
		else
			self:Hide()
			self:SetHeight(1)
		end
	end
end

local PreviousDataID = false
local function CreateSubFrame(self, Data)
	if not PreviousDataID then
		self:SetPoint("TOPRIGHT", "LazyCommander_Frame", "TOPRIGHT");
	else
		self:SetPoint("TOPRIGHT", "LazyCommander_"..PreviousDataID, "BOTTOMRIGHT",0,0);
	end
	PreviousDataID = Data.ID
	self:SetHeight(30)
	self:SetWidth(80)

	self.Icon = self:CreateTexture(nil,"BACKGROUND")
	self.Icon:SetTexture(Data.Texture)
	self.Icon:SetPoint("TOPLEFT")
	self.Icon:SetHeight(30)
	self.Icon:SetWidth(30)

	self.String = self:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
	self.String:SetPoint("TOPLEFT", self.Icon, 35, -7)
	self.String:SetText(Data.Text)

	self.Indicator = self:CreateTexture(nil,"BACKGROUND")
	self.Indicator:SetPoint("TOPRIGHT", self.String, 20, 4)
	self.Indicator:SetHeight(20)
	self.Indicator:SetWidth(20)
	UpdateIndicatorTexture(self, Data.Indicator)
	if LazyCommander_C.Filter[Data.ID] then
		ShowOrHideSubFrame(self, false)
		self.Filtered = true
	else
		self.Filtered = false
	end

end

local function CreateWOData(BuildingID)
	local WOCapacity, WOReady, WOTotal, Texture = GetWOCount(BuildingID)

	local Data = {
		ID = BuildingID,
		Text = GetString(WOReady, WOTotal),
		Indicator = GetWOIndicator(WOCapacity, WOReady, WOTotal),
		Texture = Texture,
	}

	return Data
end

local function CreateAllData()
	local CacheCount = GetCacheCount()
	local MissionCompleted, MissionTotal = GetMissionCount()
	local Information = {
		[1] = {
			ID = "Cache",
			Text = GetString(CacheCount, 500),
			Indicator = GetCacheIndicator(CacheCount),
			Texture = "Interface\\Icons\\inv_garrison_resource",
		},
		[2] = {
			ID = "Completed",
			Text = GetString(MissionCompleted, MissionTotal),
			Indicator = GetMissionIndicator(MissionCompleted, MissionTotal),
			Texture = "Interface\\Icons\\mountjournalportrait",
		},
	}

	for _, Building in next, BuildingsData do
		if HasWO(Building.buildingID) then
			table.insert(Information, CreateWOData(Building.buildingID))
		end
	end

	LCFrame:SetWidth(#Information * 30)

	for _, Data in next, Information do
		local frame = CreateFrame("Frame", "LazyCommander_"..Data.ID, LCFrame)
		Frames[Data.ID] = frame
		CreateSubFrame(frame, Data)
	end
end

local function ShowOrHideLCFrame()
	self = LCFrame
	if not LazyCommander.Hidden then
		local RevertID = GetCurrentMapAreaID()
		local RevertScale = WorldMapDetailFrame:GetScale()
		local RevertHorizontal = WorldMapScrollFrame:GetHorizontalScroll()
		local RevertVertical = WorldMapScrollFrame:GetVerticalScroll()
		SetMapToCurrentZone()
		local InstanceID = GetCurrentMapAreaID()

		if InstanceID == 971 or InstanceID == 976 then
			self:RegisterEvent("BAG_UPDATE_DELAYED")
			if not self:IsShown() then
				self:Show()
			end
		else
			self:UnregisterEvent("BAG_UPDATE_DELAYED")
			if self:IsShown() then
				self:Hide()
			end
		end
		SetMapByID(RevertID)
		WorldMapDetailFrame:SetScale(RevertScale)
		WorldMapScrollFrame:SetHorizontalScroll(RevertHorizontal)
		WorldMapScrollFrame:SetVerticalScroll(RevertVertical)
	else
		self:Hide()
	end
end

local function LockLCFrame()
	LCFrame:EnableMouse(LazyCommander.Unlocked)
	LCFrame:SetMovable(LazyCommander.Unlocked)
end

-- Create main frame, register events and show information
local function CreateLCFrame(self)
	for _,event in next, Events do
		self:RegisterEvent(event)
	end

	CreateAllData()

	self:SetHeight(120)
	self:SetWidth(120)
	self:SetPoint("BOTTOMLEFT", LazyCommander.x,LazyCommander.y)
	LockLCFrame()
	self:SetClampedToScreen(true)
	self:RegisterForDrag("LeftButton")

	self:SetScript("OnDragStart",LCFrame.StartMoving)
	self:SetScript("OnDragStop", function()
		self:StopMovingOrSizing()
		LazyCommander.x = math.ceil(self:GetLeft())
		LazyCommander.y = math.ceil(self:GetBottom())
	end)
end

local function BlacklistBuilding(BuildingName)
	for _, Building in next, BuildingsData do
		local BuildingID,BuildingNameCheck = C_Garrison.GetBuildingInfo(Building.buildingID)
		if string.lower(BuildingNameCheck) == BuildingName then
			LazyCommander_C.Filter[BuildingID] = not LazyCommander_C.Filter[BuildingID]
			Frames[BuildingID].Filtered = LazyCommander_C.Filter[BuildingID]
			ShowOrHideSubFrame(Frames[BuildingID], not LazyCommander_C.Filter[BuildingID])
			return true
		end
	end

	return false
end

local function GetGlobalData()
	local GlobalData = {}
	for _, Building in next, BuildingsData do
		GlobalData[Building.buildingID] = {
			WOCompletionTime = GetWOCompletionTime(Building.buildingID),
			CacheCompletionTime = LazyCommander_C.LastVisitedCache + 300000,
	}
	end

	return GlobalData
end

local Init = false
function LCFrame:GARRISON_LANDINGPAGE_SHIPMENTS()
	if Init then
		for _, Building in next, BuildingsData do
			UpdateWO(Building.buildingID)
		end
	else
		if not C_Garrison.GetGarrisonInfo() then
			print("Error: LazyCommander has no Garrison Info. Terminating.")
			return
		end
		BuildingsData = C_Garrison.GetBuildings()
		CreateLCFrame(self)
		ShowOrHideLCFrame()
		TickerUpdateCache()
		Init = true
	end
end

function LCFrame:BAG_UPDATE_DELAYED()
	UpdateAllWO()
end

function LCFrame:GARRISON_SHIPMENT_RECEIVED()
	UpdateAllWO()
end

local available
function LCFrame:SHIPMENT_CRAFTER_OPENED()
	C_Timer.After(0.1, function()
		available = GarrisonCapacitiveDisplayFrame.available;
		if (available and available > 0) then
			C_Garrison.RequestShipmentCreation(available);
		end
	end)
end

local SpamControl = 0
function LCFrame:SHIPMENT_CRAFTER_INFO()
	available = GarrisonCapacitiveDisplayFrame.available;
	if (available and available > 0) then
		C_Garrison.RequestShipmentCreation(available);
	end

	if SpamControl + 0.1 < GetTime() then
		SpamControl = GetTime()
		UpdateAllWO()
	end
end

function LCFrame:SHIPMENT_CRAFTER_CLOSED()
	UpdateAllWO()
end

function LCFrame:GARRISON_MISSION_LIST_UPDATE()
	UpdateMission()
end

function LCFrame:GARRISON_MISSION_NPC_CLOSED()
	UpdateMission()
end

function LCFrame:PLAYER_ENTERED_WORLD()
	ShowOrHideLCFrame()
end

function LCFrame:ZONE_CHANGED_NEW_AREA()
	ShowOrHideLCFrame()
end

function LCFrame:GARRISON_BUILDING_PLACED()
	BuildingsData = C_Garrison.GetBuildings()
	for FrameID, Frame in next, Frames do
		if FrameID ~= "Completed" and FrameID ~= "Cache" then
			local Active = false
			for _, Building in next, BuildingsData do
				if FrameID == Building.buildingID then
					Active = true
				end
			end
			ShowOrHideSubFrame(Frame, Active)
		end
	end

	for _, Building in next, BuildingsData do
		if HasWO(Building.buildingID) then
			if not Frames[Building.buildingID] then
				local Data = CreateWOData(Building.buildingID)
				local frame = CreateFrame("Frame", "LazyCommander_"..Data.ID, LCFrame)
				Frames[Data.ID] = frame
				CreateSubFrame(frame, Data)
			end
		end
	end
end

local function GetBuildingsString()
	local BuildingNames = {}
	for _, Building in next, BuildingsData do
		if HasWO(Building.buildingID) then
			local _,BuildingName = C_Garrison.GetBuildingInfo(Building.buildingID)
			table.insert(BuildingNames, BuildingName)
		end
	end

	table.sort(BuildingNames)
	return table.concat(BuildingNames,", ")
end

SLASH_LAZYCOMMANDER1 = "/lazycommander"
SLASH_LAZYCOMMANDER2 = "/lazycom"
SlashCmdList["LAZYCOMMANDER"] = function(msg, editbox)
	msg = string.lower(msg)
	local Pos = string.find(msg,"%s+")
	local Command
	local SubCommand
	if Pos ~= nil then
		SubCommand = strtrim(string.sub(msg,Pos+1,string.len(msg))," ")
		Command = strtrim(string.sub(msg,1,Pos)," ")
	else
		Command = msg
		SubCommand = nil
	end

	if Command == "lock" then
		LazyCommander.Unlocked = not LazyCommander.Unlocked
		LockLCFrame()
		if LazyCommander.Unlocked == true then
			print("LazyCommander is now unlocked. Drag the window to your liking.")
		else
			print("LazyCommander is now locked. Drag the window to your liking.")
		end
	elseif Command == "hide" then
		LazyCommander.Hidden = not LazyCommander.Hidden
		ShowOrHideLCFrame()
		if LazyCommander.Hidden == true then
			print("LazyCommander is now hidden. The window will not appear until you show it again. Type /lazycommander show to make it reappear.")
		else
			print("LazyCommander is now shown. The window will appear whenever you are in your garrison.")
		end
	elseif Command == "filter" then
		if not SubCommand then
			print([[Blacklisting is done by typing "/Lazycom Filter Herb Garden"]])
			print("Current Buildings:",GetBuildingsString())
		elseif SubCommand then
			if BlacklistBuilding(SubCommand) then
				print("Done:", SubCommand)
			else
				print("Error:",SubCommand,"is not a known building.")
				print("Current Buildings:",GetBuildingsString())
			end
		end
	else
		print("--LazyCommander Commands--")
		print("/Lazycom lock - Locks or Unlocks the window in place")
		print("/Lazycom hide - Shows or Hides the window when in garrison")
		print("/Lazycom filter - Filter out a building")
	end
end


-- GARRISON_RECRUITMENT_FOLLOWERS_GENERATED - On generation
-- GARRISON_RECRUIT_FOLLOWER_RESULT - on selectioin
-- SHIPMENT_CRAFTER_CLOSED
-- GARRISON_SHIPMENT_RECEIVED
-- C_Garrison.IsInvasionAvailable()

-- self:RegisterEvent("GARRISON_LANDINGPAGE_SHIPMENTS");
-- self:RegisterEvent("GARRISON_MISSION_LIST_UPDATE");
-- self:RegisterEvent("GARRISON_SHIPMENT_RECEIVED");
