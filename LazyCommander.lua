local frame = CreateFrame("Frame", "LazyCommander_Frame", UIParent)
local realm = GetRealmName()
local player = UnitName("player")
local frames = {}

local function GlobalVarsInit()
	if not LazyCommanderData[realm] then
		LazyCommanderData[realm] = {}
	end
	if not LazyCommanderData[realm][player] then
		LazyCommanderData[realm][player] = {}
	end
	if not LazyCommanderData[realm][player] then
		local _,_,Class = UnitClass("player")
		LazyCommanderData[realm][player] = {
		Class = Class,
		CacheLastVisit = nil,
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
end

LCFrame:SetScript("OnEvent", function(self, event, ...)
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

local function GetUrgent(group, count)
	if group == "workOrder" then
	elseif group == "mission" then
		if count.total == count.completed and count.completed > 0 then
			return true
		elseif count.total == 0 and count.completed == 0 then
			return nil
		elseif count.completed == 0 and count.total > 0 then
			return CheckMarkTexture
		elseif count.completed / count.total > 0.5 then
			return CrossTexture
		elseif count.completed / count.total <= 0.5 then
			return CheckMarkTexture
		end
	elseif group == "cache" then
		if count.complete > 350 then
			return true
		else
			return false
		end
	end
end

local function getIcon(group, id)
	if group == "workOrder" then

	elseif group == "mission" then
		return [[Interface\Icons\mountjournalportrait]]
	elseif group == "cache" then
		return [[Interface\Icons\inv_garrison_resource]]
	end
end

local function updateIndicator(frame, texture)
	shown = true, texture = true
end

local function UpdateUrgent(frame)
	local urgent = GetUrgent(frame.group, frame.count)
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

local function GetCount(group, id, offset)
	local count = {}
	if group == "workOrder" then
		local _,_,count.capacity, count.complete, count.total = C_Garrison.GetLandingPageShipmentInfo(id)
	elseif group == "mission" then
		count.total = #C_Garrison.GetInProgressMissions()
		count.complete = #C_Garrison.GetCompleteMissions()
	elseif group == "cache" then
		if LazyCommander[realm][player].lastVisitCache ~= 0 then
			count.total = 500
			count.complete = (getRealmTime() - LazyCommander[realm][player].lastVisitCache) / 600
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

local function updateCount(frame)
	local count = GetCount(frame.group, frame.id)
	if count ~= frame.count then
		frame.count = count
		frame.string:SetText(count.complete.."/"..count.total)
	end
end

local function createFrame()
	local events = {
	"SHOW_LOOT_TOAST",
	}
	for _,event in next, Events do
		frame:RegisterEvent(event)
	end

	CreateAllData()

	frame:SetHeight(1)
	frame:SetWidth(120)
	frame:SetPoint("BOTTOMLEFT", LazyCommander.x,LazyCommander.y)
	LockLCFrame()
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")

	frame:SetScript("OnDragStart",LCFrame.StartMoving)
	frame:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		LazyCommander.x = math.ceil(frame:GetLeft())
		LazyCommander.y = math.ceil(frame:GetBottom())
	end)
end

local previousFrame = false
local count = 1
local function createSubFrame(group, id)
	-- if frames[group][id] ~= nil then
	-- 	print("Frame already exists!!")
	-- 	return
	-- end

	local subFrame = CreateFrame("Frame","LazyCom_"..count,frame)
	subFrame.Icon = GetIcon(group, id)
	count = count + 1

	if not previousFrame then
		subFrame:SetPoint("TOPRIGHT", "LazyCommander_Frame", "TOPRIGHT");
	else
		subFrame:SetPoint("TOPRIGHT", previousFrame, "BOTTOMRIGHT",0,0);
	end
	previousFrame = subFrame
	subFrame:SetHeight(30)
	subFrame:SetWidth(80)

	subFrame.Icon = subFrame:CreateTexture(nil,"BACKGROUND")
	subFrame.Icon:SetTexture(Data.Texture)
	subFrame.Icon:SetPoint("TOPLEFT")
	subFrame.Icon:SetHeight(30)
	subFrame.Icon:SetWidth(30)

	subFrame.String = subFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
	subFrame.String:SetPoint("TOPLEFT", subFrame.Icon, 35, -7)
	subFrame.String:SetText(Data.Text)

	subFrame.Indicator = subFrame:CreateTexture(nil,"BACKGROUND")
	subFrame.Indicator:SetPoint("TOPRIGHT", subFrame.String, 20, 4)
	subFrame.Indicator:SetHeight(20)
	subFrame.Indicator:SetWidth(20)
	UpdateIndicatorTexture(subFrame, Data.Indicator)

	frames[group][id] = subFrame
end

local function somethingInitLol()
	createSubFrame("cache")
	createSubFrame("mission")
end

function frame:PLAYER_LOGIN()
	somethingInitLol()
end