--!strict

local Geometry = require(script.Parent.Geometry)
local SpatialIndex = require(script.Parent.SpatialIndex)
local State = require(script.Parent.State)
local Strategy = require(script.Parent.Strategy)
local Types = require(script.Parent.Types)

local STRAT_POS = Strategy.POS
local STRAT_PRIM = Strategy.PRIM
local STRAT_WORLD = Strategy.WORLD
local STRAT_CFRAME = Strategy.CFRAME
local STRAT_PIVOT = Strategy.PIVOT

local Group = {}
Group.__index = Group

function Group.new(priority: number?): Types.Group
	local g = (setmetatable({ UID = State.nextGroupId }, Group) :: any) :: Types.Group

	State.groupPriorityMap[g.UID] = priority or 1e6
	State.groupEnteredCallbacks[g.UID] = {}
	State.groupExitedCallbacks[g.UID] = {}
	State.groupActiveMembers[g.UID] = setmetatable({}, { __mode = 'k' }) :: any
	State.groupUIDToGroupObj[g.UID] = g

	State.nextGroupId += 1
	return g
end

function Group:trackItem(trackable: Types.Trackable, customData: any?)
	local data = State.trackables[trackable]
	if not data then
		local strat
		if typeof(trackable) == 'Instance' then
			if trackable:IsA('BasePart') then
				strat = STRAT_POS
			elseif trackable:IsA('Attachment') or trackable:IsA('Bone') then
				strat = STRAT_WORLD
			elseif trackable:IsA('Camera') then
				strat = STRAT_CFRAME
			elseif trackable:IsA('Model') then
				strat = trackable.PrimaryPart and STRAT_PRIM or STRAT_PIVOT
			end
		elseif typeof(trackable) == 'table' then
			if trackable.Position then
				strat = STRAT_POS
			elseif trackable.CFrame then
				strat = STRAT_CFRAME
			elseif trackable.WorldPosition then
				strat = STRAT_WORLD
			elseif trackable.GetPivot then
				strat = STRAT_PIVOT
			end
		end

		if not strat then
			error('Invalid trackable')
			return
		end

		data = {
			activeGroupMemberships = {},
			memberOfGroups = {},
			lastPosition = Vector3.zero,
			strategy = strat,
			isDirty = true,
		}
		State.trackables[trackable] = data
	end

	if customData ~= nil then
		if not State.trackableCustomData[trackable] then
			State.trackableCustomData[trackable] = {}
		end
		State.trackableCustomData[trackable][self.UID] = customData
	end

	data.memberOfGroups[self.UID] = true
	data.isDirty = true
end

function Group:untrackItem(trackable: Types.Trackable)
	local data = State.trackables[trackable]
	if not data then
		return
	end

	-- Exit Logic
	local oldZoneIdx = data.activeGroupMemberships[self.UID]
	if oldZoneIdx then
		if State.groupActiveMembers[self.UID] then
			State.groupActiveMembers[self.UID][trackable] = nil
		end

		local cbs = State.groupExitedCallbacks[self.UID]
		if cbs then
			local z = State.zoneIndexToZoneObj[oldZoneIdx]
			local cd = State.trackableCustomData[trackable] and State.trackableCustomData[trackable][self.UID]
			for _, fn in cbs do
				task.spawn(fn, trackable, z, cd)
			end
		end
	end

	data.activeGroupMemberships[self.UID] = nil
	data.memberOfGroups[self.UID] = nil

	if State.trackableCustomData[trackable] then
		State.trackableCustomData[trackable][self.UID] = nil
		if next(State.trackableCustomData[trackable]) == nil then
			State.trackableCustomData[trackable] = nil
		end
	end

	if next(data.memberOfGroups) == nil then
		State.trackables[trackable] = nil
	end
end

function Group:setPriority(p: number)
	State.groupPriorityMap[self.UID] = p
	State.isDirty = true
end

function Group:isItemInside(trackable: Types.Trackable): boolean
	local data = State.trackables[trackable]
	if not data then
		return false
	end
	return data.activeGroupMemberships[self.UID] ~= nil
end

function Group:isItemTracked(trackable: Types.Trackable): boolean
	local data = State.trackables[trackable]
	if not data then
		return false
	end
	return data.memberOfGroups[self.UID] == true
end

function Group:getTrackedItems(): { Types.Trackable }
	local results = {}
	for t, data in pairs(State.trackables) do
		if data.memberOfGroups[self.UID] then
			table.insert(results, t)
		end
	end
	return results
end

function Group:getItemsInside(): { Types.Trackable }
	local members = State.groupActiveMembers[self.UID]
	if not members then
		return {}
	end
	local results = {}
	for t, _ in pairs(members) do
		table.insert(results, t)
	end
	return results
end

function Group:getZones(): { Types.Zone }
	local results = {}
	for zoneIdx, watchingList in pairs(State.zoneWatchingGroups) do
		if table.find(watchingList, self.UID) then
			local zone = State.zoneIndexToZoneObj[zoneIdx]
			if zone then
				table.insert(results, zone)
			end
		end
	end
	return results
end

function Group:isPointInside(position: Vector3): boolean
	if not State.rootNode then
		return false
	end
	local isInside = false

	SpatialIndex.QueryPoint(State.rootNode, position, function(zoneId)
		if isInside then
			return
		end
		local groups = State.zoneWatchingGroups[zoneId]
		if groups and table.find(groups, self.UID) then
			if Geometry.IsPointInShape(position, State.objects[zoneId]) then
				isInside = true
			end
		end
	end)
	return isInside
end

function Group:onEntered(callback)
	table.insert(State.groupEnteredCallbacks[self.UID], callback)
	return function()
		local i = table.find(State.groupEnteredCallbacks[self.UID], callback)
		if i then
			table.remove(State.groupEnteredCallbacks[self.UID], i)
		end
	end
end

function Group:onExited(callback)
	table.insert(State.groupExitedCallbacks[self.UID], callback)
	return function()
		local i = table.find(State.groupExitedCallbacks[self.UID], callback)
		if i then
			table.remove(State.groupExitedCallbacks[self.UID], i)
		end
	end
end

function Group:destroy()
	local uid = self.UID

	-- Remove from zones
	for _, watchingList in pairs(State.zoneWatchingGroups) do
		local idx = table.find(watchingList, uid)
		while idx do
			table.remove(watchingList, idx)
			idx = table.find(watchingList, uid)
		end
	end

	for t, data in pairs(State.trackables) do
		if data.memberOfGroups[uid] then
			self:untrackItem(t)
		end
	end

	State.groupPriorityMap[uid] = nil
	State.groupEnteredCallbacks[uid] = nil
	State.groupExitedCallbacks[uid] = nil
	State.groupActiveMembers[uid] = nil
	State.groupUIDToGroupObj[uid] = nil

	State.isDirty = true
end

return Group
