--!strict

export type ShapeType = 'Block' | 'Ball' | 'Cylinder' | 'Wedge' | 'CornerWedge'

export type BoundingVolume = {
	Position: Vector3,
	CFrame: CFrame,
	HalfSize: Vector3,
	Shape: ShapeType,

	-- sphere specific
	radius: number?,

	-- cylinder specific
	start: Vector3?,
	axis: Vector3?,
	axisLength: number?,
	radiusSquared: number?,
}

export type Node = {
	left: Node?,
	right: Node?,
	min: Vector3,
	max: Vector3,
	id: number, -- -1 for internal nodes
}

export type TrackableTable = {
	Position: Vector3?,
	WorldPosition: Vector3?,
	CFrame: CFrame?,
	GetPivot: ((self: any) -> CFrame)?,
	[any]: any,
}

export type Trackable = BasePart | Model | Camera | Attachment | Bone | TrackableTable

export type UID = number

export type TrackableData = {
	activeGroupMemberships: { [UID]: number },
	memberOfGroups: { [UID]: boolean },
	lastPosition: Vector3,
	strategy: number,
	isDirty: boolean,
}

export type Zone = {
	bindToGroups: (zone: Zone, ...Group) -> (),
	unbindToGroups: (zone: Zone, ...Group) -> (),
	getGroups: (zone: Zone) -> { Group },
	destroy: (zone: Zone) -> (),
	index: number,
	part: BasePart?,
}

export type Callback = (Trackable, Zone, any?) -> ()

export type Group = {
	trackItem: (self: Group, trackable: Trackable, customData: any?) -> (),
	untrackItem: (self: Group, trackable: Trackable) -> (),
	setPriority: (self: Group, priority: number) -> (),
	isItemInside: (self: Group, trackable: Trackable) -> boolean,
	isPointInside: (self: Group, position: Vector3) -> boolean,
	isItemTracked: (self: Group, trackable: Trackable) -> boolean,
	getTrackedItems: (self: Group) -> { Trackable },
	getItemsInside: (self: Group) -> { Trackable },
	getZones: (self: Group) -> { Zone },
	destroy: (self: Group) -> (),
	onEntered: (self: Group, callback: Callback) -> () -> (),
	onExited: (self: Group, callback: Callback) -> () -> (),
	UID: UID,
}

return nil
