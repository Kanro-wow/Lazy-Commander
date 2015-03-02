local LCFrame = CreateFrame("Frame", "LazyCommander_Frame", UIParent)
local CheckMarkTexture = "Interface\\RaidFrame\\ReadyCheck-Ready"
local CrossTexture = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local Frames = {}
LCFrame:RegisterEvent("PLAYER_LOGIN")

local Events = {
	"SHOW_LOOT_TOAST",
	"GARRISON_SHIPMENT_RECEIVED",
	"GARRISON_MISSION_LIST_UPDATE",
	"GARRISON_BUILDING_PLACED",
	"GARRISON_BUILDING_REMOVED",
	"PLAYER_ENTERED_WORLD",
	"ZONE_CHANGED_NEW_AREA",
	"SHIPMENT_CRAFTER_INFO",
	"SHIPMENT_CRAFTER_CLOSEDSHIPMENT_CRAFTER_CLOSED",
	"GARRISON_LANDINGPAGE_SHIPMENTS",
}

-- Create overal function for handeling events on LCFrame
LCFrame:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		self[event](self,...)
	else
		print('LazyCommander:',event,'has no function!')
	end
end)

-- Defaulting Char Vars
if not LazyCommander_C then
	LazyCommander_C = {
		LastVisitedCache = 0,
		Hidden = false,
		Filter = {}
	}
end

-- Defaulting Overal Vars
if not LazyCommander then
	LazyCommander = {
		x = 200,
		y = 200,
		Unlocked = true
	}
end
--------------------------
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
--------------------------
local function GetRealmTime()
	local t = {}
	_,t.month,t.day,t.year = CalendarGetDate()
	t.hour,t.min = GetGameTime()
	return time(t)
end
--------------------------
local function GetCacheIndicator(CacheCount)
	if CacheCount == false then
		return CrossTexture
	elseif CacheCount < 350 then
		return CheckMarkTexture
	else
		return CrossTexture
	end
end
--------------------------
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
--------------------------
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
--------------------------
local function GetMissionCount()
	local Total = C_Garrison.GetInProgressMissions()
	local Completed = C_Garrison.GetCompleteMissions()

	return #Completed, #Total
end
--------------------------
local function GetWOIndicator(Capacity, Ready, Completed)
	if Ready == 0 and Completed == 0 then
		return nil
	elseif Completed - Ready >= 5 then
		return CheckMarkTexture
	else
		return CrossTexture
	end
end
--------------------------
local function GetWOCount(BuildingID)
	local _,_,WOCapacity, WOComplete, WOTotal = C_Garrison.GetLandingPageShipmentInfo(BuildingID)
	if WOComplete == nil then
		WOComplete = 0
	end
	if WOTotal == nil then
		WOTotal = 0
	end
	return WOCapacity, WOComplete, WOTotal
end
--------------------------
local function HasWO(BuildingID)
	local _,_,WorkOrder = C_Garrison.GetLandingPageShipmentInfo(BuildingID)
	if WorkOrder ~= 0 and WorkOrder ~= nil then
		return true
	else
		return false
	end
end
--------------------------
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
--------------------------
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
--------------------------
local function UpdateCache()
	local CacheCount = GetCacheCount()
	local Indicator = GetCacheIndicator(CacheCount)
	UpdateIndicatorTexture(Frames["Cache"], Indicator)
	UpdateString(Frames["Cache"], GetString(CacheCount, 500))
end
--------------------------
local function UpdateWO(buildingID)
	if Frames[buildingID] then
		local WOCapacity, WOComplete, WOTotal = GetWOCount(buildingID)
		local Indicator = GetWOIndicator(WOCapacity, WOComplete, WOTotal)
		UpdateIndicatorTexture(Frames[buildingID], Indicator)
		UpdateString(Frames[buildingID], GetString(WOComplete, WOTotal))
	end
end
--------------------------
local function UpdateAllWO()
	C_Garrison.RequestLandingPageShipmentInfo()
end
--------------------------
local function UpdateMission()
	local Completed, Total = GetMissionCount()
	local Indicator = GetMissionIndicator(Completed, Total)
	UpdateIndicatorTexture(Frames["Completed"], Indicator)
	UpdateString(Frames["Completed"], GetString(Completed, Total))
