local frame = CreateFrame("Frame", "LazyCommander_Frame", UIParent)
frame:RegisterEvent("GARRISON_BUILDING_PLACED")
local realm = GetRealmName()
local player = UnitName("player")
local frames = {}

-- if FACTION_ALLIANCE == UnitFactionGroup("player") then
-- 	local garrisonName = _G.GetMapNameByID(971)
-- else
-- 	local garrisonName = _G.GetMapNameByID(976)
-- end

local function GlobalVarsInit()
	if not LazyCommanderData then
		LazyCommanderData = {}
	end
	if not LazyCommanderData[realm] then
		LazyCommanderData[realm] = {}
	end
	if not LazyCommanderData[realm][player] then
		local _,_,Class = UnitClass("player")
		LazyCommanderData[realm][player] = {
		Class = Class,
		lastVisitCache = false,
		Filter = {},
		Buildings = {},
		}
	end
	if not LazyCommander then
		LazyCommander = {
			x = math.floor(UIParent:GetWidth()),
			y = math.floor(UIParent:GetHeight()),
			Unlocked = true,
			Shown = true,
		}
	end
	LazyCommanderData.frames = {}
end

frame:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		self[event](self,...)
	else
		print('LazyCommander:',event,'has no function!')
	end
end)

local function getRealmTime()
	local t = {}
	_,t.month,t.day,t.year = CalendarGetDate()
	t.hour,t.min = GetGameTime()
	return time(t)
end

function inGarrison()
	local _,_,_,_,_,_,_,instanceID = _G.GetInstanceInfo()
	if instanceID == 1159 or instanceID == 1153 or instanceID == 1331 or instanceID == 1330 or instanceID == 1158 or instanceID == 1152 then
		return true
	end
	print("currently not in garrison")
	return false
end

local function getUrgent(group, count)
	if group == "workOrder" then
		if count.complete == 0 and count.total == 0 then
			return nil
		elseif count.total - count.complete >= 5 then
			return false
		else
			return true
		end
	elseif group == "mission" then
		if count.total == count.complete and count.complete > 0 then
			return true
		elseif count.total == 0 and count.complete == 0 then
			return nil
		elseif count.complete == 0 and count.total > 0 then
			return false
		elseif count.complete / count.total > 0.5 then
			return true
		elseif count.complete / count.total <= 0.5 then
			return false
		end
	elseif group == "cache" then
		if count.complete == "?" or count.complete > 350 then
			return true
		else
			return false
		end
	end
end

local function getIcon(group, buildingID)
	if group == "workOrder" then
		local _,_,_,icon = C_Garrison.GetBuildingInfo(buildingID);
		return icon
	elseif group == "mission" then
		return [[Interface\Icons\mountjournalportrait]]
	elseif group == "cache" then
		return [[Interface\Icons\inv_garrison_resource]]
	end
end

local function getCount(group, id, offset)
	local count = {}
	if group == "workOrder" then
		_,count.texture,count.capacity, count.complete, count.total = C_Garrison.GetLandingPageShipmentInfo(id)
		if count.total == nil then
			count.complete = 0
			count.total = 0
		end
	elseif group == "mission" then
		count.total = #C_Garrison.GetInProgressMissions()
		count.complete = #C_Garrison.GetCompleteMissions()
	elseif group == "cache" then
		if LazyCommanderData[realm][player].lastVisitCache then
			count.total = 500
			count.complete = (getRealmTime() - LazyCommanderData[realm][player].lastVisitCache) / 600
			if offset then
				count.offset = count.complete - math.floor(count.complete)
			end
			count.complete = math.floor(count.complete)
			if count.complete > 500 then
				count.complete = 500
			end
		else
			count.total = "?"
			count.complete = "?"
		end
	end
	return count
end

local function hasWorkOrder(buildingID)
	local _,_,shipmentCapacity = C_Garrison.GetLandingPageShipmentInfo(buildingID)
	if shipmentCapacity ~= nil then
		return true
	else
		return false
	end
end

local function updateIndicator(subFrame, texture)
	if texture ~= nil then
		if not subFrame.indicator:IsShown() then
			subFrame.indicator.Show()
		end
		if subFrame.indicator:GetTexture() ~= texture then
			subFrame.indicator:SetTexture(texture)
		end
	else
		if subFrame.indicator:Show() then
			subFrame.indicator:Hide()
			subFrame.indicator:SetTexture(nil)
		end
	end
end

