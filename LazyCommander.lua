RaidFrame:UnregisterEvent('UPDATE_INSTANCE_INFO')
RaidInfoScrollFrame:SetScript('OnShow', nil)
RaidInfoFrame:SetScript('OnShow', function(self) self:Hide() end)


local f = CreateFrame("FRAME", "LazyCommander_Frame", UIParent)
f:RegisterEvent("PLAYER_ENTERING_WORLD")
local icon = {
	blank = {0,0,0,0},
	notready = [[Interface\Raidframe\ReadyCheck-NotReady]],
	ready = [[Interface\Raidframe\ReadyCheck-Ready]],
	mission = [[Interface\Icons\mountjournalportrait]],
	missionShipyard = [[Interface\Icons\inv_garrison_cargoship]],
	cache = [[Interface\Icons\inv_garrison_resource]],
}

local frames = {}
local realm = GetRealmName()
local player = UnitName("player")

local function globalVarsInit()
	if not LazyCommander then
		LazyCommander = {
			x = 500,
			y = 400,
			unlocked = true,
			show = true,
			autoWorkorder = true,
			ignoreOnShift = true,
			hideInCombat = true,
			hideOnDead = true,
			onlyInGarrison = true,
			combineMissionTypes = true,
			showCache = true,
			showMission = true,
		}
	end

	if not LazyCommander[realm] then
		LazyCommander[realm] = {}
	end
	if not LazyCommander[realm][player] then
		LazyCommander[realm][player] = {}
	end

	if not LazyCommander_C then
		LazyCommander_C = {
			blacklist = {}
		}
	end
end

f:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		self[event](...)
	else
		print('LazyCommander:',event,'has no function! Contact the addon developer on curse or github about this issue.')
	end
end)

local function getRealTime()
	local t = {}
	_,t.month,t.day,t.year = CalendarGetDate()
	t.hour,t.min = GetGameTime()
	return time(t)
end

local function getCacheSize()
	if _G.IsQuestFlaggedCompleted(37485) then
		return 1000
	elseif _G.IsQuestFlaggedCompleted(37935) or _G.IsQuestFlaggedCompleted(38445) then
		return 750
	else
		return 500
	end
end

local function inGarrison()
	local prevID = GetCurrentMapAreaID()
	SetMapToCurrentZone()
	local currentID = GetCurrentMapAreaID()
	SetMapByID(prevID)

	return IsMapGarrisonMap(currentID)
end

local function hasWorkOrder(buildingID)
	local _,_,shipmentCapacity = C_Garrison.GetLandingPageShipmentInfo(buildingID)
	if shipmentCapacity ~= nil and shipmentCapacity > 0 then
		return true
	else
		return false
	end
end

local function requestWorkorder(number)
	if number == 0 then
		return
	end
	if(C_Garrison.IsOnShipmentQuestForNPC()) then
		number = 1
	end
	print("requesting",number)
	local button = GarrisonCapacitiveDisplayFrame.StartWorkOrderButton
	if (number and number > 0 and button and button:IsEnabled()) then
		C_Garrison.RequestShipmentCreation(available)
	end
end

local function getIndicator(group, total, complete)
	if group =="workOrder" then
		if complete == 0 and total == 0 then
			return icon.blank
		elseif total - complete >= 5 then
			return icon.ready
		else
			return icon.notready
		end
	elseif group =="mission" or group == "shipMission" then
		if total == 0 and complete == 0 then
			return icon.blank
		elseif total == complete then
			return icon.notready
		elseif complete == 0 and total > 0 then
			return icon.ready
		elseif complete/total > 0.6 then
			return icon.notready
		else
			return icon.ready
		end
	elseif group == "cache" then
		if total == nil or complete == nil then
			return icon.notready
		elseif total - complete < 175 then
			return icon.notready
		else
			return icon.ready
		end
	end
end

local function getCount(group, id)
	local total, complete
	if group == "workOrder" then
		_,_,_, complete, total = C_Garrison.GetLandingPageShipmentInfo(id)
		if total == nil then
			total, complete = 0,0
		end
	elseif group == "mission" then
		total = #C_Garrison.GetInProgressMissions(id)
		complete = #C_Garrison.GetInProgressMissions(id)
	elseif group == "cache" then
		if LazyCommander[realm][player] then
			total = cacheSize
			complete = math.floor((getRealTime() - LazyCommander[realm][player].lastVisitCache) / 600)
			if complete > total then
				complete = total
			end
		end
	end
	return total,complete
end

