local frame = CreateFrame("Frame", "LazyCommander_Frame", UIParent)
frame:RegisterEvent("GARRISON_BUILDING_LIST_UPDATE")
local realm = GetRealmName()
local player = UnitName("player")
local buildings = {}
local frames = {}

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
			Unlocked = true
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

local function getBuildingID(plotID)
	local buildingID = C_Garrison.GetOwnedBuildingInfoAbbrev(plotID)
	return buildingID
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
			count.complete = 500
			count.total = 500
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

local function updateIndicator(frame, texture)
	if texture ~= nil then
		if not frame.indicator:IsShown() then
			frame.indicator.Show()
		end
		if frame.indicator:GetTexture() ~= texture then
			frame.indicator:SetTexture(texture)
		end
	else
		if frame.indicator:Show() then
			frame.indicator:Hide()
			frame.indicator:SetTexture(nil)
		end
	end
end

local function updateUrgent(frame)
	local urgent = getUrgent(frame.group, frame.count)
	if urgent ~= frame.urgent then
		frame.urgent = urgent
		if urgent == true then
			updateIndicator(frame, [[Interface\RaidFrame\ReadyCheck-NotReady]])
		elseif urgent == false then
			updateIndicator(frame, [[Interface\RaidFrame\ReadyCheck-Ready]])
		elseif urgent == nil then
			updateIndicator(frame)
		end
	end
end

local function updateString(frame)
	local count = frame.count
	frame.string:SetText(count.complete.."/"..count.total)
end

local function unlockMainFrame(unlock)
	frame:EnableMouse(unlock)
	frame:SetMovable(unlock)
end