end
--------------------------
local function ShowOrHideSubFrame(self, Show)
	if self:IsShown() ~= Show then
		if Show then
			self:Show()
			self:SetHeight(30)
		else
			self:Hide()
			self:SetHeight(1)
		end
	end
end
--------------------------
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
	ShowOrHideSubFrame(self, not LazyCommander_C.Filter[Data.ID])

end
--------------------------
local function CreateWOData(BuildingID)
	local WOCapacity, WOReady, WOTotal = GetWOCount(BuildingID)
	_,_,_,Texture = C_Garrison.GetBuildingInfo(BuildingID)

	local Data = {
		ID = BuildingID,
		Text = GetString(WOReady, WOTotal),
		Indicator = GetWOIndicator(WOCapacity, WOReady, WOTotal),
		Texture = Texture,
	}

	return Data
end
--------------------------
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

	local Buildings = C_Garrison.GetBuildings()
	for _, Building in next, Buildings do
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
--------------------------
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
		WorldMapDetailFrame:SetScale(RevertScale)
		WorldMapScrollFrame:SetHorizontalScroll(RevertHorizontal)
		WorldMapScrollFrame:SetVerticalScroll(RevertVertical)
		SetMapByID(RevertID)
	else
		self:Hide()
	end
end
--------------------------
local function LockLCFrame()
	LCFrame:EnableMouse(LazyCommander.Unlocked)
	LCFrame:SetMovable(LazyCommander.Unlocked)
end
--------------------------
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
--------------------------
local function BlacklistBuilding(BuildingName)
	local Buildings = C_Garrison.GetBuildings()
	for _, Building in next, Buildings do
		local BuildingID,BuildingNameCheck = C_Garrison.GetBuildingInfo(Building.buildingID)
		if string.lower(BuildingNameCheck) == BuildingName then
			LazyCommander_C.Filter[BuildingID] = not LazyCommander_C.Filter[BuildingID]
			ShowOrHideSubFrame(Frames[BuildingID], not LazyCommander_C.Filter[BuildingID])
			return true
		end
	end

	return false
end
--------------------------
function LCFrame:SHOW_LOOT_TOAST(_,_,_,_,_,_,lootSource)
	if lootSource == 10 then
		LazyCommander_C.LastVisitedCache = GetRealmTime()
		UpdateCache()
	else
	end
end
--------------------------
function LCFrame:GARRISON_LANDINGPAGE_SHIPMENTS()
	-- C_Timer.After(0.2, function()
	local Buildings = C_Garrison.GetBuildings()
	for _, Building in next, Buildings do
		UpdateWO(Building.buildingID)
	end
	-- end)
end

--------------------------
function LCFrame:BAG_UPDATE_DELAYED()
	UpdateAllWO()
end
--------------------------
function LCFrame:GARRISON_SHIPMENT_RECEIVED()
	UpdateAllWO()
end
--------------------------
function LCFrame:SHIPMENT_CRAFTER_CLOSED()
	UpdateAllWO()
end
--------------------------
local SpamControl = 0
function LCFrame:SHIPMENT_CRAFTER_INFO()
	if SpamControl + 0.1 < GetTime() then
		SpamControl = GetTime()
		UpdateAllWO()
	end
end
--------------------------
function LCFrame:GARRISON_MISSION_LIST_UPDATE()
	UpdateMission()
end
--------------------------
function LCFrame:PLAYER_ENTERED_WORLD()
	ShowOrHideLCFrame()
end
--------------------------
function LCFrame:ZONE_CHANGED_NEW_AREA()
	ShowOrHideLCFrame()
end
--------------------------
function LCFrame:PLAYER_LOGIN()
	C_Timer.After(1, function()
		if not C_Garrison.GetGarrisonInfo() then return end

		CreateLCFrame(self)
		ShowOrHideLCFrame()
	end)
end
--------------------------
function LCFrame:GARRISON_BUILDING_REMOVED(arg1,arg2)

end
--------------------------
function LCFrame:GARRISON_BUILDING_ACTIVATED(plotid, buildingID)