local function updateUrgent(subFrame)
	local urgent = getUrgent(subFrame.group, subFrame.count)
	if urgent ~= subFrame.urgent then
		subFrame.urgent = urgent
		if urgent == true then
			updateIndicator(subFrame, [[Interface\Raidframe\ReadyCheck-NotReady]])
		elseif urgent == false then
			updateIndicator(subFrame, [[Interface\Raidframe\ReadyCheck-Ready]])
		elseif urgent == nil then
			updateIndicator(subFrame)
		end
	end
end

local function updateString(subFrame)
	subFrame.string:SetText(subFrame.count.complete.."/"..subFrame.count.total)
end



local function unlockMainFrame(unlock)
	frame:EnableMouse(unlock)
	frame:SetMovable(unlock)
end

local frameCount = 0
local function createMainFrame()
	local events = {
	"SHOW_LOOT_TOAST",
	"GARRISON_MISSION_NPC_OPENED",
	"SHIPMENT_CRAFTER_INFO",
	"SHIPMENT_CRAFTER_CLOSED",
	"GARRISON_BUILDING_REMOVED",
	"GARRISON_SHIPMENT_RECEIVED",
	"GARRISON_LANDINGPAGE_SHIPMENTS",
	"ZONE_CHANGED_NEW_AREA",
	"GARRISON_MISSION_LIST_UPDATE",
	}
	for _,event in next, events do
		frame:RegisterEvent(event)
	end

	frame:SetWidth(130)
	frame:SetPoint("BOTTOMLEFT", LazyCommander.x, LazyCommander.y)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")

	unlockMainFrame(LazyCommander.Unlocked)
	frame:SetScript("OnDragStart",frame.StartMoving)
	frame:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		LazyCommander.x = math.ceil(frame:GetLeft())
		LazyCommander.y = math.ceil(frame:GetBottom())
	end)
end

local function showSubFrame(subFrame, show)
	if subFrame:IsShown() ~= show then
		if show and subFrame.removed == false then
			subFrame:Show()
			subFrame:SetHeight(30)
			frameCount = frameCount+1
					else
			subFrame:Hide()
			subFrame:SetHeight(1)
			frameCount = frameCount-1
		end
		frame:SetHeight(frameCount*30)
	end
end

local function showMainFrame()
	if not LazyCommander.Shown then
		if frame:IsShown() then
			frame:Hide()
			frame:UnregisterEvent("BAG_UPDATE_DELAYED")
		end
	end

	local show = inGarrison()
	if frame:IsShown() ~= show then
		if show and LazyCommander.Shown == true then
			frame:RegisterEvent("BAG_UPDATE_DELAYED")
			frame:Show()
		else
			frame:UnregisterEvent("BAG_UPDATE_DELAYED")
			frame:Hide()
		end
	end
end

local function updateSubFrame(subFrame, init, count)
	if not count then
		count = getCount(subFrame.group, subFrame.buildingID, false)
	else
		subFrame.count.total = count
		count = subFrame.count
	end
	if count ~= subFrame.count then
		subFrame.count = count
		updateUrgent(subFrame)
		updateString(subFrame)
		if init then
			subFrame.icon:SetTexture(getIcon(subFrame.group, subFrame.buildingID))
		end
		return true
	end
	return false
end

local previousFrame = false
local function createSubFrame(group, buildingID)
	local subFrame = CreateFrame("Frame","LazyCom_"..frameCount,frame)
	frameCount = frameCount + 1
	frame:SetHeight(frameCount*30)

	subFrame.buildingID = buildingID
	subFrame.group = group
	subFrame.removed = false

	if not previousFrame then
		subFrame:SetPoint("TOPLEFT", frame, "TOPLEFT");
	else
		subFrame:SetPoint("TOPRIGHT", previousFrame, "BOTTOMRIGHT",0,0);
	end
	previousFrame = subFrame
	subFrame:SetHeight(30)
	subFrame:SetWidth(100)

	subFrame.icon = subFrame:CreateTexture(nil,"BACKGROUND")
	subFrame.icon:SetPoint("TOPLEFT")
	subFrame.icon:SetHeight(30)
	subFrame.icon:SetWidth(30)

	subFrame.string = subFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
	subFrame.string:SetPoint("TOPLEFT", subFrame.icon, 35, -7)

	subFrame.indicator = subFrame:CreateTexture(nil,"BACKGROUND")
	subFrame.indicator:SetPoint("TOPRIGHT", subFrame.string , 20, 3)
	subFrame.indicator:SetHeight(20)
	subFrame.indicator:SetWidth(20)

	updateSubFrame(subFrame, true)
	return subFrame
end

local function showOrCreateSubFrame(frame, buildingID, plotID)
	if not frame then
		frames["workOrder"][plotID] = createSubFrame("workOrder", buildingID)
	elseif frame.filtered == false then
		updateSubFrame(frame, true)
		showSubFrame(frame, true)
		frame.removed = false
	end
