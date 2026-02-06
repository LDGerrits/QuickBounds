--!native
--!strict

local RunService = game:GetService('RunService')

local Geometry = require(script.Geometry)
local SpatialIndex = require(script.SpatialIndex)
local Types = require(script.Types)
local State = require(script.State)
local Zone = require(script.Zone)
local Group = require(script.Group)
local Strategy = require(script.Strategy)

local candidatePriority = table.create(16)
local candidateIndex = table.create(16)
local candidateList = table.create(16)

local MOVE_THRESHOLD = 0.1
local MOVE_THRESHOLD_SQ = MOVE_THRESHOLD * MOVE_THRESHOLD

local STRAT_POS = Strategy.POS
local STRAT_PRIM = Strategy.PRIM
local STRAT_WORLD = Strategy.WORLD
local STRAT_CFRAME = Strategy.CFRAME

local trackables = State.trackables
local objects = State.objects
local zoneWatchingGroups = State.zoneWatchingGroups
local groupPriorityMap = State.groupPriorityMap
local trackableCustomData = State.trackableCustomData
local groupEnteredCallbacks = State.groupEnteredCallbacks
local groupActiveMembers = State.groupActiveMembers
local groupExitedCallbacks = State.groupExitedCallbacks
local zoneIndexToZoneObj = State.zoneIndexToZoneObj

local function fireCallback(callbacks, trackable, zone, customData)
	if not callbacks then
		return
	end
	for _, cb in callbacks do
		task.spawn(cb, trackable, zone, customData)
	end
end

RunService.Heartbeat:Connect(function()
	if State.pendingRebuild then
		debug.profilebegin('QuickBounds_Build')
		State.rootNode = SpatialIndex.Build(State.objects)
		State.pendingRebuild = false
		debug.profileend()
		State.isDirty = true
	end

	if not State.rootNode then
		return
	end

	debug.profilebegin('QuickBounds_Step')
	local start = os.clock()
	local processed = 0
	local forceRefresh = State.isDirty
	State.isDirty = false

	for trackable, data in trackables do
		local pos
		local strategy = data.strategy
		if strategy == STRAT_POS then
			pos = (trackable :: any).Position
		elseif strategy == STRAT_WORLD then
			pos = (trackable :: any).WorldPosition
		elseif strategy == STRAT_PRIM then
			pos = (trackable :: any).PrimaryPart.Position
		elseif strategy == STRAT_CFRAME then
			pos = (trackable :: any).CFrame.Position
		else
			pos = (trackable :: any):GetPivot().Position
		end

		if not forceRefresh and not data.isDirty then
			local lastPos = data.lastPosition
			local dx = pos.X - lastPos.X
			local dy = pos.Y - lastPos.Y
			local dz = pos.Z - lastPos.Z
			local d2 = (dx * dx) + (dy * dy) + (dz * dz)
			if d2 < MOVE_THRESHOLD_SQ then
				continue
			end
		end

		data.lastPosition = pos
		data.isDirty = false

		-- Query spatial map
		table.clear(candidatePriority)
		table.clear(candidateIndex)
		table.clear(candidateList)
		local cCount = 0
		local lowestWin = math.huge

		SpatialIndex.QueryPoint(State.rootNode, pos, function(zoneId)
			local groups = zoneWatchingGroups[zoneId]
			if not groups then
				return
			end

			if not Geometry.IsPointInShape(pos, objects[zoneId]) then
				return
			end

			for _, gUID in groups do
				if data.memberOfGroups[gUID] then
					local pri = groupPriorityMap[gUID] or 1e6
					local existPri = candidatePriority[gUID]

					if not existPri or pri < existPri then
						if not existPri then
							cCount += 1
							candidateList[cCount] = gUID
						end
						candidateIndex[gUID] = zoneId
						candidatePriority[gUID] = pri
						if pri < lowestWin then
							lowestWin = pri
						end
					end
				end
			end
		end)

		local current = data.activeGroupMemberships

		-- Check exits
		for gUID, oldZoneIdx in current do
			local newPri = candidatePriority[gUID]
			if not newPri or newPri > lowestWin then
				current[gUID] = nil

				if groupActiveMembers[gUID] then
					groupActiveMembers[gUID][trackable] = nil
				end

				local zone = zoneIndexToZoneObj[oldZoneIdx]
				local cd = trackableCustomData[trackable] and trackableCustomData[trackable][gUID]
				fireCallback(groupExitedCallbacks[gUID], trackable, zone, cd)
			end
		end

		-- Check entries
		for i = 1, cCount do
			local gUID = candidateList[i]
			local pri = candidatePriority[gUID]

			if pri <= lowestWin then
				if not current[gUID] then
					local newZoneIdx = candidateIndex[gUID]
					current[gUID] = newZoneIdx

					groupActiveMembers[gUID][trackable] = true

					local zone = zoneIndexToZoneObj[newZoneIdx]
					local cd = trackableCustomData[trackable] and trackableCustomData[trackable][gUID]
					fireCallback(groupEnteredCallbacks[gUID], trackable, zone, cd)
				end
			end
		end

		processed += 1
		if processed % 32 == 0 and (os.clock() - start) > State.frameBudget then
			break
		end
	end
	debug.profileend()
end)