local function createMainFrame()
	local events = {
	"SHOW_LOOT_TOAST",
	"GARRISON_MISSION_STARTED",
	"GARRISON_MISSION_FINISHED",
	"GARRISON_MISSION_NPC_OPENED",
	"GARRISON_MISSION_COMPLETE_RESPONSE",
	"SHIPMENT_CRAFTER_INFO",
	"SHIPMENT_CRAFTER_CLOSED",
	"GARRISON_BUILDING_PLACED",

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

local function updateSubFrame(frame, init)
	print(frame.buildingID)
	local count = getCount(frame.group, frame.buildingID, false)
	if count ~= frame.count then
		frame.count = count
		updateUrgent(frame)
		updateString(frame)
	end
end

local previousFrame = false
local frameCount = 1
local function createSubFrame(group, buildingID)
	local subFrame = CreateFrame("Frame","LazyCom_"..frameCount,frame)
	frame:SetHeight(frameCount*30)
	frameCount = frameCount + 1

	subFrame.buildingID = buildingID
	subFrame.group = group

	if not previousFrame then
		subFrame:SetPoint("TOPLEFT", frame, "TOPLEFT");
	else
		subFrame:SetPoint("TOPRIGHT", previousFrame, "BOTTOMRIGHT",0,0);
	end
	previousFrame = subFrame
	subFrame:SetHeight(30)
	subFrame:SetWidth(100)

	subFrame.icon = subFrame:CreateTexture(nil,"BACKGROUND")
	subFrame.icon:SetTexture(getIcon(group, buildingID))
	subFrame.icon:SetPoint("TOPLEFT")
	subFrame.icon:SetHeight(30)
	subFrame.icon:SetWidth(30)

	subFrame.string = subFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
	subFrame.string:SetPoint("TOPLEFT", subFrame.icon, 35, -7)

	subFrame.indicator = subFrame:CreateTexture(nil,"BACKGROUND")
	subFrame.indicator:SetPoint("TOPRIGHT", subFrame.string , 20, 3)
	subFrame.indicator:SetHeight(20)
	subFrame.indicator:SetWidth(20)

	updateSubFrame(subFrame)
	return subFrame
end

function tickerCache()
	if LazyCommanderData[realm][player].lastVisitCache then
		local count = getCount("cache",nil,true)

		C_Timer.After(count.offset*600+60, function()
			updateSubFrame(frames["cache"])
			local ticker = C_Timer.NewTicker(600, function()
				updateSubFrame(frames["cache"])
			end)
		end)
	end
end


function frame:GARRISON_BUILDING_PLACED(plotID)
	if not frames["workOrder"][plotID] then
		local buildingID = getBuildingID(plotID)
		if hasWorkOrder(buildingID) then
			local data = {}
			data.name,_,data.capacity,data.complete,data.total,data.creationtime,data.duration = C_Garrison.GetLandingPageShipmentInfo(buildingID)
			data.buildingID = buildingID
			if data.duration == nil then
				data.fullShipment = true
			else
				data.fullShipment = data.creationtime + ((data.total-data.complete)*data.duration)
			end
			LazyCommanderData[realm][player].Buildings[plotID] = data
			frames["workOrder"][plotID] = createSubFrame("workOrder", buildingID)
		end
	end
end

local init = false
function frame:GARRISON_BUILDING_LIST_UPDATE()
	if not init then
		init = true
		GlobalVarsInit()
		createMainFrame()
		frames["cache"] = createSubFrame("cache")
		frames["mission"] = createSubFrame("mission")
		frames["workOrder"] = {}
		tickerCache()
		if LazyCommanderData[realm][player].lastVisitCache then
			tickerCache()
		end
	end
end

function frame:SHOW_LOOT_TOAST(_,_,_,_,_,_,lootSource)
	if lootSource == 10 then
		LazyCommanderData[realm][player].lastVisitCache = getRealmTime()
		updateSubFrame(frames["cache"])
  end
end

function frame:GARRISON_MISSION_STARTED()
	updateSubFrame(frames["mission"])
end

function frame:GARRISON_MISSION_FINISHED()
	updateSubFrame(frames["mission"])
end

function frame:GARRISON_MISSION_NPC_OPENED()
	updateSubFrame(frames["mission"])
end

function frame:SHIPMENT_CRAFTER_CLOSED(...)

	updateSubFrame(frame["workOrder"][plotID])
end

function frame:SHIPMENT_CRAFTER_INFO(...)
	print(...)
end

SlashCmdList["LAZYCOMMANDER"] = function(msg, editbox)
	-- msg = string.lower(msg)
	-- local Pos = string.find(msg,"%s+")
	-- local Command
	-- local SubCommand
	-- if Pos ~= nil then
	-- 	SubCommand = strtrim(string.sub(msg,Pos+1,string.len(msg))," ")
	-- 	Command = strtrim(string.sub(msg,1,Pos)," ")
	-- else
	-- 	Command = msg
	-- 	SubCommand = nil
	-- end

	-- if Command == "lock" then
	-- 	LazyCommander.Unlocked = not LazyCommander.Unlocked
	-- 	LockLCFrame()
	-- 	if LazyCommander.Unlocked == true then
	-- 		print("LazyCommander is now unlocked. Drag the window to your liking.")
	-- 	else
	-- 		print("LazyCommander is now locked. Drag the window to your liking.")
	-- 	end
	-- elseif Command == "hide" then
	-- 	LazyCommander.Hidden = not LazyCommander.Hidden
	-- 	ShowOrHideLCFrame()
	-- 	if LazyCommander.Hidden == true then
	-- 		print("LazyCommander is now hidden. The window will not appear until you show it again. Type /lazycommander show to make it reappear.")
	-- 	else
	-- 		print("LazyCommander is now shown. The window will appear whenever you are in your garrison.")
	-- 	end
	-- elseif Command == "filter" then
	-- 	if not SubCommand then
	-- 		print([[Blacklisting is done by typing "/Lazycom Filter Herb Garden"]])
	-- 		print("Current Buildings:",GetBuildingsString())
	-- 	elseif SubCommand then
	-- 		if BlacklistBuilding(SubCommand) then
	-- 			print("Done:", SubCommand)
	-- 		else
	-- 			print("Error:",SubCommand,"is not a known building.")
	-- 			print("Current Buildings:",GetBuildingsString())
	-- 		end
	-- 	end
	-- else
	-- 	print("--LazyCommander Commands--")
	-- 	print("/Lazycom lock - Locks or Unlocks the window in place")
	-- 	print("/Lazycom hide - Shows or Hides the window when in garrison")
	-- 	print("/Lazycom filter - Filter out a building")
	-- end
end