end

local function blacklistSubFrame(group, ID)

end

local function tickerCache()
	if LazyCommanderData[realm][player].lastVisitCache then
		local count = getCount("cache",nil,true)

		C_Timer.After((count.offset*600)+60, function()
			updateSubFrame(frames["cache"])
			local ticker = C_Timer.NewTicker(600, function()
				updateSubFrame(frames["cache"])
			end)
		end)
	end
end

function frame:GARRISON_LANDINGPAGE_SHIPMENTS()
	print("refreshing all")
	for k, subFrame in next, frames["workOrder"] do
		updateSubFrame(subFrame)
	end
end

local init = false
function frame:GARRISON_BUILDING_PLACED(plotID)
	if not init then
		print("creating main frame")
		init = true
		GlobalVarsInit()
		createMainFrame()
		showMainFrame()
		frames["cache"] = createSubFrame("cache")
		frames["mission"] = createSubFrame("mission")
		frames["workOrder"] = {}
		tickerCache()
		if LazyCommanderData[realm][player].lastVisitCache then
			tickerCache()
		end
	end

	local buildingID = C_Garrison.GetOwnedBuildingInfoAbbrev(plotID)

	if hasWorkOrder(buildingID) then
		local data = {}
		data.buildingID = buildingID

		data.name,_,data.capacity,data.complete,data.total,data.creationtime,data.duration = C_Garrison.GetLandingPageShipmentInfo(buildingID)
		if data.duration == nil then
			data.fullShipment = true
		else
			data.fullShipment = data.creationtime + ((data.total-data.complete)*data.duration)
		end

		LazyCommanderData[realm][player].Buildings[plotID] = data
		showOrCreateSubFrame(frames["workOrder"][plotID], buildingID, plotID)
	end
end

function frame:GARRISON_BUILDING_REMOVED(plotID, buildingID)
	print("Removing",plotID)
	if frames["workOrder"][plotID] then
		showSubFrame(frames["workOrder"][plotID], false)
		frames["workOrder"][plotID].removed = true
		LazyCommanderData[realm][player].Buildings[plotID] = nil
	end
end

function frame:SHOW_LOOT_TOAST(_,_,_,_,_,_,lootSource)
	if lootSource == 10 then
		LazyCommanderData[realm][player].lastVisitCache = getRealmTime()
		updateSubFrame(frames["cache"])
  end
end

function frame:GARRISON_MISSION_NPC_OPENED()
	updateSubFrame(frames["mission"])
end

function frame:GARRISON_MISSION_LIST_UPDATE()
	updateSubFrame(frames["mission"])
end

function frame:SHIPMENT_CRAFTER_INFO(_,total,_,plotID)
	updateSubFrame(frames["workOrder"][plotID],nil,total)
end

function frame:SHIPMENT_CRAFTER_CLOSED()
	C_Garrison.RequestLandingPageShipmentInfo()
end

function frame:GARRISON_SHIPMENT_RECEIVED()
	C_Garrison.RequestLandingPageShipmentInfo()
end

function frame:BAG_UPDATE_DELAYED()
	C_Garrison.RequestLandingPageShipmentInfo()
end

function frame:ZONE_CHANGED_NEW_AREA()
	showMainFrame()
end

local function getBuildingsString()
	for k, v in next, C_Garrison.GetBuildings() do
		print(k, v)
	end
end

SLASH_LAZYCOMMANDER1 = "/lazycom"
SLASH_LAZYCOMMANDER2 = "/lazycommander"
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
		unlockMainFrame(LazyCommander.Unlocked)
		if LazyCommander.Unlocked == true then
			print("LazyCommander is now unlocked. Drag the window to your liking.")
		else
			print("LazyCommander is now locked. Drag the window to your liking.")
		end
	elseif Command == "hide" then
		LazyCommander.Shown = not LazyCommander.Shown
		showMainFrame()
		if LazyCommander.Shown == true then
			print("LazyCommander is now shown. The window will appear whenever you are in your garrison.")
		else
			print("LazyCommander is now hidden. The window will not appear until you show it again. Type /lazycommander show to make it reappear.")
		end
	elseif Command == "filter" then
		if not SubCommand then
			print([[Blacklisting is done by typing "/Lazycom Filter Herb Garden"]])
			for k, v in next, C_Garrison.GetBuildings() do
				print(k, v)
			end
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

-- GARRISON_BUILDING_ACTIVATED(plotID, buildingID) - fires on finalizing a building
-- GARRISON_BUILDING_UPDATED(buildingID, plotID)