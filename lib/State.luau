--!strict

local Types = require(script.Parent.Types)

local State = {}

-- IDs
State.nextZoneId = 1
State.nextGroupId = 1

-- Geometry / Spatial
State.objects = {} :: { Types.BoundingVolume }
State.rootNode = nil :: Types.Node?
State.pendingRebuild = false
State.isDirty = false
State.frameBudget = 1 / 1000

-- Trackable Storage (Weak Keys)
State.trackables = (setmetatable({}, { __mode = 'k' }) :: any) :: { [Types.Trackable]: Types.TrackableData }
State.trackableCustomData = (setmetatable({}, { __mode = 'k' }) :: any) :: { [Types.Trackable]: { [number]: any } }

-- Maps
State.groupActiveMembers = {} :: { [number]: { [Types.Trackable]: boolean } }
State.groupPriorityMap = {} :: { [number]: number }
State.groupEnteredCallbacks = {} :: { [number]: { Types.Callback } }
State.groupExitedCallbacks = {} :: { [number]: { Types.Callback } }

State.zoneWatchingGroups = {} :: { [number]: { number } }
State.zoneIndexToZoneObj = {} :: { [number]: Types.Zone }
State.groupUIDToGroupObj = {} :: { [number]: Types.Group }

return State