end
--------------------------
function LCFrame:GARRISON_BUILDING_PLACED()
	print("---------------------")
	local Buildings = C_Garrison.GetBuildings()

	for FrameID, Frame in next, Frames do
		if FrameID ~= "Completed" and FrameID ~= "Cache" then
			local Active = false
			for _, Building in next, Buildings do
				if FrameID == Building.buildingID then
					Active = true
				end
			end
			ShowOrHideSubFrame(Frame, Active)
		end
	end
	print("---------------------")

	for _, Building in next, Buildings do
		if HasWO(Building.buildingID) then
			if not Frames[Building.buildingID] then
				local Data = CreateWOData(Building.buildingID)
				local frame = CreateFrame("Frame", "LazyCommander_"..Data.ID, LCFrame)
				Frames[Data.ID] = frame
				CreateSubFrame(frame, Data)
			end
		end
	end

	-- for _, Building in next, Buildings do
	-- 	local WOCapacity, WOReady, WOTotal = GetWOCount(Building.buildingID)
	-- 	if WorkOrder ~= 0 and WorkOrder ~= nil then
	-- 		if not Frames[Building.buildingID] then
	-- 			print("Creating new frame")
	-- 			local Data = {
	-- 				ID = Building.buildingID,
	-- 				Text = GetString(WOReady, WOTotal),
	-- 				Indicator = GetWOIndicator(WOCapacity, WOReady, WOTotal),
	-- 				Texture = Texture,
	-- 			}

	-- 			local frame = CreateFrame("Frame", "LazyCommander_"..Building.buildingID, LCFrame)
	-- 			Frames[Building.buildingID] = frame
	-- 			CreateSubFrame(frame, Data)
	-- 		end
	-- 	end
	-- end

	-- for FrameID, Frame in next, Frames do
	-- 	if FrameID == "Completed" or FrameID == "Cache" then return end

	-- 	local Shown = false
	-- 	for _, Building in next, Buildings do
	-- 		if Building.buildingID == FrameID then
	-- 			Shown = true
	-- 		end
	-- 	end
	-- 	ShowOrHideSubFrame(Frame, Shown)
	-- end

	print("---------------------")
end
--------------------------
local function GetBuildingsString()
	local BuildingNames = {}
	for _, Building in next, C_Garrison.GetBuildings() do
		if HasWO(Building.buildingID) then
			local _,BuildingName = C_Garrison.GetBuildingInfo(Building.buildingID)
			table.insert(BuildingNames, BuildingName)
		end
	end

	table.sort(BuildingNames)
	return table.concat(BuildingNames,", ")
end
--------------------------
SLASH_LAZYCOMMANDER1 = "/lazycommander"
SlashCmdList["LAZYCOMMANDER"] = function(msg, editbox)
	msg = string.lower(msg)
	local Pos = string.find(msg,"%s+")
	local Command = strtrim(string.sub(msg,1,Pos)," ")
	local SubCommand
	if Pos > 0 then
		SubCommand = strtrim(string.sub(msg,Pos+1,string.len(msg))," ")
	else
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
			print([[Blacklisting is done by typing "/LazyCommander Filter Herb Garden"]])
			print("Current Buildings:",GetBuildingsString())
			print("Filtered Buildings:",GetFilteredString())
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
		print("/lazycommander lock - Locks or Unlocks the window in place")
		print("/lazycommander hide - Shows or Hides the window when in garrison")
		print("/lazycommander filter - Filter out a building")
	end

	-- local Transforms = GetWorldMapTransforms()
	-- for k, v in next, Transforms do
	-- 	if not GlobalTest[k] then
	-- 		print("no value yet")
	-- 		GlobalTest[k] = GetWorldMapTransformInfo(v)
	-- 	else
	-- 		if GlobalTest[k] == GetWorldMapTransformInfo(v) then
	-- 			print(k..": value is the same")
	-- 		else
	-- 			print(k..": value is different")
	-- 		end
	-- 	end
	-- end
end


-- GARRISON_RECRUITMENT_FOLLOWERS_GENERATED
-- GARRISON_RECRUIT_FOLLOWER_RESULT
-- SHIPMENT_CRAFTER_CLOSED
-- GARRISON_SHIPMENT_RECEIVED
-- C_Garrison.IsInvasionAvailable()

-- self:RegisterEvent("GARRISON_LANDINGPAGE_SHIPMENTS");
-- self:RegisterEvent("GARRISON_MISSION_LIST_UPDATE");
-- self:RegisterEvent("GARRISON_SHIPMENT_RECEIVED");