local function canShow()
	if LazyCommander.show then
		if LazyCommander.hideInCombat and InCombatLockdown() then
			print("cant show because not in combat")
			return false
		elseif LazyCommander.hideOnDead and UnitIsDeadOrGhost("player") then
			print("cant show because dead")
			return false
		elseif LazyCommander.onlyInGarrison and not inGarrison() then
			print("cant show because in garrison")
			return false
		end
		print("can show")
		return true
	else
		return false
	end
end

local function showFrame(frame, show)
	if show == nil then
		show = canShow()
	end
	if frame:IsShown() ~= show then
		if show == true then
			frame:Show()
		else
			frame:Hide()
		end
	end
end


local function registerEvents(options)
	local events = {
		"QUEST_TURNED_IN",
		"SHOW_LOOT_TOAST",
		"GARRISON_MISSION_LIST_UPDATE",
	}
	for _,event in next, events do
		f:RegisterEvent(event)
	end

	if options then
		if LazyCommander.hideInCombat then
			f:RegisterEvent("PLAYER_REGEN_DISABLED")
			f:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
		if LazyCommander.onlyInGarrison then
			f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		end
		if LazyCommander.hideOnDead then
			f:RegisterEvent("PLAYER_ALIVE")
			f:RegisterEvent("PLAYER_DEAD")
		end
		if LazyCommander.autoWorkorder then
			f:RegisterEvent("SHIPMENT_CRAFTER_OPENED")
			f:RegisterEvent("SHIPMENT_CRAFTER_CLOSED")
		end
	end
end

local function unlockFrame(unlock)
	f:EnableMouse(unlock)
	f:SetMovable(unlock)
	LazyCommander.unlocked = not unlock
end

local function createFrame()
	registerEvents(true)
	print("created frame")
	f:Show()

	if not canShow() then
		print("hiding frame")
		f:Hide()
	end

	f:SetWidth(110)
	f:SetHeight(300)
	f:SetPoint("TOPLEFT", LazyCommander.x, LazyCommander.y)
	print(LazyCommander.x, LazyCommander.y)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")

	unlockFrame(LazyCommander.unlocked)
	f:SetScript("OnDragStart",f.StartMoving)
	f:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		LazyCommander.x, LazyCommander.y = f:GetBoundsRect()
	end)
end

function f:SHIPMENT_CRAFTER_OPENED()
	if LazyCommander.ignoreOnShift ~= IsShiftKeyDown or (LazyCommander.ignoreOnShift == false and IsShiftKeyDown == false) then
		f:RegisterEvent("SHIPMENT_UPDATE")
		f:RegisterEvent("SHIPMENT_CRAFTER_INFO")
	end
end

function f:SHIPMENT_CRAFTER_CLOSED()
	f:UnregisterEvent("LOOT_CLOSED")
	f:UnregisterEvent("SHIPMENT_UPDATE")
	f:UnregisterEvent("SHIPMENT_CRAFTER_INFO")
	C_Garrison.RequestLandingPageShipmentInfo()
end

function f:SHIPMENT_CRAFTER_INFO(progress,total,plotID)
	print(progress,total,plotID)
	f:UnregisterEvent("SHIPMENT_CRAFTER_INFO")
	f:RegisterEvent("LOOT_CLOSED")
	local request = total-progress
	requestWorkorder(request)

end

function f:LOOT_CLOSED()
	f:UnregisterEvent("LOOT_CLOSED")
	f:RegisterEvent("SHIPMENT_CRAFTER_INFO")
end

function f:PLAYER_REGEN_DISABLED()
	f:Hide()
end

function f:PLAYER_REGEN_ENABLED()
	if canShow() then
		f:Show()
	end
end

function f:PLAYER_DEAD()
 f:Hide()
end

function f:PLAYER_ALIVE()
	if canShow() then
		f:Show()
	end
end

function f:QUEST_TURNED_IN(questID)
	if questID == 37485 or questID == 37935 or questID == 38445 then
		setCacheSize()
		-- UPDATE CACHE FRAME NOW
	end
end

function f:SHOW_LOOT_TOAST(_,_,_,_,_,lootSource)
	if lootSource == 10 then
		LazyCommander[realm][player].lastVisitCache = getRealTime()
		-- UPDATE CACHE FRAME NOW
  end
end

function f:SHIPMENT_UPDATE(...)
	local shipmentUpdate = ...
	if shipmentUpdate then
		print(shipmentUpdate)
	end
end

function f:GARRISON_MISSION_LIST_UPDATE()
	--  UPDATE MISSION FRAME NOW
end

function f:ZONE_CHANGED_NEW_AREA()
	showFrame(f)
end

function f:PLAYER_ENTERING_WORLD()
	local frame = CreateFrame("FRAME", "FooAddonFrame");

	LazyCommander = false
	LazyCommander_C = false

	globalVarsInit()
	createFrame()
end