export type Group = Types.Group
export type Zone = Types.Zone
export type Trackable = Types.Trackable

return {
	newZone = Zone.new,
	newGroup = Group.new,

	newZoneFromPart = function(part: BasePart): Types.Zone
		local shape: Types.ShapeType = 'Block'
		if (part :: any).Shape == Enum.PartType.Ball then
			shape = 'Ball'
		elseif (part :: any).Shape == Enum.PartType.Cylinder then
			shape = 'Cylinder'
		end
		return Zone.new(part.CFrame, part.Size, shape, part)
	end,

	IsItemTrackable = function(item: any): boolean
		if typeof(item) == 'Instance' then
			if item:IsA('BasePart') then
				return true
			elseif item:IsA('Attachment') or item:IsA('Bone') then
				return true
			elseif item:IsA('Camera') then
				return true
			elseif item:IsA('Model') then
				return true
			end
		elseif typeof(item) == 'table' then
			if item.Position then
				return true
			elseif item.CFrame then
				return true
			elseif item.WorldPosition then
				return true
			elseif item.GetPivot then
				return true
			end
		end

		return false
	end,

	IsItemTracked = Group.IsItemTracked,

	GetGroupsForItem = function(trackable: Types.Trackable): { Types.Group }
		local data = State.trackables[trackable]
		if not data then
			return {}
		end
		local results = {}
		for gUID, _ in pairs(data.memberOfGroups) do
			local g = State.groupUIDToGroupObj[gUID]
			if g then
				table.insert(results, g)
			end
		end
		return results
	end,

	GetGroupsAtItem = function(trackable: Types.Trackable): { Types.Group }
		local data = State.trackables[trackable]
		if not data then
			return {}
		end
		local results = {}
		for gUID, _ in pairs(data.activeGroupMemberships) do
			local g = State.groupUIDToGroupObj[gUID]
			if g then
				table.insert(results, g)
			end
		end
		return results
	end,

	GetGroupsAtPoint = function(position: Vector3): { Types.Group }
		local results = {}
		local foundUIDs = {}
		if State.rootNode then
			SpatialIndex.QueryPoint(State.rootNode, position, function(zoneId)
				if Geometry.IsPointInShape(position, State.objects[zoneId]) then
					local groups = State.zoneWatchingGroups[zoneId]
					if groups then
						for _, uid in groups do
							if not foundUIDs[uid] then
								foundUIDs[uid] = true
								local g = State.groupUIDToGroupObj[uid]
								if g then
									table.insert(results, g)
								end
							end
						end
					end
				end
			end)
		end
		return results
	end,

	SetFrameBudget = function(n: number)
		State.frameBudget = n
	end,
}
